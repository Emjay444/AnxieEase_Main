import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native IoT Gateway Service Wrapper
///
/// This service communicates with the native Android IoT Gateway service
/// and provides a Flutter interface for:
/// 1. Starting/stopping the native gateway
/// 2. Receiving real-time sensor data via EventChannel
/// 3. Sending commands to the native service
/// 4. Managing gateway state and status
class NativeIoTGatewayService extends ChangeNotifier {
  static final NativeIoTGatewayService _instance =
      NativeIoTGatewayService._internal();
  factory NativeIoTGatewayService() => _instance;
  NativeIoTGatewayService._internal();

  // Channels for native communication
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.ctrlzed/iot_gateway_control');
  static const EventChannel _eventChannel =
      EventChannel('com.example.ctrlzed/iot_data_stream');

  // State
  bool _isGatewayRunning = false;
  bool _isDeviceConnected = false;
  String _deviceAddress = '';
  String _status = 'Disconnected';

  // Data streams
  StreamSubscription<dynamic>? _eventSubscription;

  // Real-time sensor data
  double? _heartRate;
  double? _spo2;
  double? _bodyTemperature;
  double? _ambientTemperature;
  double? _batteryLevel;
  bool _isDeviceWorn = false;
  DateTime? _lastUpdate;

  // Anxiety alerts
  String _anxietySeverity = 'normal';
  double _anxietyConfidence = 0.0;
  DateTime? _lastAlertTime;

  // Error handling
  String? _lastError;

  // Getters
  bool get isGatewayRunning => _isGatewayRunning;
  bool get isDeviceConnected => _isDeviceConnected;
  String get deviceAddress => _deviceAddress;
  String get status => _status;
  String? get lastError => _lastError;

  // Sensor data getters
  double? get heartRate => _heartRate;
  double? get spo2 => _spo2;
  double? get bodyTemperature => _bodyTemperature;
  double? get ambientTemperature => _ambientTemperature;
  double? get batteryLevel => _batteryLevel;
  bool get isDeviceWorn => _isDeviceWorn;
  DateTime? get lastUpdate => _lastUpdate;

  // Anxiety detection getters
  String get anxietySeverity => _anxietySeverity;
  double get anxietyConfidence => _anxietyConfidence;
  DateTime? get lastAlertTime => _lastAlertTime;

  /// Initialize the native IoT gateway service
  Future<void> initialize() async {
    debugPrint('🔧 NativeIoTGatewayService: Initializing...');

    try {
      // Start listening to events from native service
      _startEventListener();

      // Check current gateway status
      await _updateGatewayStatus();

      debugPrint('✅ NativeIoTGatewayService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ NativeIoTGatewayService: Initialization failed: $e');
      _lastError = 'Initialization failed: $e';
      notifyListeners();
    }
  }

  /// Start the native IoT Gateway
  Future<bool> startGateway({
    required String deviceAddress,
    required String userId,
    String? deviceId,
  }) async {
    debugPrint('🚀 NativeIoTGatewayService: Starting gateway...');
    debugPrint('📱 Device: $deviceAddress, User: $userId');

    try {
      _lastError = null;
      _status = 'Starting gateway...';
      notifyListeners();

      final result = await _methodChannel.invokeMethod('startIoTGateway', {
        'deviceAddress': deviceAddress,
        'userId': userId,
        'deviceId': deviceId ?? 'AnxieEase001',
      });

      if (result == true) {
        _isGatewayRunning = true;
        _deviceAddress = deviceAddress;
        _status = 'Gateway started';

        debugPrint('✅ NativeIoTGatewayService: Gateway started successfully');
        notifyListeners();
        return true;
      } else {
        _status = 'Failed to start gateway';
        _lastError = 'Native service returned false';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ NativeIoTGatewayService: Failed to start gateway: $e');
      _status = 'Gateway start failed';
      _lastError = 'Failed to start gateway: $e';
      notifyListeners();
      return false;
    }
  }

  /// Stop the native IoT Gateway
  Future<bool> stopGateway() async {
    debugPrint('🛑 NativeIoTGatewayService: Stopping gateway...');

    try {
      _lastError = null;
      _status = 'Stopping gateway...';
      notifyListeners();

      final result = await _methodChannel.invokeMethod('stopIoTGateway');

      if (result == true) {
        _isGatewayRunning = false;
        _isDeviceConnected = false;
        _deviceAddress = '';
        _status = 'Gateway stopped';

        // Clear sensor data
        _clearSensorData();

        debugPrint('✅ NativeIoTGatewayService: Gateway stopped successfully');
        notifyListeners();
        return true;
      } else {
        _status = 'Failed to stop gateway';
        _lastError = 'Native service returned false';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ NativeIoTGatewayService: Failed to stop gateway: $e');
      _status = 'Gateway stop failed';
      _lastError = 'Failed to stop gateway: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reconnect to the device
  Future<bool> reconnectDevice() async {
    debugPrint('🔄 NativeIoTGatewayService: Reconnecting device...');

    try {
      _lastError = null;
      _status = 'Reconnecting...';
      notifyListeners();

      final result = await _methodChannel.invokeMethod('reconnectDevice');

      if (result == true) {
        _status = 'Reconnection initiated';
        debugPrint('✅ NativeIoTGatewayService: Reconnection initiated');
        notifyListeners();
        return true;
      } else {
        _status = 'Reconnection failed';
        _lastError = 'Native service returned false';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ NativeIoTGatewayService: Reconnection failed: $e');
      _status = 'Reconnection failed';
      _lastError = 'Reconnection failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Send a command to the connected device
  Future<bool> sendDeviceCommand(String command) async {
    debugPrint('📤 NativeIoTGatewayService: Sending command: $command');

    try {
      final result = await _methodChannel.invokeMethod('sendDeviceCommand', {
        'command': command,
      });

      debugPrint('✅ NativeIoTGatewayService: Command sent successfully');
      return result == true;
    } catch (e) {
      debugPrint('❌ NativeIoTGatewayService: Failed to send command: $e');
      _lastError = 'Failed to send command: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get current gateway status
  Future<void> _updateGatewayStatus() async {
    try {
      final status = await _methodChannel.invokeMethod('getGatewayStatus');

      if (status is Map) {
        _isGatewayRunning = status['isRunning'] ?? false;
        _isDeviceConnected = status['isConnected'] ?? false;
        _deviceAddress = status['deviceAddress'] ?? '';

        debugPrint(
            '📊 NativeIoTGatewayService: Status updated - Running: $_isGatewayRunning, Connected: $_isDeviceConnected');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ NativeIoTGatewayService: Failed to get status: $e');
    }
  }

  /// Start listening to events from the native service
  void _startEventListener() {
    debugPrint('👂 NativeIoTGatewayService: Starting event listener...');

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        try {
          if (event is Map) {
            _handleNativeEvent(event);
          }
        } catch (e) {
          debugPrint('❌ NativeIoTGatewayService: Error handling event: $e');
        }
      },
      onError: (dynamic error) {
        debugPrint('❌ NativeIoTGatewayService: Event stream error: $error');
        _lastError = 'Event stream error: $error';
        notifyListeners();
      },
      onDone: () {
        debugPrint('📡 NativeIoTGatewayService: Event stream closed');
      },
    );
  }

  /// Handle events from the native service
  void _handleNativeEvent(Map<dynamic, dynamic> event) {
    final type = event['type'] as String?;

    debugPrint('📡 NativeIoTGatewayService: Received event: $type');

    switch (type) {
      case 'connection_status':
        _handleConnectionStatus(event);
        break;

      case 'sensor_data':
        _handleSensorData(event);
        break;

      case 'anxiety_alert':
        _handleAnxietyAlert(event);
        break;

      default:
        debugPrint('⚠️ NativeIoTGatewayService: Unknown event type: $type');
    }
  }

  void _handleConnectionStatus(Map<dynamic, dynamic> event) {
    _isDeviceConnected = event['connected'] ?? false;
    _deviceAddress = event['deviceAddress'] ?? '';

    _status =
        _isDeviceConnected ? 'Connected to $_deviceAddress' : 'Disconnected';

    debugPrint(
        '🔗 NativeIoTGatewayService: Connection status - Connected: $_isDeviceConnected');
    notifyListeners();
  }

  void _handleSensorData(Map<dynamic, dynamic> event) {
    final data = event['data'] as Map<dynamic, dynamic>?;

    if (data != null) {
      _heartRate = (data['heartRate'] as num?)?.toDouble();
      _spo2 = (data['spo2'] as num?)?.toDouble();
      _bodyTemperature = (data['bodyTemperature'] as num?)?.toDouble();
      _ambientTemperature = (data['ambientTemperature'] as num?)?.toDouble();
      _batteryLevel = (data['batteryLevel'] as num?)?.toDouble();
      _isDeviceWorn = data['isDeviceWorn'] ?? false;
      _lastUpdate = DateTime.now();

      debugPrint(
          '📊 NativeIoTGatewayService: Sensor data updated - HR: $_heartRate, SpO2: $_spo2');
      notifyListeners();
    }
  }

  void _handleAnxietyAlert(Map<dynamic, dynamic> event) {
    final alert = event['alert'] as Map<dynamic, dynamic>?;

    if (alert != null) {
      _anxietySeverity = alert['severity'] ?? 'normal';
      _anxietyConfidence = (alert['confidence'] as num?)?.toDouble() ?? 0.0;
      _lastAlertTime =
          DateTime.fromMillisecondsSinceEpoch(alert['timestamp'] ?? 0);

      debugPrint(
          '🚨 NativeIoTGatewayService: Anxiety alert - Severity: $_anxietySeverity');
      notifyListeners();
    }
  }

  void _clearSensorData() {
    _heartRate = null;
    _spo2 = null;
    _bodyTemperature = null;
    _ambientTemperature = null;
    _batteryLevel = null;
    _isDeviceWorn = false;
    _lastUpdate = null;
    _anxietySeverity = 'normal';
    _anxietyConfidence = 0.0;
    _lastAlertTime = null;
  }

  /// Dispose of resources
  void dispose() {
    debugPrint('🔻 NativeIoTGatewayService: Disposing...');
    _eventSubscription?.cancel();
    super.dispose();
  }
}
