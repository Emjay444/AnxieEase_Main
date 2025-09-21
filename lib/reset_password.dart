import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'forgotpass.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;
  final String? email;
  final String? errorMessage;

  const ResetPasswordScreen(
      {super.key, this.token, this.email, this.errorMessage});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _tokenExpired = false;

  @override
  void initState() {
    super.initState();
    if (widget.token != null) {
      print('Reset password screen initialized with token: ${widget.token}');
      if (widget.email != null) {
        print('Reset password screen initialized with email: ${widget.email}');
      }
    }

    // Set error message if provided
    if (widget.errorMessage != null) {
      setState(() {
        _errorMessage = widget.errorMessage;
        // Check if the error message indicates token expiration
        if (widget.errorMessage!.contains('expired') ||
            widget.errorMessage!.contains('invalid')) {
          _tokenExpired = true;
        }
      });
    }
  }

  Future<void> _updatePassword() async {
    if (_passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    // Enhanced password validation
    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters long';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // If we have a token from the reset password link or verification code
      if (widget.token != null) {
        try {
          print(
              'Attempting to update password with recovery token: ${widget.token}');

          // Use our updated method to handle token reset
          await SupabaseService()
              .updatePasswordWithToken(_passwordController.text);

          setState(() {
            _isSuccess = true;
          });

          // Ensure we clear any existing session and return to AuthWrapper
          try {
            await SupabaseService().signOut();
            print('Signed out after password reset to return to login');
          } catch (_) {}

          // Brief success pause then navigate to root so AuthWrapper takes over
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false,
            );
          }
        } catch (e) {
          print('Error updating password: $e');

          if (e.toString().contains('expired') ||
              e.toString().contains('invalid') ||
              e.toString().contains('otp_expired')) {
            setState(() {
              _errorMessage =
                  'Your reset link has expired. Please request a new one.';
              _tokenExpired = true;
            });
          } else {
            setState(() {
              _errorMessage = 'Failed to update password: ${e.toString()}';
            });
          }
        }
      } else {
        setState(() {
          _errorMessage =
              'No valid reset token found. Please request a new password reset.';
          _tokenExpired = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update password. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Navigate to forgot password screen to request a new reset link
  void _requestNewResetLink() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const Forgotpass(),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: size.height * 0.05),

              // App Logo
              Container(
                height: 130,
                width: 130,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF3AA772).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/images/greenribbon.png',
                    height: 80,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Reset Password Text
              const Text(
                "Reset Password",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3AA772),
                  fontFamily: 'Poppins',
                ),
              ),

              const SizedBox(height: 10),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  widget.errorMessage != null || _tokenExpired
                      ? "Please request a new password reset link"
                      : "Create a new password for your account",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Main Content Container
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isSuccess)
                      Container(
                        padding: const EdgeInsets.all(15),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3AA772).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF3AA772)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Password updated successfully! Redirecting to login...',
                                style: TextStyle(color: Color(0xFF3AA772)),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Error message display
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(15),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _tokenExpired
                                        ? 'Password Reset Link Expired'
                                        : 'Error',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  if (_tokenExpired)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        'For security reasons, password reset links expire after a short time. Please request a new link using the button below.',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // If token expired, show a button to request a new reset link
                    if (_tokenExpired)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: ElevatedButton(
                          onPressed: _requestNewResetLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3AA772),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "Request New Reset Link",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Show password fields only if no error message from link expiration
                    if (widget.errorMessage == null && !_tokenExpired) ...[
                      // New Password Field
                      const Text(
                        "New Password",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: "Enter new password",
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF3AA772),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        style: const TextStyle(color: Colors.black87),
                        enabled: !_isLoading && !_isSuccess,
                      ),

                      const SizedBox(height: 20),

                      // Confirm Password Field
                      const Text(
                        "Confirm Password",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          hintText: "Confirm new password",
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF3AA772),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        style: const TextStyle(color: Colors.black87),
                        enabled: !_isLoading && !_isSuccess,
                      ),

                      const SizedBox(height: 30),

                      // Update Password Button
                      ElevatedButton(
                        onPressed:
                            _isLoading || _isSuccess ? null : _updatePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3AA772),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isSuccess
                                    ? "Password Updated"
                                    : "Update Password",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ] else ...[
                      // Request New Link Button
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const Forgotpass(),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3AA772),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Request New Reset Code",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Back to Login
                    if (!_isSuccess)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/', // This will go to AuthWrapper, which will show login for unauthenticated users
                            (route) => false,
                          );
                        },
                        child: const Text(
                          "Back to Login",
                          style: TextStyle(
                            color: Color(0xFF3AA772),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
