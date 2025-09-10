import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  late DatabaseReference _deviceRef;
  late DatabaseReference _currentRef;

  Timer? _sensorTimer;
  Timer? _firestoreFlushTimer; // flush buffered readings periodically
  bool _isActive = false;
  bool _initialized = false;
  int _updateIntervalSeconds = 3; // adaptive interval
  static const int _minInterval = 2;
  static const int _maxInterval = 12;
  final List<Map<String, dynamic>> _firestoreBuffer = [];
  static const int _firestoreFlushThreshold = 12;
  final String _deviceId = 'AnxieEase001';
  final String _userId = 'user_001';

  // Current sensor values
  double _heartRate = 72.0;
  double _spo2 = 98.0;
  double _bodyTemperature = 36.5;
  double _ambientTemperature = 23.0;
  double _batteryLevel = 85.0;
  bool _isDeviceWorn = true;
  bool _isConnected = false;

  // Realistic value ranges and patterns
  final Random _random = Random();
  DateTime? _lastStressEvent;
  bool _isStressMode = false;
  String _currentSeverityLevel =
      'mild'; // Use severity levels: mild, moderate, severe

  // Getters for current values
  double get heartRate => _heartRate;
  double get spo2 => _spo2;
  double get bodyTemperature => _bodyTemperature;
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

    // Skip legacy cleanup to avoid permission errors - all new writes use current structure
  AppLogger.d('IoTSensorService: Using clean structure');

    // Set initial device metadata with IoT structure
    await _deviceRef.child('metadata').set({
      'deviceId': _deviceId,
      'deviceType': 'simulated_health_monitor',
      'userId': _userId,
      'status': 'initialized',
      'lastInitialized': ServerValue.timestamp,
      'isSimulated': true,
      'architecture': 'pure_iot_firebase',
      'version': '2.0.0',
    });

    // Initialize proper IoT current data structure
    await _currentRef.set({
      'heartRate': _heartRate.round(),
      'spo2': _spo2.round(),
      'bodyTemp': double.parse(_bodyTemperature.toStringAsFixed(1)),
      'ambientTemp': double.parse(_ambientTemperature.toStringAsFixed(1)),
      'battPerc': _batteryLevel.round(),
      'worn': _isDeviceWorn,
      'timestamp': ServerValue.timestamp,
      'deviceId': _deviceId,
      'userId': _userId,
      'severityLevel': _currentSeverityLevel,
      'source': 'iot_simulation',
      'connectionStatus': 'initialized',
    });

  AppLogger.d('IoTSensorService: Initialized');
    _initialized = true;
  }

  /// Start IoT sensor simulation
  Future<void> startSensors() async {
    if (_isActive) {
      AppLogger.d('IoTSensorService: Already active');
      return;
    }

    if (!_initialized) {
      await initialize();
    }

  AppLogger.d('IoTSensorService: Starting simulation');

    _isActive = true;
    _isConnected = true;

    // Update device status
    await _deviceRef.child('metadata/status').set('active');
    await _currentRef.child('connectionStatus').set('connected');

    // Start sensor data generation
  _startSensorTimer();
  _firestoreFlushTimer ??=
    Timer.periodic(const Duration(seconds: 10), (_) => _flushFirestoreBuffer());

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
  _firestoreFlushTimer?.cancel();
  _firestoreFlushTimer = null;

    _isActive = false;
    _isConnected = false;

    // Update device status
    await _deviceRef.child('metadata/status').set('offline');
    await _currentRef.child('connectionStatus').set('disconnected');

    notifyListeners();
    AppLogger.d('IoTSensorService: Stopped');
  }

  void _startSensorTimer() {
    _sensorTimer?.cancel();
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

  Future<void> _flushFirestoreBuffer() async {
    if (_firestoreBuffer.isEmpty) return;
    try {
      final batch = _firestore.batch();
      for (final data in _firestoreBuffer) {
        final doc = _firestore.collection('sensor_readings').doc();
        batch.set(doc, data);
      }
      await batch.commit();
      AppLogger.d('IoTSensorService: Flushed ${_firestoreBuffer.length} readings');
    } catch (e, st) {
      AppLogger.e('IoTSensorService: Flush error', e as Object?, st);
    } finally {
      _firestoreBuffer.clear();
    }
  }

  /// Generate realistic sensor data
  void _generateSensorData(Timer timer) async {
    try {
      // Simulate device being worn/unworn randomly
      if (_random.nextDouble() < 0.05) {
        // 5% chance to change worn status
        _isDeviceWorn = !_isDeviceWorn;
      }

      // Simulate stress events occasionally
      if (_random.nextDouble() < 0.02) {
        // 2% chance for stress event
        _triggerStressEvent();
      }

      // Generate heart rate (realistic patterns)
      if (_isDeviceWorn) {
        if (_isStressMode) {
          // Elevated heart rate during stress
          _heartRate = 95 + _random.nextDouble() * 25; // 95-120 BPM
        } else {
          // Normal resting heart rate with variation
          _heartRate = 65 +
              _random.nextDouble() * 15 +
              sin(DateTime.now().millisecondsSinceEpoch / 10000) *
                  5; // 65-80 BPM with slight variation
        }
      } else {
        _heartRate = 0; // No reading when not worn
      }

      // Generate SpO2 (typically high, drops slightly during stress)
      if (_isDeviceWorn) {
        if (_isStressMode) {
          _spo2 = 95 + _random.nextDouble() * 3; // 95-98%
        } else {
          _spo2 = 97 + _random.nextDouble() * 2; // 97-99%
        }
      } else {
        _spo2 = 0;
      }

      // Generate body temperature (stable with minor variations)
      if (_isDeviceWorn) {
        _bodyTemperature = 36.2 + _random.nextDouble() * 0.8; // 36.2-37.0°C
      } else {
        _bodyTemperature = 0;
      }

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

      // Create sensor data payload
      final sensorData = {
        'heartRate': _heartRate.round(),
        'spo2': _spo2.round(),
        'bodyTemp': double.parse(_bodyTemperature.toStringAsFixed(1)),
        'ambientTemp': double.parse(_ambientTemperature.toStringAsFixed(1)),
        'battPerc': _batteryLevel.round(),
        'worn': _isDeviceWorn,
        'timestamp': ServerValue.timestamp,
        'deviceId': _deviceId,
        'userId': _userId,
        'severityLevel': _currentSeverityLevel,
        'source': 'iot_simulation',
      };

      // Upload to Firebase Realtime Database
      await _currentRef.set(sensorData);

      // Also store in Firestore for historical data (throttled)
      if (_random.nextDouble() < 0.25) {
        _firestoreBuffer.add({
          ...sensorData,
          'timestamp': FieldValue.serverTimestamp(),
        });
        if (_firestoreBuffer.length >= _firestoreFlushThreshold) {
          _flushFirestoreBuffer();
        }
      }

      // Trigger anxiety detection if stress is detected
      if (_isStressMode && _heartRate > 100) {
        await _triggerAnxietyAlert();
      }

      notifyListeners();

      // Occasional debug log
      if (_random.nextDouble() < 0.05) {
        AppLogger.d('IoT HR ${_heartRate.round()} SpO2 ${_spo2.round()} Sev $_currentSeverityLevel');
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
    _triggerStressEvent();
    await _currentRef.child('manualStressTest').set({
      'triggered': true,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Trigger anxiety alert
  Future<void> _triggerAnxietyAlert() async {
    try {
      await _firestore.collection('anxiety_alerts').add({
        'deviceId': _deviceId,
        'userId': _userId,
        'heartRate': _heartRate,
        'spo2': _spo2,
        'bodyTemperature': _bodyTemperature,
        'severity': _currentSeverityLevel,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'iot_simulation',
        'isSimulated': true,
      });

  AppLogger.i('IoTSensorService: Anxiety alert (HR ${_heartRate.round()} Sev $_currentSeverityLevel)');
    } catch (e) {
  AppLogger.e('IoTSensorService: Anxiety alert error', e as Object?);
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
    _firestoreFlushTimer?.cancel();
    if (_firestoreBuffer.isNotEmpty) {
      _flushFirestoreBuffer();
    }
    super.dispose();
  }
}
