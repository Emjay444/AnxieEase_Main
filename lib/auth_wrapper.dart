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
        debugPrint(
            '🔍 AuthWrapper - isInitialized: ${authProvider.isInitialized}');
        debugPrint(
            '🔍 AuthWrapper - isAuthenticated: ${authProvider.isAuthenticated}');
        debugPrint(
            '🔍 AuthWrapper - currentUser: ${authProvider.currentUser?.firstName ?? 'null'}');
        debugPrint('🔍 AuthWrapper - isLoading: ${authProvider.isLoading}');

        // Show loading indicator ONLY during initial auth/session restoration
        // Do NOT gate on isLoading here to avoid resetting the auth screens
        // while the user is interacting with Login/Register flows.
        if (!authProvider.isInitialized) {
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
        // BUT WAIT for currentUser to be loaded to avoid showing "Guest"
        if (authProvider.isAuthenticated) {
          // Check if we have user profile data loaded
          if (authProvider.currentUser != null) {
            debugPrint(
                '✅ AuthWrapper - User authenticated with profile data, showing HomePage');
            return const HomePage();
          } else {
            // User is authenticated but profile data is still loading
            debugPrint(
                '⏳ AuthWrapper - User authenticated but profile loading, showing loading screen');
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
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Loading your profile...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Add retry button in case loading takes too long
                      ElevatedButton(
                        onPressed: () async {
                          debugPrint('🔄 Manual retry requested by user');
                          await authProvider.loadUserProfile();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2D9254),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }

        // If user is not authenticated, show the authentication screens
        debugPrint(
            '❌ AuthWrapper - User not authenticated, showing AuthScreen');
        return const AuthScreen();
      },
    );
  }
}
