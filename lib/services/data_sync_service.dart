import 'package:firebase_database/firebase_database.dart';
import '../utils/logger.dart';

/// Service to sync data from physical device to virtual user-specific device paths
/// This allows multiple users to test with one physical device
class DataSyncService {
  static final DataSyncService _instance = DataSyncService._internal();
  factory DataSyncService() => _instance;
  DataSyncService._internal();

  static const String _physicalDeviceId = 'AnxieEase001';
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Start syncing data from physical device to user's virtual device
  void startSyncForUser(String virtualDeviceId) {
    AppLogger.d(
        'Starting data sync from $_physicalDeviceId to $virtualDeviceId');

    // Listen to physical device data
    final physicalDeviceRef =
        _database.ref('devices/$_physicalDeviceId/current');

    physicalDeviceRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;

        // Copy data to virtual device path
        final virtualDeviceRef =
            _database.ref('devices/$virtualDeviceId/current');
        virtualDeviceRef.set(data).then((_) {
          AppLogger.d('Data synced to $virtualDeviceId');
        }).catchError((error) {
          AppLogger.e('Error syncing data to $virtualDeviceId: $error');
        });
      }
    });
  }

  /// Stop all sync operations (when user finishes testing)
  void stopSync() {
    // In a real implementation, you'd track and cancel subscriptions
    AppLogger.d('Data sync stopped');
  }

  /// Manual sync for current state
  Future<void> syncCurrentData(String virtualDeviceId) async {
    try {
      final physicalDeviceRef =
          _database.ref('devices/$_physicalDeviceId/current');
      final snapshot = await physicalDeviceRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final virtualDeviceRef =
            _database.ref('devices/$virtualDeviceId/current');
        await virtualDeviceRef.set(data);
        AppLogger.d('Manual sync completed for $virtualDeviceId');
      }
    } catch (e) {
      AppLogger.e('Error during manual sync', e);
    }
  }
}
