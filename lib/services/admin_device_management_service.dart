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
          .select('device_id, user_id, is_active, status')
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

      final device = response;
      final assignmentStatus = device['status'] as String? ?? 'available';
      AppLogger.d(
          'AdminDeviceManagementService: Assignment status: $assignmentStatus');
      final assignedAt = device['assigned_at'] != null
          ? DateTime.parse(device['assigned_at'] as String)
          : null;
      final expiresAt = device['expires_at'] != null
          ? DateTime.parse(device['expires_at'] as String)
          : null;

      // If no assigned_at date but status is assigned, use created_at or current time
      final effectiveAssignedAt = assignedAt ?? DateTime.now();

      return DeviceAssignmentStatus.fromDatabase(
        status: assignmentStatus,
        assignedAt: effectiveAssignedAt,
        expiresAt: expiresAt,
        sessionNotes: device['session_notes'] as String?,
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
  final String status; // 'assigned', 'active', 'completed', 'expired'
  final DateTime? assignedAt;
  final DateTime? expiresAt;
  final String? sessionNotes;
  final String? errorMessage;

  DeviceAssignmentStatus({
    required this.isAssigned,
    required this.status,
    this.assignedAt,
    this.expiresAt,
    this.sessionNotes,
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
    DateTime? expiresAt,
    String? sessionNotes,
  }) {
    final now = DateTime.now();
    final isExpired = expiresAt != null && now.isAfter(expiresAt);

    return DeviceAssignmentStatus(
      isAssigned: !isExpired && (status == 'assigned' || status == 'active'),
      status: isExpired ? 'expired' : status,
      assignedAt: assignedAt,
      expiresAt: expiresAt,
      sessionNotes: sessionNotes,
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
  bool get isExpired => status == 'expired';
  bool get isActive => status == 'active';

  String get displayMessage {
    switch (status) {
      case 'assigned':
        return 'Device assigned to you. You can start testing.';
      case 'active':
        return 'Testing session active.';
      case 'completed':
        return 'Testing session completed.';
      case 'expired':
        return 'Device assignment has expired.';
      case 'not_assigned':
        return 'Device not assigned. Contact admin to assign device.';
      case 'error':
        return errorMessage ?? 'Error checking assignment';
      default:
        return 'Unknown status: $status';
    }
  }
}
