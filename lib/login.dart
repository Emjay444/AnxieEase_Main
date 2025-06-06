import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Import for Timer
import 'homepage.dart';
import 'forgotpass.dart';
import 'providers/auth_provider.dart';
import 'utils/logger.dart';
import 'services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onSwitch;

  const LoginScreen({
    super.key,
    required this.onSwitch,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // For storage service
  final StorageService _storageService = StorageService();

  // For validation
  final Map<String, String> _fieldErrors = {
    'email': '',
    'password': '',
  };

  // For account lockout
  int _failedLoginAttempts = 0;
  DateTime? _lockoutEndTime;

  // For debouncing email validation
  Timer? _emailDebounce;
  bool _emailFieldTouched = false;
  bool _isValidatingEmail = false;

  @override
  void initState() {
    super.initState();

    // Initialize storage service and load saved credentials
    _initStorageAndLoadCredentials();

    // Add listener for email validation with debounce
    emailController.addListener(() {
      // Mark the field as touched once the user starts typing
      if (emailController.text.isNotEmpty && !_emailFieldTouched) {
        _emailFieldTouched = true;
      }

      // Cancel previous debounce timer
      if (_emailDebounce?.isActive ?? false) {
        _emailDebounce!.cancel();
      }

      // Only validate after the user stops typing for 3 seconds
      _emailDebounce = Timer(const Duration(seconds: 3), () {
        Logger.debug(
            'Email validation triggered after 3 seconds for: ${emailController.text}');
        setState(() {
          _isValidatingEmail = true;
          if (emailController.text.isEmpty) {
            // Clear error when field is empty
            _fieldErrors['email'] = '';
            Logger.debug('Email field empty, cleared error');
          } else if (!_isValidEmail(emailController.text)) {
            // Show error for invalid email
            _fieldErrors['email'] = 'Invalid email address';
            Logger.debug('Invalid email, showing error');
          } else {
            // Clear error for valid email
            _fieldErrors['email'] = '';
            Logger.debug('Valid email, cleared error');
          }
          _isValidatingEmail = false;
        });
      });
    });

    // Add listener for password field
    passwordController.addListener(() {
      // We don't immediately clear errors when typing in password field
      // This allows validation errors to remain visible
    });
  }

  // Initialize storage and load credentials
  Future<void> _initStorageAndLoadCredentials() async {
    try {
      await _storageService.init();

      // Get remember me status
      _rememberMe = await _storageService.getRememberMe();

      // If remember me is enabled, load credentials
      if (_rememberMe) {
        final savedCredentials = await _storageService.getSavedCredentials();

        if (savedCredentials['email'] != null) {
          emailController.text = savedCredentials['email']!;
          _emailFieldTouched = true;
        }

        if (savedCredentials['password'] != null) {
          passwordController.text = savedCredentials['password']!;
        }
      }

      // Update UI
      setState(() {});
    } catch (e) {
      Logger.error('Failed to load saved credentials', e);
    }
  }

  @override
  void dispose() {
    // Cancel any active timer
    _emailDebounce?.cancel();

    // Make sure to clean up controllers
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Validate email format
  bool _isValidEmail(String email) {
    final RegExp emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegExp.hasMatch(email);
  }

  void _submit(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Check if account is locked out
    if (_lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!)) {
      final remainingSeconds =
          _lockoutEndTime!.difference(DateTime.now()).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Too many failed attempts. Please try again in $remainingSeconds seconds.'),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Reset lockout if it has expired
    if (_lockoutEndTime != null && DateTime.now().isAfter(_lockoutEndTime!)) {
      setState(() {
        _failedLoginAttempts = 0;
        _lockoutEndTime = null;
      });
    }

    // Validate fields
    bool hasErrors = false;

    // Validate email
    if (emailController.text.isEmpty) {
      setState(() {
        _fieldErrors['email'] = 'Email is required';
      });
      hasErrors = true;
    } else if (!_isValidEmail(emailController.text)) {
      setState(() {
        _fieldErrors['email'] = 'Please enter a valid email address';
      });
      hasErrors = true;
    } else {
      setState(() {
        _fieldErrors['email'] = '';
      });
    }

    // Validate password
    if (passwordController.text.isEmpty) {
      setState(() {
        _fieldErrors['password'] = 'Password is required';
      });
      hasErrors = true;
    } else {
      setState(() {
        _fieldErrors['password'] = '';
      });
    }

    if (hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await authProvider.signIn(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // Reset failed login attempts on successful login
      setState(() {
        _failedLoginAttempts = 0;
        _lockoutEndTime = null;
      });

      // Save user session if "Remember Me" is checked
      if (_rememberMe) {
        await _storageService.setRememberMe(true);
        await _storageService.saveCredentials(
          emailController.text.trim(),
          passwordController.text,
        );
        Logger.debug('Credentials saved for "Remember Me"');
      } else {
        // Ensure "Remember Me" is turned off and credentials are cleared
        await _storageService.setRememberMe(false);
        Logger.debug('Remember Me disabled, credentials cleared');
      }

      if (!mounted) return;

      // Navigate without using WidgetsBinding.addPostFrameCallback to prevent double-click issue
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false, // Remove all previous routes
      );
    } catch (e) {
      if (!mounted) return;

      // Increment failed login attempts
      setState(() {
        _failedLoginAttempts++;

        // Lock account after 5 failed attempts
        if (_failedLoginAttempts >= 5) {
          _lockoutEndTime = DateTime.now().add(const Duration(seconds: 30));
        }
      });

      // Log the error for debugging
      Logger.error('Login error', e);

      String errorMessage;
      // Check for specific error messages from Supabase
      if (e.toString().contains('Invalid login credentials') ||
          e.toString().contains('Invalid email or password')) {
        errorMessage = 'Invalid email or password.';

        // Set field errors for visual indication and clear password
        setState(() {
          _fieldErrors['email'] = '';
          _fieldErrors['password'] = 'Invalid email or password.';
          passwordController.clear(); // Clear password field for security
        });
      } else if (e.toString().contains('verify your email')) {
        errorMessage =
            'Please verify your email before logging in. Check your inbox for the verification link.';
      } else if (e.toString().contains('rate limit')) {
        errorMessage = 'Too many login attempts. Please try again later.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        // For any other error, still show "Invalid email or password" for security reasons
        // when credentials are likely the issue
        errorMessage = 'Invalid email or password.';

        // Set field errors for visual indication and clear password
        setState(() {
          _fieldErrors['email'] = '';
          _fieldErrors['password'] = 'Invalid email or password.';
          passwordController.clear(); // Clear password field for security
        });
      }

      // Store context before the async gap
      final scaffoldContext = context;

      // Use WidgetsBinding to ensure we're not in the middle of a build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 6), // Increased duration
              backgroundColor: Colors.red,
              behavior:
                  SnackBarBehavior.floating, // Make it float above content
              margin: const EdgeInsets.all(10), // Add margin
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  if (mounted) {
                    ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
                  }
                },
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textFieldBgColor = isDark ? theme.cardColor : Colors.white;
    final textFieldTextColor = isDark ? Colors.white : Colors.black87;
    final textFieldHintColor = isDark ? Colors.white70 : Colors.grey[600];
    final iconColor = isDark ? Colors.white70 : Colors.grey[600];

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2D9254), Color(0xFF00382A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 60),

                    // App Logo
                    Container(
                      height: 130,
                      width: 130,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(38), // 0.15 opacity
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

                    const SizedBox(height: 40),

                    // Welcome Text
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withAlpha(204), // 0.8 opacity
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Email Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: textFieldBgColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              fontSize: 16,
                              color: textFieldTextColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Email',
                              hintStyle: TextStyle(
                                color: textFieldHintColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: iconColor,
                              ),
                              suffixIcon: _isValidatingEmail
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white.withAlpha(179),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : _fieldErrors['email']!.isNotEmpty
                                      ? const Icon(Icons.error_outline,
                                          color: Colors.red)
                                      : _emailFieldTouched
                                          ? const Icon(Icons.check_circle,
                                              color: Colors.green)
                                          : null,
                            ),
                          ),
                        ),
                        if (_fieldErrors['email']!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 8),
                            child: Text(
                              _fieldErrors['email']!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Password Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: textFieldBgColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(
                              fontSize: 16,
                              color: textFieldTextColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: TextStyle(
                                color: textFieldHintColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: iconColor,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: iconColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        if (_fieldErrors['password']!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 8),
                            child: Text(
                              _fieldErrors['password']!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Remember Me Checkbox and Forgot Password
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          checkColor: Colors.white,
                          fillColor: WidgetStateProperty.resolveWith<Color>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xFF3AA772);
                              }
                              return Colors.white.withAlpha(128); // 0.5 opacity
                            },
                          ),
                        ),
                        Text(
                          'Remember Me',
                          style: TextStyle(
                            color: Colors.white.withAlpha(204), // 0.8 opacity
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        // Forgot Password
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const Forgotpass()),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withAlpha(204), // 0.8 opacity
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading
                            ? null
                            : () => _submit(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF3AA772),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF3AA772),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Log In',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sign Up Link
                    TextButton(
                      onPressed: widget.onSwitch,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        "Don't have an account? Sign Up",
                        style: TextStyle(
                          color: Colors.white.withAlpha(204), // 0.8 opacity
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
