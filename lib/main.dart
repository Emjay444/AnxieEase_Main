import 'package:flutter/material.dart';
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
import 'breathing_screen.dart';
import 'grounding_screen.dart';
import 'screens/device_linking_screen.dart';
import 'screens/device_setup_wizard_screen.dart';
import 'screens/baseline_recording_screen.dart';
import 'screens/health_dashboard_screen.dart';
import 'search.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

// Global completer to signal when services finish initialization (replaces polling bool)
final Completer<void> servicesInitializedCompleter = Completer<void>();
// Toggle this to enable/disable verbose logging app‑wide
const bool kVerboseLogging = true;

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
            debugPrint('🚨 Critical alert → Direct help modal (auto-confirmed)');
            await _showCriticalAlertHelpModal(
              notificationTitle: receivedAction.title ?? 'Critical Anxiety Alert',
              notificationMessage: receivedAction.body ?? 'Critical anxiety level detected.',
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
    // --- CORE (block only what is strictly necessary for first frame) --- //
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await SupabaseService().initialize(); // needed for AuthProvider

    // Early sync attempt - try to sync notifications immediately after Supabase is ready
    debugPrint('🔄 Early sync attempt during initialization...');
    _syncPendingNotifications();

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

    // Initialize storage service with frame break and timeout handling
    try {
      await Future.any([
        StorageService().init(),
        Future.delayed(const Duration(seconds: 5), () {
          AppLogger.w(
              '! StorageService initialization timed out, continuing anyway');
        })
      ]);
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

    // Don't wait too long for auth - sync regardless
    Future.any([
      _waitForAuthReady(
          ensureAuthenticated: false), // Don't require authentication
      Future.delayed(const Duration(seconds: 5), () {
        debugPrint('! Auth timeout - proceeding with sync anyway');
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
        // App became active/foreground - sync notifications
        debugPrint('🔄 App resumed - triggering notification sync...');
        Future.delayed(const Duration(milliseconds: 500), () async {
          await _debugLocalNotifications(); // Debug what's in local storage
          _syncPendingNotifications();
        });
        break;
      case AppLifecycleState.paused:
        debugPrint('⏸️ App paused');
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
  Future<void> _setupMultipleSyncStrategies() async {
    debugPrint('🔄 Setting up multiple sync strategies...');

    // Strategy 0: Immediate sync attempt (before auth is fully ready)
    debugPrint('🔄 Strategy 0: Immediate sync attempt...');
    await _debugLocalNotifications(); // Debug what's in local storage
    _syncPendingNotifications();

    // Strategy 1: AuthProvider listener (immediate when auth ready)
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
          await _debugLocalNotifications(); // Debug what's in local storage
          await _syncPendingNotifications();
        }
      });
    } catch (e) {
      debugPrint('⚠️ Could not attach auth listener for pending sync: $e');
    }

    // Strategy 2: Aggressive early retry (1 second)
    Future.delayed(const Duration(seconds: 1), () async {
      debugPrint('🔄 Strategy 2: Early sync attempt after 1 second...');
      await _debugLocalNotifications(); // Debug what's in local storage
      await _syncPendingNotifications();
    });

    // Strategy 3: Standard retry sync (3 seconds)
    Future.delayed(const Duration(seconds: 3), () async {
      debugPrint('🔄 Strategy 3: Standard sync attempt after 3 seconds...');
      await _debugLocalNotifications(); // Debug what's in local storage
      await _syncPendingNotifications();
    });

    // Strategy 4: Extended retry (8 seconds)
    Future.delayed(const Duration(seconds: 8), () async {
      debugPrint('🔄 Strategy 4: Extended sync attempt after 8 seconds...');
      await _debugLocalNotifications(); // Debug what's in local storage
      await _syncPendingNotifications();
    });

    // Strategy 5: Final fallback (15 seconds)
    Future.delayed(const Duration(seconds: 15), () async {
      debugPrint('🔄 Strategy 5: Final fallback sync after 15 seconds...');
      await _debugLocalNotifications(); // Debug what's in local storage
      await _syncPendingNotifications();
    });

    // Strategy 6: Periodic sync every 30 seconds for the first 2 minutes
    for (int i = 1; i <= 4; i++) {
      Future.delayed(Duration(seconds: 30 * i), () async {
        debugPrint('🔄 Strategy 6.$i: Periodic sync at ${30 * i} seconds...');
        await _debugLocalNotifications();
        await _syncPendingNotifications();
      });
    }
  }

  void _handleAppLink(Uri uri) {
    print('🔗 Deep link received: $uri');
    print('🔗 URI scheme: ${uri.scheme}');
    print('🔗 URI host: ${uri.host}');
    print('🔗 URI path: ${uri.path}');
    print('🔗 URI query: ${uri.queryParameters}');
    print('🔗 URI fragment: ${uri.fragment}');

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
        print('Code parameter found: $token');
      }

      // Check for token parameter (alternative approach)
      if (token == null && uri.queryParameters.containsKey('token')) {
        token = uri.queryParameters['token'];
        print('Token parameter found: $token');
      }

      // Check for access_token in fragment (Supabase often uses this)
      if (token == null && uri.fragment.isNotEmpty) {
        final fragmentParams = Uri.splitQueryString(uri.fragment);
        if (fragmentParams.containsKey('access_token')) {
          token = fragmentParams['access_token'];
          print('Access token found in fragment: $token');
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
          print('6-digit PIN extracted from URL: $token');
        } else {
          // Look for code= parameter in the full URL
          final codeRegExp = RegExp(r'code=([^&]+)');
          final codeMatch = codeRegExp.firstMatch(fullUrl);
          if (codeMatch != null && codeMatch.groupCount >= 1) {
            token = codeMatch.group(1);
            print('Code extracted from URL: $token');
          }
        }
      }

      // Extract email from query parameters
      if (uri.queryParameters.containsKey('email')) {
        email = uri.queryParameters['email'];
        print('Email parameter found: $email');
      }

      // If we have a token, navigate to reset password screen
      if (token != null) {
        print('Navigating to verification screen with token: $token');

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
        '/device-setup-wizard': (context) => const DeviceSetupWizardScreen(),
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
      debugPrint('🔄 FCM token refreshed: $newToken');
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
        try {
          final stored = await _storeAnxietyAlertNotification(
              message.notification, message.data);
          debugPrint(
              '🧾 Stored tapped anxiety alert from OS notification: $stored');
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
            debugPrint('🔴 Critical alert → Direct help modal (auto-confirmed)');
            // For critical alerts, directly show help modal without confirmation
            await _showCriticalAlertHelpModal(
              notificationTitle: message.notification?.title ?? 'Critical Anxiety Alert',
              notificationMessage: message.notification?.body ?? 'Critical anxiety level detected.',
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
                notificationTitle: initialMsg.notification?.title ?? 'Critical Anxiety Alert',
                notificationMessage: initialMsg.notification?.body ?? 'Critical anxiety level detected.',
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

/// Store anxiety alert notification in Supabase for notifications screen display
Future<bool> _storeAnxietyAlertNotification(
    RemoteNotification? notification, Map<String, dynamic> data) async {
  try {
    final supabaseService = SupabaseService();

    // Extract information from FCM data
    final severity = data['severity'] ?? 'unknown';
    final heartRate = data['heartRate'] ?? 'N/A';
    final baseline = data['baseline'];

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

    await supabaseService.createNotification(
      title: title,
      message: body,
      type: 'alert',
      relatedScreen:
          'notifications', // Changed to match where user gets redirected
      relatedId: data['notificationId'],
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
    await supabaseService.createNotification(
      title: title,
      message: body,
      type: 'reminder',
      relatedScreen: relatedScreen,
      relatedId: data['timestamp']?.toString(),
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
    await supabaseService.createNotification(
      title: title,
      message: body,
      type: 'reminder',
      relatedScreen: 'breathing_screen',
      relatedId: data['timestamp']?.toString(),
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
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      notificationProvider.triggerNotificationRefresh();
      debugPrint(
          '✅ Triggered notification refresh in home screen successfully');

      // Also trigger additional refreshes with delays to ensure UI updates
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          notificationProvider.triggerNotificationRefresh();
          debugPrint('✅ Triggered delayed notification refresh (500ms)');
        } catch (e) {
          debugPrint('⚠️ Delayed refresh failed: $e');
        }
      });

      Future.delayed(const Duration(seconds: 1), () {
        try {
          notificationProvider.triggerNotificationRefresh();
          debugPrint('✅ Triggered delayed notification refresh (1s)');
        } catch (e) {
          debugPrint('⚠️ Delayed refresh (1s) failed: $e');
        }
      });
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
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            ),
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
                        'Critical Alert - We\'re Here to Help',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Critical anxiety level detected. Here are immediate resources:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[600],
                        ),
                        textAlign: TextAlign.center,
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

                        // Emergency Contact Section
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.phone_in_talk, color: Colors.red[700], size: 20),
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
                              if (emergencyContact != null && emergencyContact.trim().isNotEmpty) ...[
                                _buildContactChip(
                                  label: 'Your Emergency Contact',
                                  number: emergencyContact.trim(),
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
                            // Emergency Call 911 Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    // Method 1: Try direct Android intent for dialer
                                    final dialerUri = Uri(scheme: 'tel', path: '911');
                                    if (await canLaunchUrl(dialerUri)) {
                                      await launchUrl(dialerUri, mode: LaunchMode.externalApplication);
                                    } else {
                                      // Method 2: Try alternative dialer intent
                                      const platform = MethodChannel('anxieease.dev/emergency');
                                      try {
                                        await platform.invokeMethod('makeEmergencyCall', {'number': '911'});
                                      } catch (platformError) {
                                        // Method 3: Show manual dial instructions
                                        if (context.mounted) {
                                          showDialog(
                                            context: dialogContext,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Emergency Call'),
                                              content: const Text(
                                                'Please manually dial 911 on your phone\'s keypad.\n\n'
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
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please manually dial 911'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.emergency, color: Colors.white, size: 20),
                                label: const Text('Emergency Call 911'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                                  Navigator.pop(dialogContext);
                                  rootNavigatorKey.currentState?.pushNamed('/breathing');
                                },
                                icon: const Icon(Icons.air, color: Colors.white),
                                label: const Text('Breathing Exercise'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                                  Navigator.pop(dialogContext);
                                  rootNavigatorKey.currentState?.pushNamed('/grounding');
                                },
                                icon: const Icon(Icons.self_improvement, color: Colors.white),
                                label: const Text('Grounding Technique'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                                  Navigator.pop(dialogContext);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SearchScreen(),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.local_hospital, color: Colors.red[700]),
                                label: const Text('Find Nearest Clinic'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red[700],
                                  side: BorderSide(color: Colors.red[700]!),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Close Button
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text(
                                'Close',
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
          response: 'CONFIRMED_CRITICAL', // Confirmed as critical anxiety attack
          severity: 'critical', // severity level
        );
        debugPrint('✅ Critical alert automatically marked as confirmed anxiety attack in database');
      } catch (e) {
        debugPrint('❌ Error marking critical alert as confirmed: $e');
      }
    } else {
      debugPrint('⚠️ No notification ID provided for critical alert confirmation');
    }
  } catch (e) {
    debugPrint('❌ Error showing critical alert help modal: $e');
  }
}

/// Helper function to build contact chip (copied from notifications_screen.dart)
Widget _buildContactChip({
  required String label,
  required String number,
  required Color color,
}) {
  return GestureDetector(
    onTap: () async {
      try {
        final Uri phoneUri = Uri(scheme: 'tel', path: number);
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Could not launch $phoneUri');
        }
      } catch (e) {
        debugPrint('Error launching phone call: $e');
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                number,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
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

    // Only subscribe to anxiety_alerts once per installation
    bool subscribedToAnxiety =
        prefs.getBool('subscribed_anxiety_alerts') ?? false;
    if (!subscribedToAnxiety) {
      await FirebaseMessaging.instance.subscribeToTopic('anxiety_alerts');
      await prefs.setBool('subscribed_anxiety_alerts', true);
      debugPrint('✅ First-time subscription to anxiety_alerts topic');
    } else {
      debugPrint('ℹ️ Already subscribed to anxiety_alerts topic');
    }

    // Only subscribe to wellness_reminders once per installation
    bool subscribedToWellness =
        prefs.getBool('subscribed_wellness_reminders') ?? false;
    if (!subscribedToWellness) {
      await FirebaseMessaging.instance.subscribeToTopic('wellness_reminders');
      await prefs.setBool('subscribed_wellness_reminders', true);
      debugPrint('✅ First-time subscription to wellness_reminders topic');
    } else {
      debugPrint('ℹ️ Already subscribed to wellness_reminders topic');
    }
  } catch (e) {
    debugPrint('❌ Failed to manage FCM topic subscriptions: $e');
  }
}

// Get fresh FCM token and store it
Future<void> _refreshAndStoreToken() async {
  try {
    // Force token refresh to get the latest token
    await FirebaseMessaging.instance.deleteToken();
    final token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
      debugPrint('🔑 Fresh FCM registration token: $token');
      await _storeTokenAtAssignmentLevel(token);
    } else {
      debugPrint('⚠️ FCM token is null after refresh');
    }
  } catch (e) {
    debugPrint('❌ Error refreshing FCM token: $e');
  }
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

// Store user-level FCM token for wellness notifications and general app notifications
Future<void> _storeUserLevelFCMToken(String token) async {
  try {
    final supabaseService = SupabaseService();
    final user = supabaseService.client.auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ No authenticated user for FCM token storage');
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
Future<void> _syncPendingNotifications() async {
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
      // Don't trigger UI refresh if no notifications - reduces aggressive refreshing
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
          final title = notificationData['title'] ?? 'Anxiety Alert';
          final message = notificationData['body'] ??
              notificationData['message'] ??
              'Please check your status.';
          final severity = notificationData['severity'] ?? 'unknown';
          final timestamp =
              notificationData['timestamp'] ?? DateTime.now().toIso8601String();
          final heartRate = notificationData['heartRate'] ?? '';
          final baseline = notificationData['baseline'] ?? '';
          final duration = notificationData['duration'] ?? '';
          final reason = notificationData['reason'] ?? '';

          debugPrint('💾 Syncing enhanced notification:');
          debugPrint('   Title: $title');
          debugPrint('   Message: $message');
          debugPrint('   Severity: $severity');
          debugPrint('   Heart Rate: $heartRate');
          debugPrint('   Baseline: $baseline');
          debugPrint('   Duration: $duration');
          debugPrint('   Reason: $reason');
          debugPrint('   Timestamp: $timestamp');

          // Store in Supabase with enhanced information in the message
          final enhancedMessage = message +
              (heartRate.isNotEmpty ? " | HR: ${heartRate} BPM" : "") +
              (baseline.isNotEmpty ? " (Baseline: ${baseline} BPM)" : "") +
              (duration.isNotEmpty ? " for ${duration}s" : "") +
              (reason.isNotEmpty ? " | ${reason}" : "");

          await supabaseService.createNotification(
            title: title,
            message: enhancedMessage,
            type: 'alert',
            relatedScreen: 'notifications',
            relatedId:
                'bg_${severity}_${DateTime.now().millisecondsSinceEpoch}',
          );

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

/// Clear old background notification markers (for cleanup)
Future<void> _clearOldBackgroundMarkers() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final backgroundKeys = allKeys
        .where((key) => key.startsWith('last_background_notification_'))
        .toList();

    debugPrint(
        '🧹 Clearing ${backgroundKeys.length} old background notification markers');

    for (final key in backgroundKeys) {
      await prefs.remove(key);
      debugPrint('   ✅ Cleared: $key');
    }

    debugPrint('✅ All old background markers cleared');
  } catch (e) {
    debugPrint('❌ Error clearing background markers: $e');
  }
}
