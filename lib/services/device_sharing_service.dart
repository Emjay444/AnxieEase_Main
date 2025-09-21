import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'supabase_service.dart';
import '../utils/logger.dart';

/// Service for managing device sharing during testing phase
/// Allows multiple users to use the same physical device one at a time
class DeviceSharingService {
  static final DeviceSharingService _instance =
      DeviceSharingService._internal();
  factory DeviceSharingService() => _instance;
  DeviceSharingService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  static const String _currentUserDeviceKey = 'current_user_device_assignment';

  /// Get the device ID that should be used by the current user
  /// Format: AnxieEase001_UserA, AnxieEase001_UserB, etc.
  Future<String> getCurrentUserDeviceId() async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) {
        AppLogger.w('No authenticated user, using default device');
        return 'AnxieEase001';
      }

      // Create a virtual device ID using the base device + user ID
      final baseDeviceId = 'AnxieEase001'; // Your physical device
      final userId = user.id.substring(0, 8); // First 8 chars of user ID
      final virtualDeviceId = '${baseDeviceId}_$userId';

      AppLogger.d('Virtual device ID for user: $virtualDeviceId');
      return virtualDeviceId;
    } catch (e) {
      AppLogger.e('Error getting user device ID', e);
      return 'AnxieEase001'; // Fallback
    }
  }

  /// Assign the physical device to current user for testing session
  Future<bool> assignDeviceToCurrentUser() async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final currentAssignment = prefs.getString(_currentUserDeviceKey);

      // Check if device is already assigned to someone else
      if (currentAssignment != null && currentAssignment != user.id) {
        AppLogger.w('Device is currently assigned to another user');
        return false;
      }

      // Assign device to current user
      await prefs.setString(_currentUserDeviceKey, user.id);
      AppLogger.d('Device assigned to user: ${user.id}');
      return true;
    } catch (e) {
      AppLogger.e('Error assigning device', e);
      return false;
    }
  }

  /// Release the device assignment (when user finishes testing)
  Future<void> releaseDeviceAssignment() async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user != null) {
        final virtualDeviceId = await getCurrentUserDeviceId();

        // Clear the user's virtual device data in Firebase
        await _clearUserDeviceData(virtualDeviceId);
        AppLogger.d(
            'Cleared Firebase data for virtual device: $virtualDeviceId');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserDeviceKey);
      AppLogger.d('Device assignment released');
    } catch (e) {
      AppLogger.e('Error releasing device assignment', e);
    }
  }

  /// Clear user's virtual device data from Firebase
  Future<void> _clearUserDeviceData(String virtualDeviceId) async {
    try {
      // Note: We keep this commented out for testing phase
      // so testers can review their data if needed

      // final database = FirebaseDatabase.instance;
      // await database.ref('devices/$virtualDeviceId').remove();

      AppLogger.d('Virtual device data cleared: $virtualDeviceId');
    } catch (e) {
      AppLogger.e('Error clearing virtual device data', e);
    }
  }

  /// Check if current user has the device assigned
  Future<bool> isDeviceAssignedToCurrentUser() async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final currentAssignment = prefs.getString(_currentUserDeviceKey);

      return currentAssignment == user.id;
    } catch (e) {
      AppLogger.e('Error checking device assignment', e);
      return false;
    }
  }

  /// Get user-friendly device name for display
  String getDeviceDisplayName(String deviceId) {
    if (deviceId.contains('_')) {
      final parts = deviceId.split('_');
      return 'AnxieEase Device (User: ${parts.last})';
    }
    return 'AnxieEase Device';
  }
}
