import 'package:firebase_database/firebase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class UnifiedDeviceService {
  static final UnifiedDeviceService _instance =
      UnifiedDeviceService._internal();
  factory UnifiedDeviceService() => _instance;
  UnifiedDeviceService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _currentDeviceId;
  String? _currentUserId;
  Timer? _sensorDataTimer;
  StreamSubscription? _assignmentSubscription;

  /// Initialize the service with device and user IDs
  void initialize(String deviceId, String? userId) {
    _currentDeviceId = deviceId;
    _currentUserId = userId;

    if (userId != null) {
      _startSensorDataStreaming();
      _subscribeToAssignmentChanges();
    }
  }

  /// Check device assignment status from Supabase
  Future<Map<String, dynamic>?> checkDeviceAssignment(String deviceId) async {
    try {
      final response = await _supabase.from('wearable_devices').select('''
            *,
            user_profiles (
              id,
              first_name,
              last_name,
              email
            )
          ''').eq('device_id', deviceId).single();

      return response;
    } catch (error) {
      print('Error checking device assignment: $error');
      return null;
    }
  }

  /// Update device status in both Firebase and Supabase
  Future<void> updateDeviceStatus(String status) async {
    if (_currentDeviceId == null) return;

    try {
      // Update Firebase status
      await _database
          .ref('device_sessions/$_currentDeviceId/status')
          .set(status);

      // Update last seen in Supabase
      await _supabase.from('wearable_devices').update({
        'last_seen': DateTime.now().toIso8601String(),
        'status': status == 'active' ? 'assigned' : 'available',
      }).eq('device_id', _currentDeviceId!);

      print('Device status updated to: $status');
    } catch (error) {
      print('Error updating device status: $error');
    }
  }

  /// Send sensor data to Firebase
  Future<void> sendSensorData(Map<String, dynamic> sensorData) async {
    if (_currentDeviceId == null || _currentUserId == null) return;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await _database
          .ref('device_sessions/$_currentDeviceId/sensorData/$timestamp')
          .set({
        ...sensorData,
        'timestamp': ServerValue.timestamp,
        'deviceId': _currentDeviceId,
        'userId': _currentUserId,
      });

      // Update last sensor update time
      await _database
          .ref('device_sessions/$_currentDeviceId/lastSensorUpdate')
          .set(ServerValue.timestamp);
    } catch (error) {
      print('Error sending sensor data: $error');
    }
  }

  /// Listen to sensor data stream from Firebase
  Stream<Map<String, dynamic>> listenToSensorData(String deviceId) {
    return _database
        .ref('device_sessions/$deviceId/sensorData')
        .orderByChild('timestamp')
        .limitToLast(1)
        .onValue
        .map((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final values = data.values.toList();
        if (values.isNotEmpty) {
          return Map<String, dynamic>.from(values.last as Map);
        }
      }
      return <String, dynamic>{};
    });
  }

  /// Create or update device session in Firebase
  Future<void> createDeviceSession() async {
    if (_currentDeviceId == null || _currentUserId == null) return;

    try {
      await _database.ref('device_sessions/$_currentDeviceId').set({
        'userId': _currentUserId,
        'startTime': ServerValue.timestamp,
        'status': 'active',
        'deviceInitiated': true,
        'lastUpdate': ServerValue.timestamp,
      });

      // Create user record in Firebase
      await _database.ref('users/$_currentUserId').update({
        'deviceId': _currentDeviceId,
        'lastActive': ServerValue.timestamp,
        'sessionStart': ServerValue.timestamp,
      });

      print('Device session created successfully');
    } catch (error) {
      print('Error creating device session: $error');
    }
  }

  /// End device session
  Future<void> endDeviceSession() async {
    if (_currentDeviceId == null) return;

    try {
      // Update session status to completed
      await _database
          .ref('device_sessions/$_currentDeviceId/status')
          .set('completed');

      await _database
          .ref('device_sessions/$_currentDeviceId/endTime')
          .set(ServerValue.timestamp);

      // Stop sensor data streaming
      _stopSensorDataStreaming();

      print('Device session ended');
    } catch (error) {
      print('Error ending device session: $error');
    }
  }

  /// Send emergency alert
  Future<void> sendEmergencyAlert({
    required String alertType,
    required Map<String, dynamic> sensorData,
    Map<String, double>? location,
  }) async {
    if (_currentDeviceId == null || _currentUserId == null) return;

    try {
      await _database.ref('emergency_alerts/$_currentDeviceId').set({
        'userId': _currentUserId,
        'type': alertType,
        'sensorData': sensorData,
        'location': location,
        'timestamp': ServerValue.timestamp,
        'status': 'active',
      });

      print('Emergency alert sent: $alertType');
    } catch (error) {
      print('Error sending emergency alert: $error');
    }
  }

  /// Subscribe to assignment changes from Supabase
  void _subscribeToAssignmentChanges() {
    if (_currentDeviceId == null) return;

    _assignmentSubscription = _supabase
        .from('wearable_devices')
        .stream(primaryKey: ['device_id'])
        .eq('device_id', _currentDeviceId!)
        .listen((data) {
          if (data.isNotEmpty) {
            final deviceData = data.first;
            final assignedUserId = deviceData['user_id'] as String?;

            if (assignedUserId != _currentUserId) {
              _handleAssignmentChange(assignedUserId);
            }
          }
        });
  }

  /// Handle assignment changes
  void _handleAssignmentChange(String? newUserId) {
    if (newUserId == null) {
      // Device was unassigned
      _currentUserId = null;
      endDeviceSession();
      _stopSensorDataStreaming();
      print('Device unassigned - stopping session');
    } else if (newUserId != _currentUserId) {
      // Device was reassigned to different user
      _currentUserId = newUserId;
      createDeviceSession();
      _startSensorDataStreaming();
      print('Device reassigned to user: $newUserId');
    }
  }

  /// Start periodic sensor data streaming
  void _startSensorDataStreaming() {
    _stopSensorDataStreaming(); // Stop existing timer if any

    _sensorDataTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _sendPeriodicSensorData();
    });
  }

  /// Stop sensor data streaming
  void _stopSensorDataStreaming() {
    _sensorDataTimer?.cancel();
    _sensorDataTimer = null;
  }

  /// Send periodic sensor data (placeholder - integrate with actual sensors)
  void _sendPeriodicSensorData() {
    // This would be replaced with actual sensor readings
    final sensorData = {
      'heartRate': _generateHeartRate(),
      'skinConductance': _generateSkinConductance(),
      'bodyTemperature': _generateBodyTemperature(),
      'accelerometer': {
        'x': _generateAccelerometer(),
        'y': _generateAccelerometer(),
        'z': _generateAccelerometer(),
      },
      'batteryLevel': _generateBatteryLevel(),
    };

    sendSensorData(sensorData);
  }

  /// Generate realistic heart rate data (70-100 BPM)
  double _generateHeartRate() {
    return 70 + (30 * (DateTime.now().millisecond / 1000));
  }

  /// Generate skin conductance data (2-20 μS)
  double _generateSkinConductance() {
    return 2 + (18 * (DateTime.now().second / 60));
  }

  /// Generate body temperature data (36.1-37.2°C)
  double _generateBodyTemperature() {
    return 36.1 + (1.1 * (DateTime.now().minute / 60));
  }

  /// Generate accelerometer data (-1.0 to 1.0)
  double _generateAccelerometer() {
    return -1.0 + (2.0 * (DateTime.now().microsecond / 1000000));
  }

  /// Generate battery level (0-100%)
  int _generateBatteryLevel() {
    // Slowly decrease over time for realism
    final hourOfDay = DateTime.now().hour;
    return 100 - (hourOfDay * 4); // Decrease by 4% per hour
  }

  /// Check if device session is active
  Future<bool> isSessionActive() async {
    if (_currentDeviceId == null) return false;

    try {
      final snapshot =
          await _database.ref('device_sessions/$_currentDeviceId/status').get();

      return snapshot.value == 'active';
    } catch (error) {
      print('Error checking session status: $error');
      return false;
    }
  }

  /// Get current session info
  Future<Map<String, dynamic>?> getCurrentSession() async {
    if (_currentDeviceId == null) return null;

    try {
      final snapshot =
          await _database.ref('device_sessions/$_currentDeviceId').get();

      return Map<String, dynamic>.from(snapshot.value as Map? ?? {});
    } catch (error) {
      print('Error getting current session: $error');
      return null;
    }
  }

  /// Sync device info with Supabase
  Future<void> syncDeviceInfo() async {
    if (_currentDeviceId == null) return;

    try {
      await _supabase.from('wearable_devices').upsert({
        'device_id': _currentDeviceId,
        'last_seen': DateTime.now().toIso8601String(),
        'status': _currentUserId != null ? 'assigned' : 'available',
        'firmware_version': '1.0.0', // Replace with actual version
        'battery_level': _generateBatteryLevel(),
      }).eq('device_id', _currentDeviceId!);
    } catch (error) {
      print('Error syncing device info: $error');
    }
  }

  /// Cleanup resources
  void dispose() {
    _stopSensorDataStreaming();
    _assignmentSubscription?.cancel();
    endDeviceSession();
  }

  /// Get device assignment info for display
  Future<String> getAssignmentStatus() async {
    if (_currentDeviceId == null) return 'Not initialized';

    try {
      final deviceInfo = await checkDeviceAssignment(_currentDeviceId!);

      if (deviceInfo == null) {
        return 'Device not found';
      }

      if (deviceInfo['user_id'] == null) {
        return 'Available for assignment';
      }

      final userProfile = deviceInfo['user_profiles'];
      if (userProfile != null) {
        final userName =
            '${userProfile['first_name']} ${userProfile['last_name']}';
        return 'Assigned to: $userName';
      }

      return 'Assigned to user ID: ${deviceInfo['user_id']}';
    } catch (error) {
      return 'Error checking status';
    }
  }
}
