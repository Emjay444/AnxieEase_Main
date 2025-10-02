import 'package:flutter/material.dart';
import 'main.dart'; // Access servicesInitializedCompleter
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _permissionsChecked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkInitialization();
  }

  Future<void> _checkInitialization() async {
    debugPrint('🔄 SplashScreen - Starting initialization check...');

    // Await the global completer instead of actively polling to reduce main thread work
    if (!servicesInitializedCompleter.isCompleted) {
      debugPrint('🔄 SplashScreen - Awaiting services initialization...');
      try {
        await servicesInitializedCompleter.future
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        debugPrint('⚠️ SplashScreen - Initialization timeout, continuing');
      }
      if (!mounted) return;
    }

    debugPrint('✅ SplashScreen - Services initialized!');

    // Once services are initialized, show the splash screen briefly
    setState(() {
      _isLoading = false;
    });

    // Wait a bit longer to show the splash screen since no permission dialogs
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    debugPrint('🔄 SplashScreen - Permissions already handled in main.dart...');

    setState(() {
      _permissionsChecked = true;
    });

    // Navigate to auth screen (permissions are handled in main.dart before this)
    _navigateToAuthScreen();
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
