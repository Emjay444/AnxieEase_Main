import 'dart:async';
import 'dart:io' show Platform; // Guarded with kIsWeb before use
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'supabase_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    _initFirebaseRef();
  }

  static const String notificationPermissionKey =
      'notification_permission_status';
  static const String badgeCountKey = 'notification_badge_count';
  static const String reminderEnabledKey = 'anxiety_reminders_enabled';
  static const String reminderIntervalKey = 'anxiety_reminder_interval_hours';

  final SupabaseService _supabaseService = SupabaseService();
  DatabaseReference? _firebaseRef;
  String? _currentDeviceId;
  String _currentSeverity = 'unknown';
  int _currentHeartRate = 0;
  bool _isFirstRead = true;
  VoidCallback? _onNotificationAdded;
  bool _isInitialized = false;
  bool _isInitializing = false;
  final Completer<void> _initCompleter = Completer<void>();
  StreamSubscription<DatabaseEvent>?
      _dbSubscription; // Guard against multiple listeners

  // Local de-duplication for app-side detection
  String? _lastLocalSeverity;
  int _lastLocalSeverityTimeMs = 0;

  String get currentSeverity => _currentSeverity;
  int get currentHeartRate => _currentHeartRate;
  bool get isInitialized => _isInitialized;

  // Initialize Firebase reference safely
  void _initFirebaseRef() {
    try {
      if (Firebase.apps.isNotEmpty) {
        // Use current device ID if provided, fallback to a default testing device
        final deviceId = _currentDeviceId ?? 'AnxieEase001';
        _firebaseRef =
            FirebaseDatabase.instance.ref('devices/$deviceId/current');
        debugPrint('Firebase reference initialized for device: $deviceId');
      } else {
        debugPrint(
            'Firebase not yet initialized, will initialize reference later');
      }
    } catch (e) {
      debugPrint('Error initializing Firebase reference: $e');
    }
  }

  // Update Firebase reference when device changes
  void updateDeviceReference(String? deviceId) {
    try {
      if (Firebase.apps.isNotEmpty && deviceId != null) {
        // Cancel existing subscription if any
        _dbSubscription?.cancel();

        // Update Firebase reference
        _currentDeviceId = deviceId;
        _firebaseRef =
            FirebaseDatabase.instance.ref('devices/$deviceId/current');
        debugPrint('Firebase reference updated for device: $deviceId');

        // Restart listening if we were already listening
        if (_isInitialized) {
          initializeListener();
        }
      }
    } catch (e) {
      debugPrint('Error updating Firebase reference: $e');
    }
  } // Set callback for when a notification is added

  void setOnNotificationAddedCallback(VoidCallback callback) {
    _onNotificationAdded = callback;
  }

  Future<void> initialize() async {
    // If already initialized, return immediately
    if (_isInitialized) {
      debugPrint('NotificationService already initialized');
      return;
    }

    // If initialization is in progress, wait for it to complete
    if (_isInitializing) {
      debugPrint('NotificationService initialization in progress, waiting...');
      return _initCompleter.future;
    }

    _isInitializing = true;

    try {
      // Make sure Firebase reference is initialized
      if (_firebaseRef == null && Firebase.apps.isNotEmpty) {
        _initFirebaseRef();
      }

      // Set a timeout for initialization
      await _initializeNotifications().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint(
              '⚠️ NotificationService initialization timed out, continuing anyway');
          // Don't throw exception, just continue
        },
      );

      _isInitialized = true;
      _isInitializing = false;
      _initCompleter.complete();
      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
      _isInitializing = false;
      _initCompleter.completeError(e);
      // Don't rethrow - allow the app to continue even if notifications fail
    }
  }

  Future<void> _initializeNotifications() async {
    // Initialize awesome_notifications with AnxieEase custom icon
    await AwesomeNotifications().initialize(
      'resource://drawable/launcher_icon', // Use AnxieEase custom icon instead of Flutter default
      [
        NotificationChannel(
          channelKey: 'anxiease_channel',
          channelName: 'AnxieEase Notifications',
          channelDescription: 'Notifications from AnxieEase app',
          defaultColor: Colors.blue,
          importance: NotificationImportance.High,
          enableVibration: true,
          icon: 'resource://drawable/launcher_icon',
        ),
        NotificationChannel(
          channelKey: 'alerts_channel',
          channelName: 'Alerts',
          channelDescription: 'Notification alerts for severity levels',
          defaultColor: Colors.red,
          importance: NotificationImportance.High,
          ledColor: Colors.white,
          icon: 'resource://drawable/launcher_icon',
        ),
        NotificationChannel(
          channelKey: 'reminders_channel',
          channelName: 'Local Anxiety Reminders',
          channelDescription:
              'Local scheduled reminders to help prevent anxiety attacks',
          defaultColor: Colors.green,
          importance: NotificationImportance.High,
          ledColor: Colors.green,
          icon: 'resource://drawable/launcher_icon',
        ),
        NotificationChannel(
          channelKey: 'anxiety_alerts',
          channelName: 'Anxiety Alerts',
          channelDescription: 'Notifications for anxiety level alerts',
          defaultColor: Colors.red,
          importance: NotificationImportance.High,
          ledColor: Colors.white,
          icon: 'resource://drawable/launcher_icon',
        ),
        NotificationChannel(
          channelKey: 'wellness_reminders',
          channelName: 'Wellness Reminders',
          channelDescription:
              'FCM-based wellness reminders that work when app is closed',
          defaultColor: const Color(0xFF2D9254),
          importance: NotificationImportance.Default,
          ledColor: const Color(0xFF2D9254),
          enableVibration: true,
          playSound: true,
          icon: 'resource://drawable/launcher_icon',
        ),
      ],
    );

    // Initialize badge count from storage
    await _loadBadgeCount();

    // Check if reminders are enabled
    final bool isEnabled = await isAnxietyReminderEnabled();
    if (isEnabled) {
      // Check if we already have active reminders before scheduling new ones
      final List<NotificationModel> activeReminders =
          await AwesomeNotifications().listScheduledNotifications();

      if (!activeReminders.any((notification) =>
          notification.content?.channelKey == 'reminders_channel')) {
        final int intervalHours = await getAnxietyReminderInterval();
        await scheduleAnxietyReminders(intervalHours);
      } else {
        debugPrint(
            'Reminders already active. Skipping scheduling on initialize.');
      }
    }
  }

  // Initialize Firebase listener for anxiety severity
  void initializeListener() {
    if (_firebaseRef == null) {
      debugPrint('Cannot initialize listener: Firebase reference is null');
      return;
    }

    // Prevent duplicate subscriptions
    if (_dbSubscription != null) {
      debugPrint('NotificationService listener already attached; skipping');
      return;
    }

    _dbSubscription = _firebaseRef!.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      bool shouldNotifyListeners = false;

      // Get heart rate from the root level
      final heartRate = data['heartRate'] as int?;
      if (heartRate != null && heartRate != _currentHeartRate) {
        _currentHeartRate = heartRate;
        shouldNotifyListeners = true;
        debugPrint('💓 Heart rate updated: $heartRate bpm');
      }

      // Get anxiety detection data
      final anxietyData = data['anxietyDetected'] as Map?;
      if (anxietyData != null) {
        final severity = anxietyData['severity']?.toString().toLowerCase();
        if (severity != null && severity != _currentSeverity) {
          _currentSeverity = severity;
          shouldNotifyListeners = true;
          debugPrint('😰 Severity updated: $severity');
        }
      }

      // Notify listeners if any data changed
      if (shouldNotifyListeners) {
        notifyListeners();
      }

      // Handle notifications:
      // Only use Firebase-provided severity (from Cloud Functions with baseline calculations)
      // No fallback to default thresholds - require baseline for anxiety detection
      String? severityForNotify;
      if (anxietyData != null) {
        severityForNotify = anxietyData['severity']?.toString().toLowerCase();
      }
      // Removed default HR thresholds - anxiety detection requires personalized baseline

      if (severityForNotify != null) {
        final severity = severityForNotify;

        // Explicitly suppress any 'normal' state notifications/logging
        if (severity == 'normal') {
          debugPrint('🔇 Normal state received; suppressing notification');
          _isFirstRead = false; // still mark first read consumed
          return;
        }

        // Skip notification on first read (app startup)
        if (_isFirstRead) {
          _isFirstRead = false;
          debugPrint(
              '🔇 Skipping initial Firebase notification for: $severity (HR: $heartRate)');
          return;
        }

        // Only send LOCAL notifications when app is open (since FCM won't show device notifications when app is foreground)
        // When app is closed, Cloud Function FCM will handle notifications
        debugPrint(
            '📥 Firebase data processed - sending LOCAL notification for: $severity (HR: $heartRate)');

        String title = '';
        String body = '';
        String channelKey = '';
        String notificationType = '';

        switch (severity) {
          case 'mild':
            title = '🟢 Mild Alert';
            body =
                'Slight elevation in readings. HR: ${heartRate ?? "N/A"} bpm';
            channelKey = 'anxiety_alerts';
            notificationType = 'alert';
            break;
          case 'moderate':
            title = '🟠 Moderate Alert';
            body =
                'Noticeable symptoms detected. HR: ${heartRate ?? "N/A"} bpm';
            channelKey = 'anxiety_alerts';
            notificationType = 'alert';
            break;
          case 'severe':
            title = '🔴 Severe Alert';
            body = 'URGENT: High risk! HR: ${heartRate ?? "N/A"} bpm';
            channelKey = 'anxiety_alerts';
            notificationType = 'alert';
            break;
          default:
            return;
        }

        // De-dupe locally with per-severity cooldowns
        // mild: 60s, moderate: 30s, severe: 0s (always alert)
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        int cooldownMs = 0;
        switch (severity) {
          case 'mild':
            cooldownMs = 60000;
            break;
          case 'moderate':
            cooldownMs = 30000;
            break;
          case 'severe':
            cooldownMs = 0;
            break;
          default:
            cooldownMs = 20000;
        }

        if (!(_lastLocalSeverity == severity &&
            (nowMs - _lastLocalSeverityTimeMs) < cooldownMs)) {
          _lastLocalSeverity = severity;
          _lastLocalSeverityTimeMs = nowMs;
          _showSeverityNotification(title, body, channelKey, severity);
          _saveNotificationToSupabase(title, body, notificationType, severity);
          _saveAnxietyLevelRecord(severity, false);
        } else {
          debugPrint(
              '🛑 Skipping duplicate $severity within ${cooldownMs ~/ 1000}s (client-side)');
        }
      }
    });
  }

  // Show a severity-based notification
  Future<void> _showSeverityNotification(
      String title, String body, String channelKey, String severity) async {
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
    String channelKey = 'anxiety_alerts';

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

    await _showSeverityNotification(title, body, channelKey, _currentSeverity);
    await _saveNotificationToSupabase(title, body, 'alert', _currentSeverity);
    await _saveAnxietyLevelRecord(_currentSeverity, true);
  }

  // Method to save anxiety level record to Supabase
  Future<void> _saveAnxietyLevelRecord(String severity, bool isManual) async {
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

  // Public helper to add a notification record and notify UI
  Future<void> addNotification({
    required String title,
    required String message,
    required String type,
    String? relatedScreen,
    String? relatedId,
  }) async {
    try {
      await _supabaseService.createNotification(
        title: title,
        message: message,
        type: type,
        relatedScreen: relatedScreen,
        relatedId: relatedId,
      );
      _onNotificationAdded?.call();
    } catch (e) {
      debugPrint('❌ Error adding notification: $e');
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
      if (!kIsWeb && Platform.isIOS) {
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
      // Check if user is authenticated before scheduling reminders
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) {
        debugPrint(
            'User not authenticated - skipping anxiety reminder scheduling');
        return;
      }

      // First check if we already have active reminders
      final List<NotificationModel> activeReminders =
          await AwesomeNotifications().listScheduledNotifications();

      // If we already have reminders scheduled, don't create new ones
      if (activeReminders.any((notification) =>
          notification.content?.channelKey == 'reminders_channel')) {
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
    await AwesomeNotifications()
        .cancelNotificationsByChannelKey('reminders_channel');
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
        channelKey: 'reminders_channel',
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
    // Only if user is authenticated
    final user = _supabaseService.client.auth.currentUser;
    if (user != null) {
      await _supabaseService.createNotification(
        title: message['title'] ?? 'Anxiety Check-in',
        message:
            message['body'] ?? 'Take a moment to check how you\'re feeling.',
        type: 'reminder',
        relatedScreen: 'breathing',
      );
    } else {
      debugPrint(
          'User not authenticated - skipping Supabase notification record');
    }

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

  @override
  void dispose() {
    _dbSubscription?.cancel();
    _dbSubscription = null;
    super.dispose();
  }
}
