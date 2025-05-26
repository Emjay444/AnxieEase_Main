import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'supabase_service.dart';

class SeverityNotifier with ChangeNotifier {
  final DatabaseReference _ref = FirebaseDatabase.instance
      .ref('devices/AnxieEase001/Metrics/anxietyDetected');
  final SupabaseService _supabaseService = SupabaseService();

  String _currentSeverity = 'unknown';
  bool _isFirstRead = true; // Flag to skip initial notification

  // Callback to trigger notification refresh in the UI
  VoidCallback? _onNotificationAdded;

  String get currentSeverity => _currentSeverity;

  SeverityNotifier() {
    _initializeNotifications();
  }

  // Method to set the notification refresh callback
  void setNotificationRefreshCallback(VoidCallback callback) {
    _onNotificationAdded = callback;
  }

  Future<void> _initializeNotifications() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'mild_alerts',
          channelName: 'Mild Alerts',
          channelDescription: 'Mild anxiety level alerts',
          defaultColor: Colors.green,
          importance: NotificationImportance.High,
          ledColor: Colors.green,
          enableVibration: true,
          playSound: true,
          // Uses default notification sound - gentle
        ),
        NotificationChannel(
          channelKey: 'moderate_alerts',
          channelName: 'Moderate Alerts',
          channelDescription: 'Moderate anxiety level alerts',
          defaultColor: Colors.orange,
          importance: NotificationImportance.High,
          ledColor: Colors.orange,
          enableVibration: true,
          playSound: true,
          // Uses default notification sound - more noticeable due to importance
        ),
        NotificationChannel(
          channelKey: 'severe_alerts',
          channelName: 'Severe Alerts',
          channelDescription: 'Severe anxiety level alerts - URGENT',
          defaultColor: Colors.red,
          importance: NotificationImportance.Max,
          ledColor: Colors.red,
          enableVibration: true,
          playSound: true,
          criticalAlerts: true,
          // Use default but with maximum importance for attention-grabbing behavior
        ),
        NotificationChannel(
          channelKey: 'alerts_channel',
          channelName: 'General Alerts',
          channelDescription: 'General anxiety level alerts',
          defaultColor: Colors.red,
          importance: NotificationImportance.High,
          ledColor: Colors.white,
          enableVibration: true,
          playSound: true,
        ),
        NotificationChannel(
          channelKey: 'basic_channel',
          channelName: 'Basic Notifications',
          channelDescription: 'Basic notification tests',
          defaultColor: Colors.blue,
          importance: NotificationImportance.High,
          enableVibration: true,
          playSound: true,
        ),
      ],
    );
  }

  void initializeListener() {
    _ref.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      final severity = data['severity']?.toString().toLowerCase();
      final heartRate = data['heartRate'];
      final temperature = data['temperature'];

      if (severity == null) return;

      // Update current severity and notify listeners
      _currentSeverity = severity;
      notifyListeners();

      // Skip notification on first read (app startup)
      if (_isFirstRead) {
        _isFirstRead = false;
        debugPrint('🔇 Skipping initial Firebase notification for: $severity');
        return;
      }

      // Only send notifications for actual data changes
      debugPrint(
          '🔔 Firebase data changed - sending notification for: $severity');

      String title = '';
      String body = '';
      String channelKey = '';
      String notificationType = '';

      switch (severity) {
        case 'mild':
          title = '🟢 Mild Alert';
          body =
              'Slight elevation in readings. Temp: $temperature°C, HR: $heartRate bpm';
          channelKey = 'mild_alerts';
          notificationType = 'alert';
          break;
        case 'moderate':
          title = '🟠 Moderate Alert';
          body =
              'Noticeable symptoms detected. Temp: $temperature°C, HR: $heartRate bpm';
          channelKey = 'moderate_alerts';
          notificationType = 'alert';
          break;
        case 'severe':
          title = '🔴 Severe Alert';
          body = 'URGENT: High risk! Temp: $temperature°C, HR: $heartRate bpm';
          channelKey = 'severe_alerts';
          notificationType = 'alert';
          break;
        default:
          return;
      }

      // Send push notification
      _sendNotificationWithChannel(title, body, channelKey, severity);

      // Save notification to Supabase for homepage display
      _saveNotificationToSupabase(title, body, notificationType, severity);
    });
  }

  Future<void> _sendNotification(String title, String body) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'alerts_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  Future<void> _sendNotificationWithChannel(
      String title, String body, String channelKey, String severity) async {
    // Send only ONE notification per alert, regardless of severity
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: channelKey,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        category: severity == 'severe'
            ? NotificationCategory.Alarm
            : NotificationCategory.Reminder,
        wakeUpScreen: severity == 'severe',
        fullScreenIntent: severity == 'severe',
        criticalAlert: severity == 'severe',
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
  }

  // Method to manually trigger a notification based on current severity
  Future<void> sendManualNotification() async {
    String title = '';
    String body = '';
    String channelKey = '';

    switch (_currentSeverity) {
      case 'mild':
        title = '🟢 Mild Alert (Manual)';
        body = 'Slight elevation in anxiety readings detected.';
        channelKey = 'mild_alerts';
        break;
      case 'moderate':
        title = '🟠 Moderate Alert (Manual)';
        body = 'Moderate anxiety symptoms detected.';
        channelKey = 'moderate_alerts';
        break;
      case 'severe':
        title = '🔴 Severe Alert (Manual)';
        body = 'URGENT: High anxiety levels detected!';
        channelKey = 'severe_alerts';
        break;
      default:
        title = 'Status Update';
        body = 'Current status: $_currentSeverity';
        channelKey = 'alerts_channel';
    }

    // Send push notification
    await _sendNotificationWithChannel(
        title, body, channelKey, _currentSeverity);

    // Save notification to Supabase for homepage display
    await _saveNotificationToSupabase(title, body, 'alert', _currentSeverity);
  }

  // Method to test notifications directly
  Future<void> sendTestNotification() async {
    debugPrint('🧪 Sending test notification...');

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 999,
        channelKey: 'basic_channel',
        title: '🧪 Test Notification',
        body: 'This is a test notification from AnxieEase',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  // New method to save notifications to Supabase
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

      // Trigger notification refresh in the UI
      _onNotificationAdded?.call();
    } catch (e) {
      debugPrint('❌ Error saving notification to Supabase: $e');
    }
  }
}
