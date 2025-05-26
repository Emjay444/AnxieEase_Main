import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  bool _isNotificationEnabled = false;
  int _refreshCounter = 0;

  NotificationProvider() {
    _checkNotificationStatus();
  }

  bool get isNotificationEnabled => _isNotificationEnabled;
  int get refreshCounter => _refreshCounter;

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

  // Method to trigger notification list refresh
  void triggerNotificationRefresh() {
    _refreshCounter++;
    notifyListeners();
    debugPrint('🔄 Triggered notification refresh: $_refreshCounter');
  }
}
