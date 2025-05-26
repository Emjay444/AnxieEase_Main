import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/severity_notifier.dart';
import 'reset_password.dart';
import 'verify_reset_code.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'splash_screen.dart';
import 'theme/app_theme.dart';
import 'screens/notifications_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Supabase
  await SupabaseService().initialize();

  // Clear only old notifications on app startup, preserve recent severity alerts
  await _clearNotificationsOnAppStartup();

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Request notification permissions
  final isAllowed = await notificationService.checkNotificationPermissions();
  if (!isAllowed) {
    await notificationService.requestNotificationPermissions();
  }

  // Initialize storage service
  await StorageService().init();

  // Initialize SeverityNotifier for anxiety alerts
  final severityNotifier = SeverityNotifier();

  // Start listening for Firebase data changes (but skip initial notifications)
  severityNotifier.initializeListener();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider.value(value: severityNotifier),
      ],
      child: const MyApp(),
    ),
  );
}

// Clear only old notifications on app startup, preserve recent severity alerts
Future<void> _clearNotificationsOnAppStartup() async {
  try {
    final supabaseService = SupabaseService();

    // Configuration: Set to true to enable automatic clearing of old notifications
    // Set to false to keep all notifications permanently
    const bool enableAutoClear =
        false; // Disabled by default to preserve severity alerts
    const int daysToKeep =
        7; // Keep notifications for 7 days (when auto-clear is enabled)

    if (!enableAutoClear) {
      debugPrint(
          '📱 Auto-clear disabled - preserving all notifications including severity alerts');
      return;
    }

    // Get all notifications
    final notifications = await supabaseService.getNotifications();

    if (notifications.isEmpty) {
      debugPrint('📱 No notifications to clear');
      return;
    }

    // Calculate cutoff time (7 days ago by default)
    final cutoffTime =
        DateTime.now().subtract(const Duration(days: daysToKeep));

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
        debugPrint(
            '⚠️ Error processing notification ${notification['id']}: $e');
      }
    }

    if (deletedCount > 0) {
      debugPrint(
          '🗑️ Cleared $deletedCount old notifications (older than $daysToKeep days)');
    }
    debugPrint(
        '📱 Preserved ${notifications.length - deletedCount} recent notifications');
  } catch (e) {
    debugPrint('❌ Error clearing old notifications on startup: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _initAppLinks();
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
    print('Handling deep link: $uri');
    print('URI path: ${uri.path}');
    print('URI query parameters: ${uri.queryParameters}');
    print('URI fragment: ${uri.fragment}');

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

    // Check for email verification
    if (uri.path == '/verify' || uri.path.contains('verify')) {
      print('Email verification path detected');
      String? token;
      String? email;

      // Check for token in query parameters
      if (uri.queryParameters.containsKey('token')) {
        token = uri.queryParameters['token'];
        print('Token parameter found: $token');
      }

      // Get email from parameters
      if (uri.queryParameters.containsKey('email')) {
        email = uri.queryParameters['email'];
        print('Email parameter found: $email');
      }

      // Check for type=signup_email in query parameters
      if (uri.queryParameters['type'] == 'signup_email') {
        print('Email verification link detected');

        // Update email verification status in database if email is available
        if (email != null) {
          _supabaseService.updateEmailVerificationStatus(email).then((_) {
            print('Updated email verification status for $email');
            // Navigate directly to login screen
            _navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/',
              (route) => false,
              arguments: {
                'message': 'Email verified successfully! Please log in.',
                'showLogin': true,
              },
            );
          }).catchError((e) {
            print('Error updating verification status: $e');
            // Still navigate to login even if update fails
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const AuthScreen(
                  message: 'Please try logging in with your credentials.',
                  showLogin: true,
                ),
              ),
              (route) => false,
            );
          });
        } else {
          // If no email is available, still navigate to login
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const AuthScreen(
                message: 'Please try logging in with your credentials.',
                showLogin: true,
              ),
            ),
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'AnxieEase',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const AuthScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/notifications': (context) => const NotificationsScreen(),
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
