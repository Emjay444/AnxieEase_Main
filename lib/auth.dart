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

  void _switchToRegister() {
    setState(() {
      isLogin = false;
    });
  }

  void _switchToLogin() {
    setState(() {
      isLogin = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope intercepts the back button press
    return WillPopScope(
      onWillPop: () async {
        // If we're in the registration screen
        if (!isLogin) {
          // Switch to login screen instead of exiting the app
          _switchToLogin();
          return false; // Prevent default back button behavior
        }
        // In login screen, allow normal back button behavior
        return true;
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (Widget child, Animation<double> animation) {
          // Modern fade + scale + slight slide transition
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.95,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.05),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            ),
          );
        },
        child: isLogin
            ? LoginScreen(
                key: const ValueKey('login'),
                onSwitch: _switchToRegister,
                message: widget.message,
              )
            : RegisterScreen(
                key: const ValueKey('register'),
                onSwitch: _switchToLogin,
              ),
      ),
    );
  }
}
