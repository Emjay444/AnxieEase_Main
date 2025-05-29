import 'dart:io';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'supabase_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    _currentSeverity = 'normal';
    _currentHeartRate = 0;
    _isFirstRead = true;
    _lastNotificationTime = DateTime.now();
  }

  static const String notificationPermissionKey =
      'notification_permission_status';
  static const String badgeCountKey = 'notification_badge_count';
  static const String reminderEnabledKey = 'anxiety_reminders_enabled';
  static const String reminderIntervalKey = 'anxiety_reminder_interval_hours';

  final SupabaseService _supabaseService = SupabaseService();
  final DatabaseReference _firebaseRef =
      FirebaseDatabase.instance.ref('devices/AnxieEase001/Metrics');

  late String _currentSeverity;
  late int _currentHeartRate;
  late bool _isFirstRead;
  late DateTime _lastNotificationTime;
  VoidCallback? _onNotificationAdded;

  String get currentSeverity => _currentSeverity;
  int get currentHeartRate => _currentHeartRate;

  // Set callback for when a notification is added
  void setOnNotificationAddedCallback(VoidCallback callback) {
    _onNotificationAdded = callback;
  }

  // Initialize Firebase listener for heart rate
  void initializeHeartRateListener() {
    _firebaseRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      // Get heart rate from Firebase
      if (data.containsKey('heartRate')) {
        var hrValue = data['heartRate'];
        int heartRate = (hrValue is num)
            ? hrValue.toInt()
            : int.tryParse(hrValue.toString()) ?? 0;

        // Calculate severity based on heart rate
        String severity;
        if (heartRate > 120) {
          severity = 'severe';
        } else if (heartRate >= 111) {
          severity = 'moderate';
        } else if (heartRate >= 100) {
          severity = 'mild';
        } else {
          severity = 'normal';
        }

        // Skip first read to prevent initial notification
        if (_isFirstRead) {
          debugPrint('Skipping initial notification on app start');
          _isFirstRead = false;
          _currentHeartRate = heartRate;
          _currentSeverity = severity;
          notifyListeners();
          return;
        }

        // Check if severity has changed and it's not normal
        if (severity != 'normal' && severity != _currentSeverity) {
          // Check if enough time has passed since last notification (at least 2 seconds)
          final now = DateTime.now();
          if (now.difference(_lastNotificationTime).inSeconds >= 2) {
            debugPrint(
                'Sending notification for severity change: $_currentSeverity -> $severity');
            _currentHeartRate = heartRate;
            _currentSeverity = severity;
            _lastNotificationTime = now;
            notifyListeners();
            _sendAlert(heartRate, severity);
          }
        } else {
          // Just update the values without sending notification
          _currentHeartRate = heartRate;
          _currentSeverity = severity;
          notifyListeners();
        }
      }
    });
  }

  // Private method to send alerts
  Future<void> _sendAlert(int heartRate, String severity) async {
    String channelKey;
    String title = '';
    String body = '';
    NotificationCategory category;

    switch (severity) {
      case 'mild':
        channelKey = 'mild_heart_rate_alerts';
        title = '🟢 Mild Heart Rate Alert';
        body = 'Slight elevation in heart rate detected: $heartRate bpm';
        category = NotificationCategory.Status;
        break;
      case 'moderate':
        channelKey = 'moderate_heart_rate_alerts';
        title = '🟠 Moderate Heart Rate Alert';
        body = 'Elevated heart rate detected: $heartRate bpm';
        category = NotificationCategory.Status;
        break;
      case 'severe':
        channelKey = 'severe_heart_rate_alerts';
        title = '🔴 Severe Heart Rate Alert';
        body = 'URGENT: Very high heart rate detected: $heartRate bpm';
        category = NotificationCategory.Alarm;
        break;
      default:
        return;
    }

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: channelKey,
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
          category: category,
          wakeUpScreen: severity == 'severe',
          fullScreenIntent: severity == 'severe',
          criticalAlert: severity == 'severe',
          displayOnForeground: true,
          displayOnBackground: true,
        ),
        actionButtons: severity == 'severe'
            ? [
                NotificationActionButton(
                  key: 'DISMISS',
                  label: 'Dismiss',
                  actionType: ActionType.DismissAction,
                ),
                NotificationActionButton(
                  key: 'VIEW_DETAILS',
                  label: 'View Details',
                  actionType: ActionType.Default,
                ),
              ]
            : null,
      );
      debugPrint('Successfully created notification: $title');
      await _saveNotificationToSupabase(title, body, 'alert', severity);
      await _saveAnxietyLevelRecord(severity, false, heartRate);
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  // Delete all existing notification channels
  Future<void> _deleteExistingChannels() async {
    try {
      // Remove each of our known channel keys
      await AwesomeNotifications().removeChannel('severe_heart_rate_alerts');
      await AwesomeNotifications().removeChannel('moderate_heart_rate_alerts');
      await AwesomeNotifications().removeChannel('mild_heart_rate_alerts');
      await AwesomeNotifications().removeChannel('general_notifications');
      await AwesomeNotifications().removeChannel('reminders');
      // Remove any other old channels we find in the app
      await AwesomeNotifications().removeChannel('heart_rate_alerts');
      await AwesomeNotifications().removeChannel('alerts');
      await AwesomeNotifications().removeChannel('anxiease_notifications');
      await AwesomeNotifications().removeChannel('anxiety_alerts');
      await AwesomeNotifications().removeChannel('basic_notifications');
      await AwesomeNotifications().removeChannel('default_channel');
      debugPrint('Successfully deleted all existing notification channels');
    } catch (e) {
      debugPrint('Error deleting notification channels: $e');
    }
  }

  Future<void> initialize() async {
    // Delete existing channels first
    await _deleteExistingChannels();

    // Initialize awesome_notifications
    await AwesomeNotifications().initialize(
      null,
      [
        // Severe heart rate alerts - highest priority with urgent sound
        NotificationChannel(
          channelKey: 'severe_heart_rate_alerts',
          channelName: 'Severe Heart Rate Alerts',
          channelDescription: 'Critical alerts for dangerous heart rate levels',
          defaultColor: Colors.red,
          importance: NotificationImportance.High,
          enableVibration: true,
          enableLights: true,
          playSound: true,
          defaultRingtoneType:
              DefaultRingtoneType.Alarm, // Use alarm sound for severe
          ledColor: Colors.red,
        ),
        // Moderate heart rate alerts - medium priority with warning sound
        NotificationChannel(
          channelKey: 'moderate_heart_rate_alerts',
          channelName: 'Moderate Heart Rate Alerts',
          channelDescription: 'Alerts for elevated heart rate levels',
          defaultColor: Colors.orange,
          importance: NotificationImportance.High,
          enableVibration: true,
          enableLights: true,
          playSound: true,
          defaultRingtoneType: DefaultRingtoneType.Notification,
          ledColor: Colors.orange,
        ),
        // Mild heart rate alerts - lower priority with gentle sound
        NotificationChannel(
          channelKey: 'mild_heart_rate_alerts',
          channelName: 'Mild Heart Rate Alerts',
          channelDescription: 'Alerts for slightly elevated heart rate',
          defaultColor: Colors.yellow,
          importance: NotificationImportance.Default,
          enableVibration: true,
          enableLights: true,
          playSound: true,
          defaultRingtoneType: DefaultRingtoneType.Notification,
          ledColor: Colors.yellow,
        ),
        // Keep the general notifications channel
        NotificationChannel(
          channelKey: 'general_notifications',
          channelName: 'General Notifications',
          channelDescription: 'General notifications from AnxieEase app',
          defaultColor: Colors.blue,
          importance: NotificationImportance.Default,
          enableVibration: true,
          playSound: true,
        ),
        // Keep the reminders channel
        NotificationChannel(
          channelKey: 'reminders',
          channelName: 'Reminders',
          channelDescription: 'Regular reminders to help prevent anxiety',
          defaultColor: Colors.green,
          importance: NotificationImportance.Low,
          enableVibration: false,
          playSound: false,
        ),
      ],
    );

    // Initialize badge count from storage
    await _loadBadgeCount();

    // Check if reminders are enabled
    final bool isEnabled = await isAnxietyReminderEnabled();
    if (isEnabled) {
      final List<NotificationModel> activeReminders =
          await AwesomeNotifications().listScheduledNotifications();

      if (!activeReminders.any(
          (notification) => notification.content?.channelKey == 'reminders')) {
        final int intervalHours = await getAnxietyReminderInterval();
        await scheduleAnxietyReminders(intervalHours);
      } else {
        debugPrint(
            'Reminders already active. Skipping scheduling on initialize.');
      }
    }

    // Start listening for heart rate changes
    initializeHeartRateListener();
  }

  // Show a severity-based notification
  Future<void> _showSeverityNotification(
      String title, String body, String channelKey, String severity) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: channelKey,
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
          category: severity == 'severe'
              ? NotificationCategory.Alarm
              : NotificationCategory.Status,
          wakeUpScreen: true,
          fullScreenIntent: severity == 'severe',
          criticalAlert: severity == 'severe',
          displayOnForeground: true,
          displayOnBackground: true,
        ),
        actionButtons: severity == 'severe'
            ? [
                NotificationActionButton(
                  key: 'DISMISS',
                  label: 'Dismiss',
                  actionType: ActionType.DismissAction,
                ),
                NotificationActionButton(
                  key: 'VIEW_DETAILS',
                  label: 'View Details',
                  actionType: ActionType.Default,
                ),
              ]
            : null,
      );
      debugPrint('Successfully created notification: $title');
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  // Method to save anxiety level record to Supabase
  Future<void> _saveAnxietyLevelRecord(String severity, bool isManual,
      [int? heartRate]) async {
    try {
      debugPrint('📊 Saving anxiety level record to Supabase: $severity');

      final anxietyRecord = {
        'severity_level': severity,
        'timestamp': DateTime.now().toIso8601String(),
        'is_manual': isManual,
        'source': 'app',
        'details': isManual
            ? 'Manually triggered alert'
            : 'Automatically detected alert',
        'heart_rate': heartRate ?? 0, // Use provided heart rate or default to 0
      };

      await _supabaseService.saveAnxietyRecord(anxietyRecord);
      debugPrint('✅ Successfully saved anxiety level record to Supabase');
    } catch (e) {
      debugPrint('❌ Error saving anxiety level record to Supabase: $e');
      debugPrintStack();
    }
  }

  // Method to save notifications to Supabase
  Future<void> _saveNotificationToSupabase(
      String title, String message, String type, String severity) async {
    try {
      await _supabaseService.createNotification(
        title: title,
        message: message,
        type: type,
        relatedScreen: severity == 'severe' ? 'breathing_screen' : 'metrics',
      );
      debugPrint('💾 Saved severity notification to Supabase: $title');
      _onNotificationAdded?.call();
    } catch (e) {
      debugPrint('❌ Error saving notification to Supabase: $e');
    }
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

  // ANXIETY PREVENTION REMINDERS

  // Enable or disable anxiety prevention reminders
  Future<void> setAnxietyReminderEnabled(bool enabled,
      {int intervalHours = 6}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(reminderEnabledKey, enabled);
    await prefs.setInt(reminderIntervalKey, intervalHours);

    if (enabled) {
      // Schedule the reminders
      await scheduleAnxietyReminders(intervalHours);
    } else {
      // Cancel all scheduled reminders
      await cancelAnxietyReminders();
    }

    debugPrint(
        'Anxiety reminders ${enabled ? 'enabled' : 'disabled'} with interval of $intervalHours hours');
  }

  // Check if anxiety prevention reminders are enabled
  Future<bool> isAnxietyReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(reminderEnabledKey) ?? false;
  }

  // Get the interval for anxiety prevention reminders (in hours)
  Future<int> getAnxietyReminderInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(reminderIntervalKey) ?? 6; // Default to 6 hours
  }

  // Schedule anxiety prevention reminders
  Future<void> scheduleAnxietyReminders(int intervalHours) async {
    try {
      // First check if we already have active reminders
      final List<NotificationModel> activeReminders =
          await AwesomeNotifications().listScheduledNotifications();

      // If we already have reminders scheduled, don't create new ones
      if (activeReminders.any(
          (notification) => notification.content?.channelKey == 'reminders')) {
        debugPrint('Anxiety prevention reminders already scheduled. Skipping.');
        return;
      }

      // Cancel any existing scheduled reminders first
      await cancelAnxietyReminders();

      // Schedule the first reminder
      await _scheduleNextAnxietyReminder(1, intervalHours);

      debugPrint(
          'Successfully scheduled anxiety prevention reminders every $intervalHours hours');
    } catch (e) {
      debugPrint('Error scheduling anxiety reminders: $e');
    }
  }

  // Cancel all scheduled anxiety prevention reminders
  Future<void> cancelAnxietyReminders() async {
    await AwesomeNotifications().cancelNotificationsByChannelKey('reminders');
    debugPrint('Cancelled all anxiety prevention reminders');
  }

  // Schedule the next anxiety prevention reminder
  Future<void> _scheduleNextAnxietyReminder(
      int notificationId, int intervalHours) async {
    // List of reminder messages for variety
    final List<Map<String, String>> reminderMessages = [
      {
        'title': 'Anxiety Check-in',
        'body': 'Take a moment to breathe deeply and check how you\'re feeling.'
      },
      {
        'title': 'Anxiety Prevention',
        'body':
            'Remember to take short breaks and practice mindfulness throughout your day.'
      },
      {
        'title': 'Wellness Reminder',
        'body':
            'Stay hydrated and take a few deep breaths to maintain your calm.'
      },
      {
        'title': 'Mental Health Moment',
        'body': 'Consider taking a short walk or stretching to reduce tension.'
      },
      {
        'title': 'Relaxation Reminder',
        'body':
            'Try the 4-7-8 breathing technique: Inhale for 4, hold for 7, exhale for 8.'
      },
    ];

    // Select a random message from the list
    final message =
        reminderMessages[DateTime.now().millisecond % reminderMessages.length];

    // Calculate the next reminder time
    final DateTime scheduledTime =
        DateTime.now().add(Duration(hours: intervalHours));

    // Check if a notification with this ID is already scheduled
    final List<NotificationModel> activeNotifications =
        await AwesomeNotifications().listScheduledNotifications();

    if (activeNotifications
        .any((notification) => notification.content?.id == notificationId)) {
      debugPrint(
          'Notification with ID $notificationId already exists. Skipping.');
      return;
    }

    // Schedule the notification
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notificationId,
        channelKey: 'reminders',
        title: message['title'],
        body: message['body'],
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
      ),
      schedule: NotificationCalendar(
        hour: scheduledTime.hour,
        minute: scheduledTime.minute,
        second: 0,
        millisecond: 0,
        repeats: false,
      ),
    );

    // Also create a record in Supabase for display in the app
    await _supabaseService.createNotification(
      title: message['title'] ?? 'Anxiety Check-in',
      message: message['body'] ?? 'Take a moment to check how you\'re feeling.',
      type: 'reminder',
      relatedScreen: 'breathing',
    );

    // Schedule the next notification with a new ID
    int nextId = notificationId + 1;
    if (nextId > 1000) nextId = 1; // Reset ID to avoid going too high

    // Set up a delayed task to schedule the next reminder
    Future.delayed(Duration(hours: intervalHours), () {
      _scheduleNextAnxietyReminder(nextId, intervalHours);
    });

    debugPrint(
        'Scheduled anxiety prevention reminder for ${scheduledTime.toString()} with ID $notificationId');
  }
}
