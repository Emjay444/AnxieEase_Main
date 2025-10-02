import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:provider/provider.dart';
import 'dart:async'; // Import for Timer
import 'forgotpass.dart';
import 'providers/auth_provider.dart';
import 'utils/logger.dart';
import 'services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onSwitch;
  final String? message;

  const LoginScreen({
    super.key,
    required this.onSwitch,
    this.message,
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

    // Show incoming message (e.g., after logout) once the Scaffold exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (widget.message?.isNotEmpty ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.message!),
            backgroundColor: const Color(0xFF2D9254),
          ),
        );
      }
    });

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

  // Track if we've already refreshed to avoid multiple calls
  bool _hasRefreshed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only refresh credentials on the first call to avoid clearing form multiple times
    if (!_hasRefreshed) {
      _hasRefreshed = true;
      // Refresh credentials whenever this screen becomes active
      // This handles cases where user signs out and comes back to login
      _refreshStoredCredentials();
    }
  }

  // Refresh stored credentials (called when screen becomes active)
  Future<void> _refreshStoredCredentials() async {
    try {
      debugPrint('🔄 LoginScreen - _refreshStoredCredentials() called');
      
      // Get remember me status
      final rememberMe = await _storageService.getRememberMe();
      debugPrint('🔍 LoginScreen - Current remember me status: $rememberMe');
      debugPrint('🔍 LoginScreen - Widget remember me status: $_rememberMe');
      
      // Update remember me status
      _rememberMe = rememberMe;
      
      if (_rememberMe) {
        // Load and display saved credentials
        debugPrint('💾 LoginScreen - Loading saved credentials...');
        final savedCredentials = await _storageService.getSavedCredentials();
        
        if (savedCredentials['email'] != null) {
          debugPrint('📧 LoginScreen - Setting email field to: ${savedCredentials['email']}');
          emailController.text = savedCredentials['email']!;
          _emailFieldTouched = true;
        } else {
          debugPrint('📧 LoginScreen - No saved email found');
        }
        
        if (savedCredentials['password'] != null) {
          debugPrint('🔒 LoginScreen - Setting password field (hidden)');
          passwordController.text = savedCredentials['password']!;
        } else {
          debugPrint('🔒 LoginScreen - No saved password found');
        }
      } else {
        debugPrint('❌ LoginScreen - Remember me is disabled, not loading credentials');
      }
      
      // Update UI
      if (mounted) {
        setState(() {});
        debugPrint('🔄 LoginScreen - UI updated');
      }
    } catch (e) {
      Logger.error('Failed to refresh stored credentials', e);
      debugPrint('❌ LoginScreen - Failed to refresh stored credentials: $e');
    }
  }

  // Initialize storage and load credentials
  Future<void> _initStorageAndLoadCredentials() async {
    try {
      debugPrint('🚀 LoginScreen - Initializing storage and loading credentials...');
      await _storageService.init();

      // Get remember me status
      _rememberMe = await _storageService.getRememberMe();
      debugPrint('🔍 LoginScreen - Initial remember me status: $_rememberMe');

      // If remember me is enabled, load credentials
      if (_rememberMe) {
        debugPrint('💾 LoginScreen - Remember me is enabled, loading credentials...');
        final savedCredentials = await _storageService.getSavedCredentials();

        if (savedCredentials['email'] != null) {
          emailController.text = savedCredentials['email']!;
          _emailFieldTouched = true;
          debugPrint('📧 LoginScreen - Email loaded: ${savedCredentials['email']}');
        } else {
          debugPrint('📧 LoginScreen - No saved email found');
        }

        if (savedCredentials['password'] != null) {
          passwordController.text = savedCredentials['password']!;
          debugPrint('🔒 LoginScreen - Password loaded (hidden)');
        } else {
          debugPrint('🔒 LoginScreen - No saved password found');
        }
      } else {
        debugPrint('❌ LoginScreen - Remember me is disabled, not loading credentials');
      }

      // Update UI
      setState(() {});
      debugPrint('✅ LoginScreen - Storage initialization complete');
    } catch (e) {
      Logger.error('Failed to load saved credentials', e);
      debugPrint('❌ LoginScreen - Failed to load saved credentials: $e');
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

    await _performLoginWithRetry(authProvider);
  }

  Future<void> _performLoginWithRetry(AuthProvider authProvider,
      {int attempt = 1, int maxAttempts = 3}) async {
    const retryableErrors = [
      'network',
      'timeout',
      'connection',
      'server error',
      'internal error',
      'service unavailable',
      'connection closed',
      'clientexception',
    ];

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
      // Save credentials BEFORE signing in to prevent navigation interruption
      debugPrint('🔍 LoginScreen - Checking Remember Me status before signing in...');
      debugPrint('🔍 LoginScreen - Widget _rememberMe: $_rememberMe');
      
      // Double-check the stored remember me preference
      final storedRememberMe = await _storageService.getRememberMe();
      debugPrint('🔍 LoginScreen - Stored remember me: $storedRememberMe');
      
      if (_rememberMe) {
        debugPrint('💾 LoginScreen - Remember me is checked, saving credentials NOW...');
        await _storageService.saveCredentials(
          emailController.text.trim(),
          passwordController.text,
        );
        Logger.debug('Credentials saved for "Remember Me" BEFORE sign in');
        debugPrint('✅ LoginScreen - Credentials saved successfully BEFORE sign in');
      } else {
        debugPrint('🧹 LoginScreen - Remember me is NOT checked, ensuring no credentials are saved...');
        // Note: setRememberMe(false) automatically clears credentials
        Logger.debug('Remember Me disabled, credentials cleared');
        debugPrint('✅ LoginScreen - Remember me disabled');
      }

      await authProvider.signIn(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // Reset failed login attempts on successful login
      setState(() {
        _failedLoginAttempts = 0;
        _lockoutEndTime = null;
      });

      if (!mounted) return;

      // The AuthWrapper will automatically handle navigation based on authentication state
      // No need to manually navigate to HomePage here
    } catch (e) {
      if (!mounted) return;

      String errorMessage = e.toString().toLowerCase();
      bool shouldRetry =
          retryableErrors.any((error) => errorMessage.contains(error));

      // If it's a retryable error and we haven't exceeded max attempts, retry automatically
      if (shouldRetry && attempt < maxAttempts) {
        debugPrint('🔄 Login attempt $attempt failed with retryable error: $e');
        debugPrint(
            '⏳ Auto-retrying in ${attempt} seconds... (Attempt ${attempt + 1}/$maxAttempts)');

        // Show a brief message about auto-retry
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Connection issue detected. Auto-retrying... (${attempt + 1}/$maxAttempts)'),
            duration: Duration(seconds: attempt),
            backgroundColor: Colors.orange,
          ),
        );

        // Wait with exponential backoff
        await Future.delayed(Duration(seconds: attempt));

        if (mounted) {
          await _performLoginWithRetry(authProvider,
              attempt: attempt + 1, maxAttempts: maxAttempts);
        }
        return;
      }

      // For non-retryable errors or when max attempts reached, handle normally
      setState(() {
        _failedLoginAttempts++;

        // Lock account after 5 failed attempts
        if (_failedLoginAttempts >= 5) {
          _lockoutEndTime = DateTime.now().add(const Duration(seconds: 30));
        }
      });

      // Log the error for debugging
      Logger.error('Login error', e);

      String displayErrorMessage;
      // Check for specific error messages from Supabase
      if (e.toString().contains('Invalid login credentials') ||
          e.toString().contains('Invalid email or password')) {
        displayErrorMessage = 'Invalid email or password.';

        // Set field errors for visual indication and clear password
        setState(() {
          _fieldErrors['email'] = '';
          _fieldErrors['password'] = 'Invalid email or password.';
          passwordController.clear(); // Clear password field for security
        });
      } else if (e.toString().contains('verify your email')) {
        displayErrorMessage =
            'Please verify your email before logging in. Check your inbox for the verification link.';
      } else if (e.toString().contains('rate limit')) {
        displayErrorMessage =
            'Too many login attempts. Please try again later.';
      } else if (shouldRetry && attempt >= maxAttempts) {
        displayErrorMessage =
            'Connection failed after $maxAttempts attempts. Please check your internet and try again.';
      } else if (errorMessage.contains('network')) {
        displayErrorMessage =
            'Network error. Please check your internet connection.';
      } else {
        // For any other error, still show "Invalid email or password" for security reasons
        // when credentials are likely the issue
        displayErrorMessage = 'Invalid email or password.';

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
              content: Text(displayErrorMessage),
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
                              debugPrint('🔘 LoginScreen - Remember Me checkbox changed to: $_rememberMe');
                            });
                            // Save the Remember Me preference immediately when checkbox changes
                            _storageService.setRememberMe(_rememberMe).then((_) {
                              debugPrint('💾 LoginScreen - Remember Me preference saved to storage: $_rememberMe');
                            }).catchError((e) {
                              debugPrint('❌ LoginScreen - Failed to save Remember Me preference: $e');
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
                                'Sign In',
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
