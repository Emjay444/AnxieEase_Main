import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'homepage.dart';
import 'auth.dart';

/// AuthWrapper determines whether to show the authenticated app (HomePage)
/// or the authentication screens based on the user's login status.
/// This enables persistent login behavior similar to Facebook.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        debugPrint('🔍 AuthWrapper - isInitialized: ${authProvider.isInitialized}');
        debugPrint(
            '🔍 AuthWrapper - isAuthenticated: ${authProvider.isAuthenticated}');
        debugPrint(
            '🔍 AuthWrapper - currentUser: ${authProvider.currentUser?.firstName ?? 'null'}');
        debugPrint('🔍 AuthWrapper - isLoading: ${authProvider.isLoading}');

        // Show loading indicator while initializing OR while loading user data
        if (!authProvider.isInitialized || authProvider.isLoading) {
          debugPrint('🔄 AuthWrapper - Still initializing or loading...');
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
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading...',
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

        // If user is authenticated, show the main app (HomePage)
        // Don't require currentUser to be loaded - isAuthenticated should be enough
        if (authProvider.isAuthenticated) {
          debugPrint('✅ AuthWrapper - User authenticated, showing HomePage');
          return const HomePage();
        }

        // If user is not authenticated, show the authentication screens
        debugPrint('❌ AuthWrapper - User not authenticated, showing AuthScreen');
        return const AuthScreen();
      },
    );
  }
}
