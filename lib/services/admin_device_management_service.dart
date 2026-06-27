import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Service for admin-controlled device assignment
/// Admin manages device status through React website
/// Mobile app checks assignment status from Supabase
class AdminDeviceManagementService {
  static final AdminDeviceManagementService _instance =
      AdminDeviceManagementService._internal();
  factory AdminDeviceManagementService() => _instance;
  AdminDeviceManagementService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if current user has been assigned the testing device by admin
  Future<DeviceAssignmentStatus> checkDeviceAssignment() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        AppLogger.d('AdminDeviceManagementService: No authenticated user');
        return DeviceAssignmentStatus.notLoggedIn();
      }

      AppLogger.d(
          'AdminDeviceManagementService: Checking assignment for user: ${user.id}');

      // First, let's see what devices exist in the table
      final allDevices = await _supabase
          .from('wearable_devices')
          .select('device_id, user_id, is_active')
          .limit(5);

      AppLogger.d(
          'AdminDeviceManagementService: All devices in table: $allDevices');

      // Query wearable_devices table managed by admin
      // Look for ANY device assigned to the current user
      final response = await _supabase
          .from('wearable_devices')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

      AppLogger.d('AdminDeviceManagementService: Query response: $response');

      if (response == null) {
        AppLogger.d('AdminDeviceManagementService: No device assignment found');
        return DeviceAssignmentStatus.notAssigned();
      }

      // The query above already filtered on user_id == this user, so any
      // row returned means the device is assigned to them. is_active tracks
      // hardware connectivity, not assignment, and must not gate this check
      // (the admin's web assignment never sets is_active).
      final device = response;
      const assignmentStatus = 'assigned';
      AppLogger.d(
          'AdminDeviceManagementService: Assignment status: $assignmentStatus');

      // wearable_devices has no assigned_at column; use linked_at instead.
      final linkedAt = device['linked_at'] != null
          ? DateTime.parse(device['linked_at'] as String)
          : DateTime.now();

      return DeviceAssignmentStatus.fromDatabase(
        status: assignmentStatus,
        assignedAt: linkedAt,
      );
    } catch (e) {
      AppLogger.e('Error checking device assignment', e);
      return DeviceAssignmentStatus.error(e.toString());
    }
  }

  /// Get virtual device ID for current user (used by app)
  Future<String> getVirtualDeviceId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'AnxieEase001'; // Fallback

    final userIdShort = user.id.substring(0, 8);
    return 'AnxieEase001_$userIdShort';
  }

  /// Update device session status (when user starts/ends testing)
  Future<void> updateSessionStatus(String status, {String? notes}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Use the new function from database
      await _supabase.rpc('update_session_status', params: {
        'p_device_id': 'AnxieEase001',
        'p_session_status': status,
        'p_session_notes': notes,
      });

      AppLogger.d('Session status updated: $status');
    } catch (e) {
      AppLogger.e('Error updating session status', e);
    }
  }

  /// Get current device assignment info for display
  Future<Map<String, dynamic>?> getCurrentAssignmentInfo() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('wearable_devices')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

      return response;
    } catch (e) {
      AppLogger.e('Error getting assignment info', e);
      return null;
    }
  }
}

/// Device assignment status from admin
class DeviceAssignmentStatus {
  final bool isAssigned;
  final String status; // 'assigned', 'active', 'not_assigned', 'error'
  final DateTime? assignedAt;
  final String? errorMessage;

  DeviceAssignmentStatus({
    required this.isAssigned,
    required this.status,
    this.assignedAt,
    this.errorMessage,
  });

  factory DeviceAssignmentStatus.notLoggedIn() {
    return DeviceAssignmentStatus(
      isAssigned: false,
      status: 'not_logged_in',
      errorMessage: 'User not logged in',
    );
  }

  factory DeviceAssignmentStatus.notAssigned() {
    return DeviceAssignmentStatus(
      isAssigned: false,
      status: 'not_assigned',
    );
  }

  factory DeviceAssignmentStatus.fromDatabase({
    required String status,
    required DateTime assignedAt,
  }) {
    return DeviceAssignmentStatus(
      isAssigned: status == 'assigned' || status == 'active',
      status: status,
      assignedAt: assignedAt,
    );
  }

  factory DeviceAssignmentStatus.error(String message) {
    return DeviceAssignmentStatus(
      isAssigned: false,
      status: 'error',
      errorMessage: message,
    );
  }

  bool get canUseDevice =>
      isAssigned && (status == 'assigned' || status == 'active');
  bool get isActive => status == 'active';

  String get displayMessage {
    switch (status) {
      case 'assigned':
        return 'Device assigned to you. You can start testing.';
      case 'active':
        return 'Testing session active.';
      case 'completed':
        return 'Testing session completed.';
      case 'not_assigned':
        return 'Device not assigned. Contact admin to assign device.';
      case 'error':
        return errorMessage ?? 'Error checking assignment';
      default:
        return 'Unknown status: $status';
    }
  }
}
