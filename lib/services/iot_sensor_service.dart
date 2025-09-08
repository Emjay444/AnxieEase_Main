import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

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
  bool _isActive = false;
  bool _initialized = false;
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
    debugPrint('🌐 IoTSensorService: Initializing...');

    // Ensure Firebase is initialized (especially important for tests)
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        debugPrint('❌ IoTSensorService: Firebase init failed: $e');
      }
    }

    _deviceRef = _realtimeDb.ref('devices/$_deviceId');
    _currentRef = _realtimeDb.ref('devices/$_deviceId/current');

    // Skip legacy cleanup to avoid permission errors - all new writes use current structure
    debugPrint(
        '✅ IoTSensorService: Using clean IoT structure (no legacy cleanup needed)');

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

    debugPrint('✅ IoTSensorService: Initialized with clean IoT structure');
    _initialized = true;
  }

  /// Start IoT sensor simulation
  Future<void> startSensors() async {
    if (_isActive) {
      debugPrint('⚠️ IoTSensorService: Sensors already active');
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    debugPrint('🚀 IoTSensorService: Starting sensor simulation...');

    _isActive = true;
    _isConnected = true;

    // Update device status
    await _deviceRef.child('metadata/status').set('active');
    await _currentRef.child('connectionStatus').set('connected');

    // Start sensor data generation
    _sensorTimer =
        Timer.periodic(const Duration(seconds: 2), _generateSensorData);

    notifyListeners();
    debugPrint('✅ IoTSensorService: Sensors started successfully');
  }

  /// Stop IoT sensor simulation
  Future<void> stopSensors() async {
    if (!_isActive) {
      debugPrint('⚠️ IoTSensorService: Sensors already stopped');
      return;
    }

    debugPrint('🛑 IoTSensorService: Stopping sensor simulation...');

    _sensorTimer?.cancel();
    _sensorTimer = null;

    _isActive = false;
    _isConnected = false;

    // Update device status
    await _deviceRef.child('metadata/status').set('offline');
    await _currentRef.child('connectionStatus').set('disconnected');

    notifyListeners();
    debugPrint('✅ IoTSensorService: Sensors stopped successfully');
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
          debugPrint('🧘 IoTSensorService: Stress event ended');
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
      if (_random.nextDouble() < 0.3) {
        // Only 30% of readings go to Firestore
        await _firestore.collection('sensor_readings').add({
          ...sensorData,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Trigger anxiety detection if stress is detected
      if (_isStressMode && _heartRate > 100) {
        await _triggerAnxietyAlert();
      }

      notifyListeners();

      // Occasional debug log
      if (_random.nextDouble() < 0.1) {
        debugPrint(
            '📊 IoTSensorService: HR: ${_heartRate.round()}, SpO2: ${_spo2.round()}%, '
            'Temp: ${_bodyTemperature.toStringAsFixed(1)}°C, Battery: ${_batteryLevel.round()}%, '
            'Worn: $_isDeviceWorn, Severity: $_currentSeverityLevel');
      }
    } catch (e) {
      debugPrint('❌ IoTSensorService: Error generating sensor data: $e');
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
      debugPrint('⚠️ IoTSensorService: Stress event triggered');
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

      debugPrint(
          '🚨 IoTSensorService: Anxiety alert triggered (HR: ${_heartRate.round()}, Severity: $_currentSeverityLevel)');
    } catch (e) {
      debugPrint('❌ IoTSensorService: Error triggering anxiety alert: $e');
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
