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

    debugPrint('🔔 Background FCM received data-only message');
    debugPrint('📊 Background FCM data: ${message.data}');

    // Process ALL anxiety alerts (now data-only) and any other notifications with severity data
    if (message.data['type'] == 'anxiety_alert' ||
        message.data['type'] == 'direct_test_device' ||
        message.data.containsKey('severity') ||
        message.data['override_notification'] == 'true') {
      debugPrint('🚨 Processing data-only anxiety alert - creating local notification');

      String severity = message.data['severity'] ?? 'mild';
      String soundResource = _getSeveritySound(severity);
      String channelKey = _getSeverityChannel(severity);

      // Get title and body from data payload (data-only approach)
      String title = message.data['title'] ?? message.data['message'] ?? '🚨 Anxiety Alert';
      String body = message.data['message'] ?? message.data['body'] ?? 'Please check your levels';

      debugPrint('🔊 Using sound for ${severity}: ${soundResource}');
      debugPrint('📺 Using channel for ${severity}: ${channelKey}');
      debugPrint('📋 Title: ${title}');
      debugPrint('📝 Body: ${body}');

      // Create local notification from data-only FCM message
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
            'source': 'fcm_bg_data_only',
            if (message.data['heartRate'] != null)
              'heartRate': message.data['heartRate'].toString(),
            if (message.data['baseline'] != null)
              'baseline': message.data['baseline'].toString(),
            if (message.data['duration'] != null)
              'duration': message.data['duration'].toString(),
          },
        ),
      );

      debugPrint('✅ Local notification created from data-only FCM message');

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

    // Extract comprehensive information from FCM data payload
    final severity = message.data['severity'] ?? 'unknown';
    final heartRate = message.data['heartRate'] ?? 'N/A';
    final baseline = message.data['baseline'];
    final duration = message.data['duration'];
    final reason = message.data['reason'];
    final userId = message.data['userId'];
    final sessionId = message.data['sessionId'];
    final deviceId = message.data['deviceId'];
    final timestamp = message.data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Get title and body from data payload (preferred) or notification payload
    String title = message.data['title'] ?? 
                   message.data['message'] ?? 
                   message.notification?.title ?? 
                   'Anxiety Alert';
    String body = message.data['body'] ?? 
                  message.data['message'] ?? 
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

      // Enhanced body with more context
      if (baseline != null && duration != null) {
        body = 'Heart rate: ${heartRate} BPM for ${duration}s (baseline: ${baseline} BPM). ${reason ?? "Please take a moment to breathe."}';
      } else if (baseline != null) {
        body = 'Heart rate: ${heartRate} BPM (baseline: ${baseline} BPM). ${reason ?? "Please take a moment to breathe."}';
      } else {
        body = 'Heart rate: ${heartRate} BPM - ${severity} anxiety level detected. ${reason ?? "Please check your status."}';
      }
    }

    // Create comprehensive notification data as JSON string for better structure
    final notificationData = {
      'title': title,
      'body': body,
      'severity': severity,
      'heartRate': heartRate,
      'baseline': baseline,
      'duration': duration,
      'reason': reason,
      'userId': userId,
      'sessionId': sessionId,
      'deviceId': deviceId,
      'timestamp': timestamp,
      'receivedAt': DateTime.now().toIso8601String(),
      'type': message.data['type'] ?? 'anxiety_alert',
      'source': 'background_fcm'
    };

    // Convert to JSON string for storage
    final notificationString = notificationData.entries
        .map((e) => '${e.key}=${e.value ?? "null"}')
        .join('&');

    // Get existing pending notifications
    final existingNotifications =
        prefs.getStringList('pending_notifications') ?? [];

    // Add new notification
    existingNotifications.add(notificationString);

    // Store back to SharedPreferences
    await prefs.setStringList('pending_notifications', existingNotifications);

    debugPrint('💾 [BACKGROUND] Stored notification locally: $title');
    debugPrint('📝 [BACKGROUND] Full data: $notificationString');
    debugPrint(
        '📍 [BACKGROUND] Total pending: ${existingNotifications.length}');
    
    // Debug: Print all pending notifications
    debugPrint('📋 [BACKGROUND] All pending notifications:');
    for (int i = 0; i < existingNotifications.length; i++) {
      debugPrint('   [$i]: ${existingNotifications[i]}');
    }
    
    // Also store debug info with timestamp for later checking
    final debugKey = 'last_background_notification_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString(debugKey, 'STORED: $title at ${DateTime.now().toIso8601String()}');
    debugPrint('🔍 [BACKGROUND] Debug marker stored: $debugKey');
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
