import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'iot_gateway_service.dart';
import 'bt_gateway.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// Device Manager Service
///
/// Handles automatic device detection, pairing, and persistent IoT Gateway management:
/// - Auto-detects paired Bluetooth devices
/// - Manages device setup and configuration
/// - Maintains persistent IoT Gateway connection
/// - Handles automatic reconnection
class DeviceManager extends ChangeNotifier {
  static final DeviceManager _instance = DeviceManager._internal();
  factory DeviceManager() => _instance;
  DeviceManager._internal();

  // Services
  late final IoTGatewayService _iotGateway;
  late final BtGateway _btGateway;

  // Device state
  BluetoothDevice? _selectedDevice;
  bool _isGatewayRunning = false;
  bool _isAutoConnecting = false;
  String _status = 'Initializing...';

  // Settings keys
  static const String _deviceAddressKey = 'selected_device_address';
  static const String _deviceNameKey = 'selected_device_name';
  static const String _isSetupCompleteKey = 'device_setup_complete';
  static const String _autoStartGatewayKey = 'auto_start_gateway';

  // Getters
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isGatewayRunning => _isGatewayRunning;
  bool get isAutoConnecting => _isAutoConnecting;
  String get status => _status;

  /// Initialize the device manager
  Future<void> initialize() async {
    debugPrint('🔧 DeviceManager: Initializing...');

    _btGateway = BtGateway(FirebaseFirestore.instance);
    _iotGateway = IoTGatewayService(
      _btGateway,
      FirebaseDatabase.instance,
      FirebaseFirestore.instance,
    );

    // Load saved device configuration
    await _loadDeviceConfiguration();

    // Auto-start gateway if enabled and device is configured
    if (await _isAutoStartEnabled() && _selectedDevice != null) {
      await _autoStartGateway();
    }
  }

  /// Load saved device configuration
  Future<void> _loadDeviceConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceAddress = prefs.getString(_deviceAddressKey);
      final deviceName = prefs.getString(_deviceNameKey);

      if (deviceAddress != null && deviceName != null) {
        // Find the device in bonded devices
        final bondedDevices =
            await FlutterBluetoothSerial.instance.getBondedDevices();
        _selectedDevice = bondedDevices.firstWhere(
          (device) => device.address == deviceAddress,
          orElse: () => throw Exception('Device not found'),
        );

        debugPrint(
            '📱 DeviceManager: Loaded saved device: ${_selectedDevice!.name}');
        _status = 'Device configured: ${_selectedDevice!.name}';
      } else {
        _status = 'No device configured';
      }
    } catch (e) {
      debugPrint('❌ DeviceManager: Error loading device configuration: $e');
      _status = 'Error loading device configuration';
    }
  }

  /// Save device configuration
  Future<void> _saveDeviceConfiguration(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceAddressKey, device.address);
      await prefs.setString(_deviceNameKey, device.name ?? 'Unknown Device');
      await prefs.setBool(_isSetupCompleteKey, true);

      debugPrint(
          '💾 DeviceManager: Saved device configuration: ${device.name}');
    } catch (e) {
      debugPrint('❌ DeviceManager: Error saving device configuration: $e');
    }
  }

  /// Get all paired Bluetooth devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      await _requestPermissions();

      debugPrint('📱 DeviceManager: Requesting paired devices...');
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();

      debugPrint('📱 DeviceManager: Found ${devices.length} paired devices:');
      for (final device in devices) {
        debugPrint('  - ${device.name} (${device.address})');
      }

      return devices;
    } catch (e) {
      debugPrint('❌ DeviceManager: Error getting paired devices: $e');
      return [];
    }
  }

  /// Scan for available Bluetooth devices (including unpaired)
  Future<List<BluetoothDevice>> scanForDevices() async {
    try {
      await _requestPermissions();

      debugPrint('🔍 DeviceManager: Starting Bluetooth scan...');
      _status = 'Scanning for devices...';
      notifyListeners();

      // Check if Bluetooth is enabled
      final isEnabled =
          await FlutterBluetoothSerial.instance.isEnabled ?? false;
      if (!isEnabled) {
        debugPrint('❌ DeviceManager: Bluetooth is not enabled, cannot scan');
        _status = 'Bluetooth not enabled';
        notifyListeners();
        return [];
      }

      // Start discovery
      debugPrint('🔍 DeviceManager: Starting discovery...');
      final discovery = FlutterBluetoothSerial.instance.startDiscovery();
      final List<BluetoothDevice> foundDevices = [];
      final Set<String> foundAddresses = {}; // To avoid duplicates

      // Create a completer to wait for scan completion
      final completer = Completer<void>();
      bool hasCompleted = false;

      // Listen for discovered devices
      final subscription = discovery.listen(
        (result) {
          if (hasCompleted) return;

          final device = result.device;
          debugPrint(
              '🔍 DeviceManager: Discovery result - ${device.name} (${device.address})');

          // Avoid duplicates
          if (foundAddresses.contains(device.address)) {
            debugPrint(
                '🔍 DeviceManager: Skipping duplicate device: ${device.address}');
            return;
          }
          foundAddresses.add(device.address);

          debugPrint(
              '🔍 DeviceManager: Found device: ${device.name} (${device.address})');

          // Add all devices for now (we'll filter later if needed)
          foundDevices.add(device);
        },
        onDone: () {
          if (!hasCompleted) {
            debugPrint('🔍 DeviceManager: Scan completed naturally');
            hasCompleted = true;
            completer.complete();
          }
        },
        onError: (error) {
          if (!hasCompleted) {
            debugPrint('❌ DeviceManager: Scan error: $error');
            hasCompleted = true;
            completer.complete();
          }
        },
      );

      // Wait for scan to complete with timeout
      try {
        debugPrint('🔍 DeviceManager: Waiting for scan to complete...');
        await completer.future.timeout(const Duration(seconds: 20));
      } catch (e) {
        debugPrint(
            '⏰ DeviceManager: Scan timeout, proceeding with found devices');
      }

      // Cancel subscription if still active
      try {
        await subscription.cancel();
        debugPrint('🔍 DeviceManager: Discovery subscription cancelled');
      } catch (e) {
        debugPrint('⚠️ DeviceManager: Error cancelling subscription: $e');
      }

      debugPrint(
          '🔍 DeviceManager: Scan complete, found ${foundDevices.length} devices');
      _status = 'Scan complete';
      notifyListeners();

      return foundDevices;
    } catch (e) {
      debugPrint('❌ DeviceManager: Error scanning for devices: $e');
      _status = 'Scan failed';
      notifyListeners();
      return [];
    }
  }

  /// Check if a device is an IoT device (customize this filter)
  bool _isIoTDevice(BluetoothDevice device) {
    final name = device.name?.toLowerCase() ?? '';

    // For now, accept all devices with names (not null or empty)
    // This allows users to see all available devices
    if (name.isEmpty) {
      return false; // Skip devices without names
    }

    // Optional: Add specific patterns if you want to filter
    // final iotPatterns = [
    //   'anxieease',
    //   'iot',
    //   'health',
    //   'monitor',
    //   'sensor',
    //   'esp32',
    //   'wearable',
    //   'fitness',
    //   'smartwatch',
    // ];
    // return iotPatterns.any((pattern) => name.contains(pattern));

    return true; // Accept all devices with names
  }

  /// Alternative scanning method using a simpler approach
  Future<List<BluetoothDevice>> scanForDevicesSimple() async {
    try {
      await _requestPermissions();

      debugPrint('🔍 DeviceManager: Starting simple Bluetooth scan...');
      _status = 'Scanning for devices...';
      notifyListeners();

      // Check if Bluetooth is enabled
      final isEnabled =
          await FlutterBluetoothSerial.instance.isEnabled ?? false;
      if (!isEnabled) {
        debugPrint('❌ DeviceManager: Bluetooth is not enabled, cannot scan');
        _status = 'Bluetooth not enabled';
        notifyListeners();
        return [];
      }

      final List<BluetoothDevice> foundDevices = [];
      final Set<String> foundAddresses = {};

      // Start discovery and collect devices
      debugPrint('🔍 DeviceManager: Starting simple discovery...');

      // Use a timer-based approach instead of completer
      final discovery = FlutterBluetoothSerial.instance.startDiscovery();

      discovery.listen(
        (result) {
          final device = result.device;
          debugPrint(
              '🔍 DeviceManager: Simple scan found: ${device.name} (${device.address})');

          if (!foundAddresses.contains(device.address)) {
            foundAddresses.add(device.address);
            foundDevices.add(device);
          }
        },
        onDone: () {
          debugPrint('🔍 DeviceManager: Simple scan completed');
        },
        onError: (error) {
          debugPrint('❌ DeviceManager: Simple scan error: $error');
        },
      );

      // Wait for a fixed duration
      debugPrint('🔍 DeviceManager: Waiting 15 seconds for devices...');
      await Future.delayed(const Duration(seconds: 15));

      debugPrint(
          '🔍 DeviceManager: Simple scan complete, found ${foundDevices.length} devices');
      _status = 'Scan complete';
      notifyListeners();

      return foundDevices;
    } catch (e) {
      debugPrint('❌ DeviceManager: Error in simple scan: $e');
      _status = 'Scan failed';
      notifyListeners();
      return [];
    }
  }

  /// Request necessary permissions
  Future<void> _requestPermissions() async {
    try {
      debugPrint('🔐 DeviceManager: Requesting permissions...');

      // Request permissions
      final results = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      // Check if all permissions are granted
      for (final result in results.entries) {
        debugPrint(
            '🔐 DeviceManager: ${result.key} permission: ${result.value}');
      }

      // Check if Bluetooth is enabled
      final isEnabled =
          await FlutterBluetoothSerial.instance.isEnabled ?? false;
      debugPrint('🔐 DeviceManager: Bluetooth enabled: $isEnabled');

      if (!isEnabled) {
        debugPrint('⚠️ DeviceManager: Bluetooth is not enabled');
        // You might want to show a dialog asking user to enable Bluetooth
      }
    } catch (e) {
      debugPrint('❌ DeviceManager: Error requesting permissions: $e');
    }
  }

  /// Select and configure a device
  Future<bool> selectDevice(BluetoothDevice device) async {
    try {
      _status = 'Configuring device: ${device.name}';
      notifyListeners();

      debugPrint(
          '🔧 DeviceManager: Attempting to configure device: ${device.name} (${device.address})');

      // For now, skip the availability test as it might be causing issues
      // We'll test the connection when starting the gateway instead

      // Save device configuration
      await _saveDeviceConfiguration(device);
      _selectedDevice = device;

      _status = 'Device configured: ${device.name}';
      notifyListeners();

      debugPrint('✅ DeviceManager: Device selected: ${device.name}');
      return true;
    } catch (e) {
      debugPrint('❌ DeviceManager: Error selecting device: $e');
      _status = 'Error configuring device';
      notifyListeners();
      return false;
    }
  }

  /// Auto-start IoT Gateway
  Future<void> _autoStartGateway() async {
    if (_selectedDevice == null) {
      debugPrint('❌ DeviceManager: No device selected for auto-start');
      return;
    }

    if (_isGatewayRunning) {
      debugPrint('✅ DeviceManager: Gateway already running');
      return;
    }

    try {
      _isAutoConnecting = true;
      _status = 'Auto-connecting to ${_selectedDevice!.name}...';
      notifyListeners();

      await _iotGateway.startGateway(
        deviceId: 'AnxieEase001',
        userId: 'AnxieEase001',
        deviceAddress: _selectedDevice!.address,
      );

      _isGatewayRunning = true;
      _isAutoConnecting = false;
      _status = 'IoT Gateway Active - ${_selectedDevice!.name}';

      debugPrint('✅ DeviceManager: Auto-started IoT Gateway');
      notifyListeners();
    } catch (e) {
      _isAutoConnecting = false;
      _status = 'Auto-connect failed: $e';
      debugPrint('❌ DeviceManager: Auto-start failed: $e');
      notifyListeners();
    }
  }

  /// Start IoT Gateway manually
  Future<bool> startGateway() async {
    if (_selectedDevice == null) {
      debugPrint('❌ DeviceManager: No device selected');
      return false;
    }

    try {
      _status = 'Starting IoT Gateway...';
      notifyListeners();

      await _iotGateway.startGateway(
        deviceId: 'AnxieEase001',
        userId: 'AnxieEase001',
        deviceAddress: _selectedDevice!.address,
      );

      _isGatewayRunning = true;
      _status = 'IoT Gateway Active - ${_selectedDevice!.name}';

      debugPrint('✅ DeviceManager: Started IoT Gateway');
      notifyListeners();
      return true;
    } catch (e) {
      _status = 'Failed to start gateway: $e';
      debugPrint('❌ DeviceManager: Start gateway failed: $e');
      notifyListeners();
      return false;
    }
  }

  /// Stop IoT Gateway
  Future<void> stopGateway() async {
    try {
      await _iotGateway.stopGateway();
      _isGatewayRunning = false;
      _status = 'IoT Gateway Stopped';

      debugPrint('🛑 DeviceManager: Stopped IoT Gateway');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ DeviceManager: Error stopping gateway: $e');
    }
  }

  /// Check if auto-start is enabled
  Future<bool> _isAutoStartEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoStartGatewayKey) ?? true; // Default to true
  }

  /// Set auto-start preference
  Future<void> setAutoStartEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoStartGatewayKey, enabled);
    debugPrint(
        '🔧 DeviceManager: Auto-start ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Check if device setup is complete
  Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isSetupCompleteKey) ?? false;
  }

  /// Clear device configuration
  Future<void> clearDeviceConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceAddressKey);
      await prefs.remove(_deviceNameKey);
      await prefs.remove(_isSetupCompleteKey);

      _selectedDevice = null;
      _status = 'Device configuration cleared';

      debugPrint('🗑️ DeviceManager: Device configuration cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ DeviceManager: Error clearing configuration: $e');
    }
  }

  /// Get device setup status
  String getSetupStatus() {
    if (_selectedDevice == null) {
      return 'No device configured';
    }

    if (_isGatewayRunning) {
      return 'Connected to ${_selectedDevice!.name}';
    }

    return 'Device ready: ${_selectedDevice!.name}';
  }

  /// Dispose resources (but keep gateway running)
  @override
  void dispose() {
    // Note: We don't stop the gateway here to keep it running
    // The gateway will continue running even when this service is disposed
    debugPrint('🔧 DeviceManager: Disposed (gateway continues running)');
    super.dispose();
  }
}
