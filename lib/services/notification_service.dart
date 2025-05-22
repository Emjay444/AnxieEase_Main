import 'dart:io';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String notificationPermissionKey =
      'notification_permission_status';
  static const String badgeCountKey = 'notification_badge_count';

  Future<void> initialize() async {
    // Initialize awesome_notifications
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'anxiease_channel',
          channelName: 'AnxieEase Notifications',
          channelDescription: 'Notifications from AnxieEase app',
          defaultColor: Colors.blue,
          importance: NotificationImportance.High,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'alerts_channel',
          channelName: 'Alerts',
          channelDescription: 'Notification alerts for severity levels',
          defaultColor: Colors.red,
          importance: NotificationImportance.High,
          ledColor: Colors.white,
        ),
      ],
    );

    // Initialize badge count from storage
    await _loadBadgeCount();
  }

  // Request notification permissions
  Future<bool> requestNotificationPermissions() async {
    // For Android 13+ (API level 33+), we need to use the permission_handler
    if (await Permission.notification.request().isGranted) {
      await _savePermissionStatus(true);

      // Also request permission through awesome_notifications
      await AwesomeNotifications().requestPermissionToSendNotifications();

      return true;
    } else {
      await _savePermissionStatus(false);
      return false;
    }
  }

  // Check if notification permissions are granted
  Future<bool> checkNotificationPermissions() async {
    final permissionGranted = await Permission.notification.isGranted;
    final awesomePermissionGranted =
        await AwesomeNotifications().isNotificationAllowed();

    return permissionGranted && awesomePermissionGranted;
  }

  // Open app notification settings
  Future<void> openNotificationSettings() async {
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }

  // Save permission status
  Future<void> _savePermissionStatus(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationPermissionKey, granted);
  }

  // Get saved permission status from SharedPreferences
  Future<bool?> getSavedPermissionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notificationPermissionKey);
  }

  // Update badge count
  Future<void> updateBadgeCount(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(badgeCountKey, count);

      // Update app icon badge number
      if (Platform.isIOS) {
        await AwesomeNotifications().setGlobalBadgeCounter(count);
      }

      debugPrint('Updated notification badge count to: $count');
    } catch (e) {
      debugPrint('Error updating badge count: $e');
    }
  }

  // Get current badge count
  Future<int> getBadgeCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(badgeCountKey) ?? 0;
  }

  // Load badge count from storage
  Future<void> _loadBadgeCount() async {
    final count = await getBadgeCount();
    await updateBadgeCount(count);
  }

  // Reset badge count
  Future<void> resetBadgeCount() async {
    await updateBadgeCount(0);
  }

  // Send a test notification
  Future<void> showTestNotification() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 0,
        channelKey: 'anxiease_channel',
        title: 'AnxieEase',
        body: 'Notifications are working correctly!',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }
}
