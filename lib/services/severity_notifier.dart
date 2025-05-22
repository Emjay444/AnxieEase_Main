import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

class SeverityNotifier with ChangeNotifier {
  final DatabaseReference _ref = FirebaseDatabase.instance
      .ref('devices/AnxieEase001/Metrics/anxietyDetected');

  String _currentSeverity = 'unknown';

  String get currentSeverity => _currentSeverity;

  SeverityNotifier() {
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'alerts_channel',
          channelName: 'Alerts',
          channelDescription: 'Anxiety level alerts',
          defaultColor: Colors.red,
          importance: NotificationImportance.High,
          ledColor: Colors.white,
        ),
        NotificationChannel(
          channelKey: 'basic_channel',
          channelName: 'Basic Notifications',
          channelDescription: 'Basic notification tests',
          defaultColor: Colors.blue,
          importance: NotificationImportance.High,
          enableVibration: true,
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
      final timestamp =
          data['timestamp']?.toString() ?? DateTime.now().toString();

      if (severity == null) return;

      _currentSeverity = severity;
      notifyListeners();

      String title = '';
      String body = '';

      switch (severity) {
        case 'mild':
          title = '🟢 Mild Alert';
          body =
              'Slight elevation in readings. Temp: $temperature°C, HR: $heartRate bpm';
          break;
        case 'moderate':
          title = '🟠 Moderate Alert';
          body =
              'Noticeable symptoms detected. Temp: $temperature°C, HR: $heartRate bpm';
          break;
        case 'severe':
          title = '🔴 Severe Alert';
          body = 'URGENT: High risk! Temp: $temperature°C, HR: $heartRate bpm';
          break;
        default:
          return;
      }

      _sendNotification(title, body);
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

  // Method to manually trigger a notification based on current severity
  Future<void> sendManualNotification() async {
    String title = '';
    String body = '';

    switch (_currentSeverity) {
      case 'mild':
        title = '🟢 Mild Alert (Manual)';
        body = 'Slight elevation in anxiety readings detected.';
        break;
      case 'moderate':
        title = '🟠 Moderate Alert (Manual)';
        body = 'Moderate anxiety symptoms detected.';
        break;
      case 'severe':
        title = '🔴 Severe Alert (Manual)';
        body = 'URGENT: High anxiety levels detected!';
        break;
      default:
        title = 'Status Update';
        body = 'Current status: $_currentSeverity';
    }

    await _sendNotification(title, body);
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
}
