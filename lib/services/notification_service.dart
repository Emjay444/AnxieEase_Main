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

  // Deduplication constants
  static const String lastNotificationPrefix = 'last_notification_';
  static const int duplicateWindowMinutes = 30; // 30 minute window

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

  /// Get the appropriate notification channel key based on severity level
  String _getChannelKeyForSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'mild':
        return 'mild_anxiety_alerts_v4'; // Updated to new channel
      case 'moderate':
        return 'moderate_anxiety_alerts';
      case 'severe':
        return 'severe_anxiety_alerts';
      case 'critical':
        return 'critical_anxiety_alerts';
      case 'elevated':
        return 'mild_anxiety_alerts_v4'; // Updated to new channel
      default:
        return 'anxiety_alerts'; // Fallback to general channel
    }
  }

  /// Get custom sound resource path for severity level
  String? _getCustomSoundPath(String severity) {
    switch (severity.toLowerCase()) {
      case 'mild':
      case 'elevated':
        return 'resource://raw/mild_alert';
      case 'moderate':
        return 'resource://raw/moderate_alert';
      case 'severe':
        return 'resource://raw/severe_alert';
      case 'critical':
        return 'resource://raw/critical_alert';
      default:
        return null; // Use default system sound
    }
  }

  /// Check if a notification of this type was recently sent
  /// Returns true if it's a duplicate (should not send)
  Future<bool> _isDuplicateNotification(String type, String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${lastNotificationPrefix}${type}';
      final contentKey = '${key}_content';

      final lastTime = prefs.getInt(key) ?? 0;
      final lastContent = prefs.getString(contentKey) ?? '';

      final now = DateTime.now().millisecondsSinceEpoch;
      const duplicateWindow =
          duplicateWindowMinutes * 60 * 1000; // Convert to milliseconds

      // Check if same content was sent within the time window
      if (now - lastTime < duplicateWindow && lastContent == content.trim()) {
        debugPrint(
            '🚫 Duplicate notification blocked: $type (${duplicateWindowMinutes}min window)');
        return true; // It's a duplicate
      }

      // Store this notification info for future duplicate checks
      await prefs.setInt(key, now);
      await prefs.setString(contentKey, content.trim());
      return false; // Not a duplicate
    } catch (e) {
      debugPrint('❌ Error checking notification deduplication: $e');
      return false; // On error, allow the notification
    }
  }

  /// Wrapper method to send notifications with deduplication
  Future<bool> _sendNotificationWithDeduplication({
    required String type,
    required String title,
    required String body,
    required String channelKey,
    Map<String, String>? payload,
  }) async {
    // Check for duplicates
    final isDuplicate = await _isDuplicateNotification(type, '$title: $body');
    if (isDuplicate) {
      return false; // Notification was blocked
    }

    // Send the notification
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: channelKey,
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
          category: type == 'anxiety_alert'
              ? NotificationCategory.Alarm
              : NotificationCategory.Reminder,
          icon: 'resource://drawable/ic_notification', // Add notification icon
          payload: payload ?? {},
        ),
      );
      debugPrint('✅ Notification sent: $type - $title');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
      return false;
    }
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
        // General AnxieEase channel
        NotificationChannel(
          channelKey: 'anxiease_channel',
          channelName: 'AnxieEase Notifications',
          channelDescription: 'General notifications from AnxieEase app',
          defaultColor: Colors.blue,
          importance: NotificationImportance.High,
          enableVibration: true,
          icon: 'resource://drawable/launcher_icon',
        ),

        // Severity-specific channels with custom sounds
        // TESTING: Ultra-aggressive mild anxiety channel for popup testing
        NotificationChannel(
          channelKey: 'mild_anxiety_alerts_v4',
          channelName: 'Mild Anxiety Emergency Test',
          channelDescription:
              'TESTING: Ultra-priority mild anxiety with forced popup',
          defaultColor: const Color(0xFF66BB6A), // Light Green
          importance: NotificationImportance.Max, // Maximum importance
          ledColor: const Color(0xFF66BB6A),
          enableVibration: true,
          playSound: true,
          soundSource: 'resource://raw/mild_alert', // Custom sound for mild
          defaultPrivacy: NotificationPrivacy.Public, // Show on all screens
          icon: 'resource://drawable/launcher_icon',
          // Avoid critical alerts to prevent OEMs from looping sounds
          criticalAlerts: false,
          onlyAlertOnce:
              true, // Prevent sound looping - play only once per notification
        ),

        // TESTING: New mild anxiety channel with maximum popup settings
        NotificationChannel(
          channelKey: 'mild_anxiety_alerts_v2',
          channelName: 'Mild Anxiety Alerts V2',
          channelDescription:
              'Gentle notifications for mild anxiety detection with popup',
          defaultColor: const Color(0xFF66BB6A), // Light Green
          importance:
              NotificationImportance.Max, // Maximum importance for popup
          ledColor: const Color(0xFF66BB6A),
          enableVibration: true,
          playSound: true,
          soundSource: 'resource://raw/mild_alert', // Custom sound for mild
          defaultPrivacy:
              NotificationPrivacy.Public, // Make sure it shows on lock screen
          icon: 'resource://drawable/launcher_icon',
          criticalAlerts: true, // Enable critical alerts for popup testing
        ),

        // Original mild anxiety channel (keep as backup)
        NotificationChannel(
          channelKey: 'mild_anxiety_alerts',
          channelName: 'Mild Anxiety Alerts',
          channelDescription: 'Gentle notifications for mild anxiety detection',
          defaultColor: const Color(0xFF66BB6A), // Light Green
          importance: NotificationImportance
              .High, // Changed from Default to High for popup
          ledColor: const Color(0xFF66BB6A),
          enableVibration: true,
          playSound: true,
          soundSource: 'resource://raw/mild_alert', // Custom sound for mild
          icon: 'resource://drawable/launcher_icon',
          criticalAlerts: true, // Enable critical alerts for popup testing
        ),

        NotificationChannel(
          channelKey: 'moderate_anxiety_alerts_v2',
          channelName: 'Moderate Anxiety Alerts',
          channelDescription: 'Medium priority alerts for moderate anxiety',
          defaultColor: const Color(0xFFFF9800), // Orange
          importance: NotificationImportance.High,
          ledColor: const Color(0xFFFF9800),
          enableVibration: true,
          playSound: true,
          soundSource:
              'resource://raw/moderate_alert', // Custom sound for moderate
          icon: 'resource://drawable/launcher_icon',
        ),

        NotificationChannel(
          channelKey: 'severe_anxiety_alerts_v2',
          channelName: 'Severe Anxiety Alerts',
          channelDescription:
              'High priority alerts for severe anxiety detection',
          defaultColor: const Color(0xFFF44336), // Red
          importance: NotificationImportance.High, // Changed from Max to High
          ledColor: const Color(0xFFF44336),
          enableVibration: true,
          playSound: true,
          soundSource: 'resource://raw/severe_alert', // Custom sound for severe
          icon: 'resource://drawable/launcher_icon',
          // Removed criticalAlerts: true to prevent looping
        ),

        NotificationChannel(
          channelKey: 'critical_anxiety_alerts_v2',
          channelName: 'Critical Emergency Alerts',
          channelDescription: 'Emergency alerts requiring immediate attention',
          defaultColor: const Color(0xFFD32F2F), // Dark Red
          importance: NotificationImportance.Max,
          ledColor: const Color(0xFFD32F2F),
          enableVibration: true,
          playSound: true,
          soundSource:
              'resource://raw/critical_alert', // Custom sound for critical
          icon: 'resource://drawable/launcher_icon',
          // Keep non-critical; rely on Max importance
        ),

        // General alerts channel (fallback)
        NotificationChannel(
          channelKey: 'anxiety_alerts',
          channelName: 'General Anxiety Alerts',
          channelDescription: 'General anxiety level alerts',
          defaultColor: Colors.red,
          importance: NotificationImportance.High,
          ledColor: Colors.white,
          enableVibration: true,
          playSound: true,
          icon: 'resource://drawable/launcher_icon',
        ),

        // Wellness reminders
        NotificationChannel(
          channelKey: 'wellness_reminders',
          channelName: 'Wellness Reminders',
          channelDescription: 'Wellness and anxiety prevention reminders',
          defaultColor: const Color(0xFF2D9254),
          importance: NotificationImportance.Default,
          ledColor: const Color(0xFF2D9254),
          enableVibration: true,
          playSound: true,
          icon: 'resource://drawable/launcher_icon',
        ),

        // Device alerts (battery, connectivity)
        NotificationChannel(
          channelKey: 'device_alerts_channel',
          channelName: 'Device Alerts',
          channelDescription: 'Wearable device battery and connectivity alerts',
          defaultColor: const Color(0xFFFF6B00), // Orange for device alerts
          importance: NotificationImportance.High,
          ledColor: const Color(0xFFFF6B00),
          enableVibration: true,
          vibrationPattern: lowVibrationPattern,
          playSound: true,
          soundSource: 'resource://raw/device_alert_sound',
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
          notification.content?.channelKey == 'wellness_reminders')) {
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

        // First read behavior at app startup:
        // - If severity is normal/empty, skip.
        // - If severity indicates an alert (mild/moderate/severe/critical), process immediately
        //   so it reflects in the app even if user opens via app icon without tapping the OS notif.
        if (_isFirstRead) {
          _isFirstRead = false;
          if (severity == 'normal' || severity.trim().isEmpty) {
            debugPrint('🔇 Initial Firebase read is normal; no notification.');
            return;
          } else {
            debugPrint(
                '⚡ Initial Firebase read with $severity - processing to reflect in app.');
          }
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

          // Process notifications asynchronously without blocking the listener
          _processNotificationAsync(
              title, body, channelKey, notificationType, severity);
        } else {
          debugPrint(
              '🛑 Skipping duplicate $severity within ${cooldownMs ~/ 1000}s (client-side)');
        }
      }
    });
  }

  // Process notifications asynchronously to avoid blocking the Firebase listener
  Future<void> _processNotificationAsync(String title, String body,
      String channelKey, String notificationType, String severity) async {
    try {
      // Show local notification
      await _showSeverityNotification(title, body, channelKey, severity);

      // Store in Supabase for notifications screen
      await _saveNotificationToSupabase(
          title, body, notificationType, severity);

      // Save anxiety level record
      await _saveAnxietyLevelRecord(severity, false);

      debugPrint(
          '✅ Processed $severity notification: stored locally and in Supabase');
    } catch (e) {
      debugPrint('❌ Error processing $severity notification: $e');
    }
  }

  // Show a severity-based notification with deduplication
  // Show a severity-based notification with custom sound and vibration
  Future<void> _showSeverityNotification(
      String title, String body, String channelKey, String severity) async {
    // Check for duplicates before sending (30-minute window protection)
    final isDuplicate = await _isDuplicateNotification(
        'anxiety_alert_$severity', '$title: $body');
    if (isDuplicate) {
      debugPrint('🚫 Duplicate $severity notification blocked');
      return;
    }

    // Get severity-specific channel (override the passed channelKey)
    final severityChannelKey = _getChannelKeyForSeverity(severity);

    // Determine notification behavior based on severity
    final isHighPriority = [
      'mild',
      'moderate',
      'severe',
      'critical'
    ].contains(severity.toLowerCase()); // Include all severity levels for popup
    final isCritical = severity.toLowerCase() == 'critical';

    // Send the notification with severity-specific enhancements
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: severityChannelKey, // Use severity-specific channel
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory
            .Alarm, // Use Alarm category for all anxiety notifications to ensure popup
        wakeUpScreen: true, // Always wake up screen for anxiety notifications
        fullScreenIntent:
            true, // Force full screen for all anxiety notifications (testing)
        criticalAlert:
            true, // Force critical alert for all anxiety notifications (testing)
        icon: 'resource://drawable/ic_notification', // Add small icon
        // Removed customSound to let channel handle sound completely
        payload: {
          'type': 'anxiety_alert',
          'severity': severity,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
      actionButtons: isHighPriority
          ? [
              NotificationActionButton(
                key: 'DISMISS',
                label: 'I\'m OK',
                actionType: ActionType.DismissAction,
              ),
              NotificationActionButton(
                key: 'VIEW_DETAILS',
                label: 'Open App',
                actionType: ActionType.Default,
              ),
              // Add emergency action for critical alerts
              if (isCritical)
                NotificationActionButton(
                  key: 'EMERGENCY',
                  label: 'Get Help',
                  actionType: ActionType.Default,
                ),
            ]
          : null,
    );

    debugPrint(
        '🔔 Sent $severity notification with custom sound and channel: $severityChannelKey');
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
      // Map incoming logical types to DB enum-compatible values
      String dbType = type;
      if (dbType == 'anxiety_log' || dbType == 'anxiety_alert') {
        dbType = 'alert';
      } else if (dbType == 'wellness_reminder' ||
          dbType == 'breathing_reminder') {
        dbType = 'reminder';
      }

      await _supabaseService.createNotification(
        title: title,
        message: message,
        type: dbType,
        severity: severity, // Pass severity to Supabase
        relatedScreen: severity == 'severe' ? 'breathing_screen' : 'metrics',
      );
      debugPrint('💾 Saved severity notification to Supabase: $title');

      // Trigger UI refresh callbacks
      _onNotificationAdded?.call();

      // Also trigger global notification refresh for home screen
      _triggerGlobalNotificationRefresh();
    } catch (e) {
      debugPrint('❌ Error saving notification to Supabase: $e');
    }
  }

  // Trigger global notification refresh
  void _triggerGlobalNotificationRefresh() {
    try {
      // Import is handled at the top level in main.dart
      // This will be called from there if needed
      debugPrint(
          '🔄 NotificationService: Requesting global notification refresh');
    } catch (e) {
      debugPrint('❌ Error triggering global notification refresh: $e');
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
        icon: 'resource://drawable/ic_notification', // Add notification icon
      ),
    );
  }

  // Test all severity-specific notification sounds
  Future<void> testAllSeverityNotifications() async {
    const severities = ['mild', 'moderate', 'severe', 'critical'];

    debugPrint('🔔 Testing all severity notification sounds...');

    for (int i = 0; i < severities.length; i++) {
      final severity = severities[i];

      // Wait 2 seconds between notifications
      if (i > 0) {
        await Future.delayed(const Duration(seconds: 2));
      }

      await testSeverityNotification(severity, i + 1);
      debugPrint('✅ Sent $severity test notification');
    }

    debugPrint('🎉 All severity notification tests completed!');
  }

  // Test individual severity notification sound (public method)
  Future<void> testSeverityNotification(String severity, int id) async {
    final Map<String, Map<String, String>> testData = {
      'mild': {
        'title': '🟢 Mild Alert Test',
        'body': 'Testing gentle notification sound for mild anxiety detection.'
      },
      'moderate': {
        'title': '🟠 Moderate Alert Test',
        'body': 'Testing medium priority sound for moderate anxiety levels.'
      },
      'severe': {
        'title': '🔴 Severe Alert Test',
        'body':
            'Testing urgent notification sound for severe anxiety detection.'
      },
      'critical': {
        'title': '🚨 Critical Alert Test',
        'body': 'Testing emergency notification sound for critical situations.'
      }
    };

    final data = testData[severity] ?? testData['mild']!;

    await _showSeverityNotification(
        data['title']!,
        data['body']!,
        'test_channel', // This will be overridden by severity-specific channel
        severity);
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
        .cancelNotificationsByChannelKey('wellness_reminders');
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
        channelKey:
            'wellness_reminders', // Consistent with other wellness notifications
        title: message['title'],
        body: message['body'],
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
        icon: 'resource://drawable/ic_notification', // Add notification icon
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

  /// Send low battery notification for wearable device
  Future<bool> sendLowBatteryNotification({
    required String deviceId,
    required int batteryLevel,
    required bool isCritical,
  }) async {
    if (!_isInitialized) {
      debugPrint('❌ NotificationService not initialized, cannot send low battery notification');
      return false;
    }

    final String title = isCritical 
        ? '🔋 Critical Battery Alert!'
        : '⚠️ Low Battery Warning';
    
    final String body = isCritical
        ? 'Your wearable device battery is at $batteryLevel%. Please charge immediately to avoid data loss!'
        : 'Your wearable device battery is at $batteryLevel%. Consider charging soon.';

    // Use different deduplication keys for low vs critical battery
    final String notificationType = isCritical ? 'critical_battery' : 'low_battery';

    return await _sendNotificationWithDeduplication(
      type: notificationType,
      title: title,
      body: body,
      channelKey: 'device_alerts_channel',
      payload: {
        'type': notificationType,
        'device_id': deviceId,
        'battery_level': batteryLevel.toString(),
        'is_critical': isCritical.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }

  /// Send device offline notification when battery dies
  Future<bool> sendDeviceOfflineNotification({
    required String deviceId,
  }) async {
    if (!_isInitialized) {
      debugPrint('❌ NotificationService not initialized, cannot send device offline notification');
      return false;
    }

    const String title = '📱 Device Disconnected';
    const String body = 'Your wearable device has gone offline due to low battery. Charge and reconnect to resume monitoring.';

    return await _sendNotificationWithDeduplication(
      type: 'device_offline',
      title: title,
      body: body,
      channelKey: 'device_alerts_channel',
      payload: {
        'type': 'device_offline',
        'device_id': deviceId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    _dbSubscription = null;
    super.dispose();
  }
}
