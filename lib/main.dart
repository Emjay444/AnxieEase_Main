import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth.dart';
import 'auth_wrapper.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/iot_sensor_service.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'grounding_screen.dart';
import 'screens/device_linking_screen.dart';
import 'screens/device_setup_wizard_screen.dart';
import 'screens/baseline_recording_screen.dart';
import 'screens/health_dashboard_screen.dart';

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
  final payload = receivedAction.payload;
  if (payload != null &&
      payload['type'] == 'reminder' &&
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

    // Request notification permissions
    final isAllowed = await notificationService.checkNotificationPermissions();
    if (!isAllowed) {
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

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  // Use global navigator key so services/handlers can navigate safely
  final _navigatorKey = rootNavigatorKey;
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _initAppLinks();
    // Profile first frame scheduling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      debugPrint('🕒 First frame rendered at: ' + now.toIso8601String());
    });
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
  final isAlert = title.contains('Alert') || title.contains('🚨') || title.contains('anxiety');
  final isWellness = title.contains('Wellness') || title.contains('💙') || title.contains('Check');
  final isBreathing = title.contains('Breathing') || title.contains('🫁') || title.contains('🌬️');
  
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
                              padding: const EdgeInsets.symmetric(horizontal: 16),
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

    // Get and log the FCM token (copy from logs to use in test_fcm.dart)
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      debugPrint('🔑 FCM registration token: $token');

      // Store FCM token in Firebase for Cloud Functions to use
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await FirebaseDatabase.instance
              .ref('/users/$userId/fcmToken')
              .set(token);
          debugPrint('✅ FCM token stored in Firebase for user: $userId');
        } else {
          debugPrint('⚠️ No current Supabase user found, FCM token not stored');
        }
      } catch (e) {
        debugPrint('❌ Failed to store FCM token: $e');
      }

      // Subscribe to topics only once per installation
      await _subscribeToTopicsOnce();
    } else {
      debugPrint(
          '⚠️ FCM token is null (auto-init or Google services not ready yet)');
    }

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
        if (messageType == 'reminder' &&
            (notification?.title?.contains('Breathing Exercise') == true ||
                notification?.title?.contains('🫁') == true ||
                data['related_screen'] == 'breathing_screen')) {
          // Handle breathing exercise reminder
          debugPrint('🫁 Breathing exercise reminder FCM received');

          // Inline banner for instant feedback
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

          // Also post a system notification as a fallback
          final notificationService = NotificationService();
          await notificationService.initialize();
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
              channelKey: 'wellness_reminders',
              title: notification?.title ?? '🫁 Breathing Exercise Reminder',
              body: notification?.body ??
                  'Time for a breathing exercise! Take a moment to relax and breathe.',
              notificationLayout: NotificationLayout.Default,
              category: NotificationCategory.Reminder,
            ),
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

          // Inline banner for instant feedback
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

          // Also post a system notification as a fallback
          final notificationService = NotificationService();
          await notificationService.initialize();
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
              channelKey: 'wellness_reminders',
              title: notification?.title ?? 'Wellness Reminder',
              body: notification?.body ??
                  'Take a moment to check how you\'re feeling.',
              notificationLayout: NotificationLayout.Default,
              category: NotificationCategory.Reminder,
            ),
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
              rootNavigatorKey.currentState?.pushNamed('/notifications');
            },
          );

          // IMPORTANT: Store anxiety alert in Supabase for notifications screen
          debugPrint('📱 Attempting to store anxiety alert notification...');
          final stored = await _storeAnxietyAlertNotification(notification, data);
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
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Notification tap opened app. Data: ${message.data}');

      // Handle navigation based on message type
      final messageType = message.data['type'] ?? '';
      final relatedScreen = message.data['related_screen'] ?? '';

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
            rootNavigatorKey.currentState?.pushNamed('/notifications');
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
            debugPrint('🔴 Critical alert → Notifications with urgent context');
            rootNavigatorKey.currentState?.pushNamed('/notifications');
            break;
          default:
            debugPrint('⚠️ Unknown severity → Default notifications screen');
            rootNavigatorKey.currentState?.pushNamed('/notifications');
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

      // Handle navigation based on message type when app launches from notification
      final messageType = initialMsg.data['type'] ?? '';
      final relatedScreen = initialMsg.data['related_screen'] ?? '';

      // Use a slight delay to ensure the app is fully initialized
      Future.delayed(const Duration(milliseconds: 500), () {
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
              rootNavigatorKey.currentState?.pushNamed('/notifications');
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
              debugPrint('🔴 Critical alert launch → Notifications with urgent context');
              rootNavigatorKey.currentState?.pushNamed('/notifications');
              break;
            default:
              debugPrint('⚠️ Unknown severity launch → Default notifications screen');
              rootNavigatorKey.currentState?.pushNamed('/notifications');
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
      relatedScreen: 'notifications', // Changed to match where user gets redirected
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
  try {
    // Get the current context from the navigator
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      // Find the NotificationProvider and trigger refresh
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      notificationProvider.triggerNotificationRefresh();
      debugPrint('✅ Triggered notification refresh in home screen');
    }
  } catch (e) {
    debugPrint('❌ Error triggering notification refresh: $e');
    // Don't rethrow - this is a UI update and shouldn't break notification storage
  }
}

// Subscribe to FCM topics only once per installation
Future<void> _subscribeToTopicsOnce() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Only subscribe to anxiety_alerts once per installation
    bool subscribedToAnxiety = prefs.getBool('subscribed_anxiety_alerts') ?? false;
    if (!subscribedToAnxiety) {
      await FirebaseMessaging.instance.subscribeToTopic('anxiety_alerts');
      await prefs.setBool('subscribed_anxiety_alerts', true);
      debugPrint('✅ First-time subscription to anxiety_alerts topic');
    } else {
      debugPrint('ℹ️ Already subscribed to anxiety_alerts topic');
    }
    
    // Only subscribe to wellness_reminders once per installation  
    bool subscribedToWellness = prefs.getBool('subscribed_wellness_reminders') ?? false;
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
