import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'widgets/notification_permission_dialog.dart';
import 'main.dart'; // Import to access the global servicesInitialized flag

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _permissionsChecked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkInitialization();
  }

  Future<void> _checkInitialization() async {
    debugPrint('🔄 SplashScreen - Starting initialization check...');

    // Check every 500ms if services are initialized
    while (!servicesInitialized) {
      debugPrint('🔄 SplashScreen - Waiting for services to initialize...');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }

    debugPrint('✅ SplashScreen - Services initialized!');

    // Once services are initialized, check permissions
    setState(() {
      _isLoading = false;
    });

    // Wait a bit to show the splash screen
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    debugPrint('🔄 SplashScreen - Checking notification permissions...');

    // Check if we've already asked for notification permissions
    final permissionStatus =
        await _notificationService.getSavedPermissionStatus();

    debugPrint('🔄 SplashScreen - Permission status: $permissionStatus');

    setState(() {
      _permissionsChecked = true;
    });

    if (permissionStatus == null) {
      // First time launch - show notification permission dialog
      debugPrint(
          '🔄 SplashScreen - First time launch, showing permission dialog');
      _showNotificationPermissionDialog();
    } else if (permissionStatus == false) {
      // Permission was previously denied - check if it's still denied
      debugPrint(
          '🔄 SplashScreen - Permission was denied, checking current status');
      final currentStatus =
          await _notificationService.checkNotificationPermissions();
      if (!currentStatus) {
        // Still denied - show settings redirect dialog
        debugPrint('🔄 SplashScreen - Still denied, showing settings dialog');
        _showNotificationSettingsRedirectDialog();
      } else {
        // Permission is now granted - proceed to auth screen
        debugPrint(
            '✅ SplashScreen - Permission now granted, navigating to auth');
        _navigateToAuthScreen();
      }
    } else {
      // Permission was previously granted - proceed to auth screen
      debugPrint(
          '✅ SplashScreen - Permission already granted, navigating to auth');
      _navigateToAuthScreen();
    }
  }

  void _showNotificationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NotificationPermissionDialog(
        onAllow: () async {
          Navigator.of(context).pop();
          final granted =
              await _notificationService.requestNotificationPermissions();
          if (granted) {
            // Test notification disabled - Cloud Functions handle all notifications
            // await _notificationService.showTestNotification();
          }
          _navigateToAuthScreen();
        },
        onDeny: () {
          Navigator.of(context).pop();
          _navigateToAuthScreen();
        },
      ),
    );
  }

  void _showNotificationSettingsRedirectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NotificationSettingsRedirectDialog(
        onOpenSettings: () async {
          Navigator.of(context).pop();
          await _notificationService.openNotificationSettings();
          _navigateToAuthScreen();
        },
        onCancel: () {
          Navigator.of(context).pop();
          _navigateToAuthScreen();
        },
      ),
    );
  }

  void _navigateToAuthScreen() {
    debugPrint('🚀 SplashScreen - Navigating to AuthWrapper...');
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2D9254), // Match login page dark green
              Color(0xFF00382A), // Match login page deep green
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/greenribbon.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),
              const Text(
                'AnxieEase',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              if (!_isLoading && !_permissionsChecked)
                const Text(
                  'Preparing your experience...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
