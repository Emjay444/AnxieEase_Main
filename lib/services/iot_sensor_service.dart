import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../utils/logger.dart';

/// Pure IoT Sensor Service
///
/// Simulates IoT sensor data and manages Firebase integration
/// without any Bluetooth dependencies. This creates realistic
/// health monitoring data for testing and demonstration.
class IoTSensorService extends ChangeNotifier {
  static final IoTSensorService _instance = IoTSensorService._internal();
  factory IoTSensorService() => _instance;
  IoTSensorService._internal();

  // Firebase instances are accessed lazily after Firebase.initializeApp()
  FirebaseDatabase get _realtimeDb => FirebaseDatabase.instance;

  late DatabaseReference _deviceRef;
  late DatabaseReference _currentRef;

  Timer? _sensorTimer;
  bool _isActive = false;
  bool _initialized = false;
  int _updateIntervalSeconds = 10; // 10 second interval as requested
  static const int _minInterval = 5; // Minimum 5 seconds
  static const int _maxInterval = 15; // Maximum 15 seconds

  // REAL DEVICE MODE: Disable automatic mock data generation
  bool _enableMockDataGeneration =
      false; // Set to true only for testing without real device
  final String _deviceId = 'AnxieEase001';
  final String _userId = 'user_001';

  // Current sensor values
  double _heartRate = 72.0;
  double _spo2 = 98.0;
  double _bodyTemperature = 36.5;
  double _ambientTemperature = 23.0;
  double _batteryLevel = 85.0;
  bool _isDeviceWorn = false;
  bool _isConnected = false;

  // Realistic value ranges and patterns
  final Random _random = Random();
  DateTime? _lastStressEvent;
  bool _isStressMode = false;
  String _currentSeverityLevel =
      'mild'; // Use severity levels: mild, moderate, severe

  // Getters for current values
  double get heartRate => _isDeviceWorn ? _heartRate : 0;
  double get spo2 => _isDeviceWorn ? _spo2 : 0;
  double get bodyTemperature => _isDeviceWorn ? _bodyTemperature : 0;
  double get ambientTemperature => _ambientTemperature;
  double get batteryLevel => _batteryLevel;
  bool get isDeviceWorn => _isDeviceWorn;
  bool get isConnected => _isConnected;
  bool get isActive => _isActive;
  String get deviceId => _deviceId;
  String get userId => _userId;
  String get currentSeverityLevel => _currentSeverityLevel;

  /// Initialize the IoT sensor service
  Future<void> initialize() async {
    AppLogger.d('IoTSensorService: Initializing');

    // Ensure Firebase is initialized (especially important for tests)
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        AppLogger.e('IoTSensorService: Firebase init failed', e as Object?);
      }
    }

    _deviceRef = _realtimeDb.ref('devices/$_deviceId');
    _currentRef = _realtimeDb.ref('devices/$_deviceId/current');

    // In real device mode (default), do not perform any client writes to RTDB
    // to avoid permission-denied due to lack of Firebase auth.
    if (!_enableMockDataGeneration) {
      AppLogger.i(
          'IoTSensorService: Real-device mode, skipping RTDB initialization writes');
    } else {
      // Initialize clean wearable data structure - only essential sensor data
      try {
        AppLogger.d('IoTSensorService: Using clean structure');
        await _currentRef.set({
          'heartRate': _heartRate.round(),
          'spo2': _spo2.round(),
          'bodyTemp': double.parse(_bodyTemperature.toStringAsFixed(1)),
          'battPerc': _batteryLevel.round(),
          'worn': _isDeviceWorn,
          'timestamp': ServerValue.timestamp,
        });
      } catch (e) {
        AppLogger.w('IoTSensorService: Skipped RTDB init write (mock-only)');
      }
    }

    AppLogger.d('IoTSensorService: Initialized');
    _initialized = true;
  }

  /// Start IoT sensor simulation (ONLY FOR TESTING - Real device should write directly to Firebase)
  Future<void> startSensors() async {
    if (_isActive) {
      AppLogger.d('IoTSensorService: Already active');
      return;
    }

    if (!_enableMockDataGeneration) {
      AppLogger.i(
          'IoTSensorService: Mock data generation disabled - using real wearable device');
      AppLogger.i(
          'IoTSensorService: Real device should write directly to Firebase at /devices/AnxieEase001/current');

      // Set status as active but don't generate mock data
      _isActive = true;
      _isConnected = true;

      if (!_initialized) {
        await initialize();
      }

      // Do not write any RTDB status in real-device mode to avoid permission issues
      try {
        await _deviceRef.child('metadata/status').set('active');
      } catch (e) {
        AppLogger.w(
            'IoTSensorService: Skipping RTDB status write in real-device mode');
      }

      notifyListeners();
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    AppLogger.d('IoTSensorService: Starting simulation (TEST MODE ONLY)');

    _isActive = true;
    _isConnected = true;
    // Don't force worn state - let it be determined naturally during simulation

    // Update device status (mock mode only)
    try {
      await _deviceRef.child('metadata/status').set('active');
      await _currentRef.child('connectionStatus').set('connected');
    } catch (e) {
      AppLogger.w('IoTSensorService: Skipped RTDB status writes (mock-only)');
    }

    // Start sensor data generation ONLY if mock mode enabled
    _startSensorTimer();

    notifyListeners();
    AppLogger.d('IoTSensorService: Started');
  }

  /// Stop IoT sensor simulation
  Future<void> stopSensors() async {
    if (!_isActive) {
      AppLogger.d('IoTSensorService: Already stopped');
      return;
    }

    AppLogger.d('IoTSensorService: Stopping');

    _sensorTimer?.cancel();
    _sensorTimer = null;

    _isActive = false;
    _isConnected = false;
    _isDeviceWorn = false;

    // Update device status (mock mode only)
    if (_enableMockDataGeneration) {
      try {
        await _deviceRef.child('metadata/status').set('offline');
        await _currentRef.child('connectionStatus').set('disconnected');
        await _currentRef.child('worn').set(false);
      } catch (e) {
        AppLogger.w('IoTSensorService: Skipped RTDB stop writes (mock-only)');
      }
    }

    notifyListeners();
    AppLogger.d('IoTSensorService: Stopped');
  }

  void _startSensorTimer() {
    // Only start timer if mock data generation is enabled
    if (!_enableMockDataGeneration) {
      AppLogger.d(
          'IoTSensorService: Mock data generation disabled - timer not started');
      return;
    }

    // Prevent multiple timer instances
    _sensorTimer?.cancel();
    _sensorTimer = null;

    AppLogger.d(
        'IoTSensorService: 🕒 Starting timer with ${_updateIntervalSeconds}s interval (TEST MODE)');
    _sensorTimer = Timer.periodic(
        Duration(seconds: _updateIntervalSeconds), _generateSensorData);
  }

  void setUpdateInterval(int seconds) {
    final clamped = seconds.clamp(_minInterval, _maxInterval);
    if (clamped == _updateIntervalSeconds) return;
    _updateIntervalSeconds = clamped;
    if (_isActive) {
      AppLogger.d('IoTSensorService: Interval -> ${_updateIntervalSeconds}s');
      _startSensorTimer();
    }
  }

  void setLowPowerMode(bool enabled) {
    setUpdateInterval(enabled ? 8 : 3);
  }

  /// Generate realistic sensor data (ONLY when mock mode enabled)
  void _generateSensorData(Timer timer) async {
    try {
      // CRITICAL SAFETY CHECKS - Prevent any interference
      if (!_isActive || !_enableMockDataGeneration) {
        AppLogger.d(
            'IoTSensorService: ⚠️ Skipping data generation - monitoring not active or mock mode disabled');
        return; // Don't generate data if monitoring stopped or mock disabled
      }

      // For testing: Keep device always worn to avoid 0 values
      _isDeviceWorn = true;

      AppLogger.d(
          'IoTSensorService: 🔄 Generating data cycle - Active: $_isActive, Worn: $_isDeviceWorn');

      // Check if device is not worn - skip sensor data generation
      if (!_isDeviceWorn) {
        AppLogger.d(
            'IoTSensorService: Device not worn - skipping sensor data generation');

        // Generate minimal sensor payload for not worn state
        final sensorData = {
          'accelX': 0.0,
          'accelY': 0.0,
          'accelZ': 0.0,
          'ambientTemp': 20 +
              _random.nextDouble() * 8, // Room temperature still detectable
          'battPerc': _batteryLevel.clamp(1, 100).round(),
          'bodyTemp': 0.0, // No body temperature when not worn
          'gyroX': 0.0,
          'gyroY': 0.0,
          'gyroZ': 0.0,
          'heartRate': 0,
          'pitch': 0.0,
          'roll': 0.0,
          'spo2': 0.0,
          'timestamp': ServerValue.timestamp,
          'worn': 0,
        };

        // Battery level remains stable when device is not worn
        // (no battery drain simulation when not actively being used)

        // Upload to Firebase (mock mode only)
        try {
          await _currentRef.set(sensorData);
        } catch (e) {
          AppLogger.w('IoTSensorService: Skipped RTDB write (mock-only)');
        }
        AppLogger.d(
            'IoTSensorService: ✅ Data sent - HR: 0, SpO2: 0, Worn: NOT_WORN');

        notifyListeners();
        return; // Exit early, don't generate worn sensor data
      }

      // Only reach here if device is worn - generate full sensor data
      // TEMPORARILY DISABLED: Stress events and anxiety alerts for testing
      // if (_random.nextDouble() < 0.005) {
      //   // 0.5% chance for stress event (less chaotic)
      //   _triggerStressEvent();
      // }

      // Generate heart rate (realistic patterns) - only when worn
      // TESTING MODE: Always use normal values (stress mode disabled)
      // if (_isStressMode) {
      //   // Elevated heart rate during stress
      //   _heartRate = 95 + _random.nextDouble() * 25; // 95-120 BPM
      // } else {
      // Normal resting heart rate with variation
      _heartRate = 68 +
          _random.nextDouble() * 12 +
          sin(DateTime.now().millisecondsSinceEpoch / 30000) *
              3; // 68-80 BPM with gentle variation
      // }
      // Ensure heart rate is realistic when worn
      _heartRate = _heartRate.clamp(60.0, 120.0);

      // Generate SpO2 (typically high, drops slightly during stress)
      // TESTING MODE: Always use normal values (stress mode disabled)
      // if (_isStressMode) {
      //   _spo2 = 95 + _random.nextDouble() * 3; // 95-98%
      // } else {
      _spo2 = 97 + _random.nextDouble() * 2; // 97-99%
      // }

      // Generate body temperature (stable with minor variations)
      _bodyTemperature = 36.2 + _random.nextDouble() * 0.8; // 36.2-37.0°C

      // Generate ambient temperature (room temperature)
      _ambientTemperature = 20 + _random.nextDouble() * 8; // 20-28°C

      // Simulate battery drain
      _batteryLevel = max(0, _batteryLevel - _random.nextDouble() * 0.1);
      if (_batteryLevel < 20) {
        _batteryLevel = 100; // Simulate charging
      }

      // Check if stress event should end
      if (_isStressMode && _lastStressEvent != null) {
        final duration = DateTime.now().difference(_lastStressEvent!);
        if (duration.inMinutes > 5) {
          // Stress events last 5 minutes
          _isStressMode = false;
          AppLogger.d('IoTSensorService: Stress event ended');
        }
      }

      // Calculate severity level based on multiple factors
      _currentSeverityLevel = _calculateSeverityLevel();

      // Generate accelerometer data (simulating movement)
      final accelX = _random.nextDouble() * 2 - 1; // -1 to 1
      final accelY = _random.nextDouble() * 3; // 0 to 3
      final accelZ = 9.8 + _random.nextDouble() * 2 - 1; // ~9.8 (gravity)

      // Generate gyroscope data (simulating rotation)
      final gyroX = (_random.nextDouble() - 0.5) * 0.1; // -0.05 to 0.05
      final gyroY = (_random.nextDouble() - 0.5) * 0.1;
      final gyroZ = (_random.nextDouble() - 0.5) * 0.1;

      // Generate orientation data
      final pitch = _random.nextDouble() * 40 - 20; // -20 to 20 degrees
      final roll = _random.nextDouble() * 20 - 10; // -10 to 10 degrees

      // Create complete wearable sensor payload matching your Firebase schema
      final sensorData = {
        'accelX': double.parse(accelX.toStringAsFixed(2)),
        'accelY': double.parse(accelY.toStringAsFixed(2)),
        'accelZ': double.parse(accelZ.toStringAsFixed(2)),
        'ambientTemp': double.parse(_ambientTemperature.toStringAsFixed(1)),
        'battPerc': _batteryLevel.clamp(1, 100).round(),
        'bodyTemp': _isDeviceWorn
            ? double.parse(_bodyTemperature.toStringAsFixed(1))
            : 0,
        'gyroX': double.parse(gyroX.toStringAsFixed(2)),
        'gyroY': double.parse(gyroY.toStringAsFixed(2)),
        'gyroZ': double.parse(gyroZ.toStringAsFixed(2)),
        'heartRate': _isDeviceWorn ? _heartRate.round() : 0,
        'pitch': double.parse(pitch.toStringAsFixed(1)),
        'roll': double.parse(roll.toStringAsFixed(1)),
        'spo2': _isDeviceWorn ? double.parse(_spo2.toStringAsFixed(1)) : 0,
        'timestamp': ServerValue.timestamp,
        'worn': _isDeviceWorn ? 1 : 0,
      };

      // Upload to Firebase Realtime Database
      await _currentRef.set(sensorData);

      // Debug log to track 10-second intervals and worn state consistency
      AppLogger.d(
          'IoTSensorService: ✅ Data sent - HR: ${sensorData['heartRate']}, SpO2: ${sensorData['spo2']}, Worn: ${_isDeviceWorn ? 'WORN' : 'NOT_WORN'}');

      // TEMPORARILY DISABLED: Anxiety alert triggering for testing
      // if (_isStressMode && _heartRate > 100) {
      //   await _triggerAnxietyAlert();
      // }

      notifyListeners();

      // Occasional debug log
      if (_random.nextDouble() < 0.05) {
        AppLogger.d(
            'IoT HR ${_heartRate.round()} SpO2 ${_spo2.round()} Sev $_currentSeverityLevel');
      }
    } catch (e) {
      AppLogger.e('IoTSensorService: Generation error', e as Object?);
    }
  }

  /// Calculate severity level based on sensor data
  String _calculateSeverityLevel() {
    // Base severity on heart rate, SpO2, and stress mode
    if (_isStressMode || _heartRate > 120 || _spo2 < 92) {
      return 'severe'; // Critical values
    } else if (_heartRate > 100 || _spo2 < 95 || _bodyTemperature > 37.2) {
      return 'moderate'; // Elevated values
    } else {
      return 'mild'; // Normal or slightly elevated values
    }
  }

  /// Trigger a stress event for testing
  void _triggerStressEvent() {
    if (!_isStressMode) {
      _isStressMode = true;
      _lastStressEvent = DateTime.now();
      AppLogger.d('IoTSensorService: Stress event triggered');
    }
  }

  /// Manually trigger stress event (for testing)
  Future<void> simulateStressEvent() async {
    if (!_enableMockDataGeneration) {
      AppLogger.w(
          'IoTSensorService: Cannot simulate stress - mock data generation disabled');
      return;
    }

    _triggerStressEvent();
    await _currentRef.child('manualStressTest').set({
      'triggered': true,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Enable mock data generation (for testing without real device)
  void enableMockDataGeneration(bool enable) {
    _enableMockDataGeneration = enable;
    AppLogger.i(
        'IoTSensorService: Mock data generation ${enable ? 'ENABLED' : 'DISABLED'}');

    if (!enable && _sensorTimer != null) {
      // Stop timer if mock data is disabled
      _sensorTimer?.cancel();
      _sensorTimer = null;
      AppLogger.d('IoTSensorService: Mock data timer stopped');
    }
  }

  /// Get real-time sensor data stream
  Stream<Map<String, dynamic>?> getSensorDataStream() {
    return _currentRef.onValue.map((event) {
      if (event.snapshot.value == null) return null;
      try {
        final value = event.snapshot.value;
        if (value is Map) {
          return Map<String, dynamic>.from(value);
        }
        return null;
      } catch (e) {
        debugPrint('❌ IoTSensorService: Error parsing sensor data: $e');
        return null;
      }
    });
  }

  /// Get device status
  Map<String, dynamic> getDeviceStatus() {
    return {
      'isActive': _isActive,
      'isConnected': _isConnected,
      'deviceId': _deviceId,
      'isSimulated': true,
      'lastUpdate': DateTime.now().toIso8601String(),
      'currentValues': {
        'heartRate': _heartRate,
        'spo2': _spo2,
        'bodyTemperature': _bodyTemperature,
        'batteryLevel': _batteryLevel,
        'isWorn': _isDeviceWorn,
      }
    };
  }

  /// Clean up resources
  @override
  void dispose() {
    _sensorTimer?.cancel();
    super.dispose();
  }
}
