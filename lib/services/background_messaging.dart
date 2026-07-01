import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // For WidgetsFlutterBinding.ensureInitialized
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add SharedPreferences for local storage
import '../firebase_options.dart';

/// This function handles background messages when the app is terminated or in background.
/// It must be a top-level function (not inside a class) to work properly.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Ensure Flutter bindings for background isolate before using any plugin APIs
    // This helps avoid MissingPluginException in background (SharedPreferences, Awesome Notifications, etc.)
    WidgetsFlutterBinding.ensureInitialized();

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

    // Process anxiety alerts and wellness reminders.
    // When message.notification is present the OS already showed a system notification
    // (notification+data message), so we skip creating a local duplicate.
    // We still run the data-processing path (payload storage, routing, etc.).
    if (message.data['type'] == 'anxiety_alert' ||
        message.data['type'] == 'direct_test_device' ||
        message.data.containsKey('severity') ||
        message.data['override_notification'] == 'true' ||
        message.data['type'] == 'wellness_reminder' ||
        message.data['type'] == 'reminder') {
      debugPrint(
          '🔔 Background FCM: type=${message.data['type']}, hasSystemNotif=${message.notification != null}');

      // OS already showed the notification — skip local duplicate
      if (message.notification != null) {
        debugPrint('✅ System notification shown by OS, skipping local duplicate');
        return;
      }

      debugPrint('🚨 Data-only message — creating local notification');

      // Check if this is a wellness reminder
      final isWellnessReminder = message.data['type'] == 'wellness_reminder' ||
          message.data['type'] == 'reminder';

      String severity = message.data['severity'] ?? 'mild';
      String soundResource = _getSeveritySound(severity);
      String channelKey = _getSeverityChannel(severity);

      // Override for wellness reminders
      if (isWellnessReminder) {
        soundResource = 'resource://raw/mild_alerts'; // Gentle sound
        channelKey = 'wellness_reminders'; // Wellness channel
        debugPrint('🍃 Processing wellness reminder in background');
      }

      // Get title and body from data payload (data-only approach)
      String title = message.data['title'] ??
          message.data['message'] ??
          (isWellnessReminder ? 'Wellness Reminder' : '🚨 Anxiety Alert');
      String body = message.data['message'] ??
          message.data['body'] ??
          (isWellnessReminder
              ? 'Take a moment to check how you\'re feeling.'
              : 'Please check your levels');

      debugPrint(
          '🔊 Using sound for ${isWellnessReminder ? 'wellness' : severity}: ${soundResource}');
      debugPrint(
          '📺 Using channel for ${isWellnessReminder ? 'wellness' : severity}: ${channelKey}');
      debugPrint('📋 Title: ${title}');
      debugPrint('📝 Body: ${body}');

      // Feature flag: optionally store to local pending queue for later Supabase sync
      if (_BackgroundConfig.usePendingStorage) {
        await _storeNotificationLocally(message);
      }

      // Ensure channels exist even when app is killed (minimal background init)
      await _ensureBackgroundNotificationChannelsInitialized();

      try {
        // Create local notification from data-only FCM message
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            channelKey:
                channelKey, // Use appropriate channel (wellness or severity-specific)
            // Ensure a valid small icon is set (required on Android O+)
            icon: 'resource://drawable/ic_notification',
            title: title,
            body: body,
            notificationLayout: NotificationLayout.Default,
            // Use appropriate category
            category: isWellnessReminder
                ? NotificationCategory.Reminder
                : NotificationCategory.Status,
            criticalAlert: false,
            wakeUpScreen: isWellnessReminder
                ? false
                : true, // Don't wake screen for wellness reminders
            customSound: soundResource,
            autoDismissible: true,
            // Include payload so the app can route taps properly when launching from terminated/background state
            payload: {
              'type': message.data['type'] ?? 'anxiety_alert',
              'severity': severity,
              'action':
                  isWellnessReminder ? 'open_wellness' : 'open_notifications',
              'related_screen': message.data['related_screen']?.toString() ??
                  (isWellnessReminder ? 'breathing_screen' : 'notifications'),
              'source': 'fcm_bg_data_only',
              'category': message.data['category'] ?? 'general',
              'messageType': message.data['messageType'] ?? '',
              // Forward the backend's confirmation/routing intent so the tap
              // handler (onActionNotificationMethod in main.dart) sees the
              // same context the foreground FCM listener does. Without this,
              // requiresConfirmation defaulted to false for every
              // backgrounded/killed anxiety alert, skipping straight to
              // breathing/grounding instead of the check-in dialog.
              if (message.data['requiresConfirmation'] != null)
                'requiresConfirmation':
                    message.data['requiresConfirmation'].toString(),
              if (message.data['alertType'] != null)
                'alertType': message.data['alertType'].toString(),
              if (message.data['autoConfirm'] != null)
                'autoConfirm': message.data['autoConfirm'].toString(),
              if (message.data['notificationId'] != null)
                'notificationId': message.data['notificationId'].toString(),
              if (message.data['related_id'] != null)
                'related_id': message.data['related_id'].toString(),
              if (message.data['deviceId'] != null)
                'deviceId': message.data['deviceId'].toString(),
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
      } catch (e) {
        debugPrint('❌ Failed to create local notification in background: $e');
        // Fallback: try using a generic channel if severity-specific fails
        try {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              channelKey: 'anxiety_alerts',
              // Ensure a valid small icon is set
              icon: 'resource://drawable/ic_notification',
              title: title,
              body: body,
              notificationLayout: NotificationLayout.Default,
              category: NotificationCategory.Alarm,
              autoDismissible: true,
            ),
          );
          debugPrint('✅ Fallback local notification sent on generic channel');
        } catch (e2) {
          debugPrint('❌ Fallback notification also failed: $e2');
        }
      }
    }

    // Save critical data for when app reopens
    if (message.data.containsKey('severity')) {
      debugPrint('🚨 Background alert severity: ${message.data['severity']}');
    }
  } catch (e) {
    debugPrint('❌ Error handling background FCM: $e');
  }
}

/// Lightweight configuration for background handler behavior
class _BackgroundConfig {
  // When true, background handler stores notifications in SharedPreferences
  // for later sync into Supabase on app open. Set to false once backend writes
  // alerts directly to Supabase to simplify the client flow.
  // ✅ ENABLED: keep storing so the app can sync when reopened without tap.
  static const bool usePendingStorage = true;
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
    final timestamp = message.data['timestamp'] ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final notificationId =
        message.data['notificationId'] ?? 'pending_$timestamp';

    // Get title and body from data payload (preferred) or notification payload
    // The Cloud Function sends properly formatted title/message, so use those first
    String title =
        message.data['title'] ?? message.notification?.title ?? 'Notification';
    String body =
        message.data['message'] ?? // Cloud Function uses 'message' field
            message.data['body'] ??
            message.notification?.body ??
            'You have a new notification.';

    // Determine if this is a wellness reminder
    final messageType = message.data['type'] ?? '';
    final isWellnessReminder =
        messageType == 'wellness_reminder' || messageType == 'reminder';

    // Only override title/body if Cloud Function didn't provide them (legacy support)
    // Check if we have Cloud Function formatted messages by looking for percentage info
    final hasCloudFunctionMessage = body.contains('above baseline') ||
        body.contains('% above') ||
        body.contains('Are you experiencing');

    if (!isWellnessReminder &&
        severity != 'unknown' &&
        !hasCloudFunctionMessage) {
      // Legacy fallback: only use this if Cloud Function didn't send formatted message
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
        body =
            'Heart rate: ${heartRate} BPM for ${duration}s (baseline: ${baseline} BPM). ${reason ?? "Please take a moment to breathe."}';
      } else if (baseline != null) {
        body =
            'Heart rate: ${heartRate} BPM (baseline: ${baseline} BPM). ${reason ?? "Please take a moment to breathe."}';
      } else {
        body =
            'Heart rate: ${heartRate} BPM - ${severity} anxiety level detected. ${reason ?? "Please check your status."}';
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
      'notificationId': notificationId,
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
    final debugKey =
        'last_background_notification_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString(
        debugKey, 'STORED: $title at ${DateTime.now().toIso8601String()}');
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
      return 'resource://raw/mild_alerts';
    case 'moderate':
      return 'resource://raw/moderate_alerts';
    case 'severe':
      return 'resource://raw/severe_alerts';
    case 'critical':
      return 'resource://raw/critical_alerts';
    default:
      return 'resource://raw/mild_alerts'; // Default fallback
  }
}

/// Get severity-specific notification channel
String _getSeverityChannel(String severity) {
  switch (severity.toLowerCase()) {
    case 'mild':
      return 'mild_anxiety_alerts_v4'; // Back to original working channel
    case 'moderate':
      return 'moderate_anxiety_alerts_v2'; // Back to original working channel
    case 'severe':
      return 'severe_anxiety_alerts_v2'; // Back to original working channel
    case 'critical':
      return 'critical_anxiety_alerts_v2'; // Back to original working channel
    default:
      return 'anxiety_alerts'; // Default fallback
  }
}

// Ensure minimal notification channels exist when running in background isolate
bool _bgChannelsInitialized = false;
Future<void> _ensureBackgroundNotificationChannelsInitialized() async {
  if (_bgChannelsInitialized) return;
  try {
    // Initialize with a valid default small icon required for Android O+
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_notification', // Default small icon
      [
        NotificationChannel(
          channelKey: 'wellness_reminders',
          channelName: 'Wellness Reminders',
          channelDescription: 'Daily wellness and breathing reminders',
          importance: NotificationImportance.Default,
          enableVibration: false,
          playSound: true,
        ),
        NotificationChannel(
          channelKey: 'anxiety_alerts',
          channelName: 'General Anxiety Alerts',
          channelDescription: 'General anxiety level alerts',
          importance: NotificationImportance.High,
          enableVibration: true,
          playSound: true,
        ),
        NotificationChannel(
          channelKey: 'mild_anxiety_alerts_v4',
          channelName: 'Mild Anxiety Alerts',
          channelDescription: 'Mild anxiety notifications',
          importance: NotificationImportance.Max,
          enableVibration: true,
          playSound: true,
          soundSource: 'resource://raw/mild_alert',
          // Avoid critical alerts to prevent OEM alarm behaviors
          criticalAlerts: false,
          onlyAlertOnce:
              true, // Prevent sound looping - play only once per notification
        ),
        NotificationChannel(
          channelKey: 'moderate_anxiety_alerts_v2',
          channelName: 'Moderate Anxiety Alerts',
          channelDescription: 'Moderate anxiety notifications',
          importance: NotificationImportance.High,
          enableVibration: true,
          playSound: true,
          soundSource: 'resource://raw/moderate_alert',
          onlyAlertOnce:
              true, // Prevent sound looping - play only once per notification
        ),
        NotificationChannel(
          channelKey: 'severe_anxiety_alerts_v2',
          channelName: 'Severe Anxiety Alerts',
          channelDescription: 'Severe anxiety notifications',
          importance: NotificationImportance.High,
          enableVibration: true,
          playSound: true,
          soundSource: 'resource://raw/severe_alert',
          onlyAlertOnce:
              true, // Prevent sound looping - play only once per notification
        ),
        NotificationChannel(
          channelKey: 'critical_anxiety_alerts_v2',
          channelName: 'Critical Anxiety Alerts',
          channelDescription: 'Critical anxiety notifications',
          importance: NotificationImportance.Max,
          enableVibration: true,
          playSound: true,
          soundSource: 'resource://raw/critical_alert',
          // Keep non-critical to avoid special alarm treatment; rely on importance Max
          criticalAlerts: false,
          onlyAlertOnce:
              true, // Prevent sound looping - play only once per notification
        ),
      ],
    );
    _bgChannelsInitialized = true;
    debugPrint('🔔 Background notification channels initialized');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize background channels: $e');
  }
}
