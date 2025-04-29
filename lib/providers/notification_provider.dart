import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  bool _isNotificationEnabled = false;

  NotificationProvider() {
    _checkNotificationStatus();
  }

  bool get isNotificationEnabled => _isNotificationEnabled;

  Future<void> _checkNotificationStatus() async {
    final status = await _notificationService.checkNotificationPermissions();
    _isNotificationEnabled = status;
    notifyListeners();
  }

  Future<bool> requestNotificationPermissions() async {
    final granted = await _notificationService.requestNotificationPermissions();
    _isNotificationEnabled = granted;
    notifyListeners();
    return granted;
  }

  Future<void> openNotificationSettings() async {
    await _notificationService.openNotificationSettings();
    // After returning from settings, check status again
    await _checkNotificationStatus();
  }

  Future<void> refreshNotificationStatus() async {
    await _checkNotificationStatus();
  }
}
