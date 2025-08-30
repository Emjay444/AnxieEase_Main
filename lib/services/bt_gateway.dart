import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device_reading.dart';

/// Bluetooth Classic SPP Gateway Service
///
/// Handles connection to wearable device using Bluetooth Classic Serial Port Profile.
/// Parses incoming JSON sensor data and forwards to Firebase Firestore.
///
/// Key features:
/// - Robust JSON parsing (handles missing braces)
/// - Battery percentage smoothing with moving average
/// - Automatic null handling for heart rate/body temp when device not worn
/// - Vibration command support (VIB:x,y format)
/// - Real-time data streaming to UI via broadcast stream
class BtGateway {
  final FirebaseFirestore _db;
  BluetoothConnection? _connection;
  final _lineBuffer = StringBuffer();
  final _batteryWindow = <double>[];
  final int batteryWindowSize = 5;

  // Broadcast latest parsed reading to UI
  final _readingCtrl = StreamController<DeviceReading>.broadcast();

  /// Stream of parsed device readings
  Stream<DeviceReading> get readings => _readingCtrl.stream;

  /// Current connection status
  bool get isConnected => _connection?.isConnected == true;

  /// Connection state stream for UI updates
  final _connectionStateCtrl = StreamController<bool>.broadcast();
  Stream<bool> get connectionState => _connectionStateCtrl.stream;

  BtGateway(this._db);

  /// Check if a specific device is available and ready
  Future<bool> isDeviceAvailable(String address) async {
    try {
      final bondedDevices =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      final targetDevice =
          bondedDevices.where((d) => d.address == address).firstOrNull;

      if (targetDevice == null) {
        debugPrint('❌ Device $address not found in bonded devices');
        return false;
      }

      debugPrint(
          '✅ Device found: ${targetDevice.name} ($address) - Bonded: ${targetDevice.isBonded}');
      return targetDevice.isBonded;
    } catch (e) {
      debugPrint('❌ Error checking device availability: $e');
      return false;
    }
  }

  /// Request necessary Bluetooth permissions for Android 12+
  ///
  /// Requests both new Android 12+ permissions and legacy permissions
  /// for maximum compatibility across Android versions.
  Future<bool> requestPermissions() async {
    try {
      final permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        // Legacy discovery fallback for older Android versions
        Permission.locationWhenInUse,
      ];

      final results = await permissions.request();

      // Check if critical permissions were granted
      final bluetoothGranted =
          results[Permission.bluetoothConnect]?.isGranted ?? false;
      final scanGranted = results[Permission.bluetoothScan]?.isGranted ?? false;
      final locationGranted =
          results[Permission.locationWhenInUse]?.isGranted ?? false;

      // Need either new permissions or legacy location permission
      return (bluetoothGranted && scanGranted) || locationGranted;
    } catch (e) {
      debugPrint('Error requesting Bluetooth permissions: $e');
      return false;
    }
  }

  /// Get list of bonded (paired) Bluetooth devices
  ///
  /// Returns devices that have been previously paired with this Android device.
  /// User should select their wearable device from this list.
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      return bonded;
    } catch (e) {
      debugPrint('Error getting bonded devices: $e');
      return [];
    }
  }

  /// Connect to Bluetooth device by MAC address
  ///
  /// Establishes SPP connection and starts listening for incoming data.
  /// Automatically requests permissions if not already granted.
  Future<bool> connect(String address, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            '🔵 Bluetooth connection attempt $attempt/$maxRetries to $address');

        // Ensure permissions are granted
        final permissionsGranted = await requestPermissions();
        if (!permissionsGranted) {
          debugPrint('❌ Bluetooth permissions not granted');
          return false;
        }

        // Disconnect existing connection if any
        await disconnect();

        // Add small delay between retries
        if (attempt > 1) {
          await Future.delayed(Duration(seconds: attempt));
          debugPrint('⏳ Waiting ${attempt}s before retry...');
        }

        // Check if Bluetooth is enabled
        final isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
        if (isEnabled != true) {
          debugPrint('❌ Bluetooth is not enabled');
          return false;
        }

        // Check if target device is available
        final isAvailable = await isDeviceAvailable(address);
        if (!isAvailable) {
          debugPrint('❌ Target device $address is not available or bonded');
          return false;
        }

        // Establish new connection with timeout
        debugPrint('🔗 Attempting to connect to $address...');
        _connection = await BluetoothConnection.toAddress(address)
            .timeout(const Duration(seconds: 10));

        // Verify connection is established
        if (_connection?.isConnected != true) {
          debugPrint('❌ Connection established but not active');
          _connection = null;
          continue;
        }

        // Start listening for incoming data
        _connection!.input!.listen(
          _onData,
          onDone: _onDisconnected,
          onError: (error, stackTrace) {
            debugPrint('📡 Bluetooth connection error: $error');
            _onDisconnected();
          },
        );

        // Notify connection state
        if (!_connectionStateCtrl.isClosed) {
          _connectionStateCtrl.add(true);
        }

        debugPrint('✅ Connected to Bluetooth device: $address');
        return true;
      } catch (e) {
        debugPrint('❌ Connection attempt $attempt failed: $e');
        _connection = null;

        // If this was the last attempt, notify failure
        if (attempt == maxRetries) {
          _onDisconnected();
          debugPrint('💥 All connection attempts failed for $address');
          return false;
        }
      }
    }
    return false;
  }

  /// Disconnect from current Bluetooth device
  Future<void> disconnect() async {
    try {
      await _connection?.close();
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    } finally {
      _connection = null;
      _onDisconnected();
    }
  }

  /// Handle connection loss
  void _onDisconnected() {
    _connection = null;
    // Only add to stream if it's not closed
    if (!_connectionStateCtrl.isClosed) {
      _connectionStateCtrl.add(false);
    }
    debugPrint('Bluetooth connection lost');
  }

  /// Clean up resources
  void dispose() {
    _readingCtrl.close();
    _connectionStateCtrl.close();
    disconnect();
  }

  /// Handle incoming SPP data chunks
  ///
  /// Assembles complete lines from data chunks, then parses JSON.
  /// Handles partial data reception and line boundaries correctly.
  void _onData(Uint8List data) {
    try {
      final chunk = String.fromCharCodes(data);
      _lineBuffer.write(chunk);

      // Split on newlines; keep the last partial segment in buffer
      final parts = _lineBuffer.toString().split(RegExp(r'\r?\n'));

      // If the last char was newline, last part is ""; otherwise it's partial
      _lineBuffer.clear();
      if (parts.isNotEmpty && parts.last.isNotEmpty) {
        _lineBuffer.write(parts.removeLast());
      } else {
        parts.removeLast();
      }

      // Process each complete line
      for (final line in parts) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        _parseLine(trimmed);
      }
    } catch (e) {
      debugPrint('Error processing incoming data: $e');
    }
  }

  /// Parse a single line of JSON data
  ///
  /// Attempts to parse as JSON, with fallback for missing braces.
  /// Tolerates malformed data by skipping invalid lines.
  void _parseLine(String line) {
    Map<String, dynamic>? jsonData;

    try {
      // Try parsing as-is first
      jsonData = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      try {
        // Try wrapping in braces if missing
        final wrapped = line.startsWith('{') ? line : '{$line}';
        jsonData = jsonDecode(wrapped) as Map<String, dynamic>;
      } catch (e) {
        // Skip malformed line
        debugPrint('Skipping malformed JSON line: $line');
        return;
      }
    }

    _handleParsedJson(jsonData);
  }

  /// Process parsed JSON data into DeviceReading
  ///
  /// Handles type conversion, worn status logic, and battery smoothing.
  void _handleParsedJson(Map<String, dynamic> json) {
    try {
      // Helper to safely convert to double
      double toDouble(dynamic value) {
        if (value is int) return value.toDouble();
        if (value is double) return value;
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      }

      // Parse worn status (can be 0/1 or false/true)
      final wornValue = json['worn'];
      final isWorn = (wornValue == 1) || (wornValue == true);

      // Handle battery smoothing
      final rawBattery = toDouble(json['battPerc']);
      if (rawBattery > 0) {
        _batteryWindow.add(rawBattery);
        if (_batteryWindow.length > batteryWindowSize) {
          _batteryWindow.removeAt(0);
        }
      }

      final smoothedBattery = _batteryWindow.isEmpty
          ? rawBattery
          : _batteryWindow.reduce((a, b) => a + b) / _batteryWindow.length;

      // Create reading with null heart rate/body temp when not worn
      final reading = DeviceReading(
        timestamp: DateTime.now(),
        heartRate: isWorn ? toDouble(json['heartRate']) : null,
        spo2: toDouble(json['spo2']),
        bodyTemp: isWorn ? toDouble(json['bodyTemp']) : null,
        ambientTemp: toDouble(json['ambientTemp']),
        pitch: toDouble(json['pitch']),
        roll: toDouble(json['roll']),
        accelX: toDouble(json['accelX']),
        accelY: toDouble(json['accelY']),
        accelZ: toDouble(json['accelZ']),
        gyroX: toDouble(json['gyroX']),
        gyroY: toDouble(json['gyroY']),
        gyroZ: toDouble(json['gyroZ']),
        battPercRaw: rawBattery,
        battPercSmoothed: smoothedBattery,
        worn: isWorn,
      );

      // Broadcast to UI (only if stream is not closed)
      if (!_readingCtrl.isClosed) {
        _readingCtrl.add(reading);
      }
    } catch (e) {
      debugPrint('Error processing parsed JSON: $e');
    }
  }

  /// Send vibration command to device
  ///
  /// Sends VIB:x,y\n command where:
  /// - x = number of vibrations (clamped to 0-2)
  /// - y = delay between vibrations in ms (clamped to 0-5000)
  Future<bool> sendVibration({required int count, required int delayMs}) async {
    if (!isConnected) {
      debugPrint('Cannot send vibration: not connected');
      return false;
    }

    try {
      final clampedCount = count.clamp(0, 2);
      final clampedDelay = delayMs.clamp(0, 5000);
      final command = 'VIB:$clampedCount,$clampedDelay\n';
      final bytes = Uint8List.fromList(command.codeUnits);

      debugPrint(
          '🔵 Sending vibration command: "$command" (${command.length} chars)');
      debugPrint(
          '🔵 Command bytes: ${bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');

      _connection!.output.add(bytes);
      await _connection!.output.allSent;

      debugPrint(
          '✅ Vibration command sent successfully: VIB:$clampedCount,$clampedDelay');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending vibration command: $e');
      return false;
    }
  }

  /// Send alternative vibration command formats for testing
  Future<bool> sendVibrationAlt(
      {required int count, required int delayMs, String format = 'VIB'}) async {
    if (!isConnected) {
      debugPrint('Cannot send vibration: not connected');
      return false;
    }

    try {
      final clampedCount = count.clamp(0, 2);
      final clampedDelay = delayMs.clamp(0, 5000);

      String command;
      switch (format) {
        case 'VIBRATE':
          command = 'VIBRATE:$clampedCount,$clampedDelay\n';
          break;
        case 'VIB_JSON':
          command =
              '{"cmd":"vibrate","count":$clampedCount,"delay":$clampedDelay}\n';
          break;
        case 'SIMPLE':
          command = 'V$clampedCount\n';
          break;
        default:
          command = 'VIB:$clampedCount,$clampedDelay\n';
      }

      final bytes = Uint8List.fromList(command.codeUnits);

      debugPrint('🔵 Sending alternative vibration ($format): "$command"');
      debugPrint(
          '🔵 Command bytes: ${bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');

      _connection!.output.add(bytes);
      await _connection!.output.allSent;

      debugPrint('✅ Alternative vibration command sent: $format');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending alternative vibration command: $e');
      return false;
    }
  }

  /// Send raw command for debugging
  ///
  /// Useful for testing device responses or sending custom commands.
  Future<bool> sendRawCommand(String command,
      {bool appendNewline = true}) async {
    if (!isConnected) {
      debugPrint('Cannot send command: not connected');
      return false;
    }

    try {
      final output = appendNewline ? '$command\n' : command;
      _connection!.output.add(Uint8List.fromList(output.codeUnits));
      await _connection!.output.allSent;

      debugPrint('Sent raw command: $output');
      return true;
    } catch (e) {
      debugPrint('Error sending raw command: $e');
      return false;
    }
  }

  /// Write device reading to Firestore
  ///
  /// Stores reading under /deviceData/{deviceId}/readings collection.
  /// Each reading becomes a separate document with auto-generated ID.
  Future<bool> writeToFirestore(String deviceId, DeviceReading reading) async {
    try {
      await _db
          .collection('deviceData')
          .doc(deviceId)
          .collection('readings')
          .add(reading.toFirestore());

      return true;
    } catch (e) {
      debugPrint('Error writing to Firestore: $e');
      return false;
    }
  }

  /// Batch write multiple readings to Firestore
  ///
  /// More efficient for uploading queued readings when connection is restored.
  Future<bool> batchWriteToFirestore(
      String deviceId, List<DeviceReading> readings) async {
    if (readings.isEmpty) return true;

    try {
      final batch = _db.batch();
      final collection =
          _db.collection('deviceData').doc(deviceId).collection('readings');

      for (final reading in readings) {
        final docRef = collection.doc();
        batch.set(docRef, reading.toFirestore());
      }

      await batch.commit();
      debugPrint('Batch wrote ${readings.length} readings to Firestore');
      return true;
    } catch (e) {
      debugPrint('Error batch writing to Firestore: $e');
      return false;
    }
  }

  /// Get device metadata for Firestore device document
  ///
  /// Returns basic info about the connected device for the parent document.
  Map<String, dynamic> getDeviceMetadata(
      String deviceAddress, String? deviceName) {
    return {
      'deviceAddress': deviceAddress,
      'deviceName': deviceName ?? 'Unknown Device',
      'lastConnected': DateTime.now().toIso8601String(),
      'connectionType': 'bluetooth_classic_spp',
      'appVersion': '1.0.0', // You might want to get this from package_info
    };
  }
}
