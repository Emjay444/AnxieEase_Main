import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  bool _isNotificationEnabled = false;
  int _refreshCounter = 0;
  bool _isInitialized = false;

  NotificationProvider() {
    // Delay initialization to allow services to be set up
    _initializeProvider();
  }

  bool get isNotificationEnabled => _isNotificationEnabled;
  int get refreshCounter => _refreshCounter;
  bool get isInitialized => _isInitialized;

  Future<void> _initializeProvider() async {
    // Delay the check until services are ready
    Future.delayed(const Duration(seconds: 2), () {
      _checkNotificationStatus();
      _isInitialized = true;
    });
  }

  Future<void> _checkNotificationStatus() async {
    try {
      final status = await _notificationService.checkNotificationPermissions();
      _isNotificationEnabled = status;
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking notification status: $e');
    }
  }

  Future<bool> requestNotificationPermissions() async {
    try {
      final granted =
          await _notificationService.requestNotificationPermissions();
      _isNotificationEnabled = granted;
      notifyListeners();
      return granted;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _notificationService.openNotificationSettings();
      // After returning from settings, check status again
      await _checkNotificationStatus();
    } catch (e) {
      debugPrint('Error opening notification settings: $e');
    }
  }

  Future<void> refreshNotificationStatus() async {
    await _checkNotificationStatus();
  }

  // Method to trigger notification list refresh
  void triggerNotificationRefresh() {
    _refreshCounter++;
    notifyListeners();
    debugPrint('🔄 Triggered notification refresh: $_refreshCounter');
  }
}
