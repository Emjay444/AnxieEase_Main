import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add SharedPreferences for local storage
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

    // Initialize Supabase for background operations (no Flutter dependency)
    debugPrint('🔧 Initializing Supabase for background operations...');

    debugPrint('🔔 Background FCM received: ${message.notification?.title}');
    debugPrint('📊 Background FCM data: ${message.data}');

    // For anxiety alerts OR any notification with severity data, create a custom notification
    if (message.data['type'] == 'anxiety_alert' ||
        message.data['type'] == 'direct_test_device' ||
        message.notification?.title?.contains('Anxiety') == true ||
        message.data.containsKey('severity') ||
        message.data['override_notification'] == 'true') {
      debugPrint('🚨 Creating custom notification with severity-based sound');

      String severity = message.data['severity'] ?? 'mild';
      String soundResource = _getSeveritySound(severity);
      String channelKey = _getSeverityChannel(severity);

      // Get title and body from data payload (preferred) or notification payload
      String title =
          message.data['title'] ?? message.notification?.title ?? '🚨 Alert';
      String body = message.data['body'] ??
          message.notification?.body ??
          'Please check your levels';

      debugPrint('🔊 Using sound for ${severity}: ${soundResource}');
      debugPrint('📺 Using channel for ${severity}: ${channelKey}');
      debugPrint('📋 Title: ${title}');
      debugPrint('📝 Body: ${body}');

      // Create custom notification that will override any FCM default notification
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: channelKey, // Use severity-specific channel
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Alarm,
          criticalAlert: severity == 'critical',
          wakeUpScreen: true,
          customSound: soundResource, // Use severity-specific sound
          autoDismissible: true,
          // Include payload so the app can route taps properly when launching from terminated/background state
          payload: {
            'type': message.data['type'] ?? 'anxiety_alert',
            'severity': severity,
            'action': 'open_notifications',
            'related_screen': 'notifications',
            'source': 'fcm_bg',
            if (message.data['heartRate'] != null)
              'heartRate': message.data['heartRate'].toString(),
            if (message.data['baseline'] != null)
              'baseline': message.data['baseline'].toString(),
            if (message.data['percentageAbove'] != null)
              'percentageAbove': message.data['percentageAbove'].toString(),
          },
        ),
      );

      debugPrint('✅ Custom notification created successfully');

      // IMPORTANT: Store the notification locally for app to sync later
      await _storeNotificationLocally(message);
    }

    // Save critical data for when app reopens
    if (message.data.containsKey('severity')) {
      debugPrint('🚨 Background alert severity: ${message.data['severity']}');
    }
  } catch (e) {
    debugPrint('❌ Error handling background FCM: $e');
  }
}

/// Store background-received notification locally using SharedPreferences
Future<void> _storeNotificationLocally(RemoteMessage message) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Extract information from FCM data
    final severity = message.data['severity'] ?? 'unknown';
    final heartRate = message.data['heartRate'] ?? 'N/A';
    final baseline = message.data['baseline'];

    String title =
        message.data['title'] ?? message.notification?.title ?? 'Anxiety Alert';
    String body = message.data['body'] ??
        message.notification?.body ??
        'Anxiety detected. Please check your status.';

    // Create more descriptive notification based on severity
    if (severity != 'unknown') {
      switch (severity.toLowerCase()) {
        case 'mild':
          title = '🟢 Mild Anxiety Alert';
          break;
        case 'moderate':
          title = '🟠 Moderate Anxiety Alert';
          break;
        case 'severe':
          title = '🔴 Severe Anxiety Alert';
          break;
        case 'critical':
          title = '🚨 Critical Anxiety Alert';
          break;
      }

      if (baseline != null) {
        final percentageAbove = message.data['percentageAbove'];
        if (percentageAbove != null) {
          body =
              'Heart rate: ${heartRate} BPM (${percentageAbove}% above your baseline of ${baseline} BPM)';
        } else {
          body = 'Heart rate: ${heartRate} BPM (baseline: ${baseline} BPM)';
        }
      } else {
        body =
            'Heart rate: ${heartRate} BPM - ${severity} anxiety level detected';
      }
    }

    // Create notification data as simple pipe-separated string
    final notificationString =
        '${title}|${body}|${severity}|${DateTime.now().toIso8601String()}';

    // Get existing pending notifications
    final existingNotifications =
        prefs.getStringList('pending_notifications') ?? [];

    // Add new notification
    existingNotifications.add(notificationString);

    // Store back to SharedPreferences
    await prefs.setStringList('pending_notifications', existingNotifications);

    debugPrint('💾 [BACKGROUND] Stored notification locally: $title');
    debugPrint(
        '📍 [BACKGROUND] Total pending: ${existingNotifications.length}');
  } catch (e) {
    debugPrint('❌ [BACKGROUND] Error storing notification locally: $e');
    // Don't crash the background handler if storage fails
  }
}

/// Get severity-specific sound resource path
String _getSeveritySound(String severity) {
  switch (severity.toLowerCase()) {
    case 'mild':
      return 'resource://raw/mild_alert';
    case 'moderate':
      return 'resource://raw/moderate_alert';
    case 'severe':
      return 'resource://raw/severe_alert';
    case 'critical':
      return 'resource://raw/critical_alert';
    default:
      return 'resource://raw/mild_alert'; // Default fallback
  }
}

/// Get severity-specific notification channel
String _getSeverityChannel(String severity) {
  switch (severity.toLowerCase()) {
    case 'mild':
      return 'mild_anxiety_alerts_v3'; // Updated to match current channel
    case 'moderate':
      return 'moderate_anxiety_alerts';
    case 'severe':
      return 'severe_anxiety_alerts';
    case 'critical':
      return 'critical_anxiety_alerts';
    default:
      return 'anxiety_alerts'; // Default fallback
  }
}
