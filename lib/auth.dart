import 'package:flutter/material.dart';
import 'login.dart';
import 'register.dart';

class AuthScreen extends StatefulWidget {
  final String? message;
  final bool showLogin;

  const AuthScreen({
    super.key,
    this.message,
    this.showLogin = true,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool isLogin;

  @override
  void initState() {
    super.initState();
    isLogin = widget.showLogin;
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope intercepts the back button press
    return WillPopScope(
      onWillPop: () async {
        // If we're in the registration screen
        if (!isLogin) {
          // Switch to login screen instead of exiting the app
          setState(() {
            isLogin = true;
          });
          return false; // Prevent default back button behavior
        }
        // In login screen, allow normal back button behavior
        return true;
      },
      child: isLogin
      ? LoginScreen(
              onSwitch: () {
                setState(() {
                  isLogin = false;
                });
        },
        message: widget.message,
            )
          : RegisterScreen(
              onSwitch: () {
                setState(() {
                  isLogin = true;
                });
              },
            ),
    );
  }
}
