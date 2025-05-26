import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onSwitch;

  const RegisterScreen({super.key, required this.onSwitch});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Form validation
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _fieldErrors = {
    'firstName': '',
    'middleName': '',
    'lastName': '',
    'email': '',
    'password': '',
    'confirmPassword': '',
    'terms': '',
  };

  // Track if form has been submitted to only show errors after submission attempt
  bool _formSubmitted = false;

  bool agreeToTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();

    // Add listeners to name field controllers to validate input in real-time
    firstNameController.addListener(() {
      if (firstNameController.text.isNotEmpty) {
        setState(() {
          if (!_isValidName(firstNameController.text)) {
            _fieldErrors['firstName'] =
                'Numbers and special characters are not allowed';
          } else {
            _fieldErrors['firstName'] = '';
          }
        });
      }
    });

    middleNameController.addListener(() {
      if (middleNameController.text.isNotEmpty) {
        setState(() {
          if (!_isValidName(middleNameController.text)) {
            _fieldErrors['middleName'] =
                'Numbers and special characters are not allowed';
          } else {
            _fieldErrors['middleName'] = '';
          }
        });
      }
    });

    lastNameController.addListener(() {
      if (lastNameController.text.isNotEmpty) {
        setState(() {
          if (!_isValidName(lastNameController.text)) {
            _fieldErrors['lastName'] =
                'Numbers and special characters are not allowed';
          } else {
            _fieldErrors['lastName'] = '';
          }
        });
      }
    });

    // Add listener for email validation
    emailController.addListener(() {
      if (emailController.text.isNotEmpty) {
        setState(() {
          if (!_isValidEmail(emailController.text)) {
            _fieldErrors['email'] = 'Please enter a valid email address';
          } else {
            _fieldErrors['email'] = '';
          }
        });
      }
    });

    // Add listener for password validation
    passwordController.addListener(() {
      if (passwordController.text.isNotEmpty) {
        setState(() {
          if (passwordController.text.length < 6) {
            _fieldErrors['password'] = 'Password must be at least 6 characters';
          } else {
            _fieldErrors['password'] = '';
          }

          // Also validate confirm password if it's not empty
          if (confirmPasswordController.text.isNotEmpty) {
            if (passwordController.text != confirmPasswordController.text) {
              _fieldErrors['confirmPassword'] = 'Passwords do not match';
            } else {
              _fieldErrors['confirmPassword'] = '';
            }
          }
        });
      }
    });

    // Add listener for confirm password validation
    confirmPasswordController.addListener(() {
      if (confirmPasswordController.text.isNotEmpty) {
        setState(() {
          if (passwordController.text != confirmPasswordController.text) {
            _fieldErrors['confirmPassword'] = 'Passwords do not match';
          } else {
            _fieldErrors['confirmPassword'] = '';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // Validate if string contains only letters and spaces
  bool _isValidName(String name) {
    // This regex ensures the string contains ONLY letters (a-z, A-Z) and spaces
    final RegExp nameRegExp = RegExp(r'^[a-zA-Z\s]+$');
    return nameRegExp.hasMatch(name);
  }

  // Validate email format
  bool _isValidEmail(String email) {
    final RegExp emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegExp.hasMatch(email);
  }

  // Reset all field errors
  void _resetFieldErrors() {
    setState(() {
      for (var key in _fieldErrors.keys) {
        _fieldErrors[key] = '';
      }
    });
  }

  // Validate all fields and return true if valid
  bool _validateFields() {
    _resetFieldErrors();
    bool isValid = true;

    // First Name validation
    if (firstNameController.text.trim().isEmpty) {
      _fieldErrors['firstName'] = 'First name is required';
      isValid = false;
    } else if (firstNameController.text.trim().length < 2) {
      _fieldErrors['firstName'] = 'First name must be at least 2 characters';
      isValid = false;
    } else if (!_isValidName(firstNameController.text.trim())) {
      _fieldErrors['firstName'] =
          'Numbers and special characters are not allowed';
      isValid = false;
    }

    // Middle Name validation (optional)
    if (middleNameController.text.trim().isNotEmpty &&
        !_isValidName(middleNameController.text.trim())) {
      _fieldErrors['middleName'] =
          'Numbers and special characters are not allowed';
      isValid = false;
    }

    // Last Name validation
    if (lastNameController.text.trim().isEmpty) {
      _fieldErrors['lastName'] = 'Last name is required';
      isValid = false;
    } else if (lastNameController.text.trim().length < 2) {
      _fieldErrors['lastName'] = 'Last name must be at least 2 characters';
      isValid = false;
    } else if (!_isValidName(lastNameController.text.trim())) {
      _fieldErrors['lastName'] =
          'Numbers and special characters are not allowed';
      isValid = false;
    }

    // Email validation
    if (emailController.text.trim().isEmpty) {
      _fieldErrors['email'] = 'Email is required';
      isValid = false;
    } else if (!_isValidEmail(emailController.text.trim())) {
      _fieldErrors['email'] = 'Please enter a valid email address';
      isValid = false;
    }

    // Password validation
    if (passwordController.text.isEmpty) {
      _fieldErrors['password'] = 'Password is required';
      isValid = false;
    } else if (passwordController.text.length < 6) {
      _fieldErrors['password'] = 'Password must be at least 6 characters';
      isValid = false;
    }

    // Confirm Password validation
    if (confirmPasswordController.text.isEmpty) {
      _fieldErrors['confirmPassword'] = 'Please confirm your password';
      isValid = false;
    } else if (passwordController.text != confirmPasswordController.text) {
      _fieldErrors['confirmPassword'] = 'Passwords do not match';
      isValid = false;
    }

    // Terms validation
    if (!agreeToTerms) {
      _fieldErrors['terms'] = 'You must agree to the Terms & Privacy';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  // Helper method to build input field
  Widget buildInputField(TextEditingController controller, String label,
      {String? errorText}) {
    bool isPassword = label.toLowerCase().contains('password');

    // Check if there's an error with this field
    bool hasError = errorText?.isNotEmpty == true;

    // Only show error text if form has been submitted or if the field has been edited and has an error
    String? displayErrorText =
        (_formSubmitted || (controller.text.isNotEmpty && hasError))
            ? errorText
            : null;

    // Always use error styling if there's an error, even if we're not showing the error text yet
    bool useErrorStyling = hasError && controller.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey
                .withAlpha(25), // Using withAlpha instead of withOpacity
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword
            ? (label == "Password" ? _obscurePassword : _obscureConfirmPassword)
            : false,
        // Allow all input, validation will show errors for invalid characters
        decoration: InputDecoration(
          labelText: label,
          errorText: displayErrorText,
          errorStyle: const TextStyle(color: Colors.red),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: useErrorStyling
                ? const BorderSide(color: Colors.red)
                : BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: useErrorStyling
                ? const BorderSide(color: Colors.red, width: 2)
                : const BorderSide(color: Color(0xFF00634A)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    label == "Password"
                        ? (_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility)
                        : (_obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      if (label == "Password") {
                        _obscurePassword = !_obscurePassword;
                      } else {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      }
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  void _submit(BuildContext context) async {
    // Reset validation states first
    setState(() {
      _resetFieldErrors();
      _formSubmitted = false;
    });

    // Validate fields
    if (!_validateFields()) {
      setState(() {
        _formSubmitted = true; // Only show errors if validation fails
      });
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      // Combine first, middle, and last name into full name
      String fullName = firstNameController.text.trim();
      if (middleNameController.text.trim().isNotEmpty) {
        fullName += " ${middleNameController.text.trim()}";
      }
      fullName += " ${lastNameController.text.trim()}";

      await authProvider.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        fullName: fullName,
      );

      // Close loading indicator
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Reset validation states after successful registration
      setState(() {
        _resetFieldErrors();
        _formSubmitted = false;
      });

      // Check if widget is still mounted before showing dialog
      if (!mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Check Your Email'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your account has been created successfully. Please check your email for a verification link.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Text(
                  'Verification email sent to: ${emailController.text.trim()}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                const Text(
                  'After verifying your email, you can log in to your account.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close dialog
                  widget.onSwitch(); // Switch to login screen
                },
                child: const Text('Go to Login'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Close loading indicator if it's showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Check if widget is still mounted before showing error
      if (!mounted) return;

      String errorMessage = e.toString();

      // Clean up the error message
      if (errorMessage.contains('Exception: ')) {
        errorMessage = errorMessage.replaceAll('Exception: ', '');
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 320,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF00634A), Color(0xFF3EAD7A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(50),
                      bottomRight: Radius.circular(50),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Let's",
                          style: TextStyle(
                              fontSize: 37,
                              color: Colors.white,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 3.0)),
                      Text("Create your",
                          style: TextStyle(
                              fontSize: 45,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4.0)),
                      Text("Account",
                          style: TextStyle(
                              fontSize: 45,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4.0)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        buildInputField(
                          firstNameController,
                          "First Name",
                          errorText: _fieldErrors['firstName'],
                        ),
                        const SizedBox(height: 15),
                        buildInputField(
                          middleNameController,
                          "Middle Name (Optional)",
                          errorText: _fieldErrors['middleName'],
                        ),
                        const SizedBox(height: 15),
                        buildInputField(
                          lastNameController,
                          "Last Name",
                          errorText: _fieldErrors['lastName'],
                        ),
                        const SizedBox(height: 15),
                        buildInputField(
                          emailController,
                          "Email",
                          errorText: _fieldErrors['email'],
                        ),
                        const SizedBox(height: 15),
                        buildInputField(
                          passwordController,
                          "Password",
                          errorText: _fieldErrors['password'],
                        ),
                        const SizedBox(height: 15),
                        buildInputField(
                          confirmPasswordController,
                          "Confirm Password",
                          errorText: _fieldErrors['confirmPassword'],
                        ),
                        const SizedBox(height: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: agreeToTerms,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      agreeToTerms = value ?? false;
                                    });
                                  },
                                  activeColor: Colors.green,
                                ),
                                const Expanded(
                                  child: Text(
                                    "I agree to the Terms & Privacy",
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                            if (_formSubmitted &&
                                (_fieldErrors['terms']?.isNotEmpty ?? false))
                              Padding(
                                padding: const EdgeInsets.only(left: 12.0),
                                child: Text(
                                  _fieldErrors['terms']!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: widget.onSwitch,
                          child: const Text(
                            "Already have an account? Sign in",
                            style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () => _submit(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3AA772),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 100, vertical: 15),
                            elevation: 3,
                          ),
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white),
                                ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (authProvider.isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
