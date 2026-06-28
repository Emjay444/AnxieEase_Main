import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'auth.dart';
import 'auth_wrapper.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/iot_sensor_service.dart';
import 'services/admin_device_management_service.dart';
import 'reset_password.dart';
import 'verify_reset_code.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'utils/logger.dart';
import 'splash_screen.dart';
import 'theme/app_theme.dart';
import 'screens/notifications_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'services/background_messaging.dart';
import 'services/appointment_service.dart';
import 'breathing_screen.dart';
import 'grounding_screen.dart';
import 'screens/device_linking_screen.dart';
import 'screens/baseline_recording_screen.dart';
import 'screens/health_dashboard_screen.dart';
import 'search.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

// Global completer to signal when services finish initialization (replaces polling bool)
final Completer<void> servicesInitializedCompleter = Completer<void>();
// Toggle this to enable/disable verbose logging app‑wide
const bool kVerboseLogging = false;
const bool kStoreUserLevelFcmTokenInRealtimeDb = false;

const List<String> _quietLogPatterns = [
  'AuthWrapper -',
  'LoginScreen -',
  'StorageService',
  'SplashScreen -',
  'Supabase initialized',
  'Supabase is already initialized',
  'Initializing Supabase',
  'No .env loaded',
  'Early sync attempt',
  'Checking for expired appointments',
  'Firebase reference initialized',
  'Session user:',
  'Session expires',
  'Session access token',
  'Session found during initialization',
  'No session found',
  'Setting up auth state listener',
  'Auth state listener setup complete',
  'Auth state changed',
  'Session exists:',
  'User exists:',
  'Initial session restored',
  'Processing initial session',
  'Handling sign in',
  'Fetching user profile',
  'Found existing user profile',
  'User profile loaded successfully',
  'No profile images found',
  'Updated notification badge count',
  'NotificationService initialized successfully',
  'Heart rate updated',
  'No pending appointments found',
  '_syncPendingNotifications',
  'Checking for background notification markers',
  'background notification markers',
  'Syncing pending notifications',
  'pending notifications',
  'Strategy 1:',
  'Strategy 2:',
  'Strategy 3:',
  'Setting up streamlined sync strategies',
  'Setting up periodic FCM token refresh',
  'Validating assignment FCM token',
  'FCM Token Assignment Check',
  '   - isAssigned:',
  '   - status:',
  '   - canUseDevice:',
  'Fresh FCM registration token',
  'FCM token refreshed',
  'Deleted old FCM token',
  'Cleaned up old device-level FCM token',
  'User has no device assigned',
  'Normal app open:',
  'Post-FCM sync attempt',
  'All services initialized successfully',
  'First frame rendered',
  'Avatar debug',
  'getNotifications called',
  'getNotifications success',
  'Checking for appointments created before',
  'Subscribed/re-subscribed',
  'FCM topic subscriptions completed successfully',
  '_waitForAuthReady',
  'Auth status:',
  'Auth is ready',
];

bool _shouldPrintDebugMessage(String message) {
  if (kVerboseLogging) return true;

  final lower = message.toLowerCase();
  final isImportant = lower.contains('error') ||
      lower.contains('failed') ||
      lower.contains('exception') ||
      lower.contains('denied') ||
      lower.contains('expired') ||
      lower.contains('permission') ||
      lower.contains('warning') ||
      lower.contains('warn:');

  if (isImportant) return true;

  return !_quietLogPatterns.any(message.contains);
}

void _configureDebugLogging() {
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message == null || _shouldPrintDebugMessage(message)) {
      debugPrintSynchronously(message, wrapWidth: wrapWidth);
    }
  };
}

// Global keys for navigation and in-app banners (usable outside widget context)
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// Top-level static method to handle background notification actions
@pragma("vm:entry-point")
Future<void> onActionNotificationMethod(ReceivedAction receivedAction) async {
  debugPrint(
      '📱 Background AwesomeNotification action received: ${receivedAction.payload}');

  // Handle navigation or actions here
  final payload = receivedAction.payload ?? {};

  // When tapping anxiety alerts created in background, make sure they're synced to Supabase
  if ((payload['type'] == 'anxiety_alert') || (payload['source'] == 'fcm_bg')) {
    // Wait for auth to be initialized but don't require authentication
    await _waitForAuthReady(ensureAuthenticated: false);

    // Try to sync any locally stored pending notifications first (only if authenticated)
    try {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        final authProvider = Provider.of<AuthProvider>(ctx, listen: false);
        if (authProvider.isAuthenticated) {
          await _syncPendingNotifications();
        } else {
          debugPrint('📱 User not authenticated, skipping notification sync');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to sync pending notifications on tap: $e');
    }

    // Check if this notification requires user confirmation
    final requiresConfirmation = payload['requiresConfirmation'] == 'true';
    final severity = (payload['severity'] ?? '').toString().toLowerCase();
    final navigator = rootNavigatorKey.currentState;

    if (navigator != null) {
      if (requiresConfirmation) {
        // Show confirmation dialog directly - it will save to Supabase automatically
        navigator.pushNamed(
          '/notifications',
          arguments: {
            'showConfirmationDialog': true,
            'title': receivedAction.title ?? 'Check-In',
            'message': receivedAction.body ?? 'How are you feeling?',
            'severity': severity,
            'alertType': payload['alertType'] ?? 'check_in',
            'detectionData': payload,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );
      } else {
        // Handle non-confirmation notifications (critical alerts)
        switch (severity) {
          case 'moderate':
            navigator.pushNamed('/breathing');
            break;
          case 'severe':
            navigator.pushNamed('/grounding');
            break;
          case 'critical':
            // For critical alerts, directly show help modal without confirmation
            debugPrint(
                '🚨 Critical alert → Direct help modal (auto-confirmed)');
            await _showCriticalAlertHelpModal(
              notificationTitle:
                  receivedAction.title ?? 'Critical Anxiety Alert',
              notificationMessage:
                  receivedAction.body ?? 'Critical anxiety level detected.',
              notificationId: payload['notificationId'],
            );
            break;
          default:
            navigator.pushNamed(
              '/notifications',
              arguments: {
                'show': 'notification',
                'title': receivedAction.title ?? 'Anxiety Alert',
                'message': receivedAction.body ?? 'Please check your status.',
                'type': 'alert',
                'severity': severity,
                'createdAt': DateTime.now().toIso8601String(),
              },
            );
        }
      }
    }
    return;
  }

  // Handle reminder taps
  if (payload['type'] == 'reminder' &&
      payload['related_screen'] == 'breathing_screen') {
    debugPrint('🫁 Background breathing exercise reminder action received');

    // Try to navigate if the app context is available
    if (rootNavigatorKey.currentState != null) {
      rootNavigatorKey.currentState?.pushNamed('/breathing');
    }
  }
}

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  _configureDebugLogging();
  AppLogger.verbose = kVerboseLogging;

  // Register FCM background message handler early
  // This must be a top-level function (defined in services/background_messaging.dart)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Create the theme provider first as it doesn't depend on other services
  final themeProvider = ThemeProvider();

  // Run the app immediately with just the splash screen
  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: const InitialApp(),
    ),
  );

  // Initialize required services in the background
  _initializeServices();
}

// Simple app that just shows the splash screen
class InitialApp extends StatelessWidget {
  const InitialApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AnxieEase',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}

// Run initialization tasks in the background
Future<void> _initializeServices() async {
  try {
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('✅ Loaded .env for app configuration');
    } catch (e) {
      debugPrint('ℹ️ No .env loaded: $e');
    }

    // --- CORE (block only what is strictly necessary for first frame) --- //
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await SupabaseService().initialize(); // needed for AuthProvider

    // Early sync attempt - try to sync notifications immediately after Supabase is ready
    debugPrint('🔄 Early sync attempt during initialization...');
    _syncPendingNotifications();

    // Check and expire old appointment requests
    debugPrint('⏰ Checking for expired appointments...');
    final appointmentService = AppointmentService();
    appointmentService.checkAndExpireAppointments().catchError((error) {
      debugPrint('⚠️ Failed to check expired appointments: $error');
    });

    // Create lightweight provider instances (heavy work deferred)
    final authProvider = AuthProvider();
    final notificationProvider = NotificationProvider();
    final notificationService = NotificationService();
    final themeProvider = ThemeProvider();
    final iotSensorService = IoTSensorService();

    // Mark core ready BEFORE kicking off heavy secondary init
    if (!servicesInitializedCompleter.isCompleted) {
      servicesInitializedCompleter.complete();
    }

    // Mount full app
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: notificationProvider),
          ChangeNotifierProvider.value(value: notificationService),
          ChangeNotifierProvider.value(value: iotSensorService),
        ],
        child: const MyApp(),
      ),
    );

    // Defer non-critical service work to next event loop / after first frame
    // (notification channels, storage init, IoT simulation writes, topic subscriptions)
    Future.microtask(() => _initializeRemainingServices(
          notificationService,
          iotSensorService,
        ));
  } catch (e) {
    AppLogger.e('Error during service initialization', e as Object?);
    // Even if there's an error, we should still try to run the app
    if (!servicesInitializedCompleter.isCompleted) {
      servicesInitializedCompleter.complete();
    }
  }
}

// Run remaining initialization tasks in the background
Future<void> _initializeRemainingServices(
    NotificationService notificationService,
    IoTSensorService iotSensorService) async {
  try {
    // Add frame break to prevent UI blocking
    await Future.delayed(Duration.zero);

    // Clear only old notifications on app startup, preserve recent severity alerts
    await _clearNotificationsOnAppStartup();

    // Add another frame break
    await Future.delayed(Duration.zero);

    // Initialize notification service
    await notificationService.initialize();

    // Add frame break to let UI breathe
    await Future.delayed(Duration.zero);

    // Set up AwesomeNotifications action listener for breathing exercise navigation
    AwesomeNotifications().setListeners(
      onActionReceivedMethod:
          onActionNotificationMethod, // Use the top-level static method
      onNotificationCreatedMethod:
          (ReceivedNotification receivedNotification) async {
        debugPrint(
            '📝 AwesomeNotification created: ${receivedNotification.title}');
      },
      onNotificationDisplayedMethod:
          (ReceivedNotification receivedNotification) async {
        debugPrint(
            '📺 AwesomeNotification displayed: ${receivedNotification.title}');
      },
      onDismissActionReceivedMethod: (ReceivedAction receivedAction) async {
        debugPrint('🗑️ AwesomeNotification dismissed: ${receivedAction.id}');
      },
    );

    // Add frame break after notification setup
    await Future.delayed(Duration.zero);

    // Enable Firebase listener for foreground notifications when app is open
    // This handles direct Firebase data changes (like manual severity updates)
    notificationService.initializeListener();

    // DISABLED: Background polling service to prevent duplicates
    // Cloud Functions handle real-time notifications now
    // BackgroundPollingService.startPolling(intervalSeconds: 60);

    // Add frame break before permission requests
    await Future.delayed(Duration.zero);

    // Request both notification and phone permissions simultaneously
    final isNotificationAllowed =
        await notificationService.checkNotificationPermissions();
    if (!isNotificationAllowed) {
      // Request both permissions together - the system will show the dialogs
      final Map<Permission, PermissionStatus> permissionStatuses = await [
        Permission.phone,
        Permission.notification,
      ].request();

      debugPrint(
          '📞 Phone permission: ${permissionStatuses[Permission.phone]}');
      debugPrint(
          '🔔 Notification permission: ${permissionStatuses[Permission.notification]}');

      // Also request AwesomeNotifications permission
      await notificationService.requestNotificationPermissions();
    }

    // Add frame break after permissions
    await Future.delayed(Duration.zero);

    // Initialize storage service with frame break.
    try {
      await StorageService().init();
    } catch (e) {
      AppLogger.w(
          'StorageService initialization failed: $e, continuing anyway');
    }
    await Future.delayed(Duration.zero);

    // Initialize device manager (but don't auto-start sensors for real device mode)
    await iotSensorService.initialize();
    await Future.delayed(Duration.zero);

    // REAL DEVICE MODE: Don't auto-start mock data generation
    // If you need to test without real device, manually call:
    // iotSensorService.enableMockDataGeneration(true);
    // iotSensorService.startSensors();
    AppLogger.i(
        'IoT Service initialized - mock data generation disabled for real device use');

    // Configure Firebase Cloud Messaging (foreground listeners, token log)
    await _configureFCM();

    // Another sync attempt after FCM is configured
    debugPrint('🔄 Post-FCM sync attempt...');
    _syncPendingNotifications();

    // If the app was opened normally (not via tapping a push),
    // make sure auth is ready and then sync any pending background-stored notifications
    debugPrint('⏳ Normal app open: waiting for auth readiness...');

    // Don't wait too long for auth - sync regardless.
    var authReadyBeforeTimeout = false;
    Future.any([
      _waitForAuthReady(ensureAuthenticated: false).then((_) {
        authReadyBeforeTimeout = true;
      }),
      Future.delayed(const Duration(seconds: 5), () {
        if (!authReadyBeforeTimeout) {
          AppLogger.d('Auth wait timed out; proceeding with sync');
        }
      })
    ]).then((_) async {
      debugPrint('✅ Normal app open: proceeding with sync...');
      await _syncPendingNotifications();
    });

    debugPrint('✅ All services initialized successfully');
  } catch (e) {
    AppLogger.e('Error during secondary service initialization', e as Object?);
  }
}

// Clear only old notifications on app startup, preserve recent severity alerts
Future<void> _clearNotificationsOnAppStartup() async {
  try {
    final supabaseService = SupabaseService();

    // Configuration: Set to true to enable automatic clearing of old notifications
    // Set to false to keep all notifications permanently. Currently disabled.
    final bool enableAutoClear = await _getAutoClearSetting();

    if (!enableAutoClear) {
      AppLogger.d('Auto-clear disabled - preserving notifications');
      return;
    }

    // Set a timeout for this operation and add frame break
    await Future.any([
      _doClearNotifications(supabaseService),
      Future.delayed(const Duration(seconds: 3), () {
        AppLogger.w('Notification clearing timed out after 3s - continuing');
        // Don't throw exception, just continue
      })
    ]);

    // Add frame break after clearing notifications
    await Future.delayed(Duration.zero);
  } catch (e) {
    AppLogger.e('Error clearing old notifications on startup', e as Object?);
    // Don't rethrow - allow the app to continue even if clearing fails
  }
}

// In the future this can read a setting or Remote Config. For now, keep disabled.
Future<bool> _getAutoClearSetting() async {
  return false;
}

Future<void> _doClearNotifications(SupabaseService supabaseService) async {
  const int daysToKeep =
      7; // Keep notifications for 7 days (when auto-clear is enabled)

  // Get all notifications
  final notifications = await supabaseService.getNotifications();

  if (notifications.isEmpty) {
    debugPrint('📱 No notifications to clear');
    return;
  }

  // Calculate cutoff time (7 days ago by default)
  final cutoffTime = DateTime.now().subtract(const Duration(days: daysToKeep));

  // Delete only notifications older than the cutoff time
  int deletedCount = 0;
  for (final notification in notifications) {
    try {
      final createdAt = DateTime.parse(notification['created_at']);
      if (createdAt.isBefore(cutoffTime)) {
        await supabaseService.deleteNotification(notification['id'],
            hardDelete: true);
        deletedCount++;
      }
    } catch (e) {
      debugPrint('⚠️ Error processing notification ${notification['id']}: $e');
    }
  }

  if (deletedCount > 0) {
    debugPrint(
        '🗑️ Cleared $deletedCount old notifications (older than $daysToKeep days)');
  }
  debugPrint(
      '📱 Preserved ${notifications.length - deletedCount} recent notifications');
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late AppLinks _appLinks;
  // Use global navigator key so services/handlers can navigate safely
  final _navigatorKey = rootNavigatorKey;
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    // Add this widget as an observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    _initAppLinks();
    // Profile first frame scheduling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      debugPrint('🕒 First frame rendered at: ' + now.toIso8601String());

      // After first frame, set up multiple sync strategies to be extra sure
      _setupMultipleSyncStrategies();
    });
  }

  @override
  void dispose() {
    // Remove this widget as an observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('📱 App lifecycle changed to: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // Hide keyboard and force an immediate rebuild so the UI doesn't
        // render with stale/misaligned layout after returning from the
        // background (same fix already used in verify_reset_code.dart).
        FocusManager.instance.primaryFocus?.unfocus();
        if (mounted) setState(() {});

        // App became active/foreground - refresh FCM token and sync notifications
        debugPrint(
            '🔄 App resumed - refreshing FCM token and syncing notifications...');
        Future.delayed(const Duration(milliseconds: 500), () async {
          // CRITICAL FIX: Refresh and store FCM token when app resumes
          // This ensures the assignment node always has a valid token
          await _refreshAndStoreToken();

          await _debugLocalNotifications(); // Debug what's in local storage
          _syncPendingNotifications();
        });
        break;
      case AppLifecycleState.paused:
        debugPrint('⏸️ App paused - ensuring FCM token is stored');
        // CRITICAL FIX: Store FCM token when app goes to background
        // This ensures the token persists even if the app is killed
        _ensureTokenPersistence();
        break;
      case AppLifecycleState.inactive:
        debugPrint('😴 App inactive');
        break;
      case AppLifecycleState.detached:
        debugPrint('🔌 App detached');
        break;
      case AppLifecycleState.hidden:
        debugPrint('🙈 App hidden');
        break;
    }
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();

    // Check initial link if app was launched from dead state
    try {
      final uri = await _appLinks.getInitialAppLink();
      if (uri != null) {
        _handleAppLink(uri);
      }
    } catch (e) {
      print('Error getting initial app link: $e');
    }

    // Handle incoming links when app is in background or foreground
    _appLinks.uriLinkStream.listen((uri) {
      _handleAppLink(uri);
    }, onError: (err) {
      print('Error handling app links: $err');
    });
  }

  /// Set up multiple strategies to ensure pending notifications are synced reliably
  /// OPTIMIZED: Reduced from 6 strategies to 3 for better performance
  Future<void> _setupMultipleSyncStrategies() async {
    debugPrint('🔄 Setting up streamlined sync strategies...');

    // Strategy 1: AuthProvider listener (primary - immediate when auth ready)
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Track if we've already synced to avoid duplicates
      bool hasAlreadySynced = false;

      authProvider.addListener(() async {
        debugPrint(
            '🔐 Auth state changed: init=${authProvider.isInitialized}, auth=${authProvider.isAuthenticated}, alreadySynced=$hasAlreadySynced');

        if (authProvider.isInitialized &&
            authProvider.isAuthenticated &&
            !hasAlreadySynced) {
          hasAlreadySynced = true;
          debugPrint(
              '✅ Strategy 1: Auth ready after launch → syncing pending notifications');
          await _syncPendingNotifications();

          // CRITICAL FIX: Validate and refresh FCM token after auth is ready
          await _validateAndRefreshAssignmentToken();
        }
      });
    } catch (e) {
      debugPrint('⚠️ Could not attach auth listener for pending sync: $e');
    }

    // Strategy 2: Quick fallback (3 seconds) - in case auth takes time
    Future.delayed(const Duration(seconds: 3), () async {
      debugPrint('🔄 Strategy 2: Quick fallback sync after 3 seconds...');
      await _syncPendingNotifications();
      await _validateAndRefreshAssignmentToken();
    });

    // Strategy 3: Final safety net (10 seconds) - catch any edge cases
    Future.delayed(const Duration(seconds: 10), () async {
      debugPrint('🔄 Strategy 3: Final safety net sync after 10 seconds...');
      await _syncPendingNotifications();
    });

    // CRITICAL FIX: Set up periodic FCM token refresh to prevent token loss
    // OPTIMIZED: Reduced frequency for better performance
    _setupPeriodicTokenRefresh();
  }

  // NEW: Set up periodic FCM token refresh
  // OPTIMIZED: Reduced frequency from every 30s to every 2 minutes during startup
  void _setupPeriodicTokenRefresh() {
    debugPrint('🔄 Setting up periodic FCM token refresh...');

    // Refresh token every 5 minutes to ensure it's always available
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        debugPrint('🔄 Periodic FCM token refresh...');
        await _validateAndRefreshAssignmentToken();
      } catch (e) {
        debugPrint('❌ Error in periodic token refresh: $e');
      }
    });

    // Also refresh token every 2 minutes for the first 10 minutes (during critical startup period)
    // OPTIMIZED: Reduced from every 30s to every 2 minutes
    for (int i = 1; i <= 5; i++) {
      Future.delayed(Duration(minutes: 2 * i), () async {
        try {
          debugPrint('🔄 Early periodic token refresh ${i}/5...');
          await _validateAndRefreshAssignmentToken();
        } catch (e) {
          debugPrint('❌ Error in early token refresh: $e');
        }
      });
    }
  }

  void _handleAppLink(Uri uri) {
    // Log routing-relevant parts only - never the raw query/fragment, since
    // reset tokens/codes are carried there.
    print('🔗 URI scheme: ${uri.scheme}');
    print('🔗 URI host: ${uri.host}');
    print('🔗 URI path: ${uri.path}');
    print('🔗 URI query keys: ${uri.queryParameters.keys.toList()}');
    print('🔗 URI has fragment: ${uri.fragment.isNotEmpty}');

    // Check if this is a reset password link - look for different path variations
    bool isResetPasswordLink = uri.path == '/reset-password' ||
        uri.path.contains('reset-password') ||
        uri.toString().contains('type=recovery') ||
        uri.toString().contains('/auth/recovery') ||
        uri.toString().contains('/auth/callback') ||
        uri.toString().contains('#access_token=');

    if (isResetPasswordLink) {
      print('Reset password link detected');

      String? token;
      String? email;

      // Check for various token formats in the URI
      if (uri.queryParameters.containsKey('code')) {
        token = uri.queryParameters['code'];
        print('Code parameter found (length: ${token?.length ?? 0})');
      }

      // Check for token parameter (alternative approach)
      if (token == null && uri.queryParameters.containsKey('token')) {
        token = uri.queryParameters['token'];
        print('Token parameter found (length: ${token?.length ?? 0})');
      }

      // Check for access_token in fragment (Supabase often uses this)
      if (token == null && uri.fragment.isNotEmpty) {
        final fragmentParams = Uri.splitQueryString(uri.fragment);
        if (fragmentParams.containsKey('access_token')) {
          token = fragmentParams['access_token'];
          print(
              'Access token found in fragment (length: ${token?.length ?? 0})');
        }
      }

      // Try to find token in full URL (more comprehensive approach)
      if (token == null) {
        final fullUrl = uri.toString();

        // Look for 6-digit code in the URL (for simple PIN codes)
        final pinRegExp = RegExp(r'code=(\d{6})');
        final pinMatch = pinRegExp.firstMatch(fullUrl);
        if (pinMatch != null && pinMatch.groupCount >= 1) {
          token = pinMatch.group(1);
          print('6-digit PIN extracted from URL (redacted)');
        } else {
          // Look for code= parameter in the full URL
          final codeRegExp = RegExp(r'code=([^&]+)');
          final codeMatch = codeRegExp.firstMatch(fullUrl);
          if (codeMatch != null && codeMatch.groupCount >= 1) {
            token = codeMatch.group(1);
            print('Code extracted from URL (length: ${token?.length ?? 0})');
          }
        }
      }

      // Extract email from query parameters
      if (uri.queryParameters.containsKey('email')) {
        email = uri.queryParameters['email'];
        print('Email parameter found: ${email != null}');
      }

      // If we have a token, navigate to reset password screen
      if (token != null) {
        print('Navigating to verification screen with token (redacted)');

        // Unfocus deterministically right before replacing the whole
        // navigation stack, so the swap doesn't race a lifecycle-resume
        // handler on the screen being replaced.
        FocusManager.instance.primaryFocus?.unfocus();

        // Navigate to verification screen with the token
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => email != null
                ? VerifyResetCodeScreen(email: email)
                : const VerifyResetCodeScreenWithOptionalEmail(),
          ),
          (route) => false,
        );
        return;
      } else {
        print('No token found in reset password link');
        // If we have an email but no token, navigate to the verification screen
        if (email != null) {
          print('Navigating to verification screen with email');
          FocusManager.instance.primaryFocus?.unfocus();
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) =>
                  VerifyResetCodeScreenWithOptionalEmail(email: email),
            ),
            (route) => false,
          );
          return;
        } else {
          // No token and no email - show error
          FocusManager.instance.primaryFocus?.unfocus();
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const ResetPasswordScreen(
                errorMessage:
                    'Invalid reset password link. Please request a new one.',
              ),
            ),
            (route) => false,
          );
          return;
        }
      }
    }

    // Check for email verification (Supabase confirmation callback)
    if (uri.path == '/verify' ||
        uri.path.contains('verify') ||
        uri.toString().contains('type=signup') ||
        uri.toString().contains('type=signup_email') ||
        uri.toString().contains('/auth/confirm')) {
      print('Email verification path detected');

      // Extract params from both query and fragment (Supabase often uses hash)
      final Map<String, String> frag = uri.fragment.isNotEmpty
          ? Uri.splitQueryString(uri.fragment)
          : <String, String>{};

      final String? type = uri.queryParameters['type'] ?? frag['type'];
      final String? email = uri.queryParameters['email'] ?? frag['email'];

      // Treat signup and signup_email as verification success
      if (type == 'signup' || type == 'signup_email') {
        print(
            'Supabase signup verification detected for email: ${email ?? 'unknown'}');

        // Best-effort: update flag in our profile table when we know the email
        if (email != null) {
          _supabaseService
              .updateEmailVerificationStatus(email)
              .whenComplete(() {
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const AuthScreen(
                  message: 'Email verified! You can log in now.',
                  showLogin: true,
                ),
              ),
              (route) => false,
            );
          });
        } else {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const AuthScreen(
                message: 'Email verified! Please log in.',
                showLogin: true,
              ),
            ),
            (route) => false,
          );
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      // Toggle to true temporarily if you want to visualize rendering performance
      showPerformanceOverlay: false,
      title: 'AnxieEase',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const AuthWrapper(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/breathing': (context) => const BreathingScreen(),
        '/grounding': (context) => const GroundingScreen(),
        '/device-linking': (context) => const DeviceLinkingScreen(),
        '/baseline-recording': (context) => const BaselineRecordingScreen(),
        '/health-dashboard': (context) => const HealthDashboardScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/verify-reset-code') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => VerifyResetCodeScreen(email: args['email']),
          );
        }
        return null;
      },
    );
  }
}

// Helper: show an in-app, floating banner for foreground events
void _showInAppBanner({
  required String title,
  required String body,
  Color? color,
  String? actionLabel,
  VoidCallback? onAction,
  IconData? icon,
}) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;

  // Dismiss any existing snackbars to avoid stacking
  messenger.clearSnackBars();

  // Determine notification type and styling
  final isAlert = title.contains('Alert') ||
      title.contains('🚨') ||
      title.contains('anxiety');
  final isWellness = title.contains('Wellness') ||
      title.contains('💙') ||
      title.contains('Check');
  final isBreathing = title.contains('Breathing') ||
      title.contains('🫁') ||
      title.contains('🌬️');

  Color primaryColor;
  Color borderColor;
  IconData notificationIcon;

  if (isAlert) {
    primaryColor = const Color(0xFFE57373); // Soft red
    borderColor = const Color(0xFFFFCDD2); // Light red border
    notificationIcon = Icons.health_and_safety_rounded;
  } else if (isWellness) {
    primaryColor = const Color(0xFF4FC3F7); // Soft blue
    borderColor = const Color(0xFFBBDEFB); // Light blue border
    notificationIcon = Icons.favorite_rounded;
  } else if (isBreathing) {
    primaryColor = const Color(0xFF81C784); // Soft green
    borderColor = const Color(0xFFC8E6C9); // Light green border
    notificationIcon = Icons.air_rounded;
  } else {
    primaryColor = color ?? Colors.blue;
    borderColor = (color ?? Colors.blue).withOpacity(0.25);
    notificationIcon = icon ?? Icons.notifications_active_rounded;
  }

  final snackBar = SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.white,
    elevation: 8,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    shape: RoundedRectangleBorder(
      side: BorderSide(color: borderColor, width: 1.5),
      borderRadius: BorderRadius.circular(16),
    ),
    duration: const Duration(seconds: 7),
    content: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern icon container with gradient
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.15),
                  primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              notificationIcon,
              color: primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title with better typography
                Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFF1E2432),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                // Body text with improved styling
                Text(
                  body,
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (onAction != null && (actionLabel ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Modern action button row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () {
                              messenger.hideCurrentSnackBar();
                              onAction();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: Text(
                              actionLabel!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Dismiss button
                      Container(
                        width: 36,
                        height: 36,
                        child: IconButton(
                          onPressed: () {
                            messenger.hideCurrentSnackBar();
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.grey[500],
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  // Just a dismiss button if no action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          onPressed: () {
                            messenger.hideCurrentSnackBar();
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.grey[400],
                            size: 18,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  messenger.showSnackBar(snackBar);
}

// Configure Firebase Cloud Messaging for foreground messages and token retrieval
Future<void> _configureFCM() async {
  try {
    // iOS foreground presentation options (safe to call on all platforms)
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get and store a fresh FCM token
    await _refreshAndStoreToken();

    // Handle token refresh (tokens can change automatically)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      AppLogger.d('FCM token refreshed');
      await _storeTokenAtAssignmentLevel(newToken);
    });

    // Subscribe to topics only once per installation
    await _subscribeToTopicsOnce();

    // Foreground message handler: Handle FCM messages when app is open
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      try {
        final data = message.data;
        final notification = message.notification;

        debugPrint(
            '📥 Foreground FCM received: ${notification?.title} - ${notification?.body}');
        debugPrint('📊 FCM data: $data');

        // Check if this is a wellness reminder or breathing exercise reminder
        final messageType = data['type'] ?? '';
        if ((messageType == 'reminder' ||
                messageType == 'breathing_reminder') &&
            (notification?.title?.contains('Breathing Exercise') == true ||
                notification?.title?.contains('🫁') == true ||
                notification?.title?.contains('Breathe') == true ||
                data['related_screen'] == 'breathing_screen' ||
                data['category'] == 'daily_breathing')) {
          // Handle breathing exercise reminder
          debugPrint('🫁 Breathing exercise reminder FCM received');

          // Only show in-app banner (no duplicate local notification)
          _showInAppBanner(
            title: notification?.title ?? '🫁 Breathing Exercise Reminder',
            body: notification?.body ??
                'Time for a breathing exercise! Take a moment to relax and breathe.',
            color: Colors.blue,
            icon: Icons.air,
            actionLabel: 'Breathe',
            onAction: () {
              // Navigate to breathing screen
              rootNavigatorKey.currentState?.pushNamed('/breathing');
            },
          );

          // Store breathing exercise reminder in Supabase for notifications screen
          await _storeBreathingReminderNotification(notification, data);
        } else if (messageType == 'wellness_reminder' ||
            notification?.title?.contains('Wellness') == true ||
            notification?.title?.contains('Anxiety Check-in') == true) {
          // Debug the timing
          final currentTime = DateTime.now();
          debugPrint('🍃 Wellness reminder FCM received at:');
          debugPrint('   Device time: ${currentTime.toString()}');
          debugPrint('   Timestamp from FCM: ${data['timestamp'] ?? 'N/A'}');

          // Only show in-app banner (no duplicate local notification)
          _showInAppBanner(
            title: notification?.title ?? 'Wellness Reminder',
            body: notification?.body ??
                'Take a moment to check how you\'re feeling.',
            color: Colors.green,
            icon: Icons.spa,
            actionLabel: 'Open',
            onAction: () {
              // Navigate to breathing or grounding based on payload
              final dest = (data['action'] ?? 'breathing').toString();
              final route =
                  dest.contains('ground') ? '/grounding' : '/breathing';
              rootNavigatorKey.currentState?.pushNamed(route);
            },
          );

          // Store wellness reminder in Supabase for notifications screen
          await _storeWellnessReminderNotification(notification, data);
        } else if (messageType == 'anxiety_alert' ||
            notification?.title?.toLowerCase().contains('anxiety') == true ||
            notification?.title?.toLowerCase().contains('alert') == true ||
            data['severity'] != null) {
          // Enhanced condition to catch anxiety alerts with better debugging
          debugPrint('🚨 ANXIETY ALERT DETECTED:');
          debugPrint('   messageType: $messageType');
          debugPrint('   title: ${notification?.title}');
          debugPrint('   severity: ${data['severity']}');
          debugPrint('   data keys: ${data.keys.toList()}');

          // Show inline alert banner with action to view notifications
          _showInAppBanner(
            title: notification?.title ?? 'Anxiety Alert',
            body: notification?.body ?? 'We\'re here to help. Tap to view.',
            color: Colors.deepOrange,
            icon: Icons.health_and_safety,
            actionLabel: 'View',
            onAction: () {
              rootNavigatorKey.currentState?.pushNamed(
                '/notifications',
                arguments: {
                  'show': 'notification',
                  'title': notification?.title ?? 'Anxiety Alert',
                  'message': notification?.body ?? 'We\'re here to help.',
                  'type': 'alert',
                  'severity': (data['severity'] ?? '').toString(),
                  'createdAt': DateTime.now().toIso8601String(),
                },
              );
            },
          );

          // IMPORTANT: Store anxiety alert in Supabase for notifications screen
          debugPrint('📱 Attempting to store anxiety alert notification...');
          final stored =
              await _storeAnxietyAlertNotification(notification, data);
          if (stored) {
            debugPrint('✅ Successfully stored anxiety alert notification');
          } else {
            debugPrint('❌ Failed to store anxiety alert notification');
          }
        } else {
          // For other FCM messages, keep default handling
          debugPrint('🔇 Other FCM - letting NotificationService handle it');
        }
      } catch (e) {
        debugPrint('❌ Error handling foreground FCM: $e');
      }
    });

    // When a notification is tapped and opens the app (foreground/background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('📬 Notification tap opened app. Data: ${message.data}');

      // Ensure authentication is ready so storage/navigation don't race
      await _waitForAuthReady(ensureAuthenticated: true);

      // Ensure any background-stored notifications are synced when opened from tap
      try {
        await _syncPendingNotifications();
      } catch (e) {
        debugPrint('⚠️ Failed syncing pending after tap: $e');
      }

      // Handle navigation based on message type
      final messageType = message.data['type'] ?? '';
      final relatedScreen = message.data['related_screen'] ?? '';

      // If this was an anxiety alert displayed by the OS (not our bg handler),
      // ensure it's stored in Supabase before navigation so it appears in-app.
      final looksLikeAnxiety = messageType == 'anxiety_alert' ||
          message.data['severity'] != null ||
          (message.notification?.title?.toLowerCase().contains('anxiety') ??
              false) ||
          (message.notification?.title?.toLowerCase().contains('alert') ??
              false);
      if (looksLikeAnxiety) {
        debugPrint('🔍 Checking if anxiety alert needs storage from tap...');
        debugPrint('   notificationId: ${message.data['notificationId']}');
        debugPrint('   timestamp: ${message.data['timestamp']}');
        try {
          final stored = await _storeAnxietyAlertNotification(
              message.notification, message.data);
          if (stored) {
            debugPrint('🧾 Stored tapped anxiety alert from FCM tap');
          } else {
            debugPrint('🛑 Skipped duplicate from tap (already stored)');
          }
        } catch (e) {
          debugPrint('⚠️ Could not store tapped anxiety alert: $e');
        }
      }

      // Handle wellness reminders tapped from background notifications
      final isWellnessReminder = messageType == 'wellness_reminder' ||
          messageType == 'reminder' ||
          (message.notification?.title?.toLowerCase().contains('wellness') ??
              false) ||
          (message.notification?.title?.toLowerCase().contains('breathing') ??
              false) ||
          (message.notification?.title?.toLowerCase().contains('🫁') ?? false);

      if (isWellnessReminder) {
        try {
          await _storeWellnessReminderNotification(
              message.notification, message.data);
          debugPrint('🧾 Stored tapped wellness reminder from OS notification');
        } catch (e) {
          debugPrint('⚠️ Could not store tapped wellness reminder: $e');
        }
      }

      if ((messageType == 'reminder' && relatedScreen == 'breathing_screen') ||
          message.notification?.title?.contains('Breathing Exercise') == true ||
          message.notification?.title?.contains('🫁') == true) {
        debugPrint('🫁 Navigating to breathing screen from notification tap');
        rootNavigatorKey.currentState?.pushNamed('/breathing');
      } else if (messageType == 'wellness_reminder') {
        debugPrint(
            '🍃 Navigating to breathing screen from wellness notification tap');
        final dest = (message.data['action'] ?? 'breathing').toString();
        final route = dest.contains('ground') ? '/grounding' : '/breathing';
        rootNavigatorKey.currentState?.pushNamed(route);
      } else if (messageType == 'anxiety_alert') {
        final severity = message.data['severity'] ?? '';
        debugPrint('⚠️ Anxiety alert tapped - severity: $severity');

        // Severity-specific navigation for better user experience
        switch (severity.toLowerCase()) {
          case 'mild':
            debugPrint('🟢 Mild alert → Notifications screen');
            rootNavigatorKey.currentState?.pushNamed(
              '/notifications',
              arguments: {
                'show': 'notification',
                'title': message.notification?.title ?? 'Anxiety Alert',
                'message':
                    message.notification?.body ?? 'Please check your status.',
                'type': 'alert',
                'severity': severity,
                'createdAt': DateTime.now().toIso8601String(),
              },
            );
            break;
          case 'moderate':
            debugPrint('🟡 Moderate alert → Breathing exercises');
            rootNavigatorKey.currentState?.pushNamed('/breathing');
            break;
          case 'severe':
            debugPrint('🟠 Severe alert → Grounding techniques');
            rootNavigatorKey.currentState?.pushNamed('/grounding');
            break;
          case 'critical':
            debugPrint(
                '🔴 Critical alert → Direct help modal (auto-confirmed)');
            // For critical alerts, directly show help modal without confirmation
            await _showCriticalAlertHelpModal(
              notificationTitle:
                  message.notification?.title ?? 'Critical Anxiety Alert',
              notificationMessage: message.notification?.body ??
                  'Critical anxiety level detected.',
              notificationId: message.data['notificationId'],
            );
            break;
          default:
            debugPrint('⚠️ Unknown severity → Default notifications screen');
            rootNavigatorKey.currentState?.pushNamed(
              '/notifications',
              arguments: {
                'show': 'notification',
                'title': message.notification?.title ?? 'Anxiety Alert',
                'message':
                    message.notification?.body ?? 'Please check your status.',
                'type': 'alert',
                'severity': severity,
                'createdAt': DateTime.now().toIso8601String(),
              },
            );
        }
      } else {
        debugPrint(
            '📱 Default navigation handling for message type: $messageType');
      }
    });

    // If app was launched from a terminated state by tapping a notification
    final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMsg != null) {
      debugPrint('🚀 App launched from notification. Data: ${initialMsg.data}');

      // Ensure authentication is ready so storage/navigation don't race
      await _waitForAuthReady(ensureAuthenticated: true);

      // Sync pending notifications stored while app was terminated
      try {
        await _syncPendingNotifications();
      } catch (e) {
        debugPrint('⚠️ Failed syncing pending on cold start: $e');
      }

      // Handle navigation based on message type when app launches from notification
      final messageType = initialMsg.data['type'] ?? '';
      final relatedScreen = initialMsg.data['related_screen'] ?? '';

      // Use a slight delay to ensure the app UI is fully built
      Future.delayed(const Duration(milliseconds: 300), () async {
        // Double-check auth readiness (best-effort)
        await _waitForAuthReady(ensureAuthenticated: true);
        // If this was an anxiety alert shown by the OS, store it before/while navigating
        final looksLikeAnxiety = messageType == 'anxiety_alert' ||
            initialMsg.data['severity'] != null ||
            (initialMsg.notification?.title
                    ?.toLowerCase()
                    .contains('anxiety') ??
                false) ||
            (initialMsg.notification?.title?.toLowerCase().contains('alert') ??
                false);
        if (looksLikeAnxiety) {
          try {
            final stored = await _storeAnxietyAlertNotification(
                initialMsg.notification, initialMsg.data);
            debugPrint(
                '🧾 Stored cold-start anxiety alert from OS notification: $stored');
          } catch (e) {
            debugPrint('⚠️ Could not store cold-start anxiety alert: $e');
          }
        }
        if ((messageType == 'reminder' &&
                relatedScreen == 'breathing_screen') ||
            initialMsg.notification?.title?.contains('Breathing Exercise') ==
                true ||
            initialMsg.notification?.title?.contains('🫁') == true) {
          debugPrint(
              '🫁 App launched from breathing exercise notification - navigating to breathing screen');
          rootNavigatorKey.currentState?.pushNamed('/breathing');
        } else if (messageType == 'wellness_reminder') {
          debugPrint(
              '🍃 App launched from wellness notification - navigating to breathing screen');
          final dest = (initialMsg.data['action'] ?? 'breathing').toString();
          final route = dest.contains('ground') ? '/grounding' : '/breathing';
          rootNavigatorKey.currentState?.pushNamed(route);
        } else if (messageType == 'anxiety_alert') {
          final severity = initialMsg.data['severity'] ?? '';
          debugPrint('🚀 App launched from $severity anxiety alert');

          // Severity-specific navigation when app launches from notification
          switch (severity.toLowerCase()) {
            case 'mild':
              debugPrint('🟢 Mild alert launch → Notifications screen');
              rootNavigatorKey.currentState?.pushNamed(
                '/notifications',
                arguments: {
                  'show': 'notification',
                  'title': initialMsg.notification?.title ?? 'Anxiety Alert',
                  'message': initialMsg.notification?.body ??
                      'Please check your status.',
                  'type': 'alert',
                  'severity': severity,
                  'createdAt': DateTime.now().toIso8601String(),
                },
              );
              break;
            case 'moderate':
              debugPrint('🟡 Moderate alert launch → Breathing exercises');
              rootNavigatorKey.currentState?.pushNamed('/breathing');
              break;
            case 'severe':
              debugPrint('🟠 Severe alert launch → Grounding techniques');
              rootNavigatorKey.currentState?.pushNamed('/grounding');
              break;
            case 'critical':
              debugPrint(
                  '🔴 Critical alert launch → Direct help modal (auto-confirmed)');
              // For critical alerts, directly show help modal without confirmation
              await _showCriticalAlertHelpModal(
                notificationTitle:
                    initialMsg.notification?.title ?? 'Critical Anxiety Alert',
                notificationMessage: initialMsg.notification?.body ??
                    'Critical anxiety level detected.',
                notificationId: initialMsg.data['notificationId'],
              );
              break;
            default:
              debugPrint(
                  '⚠️ Unknown severity launch → Default notifications screen');
              rootNavigatorKey.currentState?.pushNamed(
                '/notifications',
                arguments: {
                  'show': 'notification',
                  'title': initialMsg.notification?.title ?? 'Anxiety Alert',
                  'message': initialMsg.notification?.body ??
                      'Please check your status.',
                  'type': 'alert',
                  'severity': severity,
                  'createdAt': DateTime.now().toIso8601String(),
                },
              );
          }
        }
      });
    }
  } catch (e) {
    debugPrint('❌ Error configuring FCM: $e');
  }
}

DateTime _resolveNotificationTimestamp(dynamic rawTimestamp,
    {required String source}) {
  final fallback = DateTime.now().toUtc();

  if (rawTimestamp == null) {
    debugPrint('🕒 [$source] No timestamp provided; using fallback');
    return fallback;
  }

  try {
    if (rawTimestamp is int) {
      final isSeconds = rawTimestamp < 1000000000000;
      final millis = isSeconds ? rawTimestamp * 1000 : rawTimestamp;
      final parsed = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      debugPrint(
          '📅 [$source] Parsed int timestamp → ${parsed.toIso8601String()}');
      return parsed;
    }

    if (rawTimestamp is double) {
      final isSeconds = rawTimestamp < 1000000000000;
      final millis =
          isSeconds ? (rawTimestamp * 1000).round() : rawTimestamp.round();
      final parsed = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      debugPrint(
          '📅 [$source] Parsed double timestamp → ${parsed.toIso8601String()}');
      return parsed;
    }

    final rawString = rawTimestamp.toString().trim();
    if (rawString.isEmpty) {
      debugPrint('🕒 [$source] Empty timestamp string; using fallback');
      return fallback;
    }

    final numericValue = int.tryParse(rawString);
    if (numericValue != null) {
      final isSeconds = rawString.length <= 10;
      final millis = isSeconds ? numericValue * 1000 : numericValue;
      final parsed = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      debugPrint(
          '📅 [$source] Parsed numeric string → ${parsed.toIso8601String()}');
      return parsed;
    }

    final doubleValue = double.tryParse(rawString);
    if (doubleValue != null) {
      final isSeconds = doubleValue < 1000000000000;
      final millis =
          isSeconds ? (doubleValue * 1000).round() : doubleValue.round();
      final parsed = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      debugPrint(
          '📅 [$source] Parsed decimal string → ${parsed.toIso8601String()}');
      return parsed;
    }

    final parsedDate = DateTime.tryParse(rawString);
    if (parsedDate != null) {
      final utcDate = parsedDate.isUtc ? parsedDate : parsedDate.toUtc();
      debugPrint(
          '📅 [$source] Parsed ISO string → ${utcDate.toIso8601String()}');
      return utcDate;
    }

    debugPrint(
        '🕒 [$source] Unsupported timestamp format ($rawString); using fallback');
    return fallback;
  } catch (e) {
    debugPrint('⚠️ [$source] Failed to parse timestamp ($rawTimestamp): $e');
    return fallback;
  }
}

/// Store anxiety alert notification in Supabase for notifications screen display
/// Track recently stored notification IDs to prevent duplicates
final Map<String, DateTime> _storedNotificationIds = {};

Future<bool> _storeAnxietyAlertNotification(
    RemoteNotification? notification, Map<String, dynamic> data) async {
  try {
    final supabaseService = SupabaseService();

    // Extract information from FCM data
    final severity = data['severity'] ?? 'unknown';
    final heartRate = data['heartRate'] ?? 'N/A';
    final baseline = data['baseline'];
    final notificationId = data['notificationId'] ?? data['timestamp'] ?? '';

    // Deduplication: Check if we've stored this notification in the last 10 seconds
    if (notificationId.isNotEmpty) {
      final lastStored = _storedNotificationIds[notificationId];
      if (lastStored != null) {
        final timeSinceStored = DateTime.now().difference(lastStored).inSeconds;
        if (timeSinceStored < 10) {
          debugPrint(
              '🛑 Skipping duplicate notification (stored ${timeSinceStored}s ago): $notificationId');
          return false;
        }
      }
      // Mark as stored
      _storedNotificationIds[notificationId] = DateTime.now();
      // Clean up old entries (keep last 50)
      if (_storedNotificationIds.length > 50) {
        final oldestKey = _storedNotificationIds.keys.first;
        _storedNotificationIds.remove(oldestKey);
      }
    }

    String title = notification?.title ?? 'Anxiety Alert';
    String body =
        notification?.body ?? 'Anxiety detected. Please check your status.';

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
        final percentageAbove = data['percentageAbove'];
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

    // Store in Supabase with enhanced debugging
    debugPrint('💾 Storing anxiety alert with details:');
    debugPrint('   title: $title');
    debugPrint('   body: $body');
    debugPrint('   severity: $severity');

    // Use the timestamp from FCM data if available, otherwise use current time
    final fcmTimestamp =
        data['timestamp'] ?? data['created_at'] ?? data['createdAt'];
    final notificationTime =
        _resolveNotificationTimestamp(fcmTimestamp, source: 'anxiety_alert');

    debugPrint('🕐 Storing notification with timestamp:');
    debugPrint('   FCM raw timestamp: $fcmTimestamp');
    debugPrint('   Resolved time (UTC): ${notificationTime.toIso8601String()}');
    debugPrint(
        '   Resolved time (local): ${notificationTime.toLocal().toIso8601String()}');
    debugPrint(
        '   Current time (UTC): ${DateTime.now().toUtc().toIso8601String()}');
    debugPrint('   Current time (local): ${DateTime.now().toIso8601String()}');

    await supabaseService.createNotificationWithTimestamp(
      title: title,
      message: body,
      type: 'alert',
      relatedScreen:
          'notifications', // Changed to match where user gets redirected
      relatedId: data['notificationId'],
      createdAt: notificationTime,
    );

    // Trigger notification refresh in home screen
    debugPrint('🔄 Triggering notification refresh...');
    _triggerNotificationRefresh();

    debugPrint('✅ Stored anxiety alert in Supabase: $title');
    return true;
  } catch (e) {
    debugPrint('❌ Error storing anxiety alert notification: $e');
    // Notification display shouldn't fail if storage fails
    return false;
  }
}

/// Store wellness reminder notification in Supabase for notifications screen display
Future<void> _storeWellnessReminderNotification(
    RemoteNotification? notification, Map<String, dynamic> data) async {
  try {
    final supabaseService = SupabaseService();

    String title = notification?.title ?? 'Wellness Reminder';
    String body =
        notification?.body ?? 'Take a moment to check how you\'re feeling.';

    // Determine related screen based on data
    String relatedScreen = 'breathing_screen'; // default
    final action = data['action']?.toString() ?? '';
    if (action.contains('ground')) {
      relatedScreen = 'grounding_screen';
    }

    // Store in Supabase
    final rawTimestamp =
        data['timestamp'] ?? data['scheduled_at'] ?? data['scheduledAt'];
    final notificationTime = _resolveNotificationTimestamp(rawTimestamp,
        source: 'wellness_reminder');
    await supabaseService.createNotificationWithTimestamp(
      title: title,
      message: body,
      type: 'reminder',
      relatedScreen: relatedScreen,
      relatedId: rawTimestamp?.toString(),
      createdAt: notificationTime,
    );

    // Trigger notification refresh in home screen
    _triggerNotificationRefresh();

    debugPrint('✅ Stored wellness reminder in Supabase: $title');
  } catch (e) {
    debugPrint('❌ Error storing wellness reminder notification: $e');
    // Don't rethrow - notification display shouldn't fail if storage fails
  }
}

/// Store breathing exercise reminder notification in Supabase for notifications screen display
Future<void> _storeBreathingReminderNotification(
    RemoteNotification? notification, Map<String, dynamic> data) async {
  try {
    final supabaseService = SupabaseService();

    String title = notification?.title ?? '🫁 Breathing Exercise Reminder';
    String body = notification?.body ??
        'Time for a breathing exercise! Take a moment to relax and breathe.';

    // Store in Supabase
    final rawTimestamp =
        data['timestamp'] ?? data['scheduled_at'] ?? data['scheduledAt'];
    final notificationTime = _resolveNotificationTimestamp(rawTimestamp,
        source: 'breathing_reminder');
    await supabaseService.createNotificationWithTimestamp(
      title: title,
      message: body,
      type: 'reminder',
      relatedScreen: 'breathing_screen',
      relatedId: rawTimestamp?.toString(),
      createdAt: notificationTime,
    );

    // Trigger notification refresh in home screen
    _triggerNotificationRefresh();

    debugPrint('✅ Stored breathing reminder in Supabase: $title');
  } catch (e) {
    debugPrint('❌ Error storing breathing reminder notification: $e');
    // Don't rethrow - notification display shouldn't fail if storage fails
  }
}

/// Trigger notification refresh in home screen
void _triggerNotificationRefresh() {
  debugPrint(
      '🔔 _triggerNotificationRefresh called at ${DateTime.now().toIso8601String()}');

  try {
    // Get the current context from the navigator
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      // Find the NotificationProvider and trigger refresh
      // A single call is enough: triggerNotificationRefresh() synchronously
      // calls notifyListeners(), so firing it repeatedly with delays only
      // causes listening screens (e.g. NotificationsScreen) to reload multiple
      // times for the same event.
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      notificationProvider.triggerNotificationRefresh();
      debugPrint(
          '✅ Triggered notification refresh in home screen successfully');
    } else {
      debugPrint(
          '⚠️ No context available for notification refresh - will retry');
      // Retry after a short delay if context isn't available yet
      Future.delayed(const Duration(milliseconds: 500), () {
        _triggerNotificationRefresh();
      });
    }
  } catch (e) {
    debugPrint('❌ Error triggering notification refresh: $e');
    // Don't rethrow - this is a UI update and shouldn't break notification storage
    // Try again after a delay
    Future.delayed(const Duration(seconds: 1), () {
      try {
        debugPrint('🔄 Retrying notification refresh after error...');
        _triggerNotificationRefresh();
      } catch (retryError) {
        debugPrint('❌ Notification refresh retry also failed: $retryError');
      }
    });
  }
}

/// Show help modal directly for critical anxiety alerts
/// This function automatically marks critical alerts as confirmed anxiety attacks
Future<void> _showCriticalAlertHelpModal({
  String? notificationTitle,
  String? notificationMessage,
  String? notificationId,
}) async {
  try {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('⚠️ No context available for critical alert help modal');
      return;
    }

    // Get user's emergency contact
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final emergencyContact = user?.emergencyContact;

    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return _CriticalHelpModalWidget(
          emergencyContact: emergencyContact,
          notificationId: notificationId,
        );
      },
    );

    // CRITICAL: Mark this critical alert as confirmed anxiety attack in the database
    if (notificationId != null) {
      try {
        final supabaseService = SupabaseService();
        // Mark the notification as answered with confirmed = true (anxiety attack)
        await supabaseService.markNotificationAsAnswered(
          notificationId,
          response:
              'CONFIRMED_CRITICAL', // Confirmed as critical anxiety attack
          severity: 'critical', // severity level
        );
        debugPrint(
            '✅ Critical alert automatically marked as confirmed anxiety attack in database');
      } catch (e) {
        debugPrint('❌ Error marking critical alert as confirmed: $e');
      }
    } else {
      debugPrint(
          '⚠️ No notification ID provided for critical alert confirmation');
    }
  } catch (e) {
    debugPrint('❌ Error showing critical alert help modal: $e');
  }
}

/// Wait until authentication is initialized and optionally authenticated
Future<void> _waitForAuthReady({
  bool ensureAuthenticated = false,
  Duration timeout = const Duration(seconds: 15), // Increased timeout
}) async {
  final start = DateTime.now();
  debugPrint(
      '🔐 _waitForAuthReady starting (ensureAuthenticated=$ensureAuthenticated)');

  int logCount = 0; // Prevent log spam
  while (DateTime.now().difference(start) < timeout) {
    try {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        final authProvider = Provider.of<AuthProvider>(ctx, listen: false);
        final init = authProvider.isInitialized;
        final authed = authProvider.isAuthenticated;

        // Only log every 20 iterations (every 2 seconds) to prevent spam
        if (logCount % 20 == 0) {
          debugPrint(
              '🔐 Auth status: initialized=$init, authenticated=$authed');
        }
        logCount++;

        if (init && (!ensureAuthenticated || authed)) {
          debugPrint(
              '✅ Auth is ready! (took ${DateTime.now().difference(start).inMilliseconds}ms)');
          return; // Ready
        }

        // If we don't need authentication and auth is initialized, exit early
        if (init && !ensureAuthenticated) {
          debugPrint('✅ Auth initialized (authentication not required)');
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking auth status: $e');
    }
    await Future.delayed(const Duration(milliseconds: 100)); // Faster polling
  }
  debugPrint(
      '⏳ _waitForAuthReady timed out after ${timeout.inSeconds}s (ensureAuthenticated=$ensureAuthenticated)');
}

// Subscribe to FCM topics only once per installation
Future<void> _subscribeToTopicsOnce() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Always re-subscribe to ensure fresh connection (changed from once-only)
    await FirebaseMessaging.instance.subscribeToTopic('anxiety_alerts');
    await prefs.setBool('subscribed_anxiety_alerts', true);
    debugPrint('✅ Subscribed/re-subscribed to anxiety_alerts topic');

    // Always re-subscribe to wellness_reminders to ensure fresh connection
    await FirebaseMessaging.instance.subscribeToTopic('wellness_reminders');
    await prefs.setBool('subscribed_wellness_reminders', true);
    debugPrint('✅ Subscribed/re-subscribed to wellness_reminders topic');

    debugPrint('📱 FCM topic subscriptions completed successfully');
  } catch (e) {
    debugPrint('❌ Failed to manage FCM topic subscriptions: $e');
  }
}

// Get fresh FCM token and store it
Future<void> _refreshAndStoreToken() async {
  int retryCount = 0;
  const maxRetries = 3;

  while (retryCount < maxRetries) {
    try {
      // Reuse the current token during normal startup/resume. Deleting it here
      // causes unnecessary token churn and repeated database writes.
      AppLogger.d('Checking current FCM token');

      if (retryCount > 0) {
        await Future.delayed(Duration(seconds: retryCount + 1));
      }

      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        AppLogger.d('FCM registration token available');
        await _storeTokenAtAssignmentLevel(token);
        AppLogger.d('FCM token stored successfully');
        return; // Success, exit retry loop
      } else {
        debugPrint(
            '⚠️ FCM token is null after refresh (attempt ${retryCount + 1}/$maxRetries)');
      }
    } catch (e) {
      retryCount++;
      debugPrint(
          '❌ Error refreshing FCM token (attempt $retryCount/$maxRetries): $e');

      if (e.toString().contains('SERVICE_NOT_AVAILABLE')) {
        debugPrint('⚠️ Google Play Services not available. Please check:');
        debugPrint('   1. Google Play Services is installed and updated');
        debugPrint('   2. Device has internet connection');
        debugPrint('   3. Date & time settings are correct');

        if (retryCount < maxRetries) {
          debugPrint('   🔄 Retrying in ${retryCount + 1} seconds...');
          await Future.delayed(Duration(seconds: retryCount + 1));
        }
      }
    }
  }

  debugPrint('❌ Failed to get FCM token after $maxRetries attempts');
  debugPrint(
      '💡 Notifications will not work until Google Play Services is available');
}

// Store FCM token at both user and assignment levels for different notification types
Future<void> _storeTokenAtAssignmentLevel(String token) async {
  try {
    const deviceId = 'AnxieEase001'; // Your device ID

    // 1. ALWAYS store user-level FCM token for wellness notifications
    await _storeUserLevelFCMToken(token);

    // 2. Store assignment-level FCM token ONLY if user has device assigned
    final adminDeviceService = AdminDeviceManagementService();
    final assignmentStatus = await adminDeviceService.checkDeviceAssignment();

    debugPrint('🔍 FCM Token Assignment Check - User Assignment Status:');
    debugPrint('   - isAssigned: ${assignmentStatus.isAssigned}');
    debugPrint('   - status: ${assignmentStatus.status}');
    debugPrint('   - canUseDevice: ${assignmentStatus.canUseDevice}');

    if (assignmentStatus.canUseDevice) {
      // ADDITIONAL VALIDATION: Check if assignment node exists and belongs to current user
      final supabaseService = SupabaseService();
      final currentUser = supabaseService.client.auth.currentUser;

      if (currentUser == null) {
        debugPrint(
            '❌ No authenticated user - cannot store assignment FCM token');
        return;
      }

      final assignmentRef =
          FirebaseDatabase.instance.ref('/devices/$deviceId/assignment');
      final assignmentSnapshot = await assignmentRef.once();
      final assignmentData = assignmentSnapshot.snapshot.value as Map?;

      // Validate that existing assignment belongs to current user
      if (assignmentData != null) {
        final assignedUserId = assignmentData['assignedUser'] as String?;
        if (assignedUserId != null && assignedUserId != currentUser.id) {
          debugPrint(
              '⚠️ WARNING: Assignment exists for different user ($assignedUserId), current user: ${currentUser.id}');
          debugPrint(
              '⚠️ Skipping FCM token storage to prevent overwriting another user\'s token');
          return;
        }

        // Safe to update - either no assignedUser field or it matches current user
        await assignmentRef.update({
          'fcmToken': token,
          'tokenAssignedAt': DateTime.now().toIso8601String(),
          'assignedUser': currentUser
              .id, // Ensure we track which user this token belongs to
          'lastTokenRefresh':
              DateTime.now().toIso8601String(), // Add refresh timestamp
        });
        debugPrint(
            '✅ FCM token stored in assignment node: $deviceId (User: ${currentUser.id})');
      } else {
        // Create assignment if it doesn't exist
        await assignmentRef.set({
          'fcmToken': token,
          'tokenAssignedAt': DateTime.now().toIso8601String(),
          'assignedUser':
              currentUser.id, // Track which user this token belongs to
          'status': 'inactive',
          'assignedAt': DateTime.now().toIso8601String(),
          'lastTokenRefresh': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ Created assignment with FCM token: $deviceId (User: ${currentUser.id})');
      }
    } else {
      debugPrint(
          'ℹ️ User has no device assigned (status: ${assignmentStatus.status}) - skipping assignment FCM token');

      // IMPORTANT: If user is not assigned, ensure they don't have any assignment-level token
      try {
        final assignmentRef =
            FirebaseDatabase.instance.ref('/devices/$deviceId/assignment');
        final assignmentSnapshot = await assignmentRef.once();
        final assignmentData = assignmentSnapshot.snapshot.value as Map?;

        if (assignmentData != null) {
          final supabaseService = SupabaseService();
          final currentUser = supabaseService.client.auth.currentUser;
          final assignedUserId = assignmentData['assignedUser'] as String?;

          // Remove FCM token if it belongs to current user (they're no longer assigned)
          if (currentUser != null && assignedUserId == currentUser.id) {
            await assignmentRef.update({
              'fcmToken': null,
              'tokenAssignedAt': null,
              'lastTokenRefresh': null,
            });
            debugPrint(
                '🧹 Removed assignment FCM token for unassigned user: ${currentUser.id}');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Could not clean up assignment token: $e');
      }
    }

    // Clean up old device-level token (legacy location)
    try {
      await FirebaseDatabase.instance
          .ref('/devices/$deviceId/fcmToken')
          .remove();
      debugPrint('🧹 Cleaned up old device-level FCM token');
    } catch (e) {
      debugPrint('⚠️ Could not remove old device-level token: $e');
    }
  } catch (e) {
    debugPrint('❌ Failed to store FCM tokens: $e');
  }
}

// NEW: Ensure FCM token persistence when app goes to background
Future<void> _ensureTokenPersistence() async {
  try {
    debugPrint('🔒 Ensuring FCM token persistence...');

    // Get current token and store it
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _storeTokenAtAssignmentLevel(token);
      debugPrint('✅ FCM token persisted before app backgrounding');
    } else {
      debugPrint('⚠️ No FCM token available for persistence');
    }
  } catch (e) {
    debugPrint('❌ Error ensuring token persistence: $e');
  }
}

// NEW: Validate and refresh FCM token if missing from assignment
Future<void> _validateAndRefreshAssignmentToken() async {
  try {
    const deviceId = 'AnxieEase001';
    debugPrint('🔍 Validating assignment FCM token...');

    final adminDeviceService = AdminDeviceManagementService();
    final assignmentStatus = await adminDeviceService.checkDeviceAssignment();

    if (!assignmentStatus.canUseDevice) {
      debugPrint('ℹ️ User has no device assigned - skipping token validation');
      return;
    }

    final supabaseService = SupabaseService();
    final currentUser = supabaseService.client.auth.currentUser;

    if (currentUser == null) {
      debugPrint('❌ No authenticated user for token validation');
      return;
    }

    // Check if assignment has FCM token
    final assignmentRef =
        FirebaseDatabase.instance.ref('/devices/$deviceId/assignment');
    final assignmentSnapshot = await assignmentRef.once();
    final assignmentData = assignmentSnapshot.snapshot.value as Map?;

    final fcmToken = assignmentData?['fcmToken'] as String?;
    final assignedUserId = assignmentData?['assignedUser'] as String?;

    // If no token exists or token belongs to different user, refresh it
    if (fcmToken == null || assignedUserId != currentUser.id) {
      debugPrint(
          '🔄 Assignment missing FCM token or belongs to different user - refreshing...');
      await _refreshAndStoreToken();
    } else {
      debugPrint('✅ Assignment FCM token validation passed');
    }
  } catch (e) {
    debugPrint('❌ Error validating assignment token: $e');
  }
}

// Store user-level FCM token for wellness notifications and general app notifications
Future<void> _storeUserLevelFCMToken(String token) async {
  try {
    if (!kStoreUserLevelFcmTokenInRealtimeDb) {
      AppLogger.d(
          'Skipping user-level FCM token write; Realtime Database rules do not allow this path.');
      return;
    }

    final supabaseService = SupabaseService();
    final user = supabaseService.client.auth.currentUser;
    if (user == null) {
      AppLogger.d('No authenticated user for FCM token storage');
      return;
    }

    // Store at user level for wellness reminders and general notifications
    final userFCMRef =
        FirebaseDatabase.instance.ref('/users/${user.id}/fcmToken');
    await userFCMRef.set({
      'token': token,
      'updatedAt': DateTime.now().toIso8601String(),
      'deviceInfo': {
        'platform': Platform.isIOS ? 'ios' : 'android',
        'appVersion': '1.0.0', // You can get this from package_info
      }
    });

    debugPrint(
        '✅ User-level FCM token stored for wellness notifications: ${user.id}');
  } catch (e) {
    debugPrint('❌ Failed to store user-level FCM token: $e');
  }
}

// Add this new debugging function right after _syncPendingNotifications
/// Debug function to check what's stored in SharedPreferences
Future<void> _debugLocalNotifications() async {
  try {
    debugPrint('🔍 DEBUG: Checking local notification storage...');
    final prefs = await SharedPreferences.getInstance();

    // Check pending notifications
    final pendingNotifications =
        prefs.getStringList('pending_notifications') ?? [];
    debugPrint(
        '🔍 DEBUG: Found ${pendingNotifications.length} pending notifications in local storage:');
    for (int i = 0; i < pendingNotifications.length; i++) {
      debugPrint('   [$i]: ${pendingNotifications[i]}');
    }

    // Check all keys that might be related to notifications
    final allKeys = prefs.getKeys();
    final notificationKeys =
        allKeys.where((key) => key.toLowerCase().contains('notif')).toList();
    debugPrint(
        '🔍 DEBUG: Notification-related keys in SharedPreferences: $notificationKeys');

    for (final key in notificationKeys) {
      final value = prefs.get(key);
      debugPrint('🔍 DEBUG: $key = $value');
    }
  } catch (e) {
    debugPrint('❌ DEBUG: Error checking local notifications: $e');
  }
}

/// Sync pending notifications from local storage to Supabase
bool _isSyncingPendingNotifications = false;

Future<void> _syncPendingNotifications() async {
  if (_isSyncingPendingNotifications) {
    debugPrint(
        '⏳ _syncPendingNotifications already running; skipping re-entry');
    return;
  }

  _isSyncingPendingNotifications = true;
  try {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('🔄 _syncPendingNotifications called at $timestamp');

    // Debug: Check for background notification markers
    debugPrint('🔍 Checking for background notification markers...');
    await _debugCheckBackgroundMarkers();

    final prefs = await SharedPreferences.getInstance();

    debugPrint('🔄 Syncing pending notifications from local storage...');

    // Get all pending notifications from SharedPreferences
    final pendingNotifications =
        prefs.getStringList('pending_notifications') ?? [];

    debugPrint(
        '📋 Total pending notifications found: ${pendingNotifications.length}');
    if (pendingNotifications.isEmpty) {
      debugPrint('📋 No pending notifications to sync');
      return;
    }

    debugPrint(
        '📥 Found ${pendingNotifications.length} pending notifications:');
    for (int i = 0; i < pendingNotifications.length; i++) {
      debugPrint('   [$i]: ${pendingNotifications[i]}');
    }

    // Try to get Supabase service - if it fails, we'll retry later
    SupabaseService? supabaseService;
    try {
      supabaseService = SupabaseService();
      // Simple connectivity test - just instantiate the service
      debugPrint('✅ Supabase service is ready for syncing');
    } catch (e) {
      debugPrint('⚠️ Supabase not ready yet, will retry later: $e');
      // Schedule a retry in a few seconds
      Future.delayed(const Duration(seconds: 3), () async {
        debugPrint('🔄 Retrying sync after Supabase delay...');
        await _syncPendingNotifications();
      });
      return;
    }

    int syncedCount = 0;
    List<String> remainingNotifications = [];

    // Process each pending notification
    for (final notificationString in pendingNotifications) {
      try {
        debugPrint('🔍 Processing notification: $notificationString');

        // Parse the notification data - try new format first (key=value), then fallback to old format (pipe-separated)
        Map<String, String> notificationData = {};

        if (notificationString.contains('=') &&
            notificationString.contains('&')) {
          // New enhanced format: key=value&key2=value2
          final pairs = notificationString.split('&');
          for (final pair in pairs) {
            final keyValue = pair.split('=');
            if (keyValue.length == 2) {
              notificationData[keyValue[0]] =
                  keyValue[1] == 'null' ? '' : keyValue[1];
            }
          }
        } else {
          // Old pipe-separated format: title|message|severity|timestamp
          final parts = notificationString.split('|');
          if (parts.length >= 4) {
            notificationData = {
              'title': parts[0],
              'body': parts[1],
              'severity': parts.length > 2 ? parts[2] : 'unknown',
              'timestamp': parts.length > 3
                  ? parts[3]
                  : DateTime.now().toIso8601String(),
              'type': 'anxiety_alert',
            };
          }
        }

        if (notificationData.isNotEmpty) {
          final title = notificationData['title'] ?? 'Notification';
          final message = notificationData['body'] ??
              notificationData['message'] ??
              'You have a new notification.';
          final severity = notificationData['severity'] ?? 'unknown';
          final notificationType = notificationData['type'] ?? 'alert';
          final timestamp =
              notificationData['timestamp'] ?? DateTime.now().toIso8601String();
          final heartRate = notificationData['heartRate'] ?? '';
          final baseline = notificationData['baseline'] ?? '';
          final duration = notificationData['duration'] ?? '';
          final reason = notificationData['reason'] ?? '';
          final notificationId = notificationData['notificationId'] ?? '';

          debugPrint('💾 Syncing enhanced notification:');
          debugPrint('   Title: $title');
          debugPrint('   Message: $message');
          debugPrint('   Type: $notificationType');
          debugPrint('   Severity: $severity');
          debugPrint('   Heart Rate: $heartRate');
          debugPrint('   Baseline: $baseline');
          debugPrint('   Duration: $duration');
          debugPrint('   Reason: $reason');
          debugPrint('   Timestamp: $timestamp');
          if (notificationId.isNotEmpty) {
            final lastStored = _storedNotificationIds[notificationId];
            if (lastStored != null) {
              final secondsSince =
                  DateTime.now().difference(lastStored).inSeconds;
              if (secondsSince < 10) {
                debugPrint(
                    '🛑 Skipping pending duplicate (stored ${secondsSince}s ago): $notificationId');
                continue;
              }
            }
          }

          final resolvedTimestamp =
              _resolveNotificationTimestamp(timestamp, source: 'pending_sync');

          // Build enhanced message only for anxiety alerts (not wellness reminders)
          final isWellnessReminder = notificationType == 'wellness_reminder' ||
              notificationType == 'reminder';
          final enhancedMessage = isWellnessReminder
              ? message
              : message +
                  (heartRate.isNotEmpty ? " | HR: ${heartRate} BPM" : "") +
                  (baseline.isNotEmpty ? " (Baseline: ${baseline} BPM)" : "") +
                  (duration.isNotEmpty ? " for ${duration}s" : "") +
                  (reason.isNotEmpty ? " | ${reason}" : "");

          // Determine related screen based on notification type
          final relatedScreen =
              isWellnessReminder ? 'breathing_screen' : 'notifications';

          await supabaseService.createNotificationWithTimestamp(
            title: title,
            message: enhancedMessage,
            type: notificationType, // Use actual type (reminder or alert)
            relatedScreen: relatedScreen,
            relatedId:
                'bg_${severity}_${DateTime.now().millisecondsSinceEpoch}',
            createdAt: resolvedTimestamp,
          );

          if (notificationId.isNotEmpty) {
            _storedNotificationIds[notificationId] = DateTime.now();
            if (_storedNotificationIds.length > 50) {
              final oldestKey = _storedNotificationIds.keys.first;
              _storedNotificationIds.remove(oldestKey);
            }
          }

          syncedCount++;
          debugPrint('✅ Successfully synced enhanced notification: $title');
        } else {
          debugPrint(
              '⚠️ Could not parse notification format: $notificationString');
          // Keep malformed notifications for retry
          remainingNotifications.add(notificationString);
        }
      } catch (e) {
        debugPrint('❌ Failed to sync individual notification: $e');
        debugPrint('   Notification data: $notificationString');
        // Keep failed notifications for retry
        remainingNotifications.add(notificationString);
      }
    }

    // Update SharedPreferences with remaining notifications
    await prefs.setStringList('pending_notifications', remainingNotifications);

    debugPrint('✅ Sync complete at ${DateTime.now().toIso8601String()}:');
    debugPrint('   $syncedCount notifications synced to Supabase');
    debugPrint(
        '   ${remainingNotifications.length} notifications remain pending');

    if (remainingNotifications.isNotEmpty) {
      debugPrint('📝 Remaining pending notifications:');
      for (int i = 0; i < remainingNotifications.length; i++) {
        debugPrint('   [$i]: ${remainingNotifications[i]}');
      }
    }

    // Trigger notification refresh in UI only once after successful sync
    if (syncedCount > 0) {
      debugPrint(
          '🔔 Triggering UI refresh after syncing ${syncedCount} notifications...');
      _triggerNotificationRefresh();
    }
  } catch (e) {
    debugPrint('❌ Error syncing pending notifications: $e');
    debugPrint('❌ Stack trace: ${StackTrace.current}');
    // Schedule a retry for failed sync
    Future.delayed(const Duration(seconds: 5), () async {
      debugPrint('🔄 Retrying sync after error...');
      await _syncPendingNotifications();
    });
  } finally {
    _isSyncingPendingNotifications = false;
  }
}

/// Debug helper to check background notification markers
Future<void> _debugCheckBackgroundMarkers() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final backgroundKeys = allKeys
        .where((key) => key.startsWith('last_background_notification_'))
        .toList();

    debugPrint(
        '🔍 Found ${backgroundKeys.length} background notification markers');
    for (final key in backgroundKeys) {
      final value = prefs.getString(key);
      debugPrint('   📍 $key: $value');
    }

    if (backgroundKeys.isEmpty) {
      debugPrint(
          '⚠️ No background notification markers found - background handler may not be working');
    }
  } catch (e) {
    debugPrint('❌ Error checking background markers: $e');
  }
}

/// StatefulWidget for Critical Help Modal with lifecycle management
class _CriticalHelpModalWidget extends StatefulWidget {
  final String? emergencyContact;
  final String? notificationId;

  const _CriticalHelpModalWidget({
    this.emergencyContact,
    this.notificationId,
  });

  @override
  State<_CriticalHelpModalWidget> createState() =>
      _CriticalHelpModalWidgetState();
}

class _CriticalHelpModalWidgetState extends State<_CriticalHelpModalWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Unfocus any text fields and trigger a rebuild when returning from external apps
      FocusScope.of(context).unfocus();
      if (mounted) {
        setState(() {
          // Trigger a rebuild to refresh the UI state
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.withOpacity(0.05),
                Colors.white,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite,
                      color: Colors.red[700],
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'re Not Alone - We\'re Here to Help',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.psychology,
                                  color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'First, take a moment to breathe slowly and deeply',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• You are safe right now\n• This feeling will pass\n• Focus on your breathing: in for 4, hold for 4, out for 6\n• Use the resources below when you\'re ready',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[600],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Immediate Self-Care Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.self_improvement,
                                    color: Colors.green[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Immediate Relief Techniques',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Try these calming techniques first:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.green[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🫁 4-7-8 Breathing: Breathe in for 4 counts, hold for 7, exhale for 8',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '🌿 5-4-3-2-1 Grounding: Name 5 things you see, 4 you hear, 3 you touch, 2 you smell, 1 you taste',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '💭 Remind yourself: "I am safe. This will pass. I can handle this."',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Emergency Contact Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.phone_in_talk,
                                    color: Colors.red[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Emergency Contacts',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // User's Personal Emergency Contact (if available)
                            if (widget.emergencyContact != null &&
                                widget.emergencyContact!.trim().isNotEmpty) ...[
                              _buildContactChip(
                                label: 'Your Emergency Contact',
                                number: widget.emergencyContact!.trim(),
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 8),
                            ],

                            // NCMH Crisis Hotlines
                            Text(
                              'NCMH (National Center for Mental Health) Crisis Hotline',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.red[700],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildContactChip(
                              label: 'Main Hotline',
                              number: '1553',
                              color: Colors.red,
                            ),
                            const SizedBox(height: 6),
                            _buildContactChip(
                              label: 'Alternative',
                              number: '180018881553',
                              color: Colors.red,
                            ),
                            const SizedBox(height: 6),
                            _buildContactChip(
                              label: 'Smart/TNT',
                              number: '09190571553',
                              color: Colors.red,
                            ),
                            const SizedBox(height: 6),
                            _buildContactChip(
                              label: 'Globe/TM',
                              number: '09178998727',
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons
                      Column(
                        children: [
                          // Reassuring message before emergency options
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange[700], size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'If breathing techniques don\'t help and you feel unsafe, reach out for support:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Emergency Call 911 Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _makeEmergencyCall('911'),
                              icon: const Icon(Icons.emergency,
                                  color: Colors.white, size: 20),
                              label: const Text(
                                  'Emergency Call 911 (if in danger)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Breathing Exercise Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                rootNavigatorKey.currentState
                                    ?.pushNamed('/breathing');
                              },
                              icon: const Icon(Icons.air, color: Colors.white),
                              label: const Text('Guided Breathing Exercise'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Grounding Technique Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                rootNavigatorKey.currentState
                                    ?.pushNamed('/grounding');
                              },
                              icon: const Icon(Icons.self_improvement,
                                  color: Colors.white),
                              label: const Text('5-4-3-2-1 Grounding Exercise'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Find Nearest Clinic Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SearchScreen(),
                                  ),
                                );
                              },
                              icon: Icon(Icons.local_hospital,
                                  color: Colors.red[700]),
                              label: const Text('Find Nearest Clinic'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red[700],
                                side: BorderSide(color: Colors.red[700]!),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Encouraging message
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.favorite,
                                    color: Colors.purple[600], size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Remember: You are stronger than you think. This moment will pass.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple[600],
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Icon(Icons.favorite,
                                    color: Colors.purple[600], size: 16),
                              ],
                            ),
                          ),

                          // Close Button
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'I\'m feeling better now',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactChip({
    required String label,
    required String number,
    required MaterialColor color,
  }) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _makePhoneCall(number),
        icon: Icon(Icons.phone, color: Colors.white, size: 16),
        label: Text('$label: $number'),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final dialerUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(dialerUri)) {
        await launchUrl(dialerUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch dialer for $phoneNumber'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching phone dialer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please manually dial $phoneNumber'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _makeEmergencyCall(String emergencyNumber) async {
    try {
      // Method 1: Try direct Android intent for dialer
      final dialerUri = Uri(scheme: 'tel', path: emergencyNumber);
      if (await canLaunchUrl(dialerUri)) {
        await launchUrl(dialerUri, mode: LaunchMode.externalApplication);
      } else {
        // Method 2: Try alternative dialer intent
        const platform = MethodChannel('anxieease.dev/emergency');
        try {
          await platform
              .invokeMethod('makeEmergencyCall', {'number': emergencyNumber});
        } catch (platformError) {
          // Method 3: Show manual dial instructions
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Emergency Call'),
                content: Text(
                  'Please manually dial $emergencyNumber on your phone\'s keypad.\n\n'
                  'Alternative emergency numbers:\n'
                  '• 117 (PNP Emergency Hotline)\n'
                  '• Use your phone\'s emergency call feature',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please manually dial $emergencyNumber'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
