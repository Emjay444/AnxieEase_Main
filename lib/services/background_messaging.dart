import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import '../firebase_options.dart';

/// This function handles background messages when the app is terminated or in background.
/// It must be a top-level function (not inside a class) to work properly.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize Firebase if not already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    debugPrint('🔔 Background FCM received: ${message.notification?.title}');
    debugPrint('📊 Background FCM data: ${message.data}');

    // Initialize AwesomeNotifications for background notifications
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'anxiety_alerts',
          channelName: 'Anxiety Alerts',
          channelDescription: 'Notifications for anxiety level alerts',
          defaultColor: const Color(0xFF9D50DD),
          importance: NotificationImportance.High,
          ledColor: Colors.white,
          enableVibration: true,
        ),
      ],
    );

    // Create a local notification from the FCM message
    if (message.notification != null) {
      final notification = message.notification!;
      final data = message.data;

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'anxiety_alerts',
          title: notification.title ?? 'AnxieEase Alert',
          body: notification.body ?? 'Check your anxiety levels',
          notificationLayout: NotificationLayout.Default,
          category: data['severity'] == 'severe'
              ? NotificationCategory.Alarm
              : NotificationCategory.Reminder,
          wakeUpScreen: data['severity'] == 'severe',
          criticalAlert: data['severity'] == 'severe',
          payload: data.map((key, value) => MapEntry(key, value.toString())),
        ),
      );

      debugPrint('✅ Background notification created successfully');
    }

    // Save critical data for when app reopens
    if (message.data.containsKey('severity')) {
      debugPrint('🚨 Background alert severity: ${message.data['severity']}');
      // Note: You can save to local storage here if needed
    }
  } catch (e) {
    debugPrint('❌ Error handling background FCM: $e');
  }
}
