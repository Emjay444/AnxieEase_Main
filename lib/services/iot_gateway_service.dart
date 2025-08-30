import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bt_gateway.dart';
import '../models/device_reading.dart';

/// IoT Gateway Service
///
/// Transforms phone into an IoT gateway that:
/// 1. Receives sensor data via Bluetooth
/// 2. Streams data to Firebase Realtime Database
/// 3. Enables multi-device access to sensor data
/// 4. Provides cloud-based analytics and alerts
class IoTGatewayService {
  final BtGateway _btGateway;
  final FirebaseDatabase _realtimeDb;
  final FirebaseFirestore _firestore;

  late DatabaseReference _deviceRef;
  late DatabaseReference _currentRef;

  StreamSubscription<DeviceReading>? _readingsSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  String? _currentDeviceId;
  String? _currentUserId;
  bool _isRunning = false;

  // IoT Analytics
  final List<double> _heartRateWindow = [];
  DateTime? _lastAlertTime;
  static const int _heartRateWindowSize = 10;
  static const Duration _alertCooldown = Duration(minutes: 5);

  IoTGatewayService(this._btGateway, this._realtimeDb, this._firestore);

  /// Start IoT Gateway for a specific device and user
  Future<void> startGateway({
    required String deviceId,
    required String userId,
    required String deviceAddress,
  }) async {
    if (_isRunning) {
      debugPrint('🚨 IoT Gateway already running');
      return;
    }

    _currentDeviceId = deviceId;
    _currentUserId = userId;

    // Setup Firebase Realtime Database references
    _deviceRef = _realtimeDb.ref('devices/$deviceId');
    _currentRef = _deviceRef.child('current');

    // Set device metadata
    await _deviceRef.child('metadata').set({
      'userId': userId,
      'deviceAddress': deviceAddress,
      'gatewayStarted': ServerValue.timestamp,
      'status': 'connecting',
      'type': 'wearable_anxiety_monitor',
    });

    // Connect to Bluetooth device
    final connected = await _btGateway.connect(deviceAddress);
    if (!connected) {
      debugPrint('❌ Failed to connect to Bluetooth device');
      await _deviceRef.child('metadata/status').set('connection_failed');
      return;
    }

    // Start listening to sensor data
    _readingsSubscription = _btGateway.readings.listen(_onSensorReading);
    _connectionSubscription =
        _btGateway.connectionState.listen(_onConnectionChange);

    _isRunning = true;
    debugPrint('🚀 IoT Gateway started for device: $deviceId');

    await _deviceRef.child('metadata/status').set('active');
  }

  /// Stop IoT Gateway
  Future<void> stopGateway() async {
    if (!_isRunning) return;

    _readingsSubscription?.cancel();
    _connectionSubscription?.cancel();

    await _btGateway.disconnect();

    if (_currentDeviceId != null) {
      await _deviceRef.child('metadata').update({
        'status': 'offline',
        'gatewayStoppedAt': ServerValue.timestamp,
      });
    }

    _isRunning = false;
    _currentDeviceId = null;
    _currentUserId = null;
    _heartRateWindow.clear();

    debugPrint('🛑 IoT Gateway stopped');
  }

  /// Handle incoming sensor readings
  void _onSensorReading(DeviceReading reading) async {
    if (!_isRunning || _currentDeviceId == null) return;

    try {
      // Convert to IoT format
      final iotData = _convertToIoTFormat(reading);

      // Stream to Firebase Realtime Database (for real-time access)
      await _currentRef.set(iotData);

      // Also store in Firestore (for historical analysis)
      await _firestore
          .collection('iot_devices')
          .doc(_currentDeviceId)
          .collection('readings')
          .add({
        ...iotData,
        'userId': _currentUserId,
        'gatewayId': _getGatewayId(),
      });

      // Perform IoT analytics
      await _performIoTAnalytics(reading);

      debugPrint(
          '📡 IoT data streamed: HR=${reading.heartRate}, Worn=${reading.worn}');
    } catch (e) {
      debugPrint('❌ Error streaming IoT data: $e');
    }
  }

  /// Convert DeviceReading to IoT format
  Map<String, dynamic> _convertToIoTFormat(DeviceReading reading) {
    return {
      'timestamp': reading.timestamp.millisecondsSinceEpoch,
      'isoTimestamp': reading.timestamp.toIso8601String(),

      // Enhanced sensor data for AnxieEase001 compatibility
      'sensors': {
        'heartRate': reading.heartRate,
        'spo2': reading.spo2,
        'bodyTemperature': reading.bodyTemp,
        'ambientTemperature': reading.ambientTemp,
        'motion': {
          'pitch': reading.pitch,
          'roll': reading.roll,
          'acceleration': {
            'x': reading.accelX,
            'y': reading.accelY,
            'z': reading.accelZ,
          },
          'gyroscope': {
            'x': reading.gyroX,
            'y': reading.gyroY,
            'z': reading.gyroZ,
          },
        },
      },

      // Device status (compatible with existing AnxieEase format)
      'device': {
        'batteryRaw': reading.battPercRaw,
        'batterySmoothed': reading.battPercSmoothed,
        'worn': reading.worn,
        'isConnected': true,
        'lastSeen': reading.timestamp.millisecondsSinceEpoch,
      },

      // Enhanced anxiety detection (merge with existing system)
      'anxietyDetection': _generateAnxietyData(reading),

      // Gateway information
      'gateway': {
        'id': _getGatewayId(),
        'userId': _currentUserId,
        'location': 'mobile_app',
        'version': '2.0_iot',
      },
    };
  }

  /// Generate anxiety detection data compatible with existing AnxieEase001 format
  Map<String, dynamic> _generateAnxietyData(DeviceReading reading) {
    if (reading.heartRate == null || !reading.worn) {
      return {
        'confidence': 0.0,
        'severity': 'unknown',
        'timestamp': reading.timestamp.millisecondsSinceEpoch,
        'heartRate': null,
        'source': 'iot_gateway',
      };
    }

    // Enhanced anxiety detection based on multiple sensors
    double confidence = 0.0;

    // Heart rate analysis
    final hr = reading.heartRate!;
    if (hr > 100) {
      confidence += 0.4;
    } else if (hr > 80) {
      confidence += 0.2;
    }

    // SpO2 analysis (low oxygen can indicate stress)
    if (reading.spo2 < 95) {
      confidence += 0.3;
    }

    // Motion analysis (excessive movement can indicate anxiety)
    final motionIntensity =
        (reading.accelX.abs() + reading.accelY.abs() + reading.accelZ.abs()) /
            3;
    if (motionIntensity > 2.0) {
      confidence += 0.2;
    }

    // Body temperature (stress can affect temperature)
    if (reading.bodyTemp != null && reading.bodyTemp! > 37.5) {
      confidence += 0.1;
    }

    confidence = confidence.clamp(0.0, 1.0);

    return {
      'confidence': confidence,
      'severity': confidence > 0.7
          ? 'severe'
          : confidence > 0.5
              ? 'moderate'
              : confidence > 0.3
                  ? 'mild'
                  : 'normal',
      'timestamp': reading.timestamp.millisecondsSinceEpoch,
      'heartRate': hr,
      'spo2': reading.spo2,
      'motionIntensity': motionIntensity,
      'bodyTemp': reading.bodyTemp,
      'source': 'iot_gateway_enhanced',
    };
  }

  /// Perform IoT Analytics and trigger alerts
  Future<void> _performIoTAnalytics(DeviceReading reading) async {
    if (reading.heartRate == null || !reading.worn) return;

    // Add to heart rate window for trend analysis
    _heartRateWindow.add(reading.heartRate!);
    if (_heartRateWindow.length > _heartRateWindowSize) {
      _heartRateWindow.removeAt(0);
    }

    // Calculate anxiety indicators
    final avgHeartRate =
        _heartRateWindow.reduce((a, b) => a + b) / _heartRateWindow.length;
    final heartRateVariability = _calculateHRV();

    // Anxiety detection algorithm
    final anxietyLevel =
        _detectAnxietyLevel(avgHeartRate, heartRateVariability, reading);

    // Update real-time anxiety status
    await _currentRef.child('analytics').set({
      'anxietyLevel': anxietyLevel,
      'avgHeartRate': avgHeartRate,
      'heartRateVariability': heartRateVariability,
      'lastAnalysis': ServerValue.timestamp,
      'samplesAnalyzed': _heartRateWindow.length,
    });

    // Trigger alerts if needed
    if (anxietyLevel == 'high' || anxietyLevel == 'severe') {
      await _triggerIoTAlert(anxietyLevel, avgHeartRate, reading);
    }
  }

  /// Calculate Heart Rate Variability
  double _calculateHRV() {
    if (_heartRateWindow.length < 3) return 0.0;

    double sum = 0;
    for (int i = 1; i < _heartRateWindow.length; i++) {
      final diff = _heartRateWindow[i] - _heartRateWindow[i - 1];
      sum += diff * diff;
    }

    return sum / (_heartRateWindow.length - 1);
  }

  /// Detect anxiety level using IoT analytics
  String _detectAnxietyLevel(double avgHR, double hrv, DeviceReading reading) {
    // Enhanced anxiety detection using multiple sensors

    // Heart rate thresholds
    if (avgHR > 120) return 'severe';
    if (avgHR > 100) return 'high';
    if (avgHR > 85) return 'moderate';
    if (avgHR > 70) return 'mild';

    // Consider motion patterns (high motion + high HR = stress)
    final totalAccel =
        (reading.accelX.abs() + reading.accelY.abs() + reading.accelZ.abs());
    if (avgHR > 90 && totalAccel > 15) return 'high';

    // Consider temperature (stress can affect body temp)
    if (reading.bodyTemp != null && reading.bodyTemp! > 37.5 && avgHR > 85) {
      return 'moderate';
    }

    return 'normal';
  }

  /// Trigger IoT Alert (Logging only - app handles notifications)
  Future<void> _triggerIoTAlert(
      String level, double heartRate, DeviceReading reading) async {
    // Cooldown check
    if (_lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!) < _alertCooldown) {
      return;
    }

    _lastAlertTime = DateTime.now();

    debugPrint(
        '🚨 IoT Alert detected: $level anxiety (HR: $heartRate) - App will handle notifications');
  }

  /// Handle connection state changes
  void _onConnectionChange(bool connected) async {
    if (_currentDeviceId == null) return;

    await _deviceRef.child('metadata').update({
      'bluetoothConnected': connected,
      'lastConnectionChange': ServerValue.timestamp,
    });

    if (!connected) {
      await _currentRef.child('connectionStatus').set('disconnected');
      debugPrint('📡 IoT Gateway: Bluetooth disconnected');
    } else {
      await _currentRef.child('connectionStatus').set('connected');
      debugPrint('📡 IoT Gateway: Bluetooth reconnected');
    }
  }

  /// Get unique gateway identifier
  String _getGatewayId() {
    // You might want to use device fingerprint or user ID
    return 'gateway_${_currentUserId ?? 'unknown'}';
  }

  /// Get current device data stream (for real-time UI updates)
  Stream<Map<String, dynamic>?> getCurrentDeviceStream(String deviceId) {
    return _realtimeDb.ref('devices/$deviceId/current').onValue.map((event) {
      if (event.snapshot.value == null) return null;
      try {
        // Safe conversion from Firebase Object to Map<String, dynamic>
        final value = event.snapshot.value;
        if (value is Map) {
          return Map<String, dynamic>.from(value);
        } else {
          debugPrint('❌ Unexpected Firebase data type: ${value.runtimeType}');
          return <String, dynamic>{};
        }
      } catch (e) {
        debugPrint('❌ Error converting Firebase data: $e');
        return <String, dynamic>{};
      }
    });
  }

  /// Get device alerts stream
  Stream<List<Map<String, dynamic>>> getAlertsStream(String deviceId) {
    return _realtimeDb
        .ref('devices/$deviceId/alerts')
        .orderByChild('timestamp')
        .limitToLast(10)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return <Map<String, dynamic>>[];

      try {
        final value = event.snapshot.value;
        if (value is Map) {
          final alertsMap = Map<String, dynamic>.from(value);
          return alertsMap.values
              .whereType<Map>()
              .map((alert) => Map<String, dynamic>.from(alert))
              .toList()
            ..sort((a, b) {
              final aTime = a['timestamp'] as int? ?? 0;
              final bTime = b['timestamp'] as int? ?? 0;
              return bTime.compareTo(aTime);
            });
        } else {
          debugPrint('❌ Unexpected alerts data type: ${value.runtimeType}');
          return <Map<String, dynamic>>[];
        }
      } catch (e) {
        debugPrint('❌ Error converting alerts data: $e');
        return <Map<String, dynamic>>[];
      }
    });
  }

  /// Check if gateway is running
  bool get isRunning => _isRunning;

  /// Get current device ID
  String? get currentDeviceId => _currentDeviceId;

  /// Dispose resources
  void dispose() {
    stopGateway();
  }
}
