import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'main.dart';
import 'package:intl/intl.dart';
import 'legal/legal_documents_dialog.dart';

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
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController emergencyContactController =
      TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Multi-step UI state
  int _currentStep = 0; // 0: Personal, 1: Contact, 2: Account

  DateTime? _selectedBirthDate;
  String? _selectedSex;

  // List of sex options for dropdown
  final List<String> _sexOptions = [
    'Male',
    'Female',
  ];

  // Form validation
  final _formKey = GlobalKey<FormState>();
  final Map<String, String?> _fieldErrors = {
    'firstName': null,
    'middleName': null, // Optional field starts with null
    'lastName': null,
    'birthDate': null,
    'sex': null,
    'contactNumber': null, // Optional field starts with null
    'emergencyContact': null, // Optional field starts with null
    'email': null,
    'password': null,
    'confirmPassword': null,
    'terms': null,
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
      setState(() {
        final text = firstNameController.text.trim();
        if (text.isEmpty) {
          // Keep or set required only if form already submitted; otherwise no error yet
          _fieldErrors['firstName'] =
              _formSubmitted ? 'First name is required' : null;
        } else if (text.length < 2) {
          _fieldErrors['firstName'] =
              'First name must be at least 2 characters';
        } else if (!_isValidName(text)) {
          _fieldErrors['firstName'] =
              'Numbers and special characters are not allowed';
        } else {
          _fieldErrors['firstName'] = null;
        }
      });
    });

    middleNameController.addListener(() {
      setState(() {
        if (middleNameController.text.isNotEmpty) {
          if (!_isValidName(middleNameController.text)) {
            _fieldErrors['middleName'] =
                'Numbers and special characters are not allowed';
          } else {
            _fieldErrors['middleName'] = null;
          }
        } else {
          // Clear error when field is empty since it's optional
          _fieldErrors['middleName'] = null;
        }
      });
    });

    lastNameController.addListener(() {
      setState(() {
        final text = lastNameController.text.trim();
        if (text.isEmpty) {
          _fieldErrors['lastName'] =
              _formSubmitted ? 'Last name is required' : null;
        } else if (text.length < 2) {
          _fieldErrors['lastName'] = 'Last name must be at least 2 characters';
        } else if (!_isValidName(text)) {
          _fieldErrors['lastName'] =
              'Numbers and special characters are not allowed';
        } else {
          _fieldErrors['lastName'] = null;
        }
      });
    });

    // Add listener for contact number validation (required)
    contactNumberController.addListener(() {
      setState(() {
        if (contactNumberController.text.trim().isEmpty) {
          _fieldErrors['contactNumber'] = 'Contact number is required';
        } else if (!_isValidPhoneNumber(contactNumberController.text.trim())) {
          _fieldErrors['contactNumber'] = 'Please enter a valid phone number';
        } else {
          _fieldErrors['contactNumber'] = null;
        }
      });
    });

    // Add listener for emergency contact validation (required)
    emergencyContactController.addListener(() {
      setState(() {
        if (emergencyContactController.text.trim().isEmpty) {
          _fieldErrors['emergencyContact'] =
              'Emergency contact number is required';
        } else if (!_isValidPhoneNumber(
            emergencyContactController.text.trim())) {
          _fieldErrors['emergencyContact'] =
              'Please enter a valid phone number';
        } else {
          _fieldErrors['emergencyContact'] = null;
        }
      });
    });

    // Add listener for email validation
    emailController.addListener(() {
      setState(() {
        final text = emailController.text.trim();
        if (text.isEmpty) {
          _fieldErrors['email'] = _formSubmitted ? 'Email is required' : null;
        } else if (!_isValidEmail(text)) {
          _fieldErrors['email'] = 'Please enter a valid email address';
        } else {
          _fieldErrors['email'] = null;
        }
      });
    });

    // Add listener for password validation
    passwordController.addListener(() {
      if (passwordController.text.isNotEmpty) {
        setState(() {
          if (!_isPasswordValid(passwordController.text)) {
            final validation = _validatePassword(passwordController.text);
            List<String> missingRequirements = [];

            if (!validation['length']!)
              missingRequirements.add('8+ characters');
            if (!validation['uppercase']!)
              missingRequirements.add('uppercase letter');
            if (!validation['lowercase']!)
              missingRequirements.add('lowercase letter');
            if (!validation['number']!) missingRequirements.add('number');
            if (!validation['special']!)
              missingRequirements.add('special character');

            _fieldErrors['password'] =
                'Password must contain: ${missingRequirements.join(', ')}';
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
    passwordController.addListener(() {
      setState(() {
        final text = passwordController.text;
        if (text.isEmpty) {
          _fieldErrors['password'] =
              _formSubmitted ? 'Password is required' : null;
        } else if (!_isPasswordValid(text)) {
          final validation = _validatePassword(text);
          List<String> missingRequirements = [];
          if (!validation['length']!) missingRequirements.add('8+ characters');
          if (!validation['uppercase']!)
            missingRequirements.add('uppercase letter');
          if (!validation['lowercase']!)
            missingRequirements.add('lowercase letter');
          if (!validation['number']!) missingRequirements.add('number');
          if (!validation['special']!)
            missingRequirements.add('special character');
          _fieldErrors['password'] =
              'Password must contain: ${missingRequirements.join(', ')}';
        } else {
          _fieldErrors['password'] = null;
        }
      });
    });
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

  // Validate birth date
  bool _isValidBirthDate(DateTime? birthDate) {
    if (birthDate == null) return false;

    final now = DateTime.now();
    final minDate = DateTime(now.year - 120); // 120 years ago maximum
    final maxDate = DateTime(now.year - 13); // At least 13 years old

    return birthDate.isAfter(minDate) && birthDate.isBefore(maxDate);
  }

  // Validate phone number
  bool _isValidPhoneNumber(String phone) {
    // Must be exactly 11 digits, no other characters allowed
    final RegExp phoneRegExp = RegExp(r'^[0-9]{11}$');
    return phoneRegExp.hasMatch(phone);
  }

  // Comprehensive password validation
  Map<String, bool> _validatePassword(String password) {
    return {
      'length': password.length >= 8,
      'uppercase': RegExp(r'[A-Z]').hasMatch(password),
      'lowercase': RegExp(r'[a-z]').hasMatch(password),
      'number': RegExp(r'[0-9]').hasMatch(password),
      'special': RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password),
    };
  }

  // Check if password meets all requirements
  bool _isPasswordValid(String password) {
    final validation = _validatePassword(password);
    return validation.values.every((requirement) => requirement);
  }

  // Get password strength (0-3)
  int _getPasswordStrength(String password) {
    final validation = _validatePassword(password);
    int score = 0;

    if (validation['length']!) score++;
    if (validation['uppercase']! && validation['lowercase']!) score++;
    if (validation['number']!) score++;
    if (validation['special']!) score++;

    return score;
  }

  // Reset all field errors
  void _resetFieldErrors() {
    setState(() {
      for (var key in _fieldErrors.keys) {
        _fieldErrors[key] = null;
      }
    });
  }

  // Show date picker to select birth date
  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate =
        _selectedBirthDate ?? DateTime(now.year - 20, now.month, now.day);
    final DateTime firstDate =
        DateTime(now.year - 120); // 120 years ago maximum
    final DateTime lastDate =
        DateTime(now.year - 13, now.month, now.day); // At least 13 years old

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(lastDate) ? lastDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3AA772), // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Calendar text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3AA772), // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
        birthDateController.text = DateFormat('MMM dd, yyyy').format(picked);

        // Validate birth date
        if (!_isValidBirthDate(picked)) {
          _fieldErrors['birthDate'] =
              'Please enter a valid birth date (13-120 years old)';
        } else {
          _fieldErrors['birthDate'] = null;
        }
      });
    }
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
    } else {
      // Clear error if middle name is empty (optional) or valid
      _fieldErrors['middleName'] = null;
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

    // Birth Date validation
    if (_selectedBirthDate == null) {
      _fieldErrors['birthDate'] = 'Birth date is required';
      isValid = false;
    } else if (!_isValidBirthDate(_selectedBirthDate)) {
      _fieldErrors['birthDate'] =
          'Please enter a valid birth date (13-120 years old)';
      isValid = false;
    }

    // Sex validation
    if (_selectedSex == null) {
      _fieldErrors['sex'] = 'Please select a sex';
      isValid = false;
    }

    // Contact number validation (required)
    if (contactNumberController.text.trim().isEmpty) {
      _fieldErrors['contactNumber'] = 'Contact number is required';
      isValid = false;
    } else if (!_isValidPhoneNumber(contactNumberController.text.trim())) {
      _fieldErrors['contactNumber'] = 'Please enter a valid phone number';
      isValid = false;
    } else {
      _fieldErrors['contactNumber'] = null;
    }

    // Emergency contact validation (required)
    if (emergencyContactController.text.trim().isEmpty) {
      _fieldErrors['emergencyContact'] = 'Emergency contact number is required';
      isValid = false;
    } else if (!_isValidPhoneNumber(emergencyContactController.text.trim())) {
      _fieldErrors['emergencyContact'] = 'Please enter a valid phone number';
      isValid = false;
    } else {
      _fieldErrors['emergencyContact'] = null;
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
    } else if (!_isPasswordValid(passwordController.text)) {
      final validation = _validatePassword(passwordController.text);
      List<String> missingRequirements = [];

      if (!validation['length']!) missingRequirements.add('8+ characters');
      if (!validation['uppercase']!)
        missingRequirements.add('uppercase letter');
      if (!validation['lowercase']!)
        missingRequirements.add('lowercase letter');
      if (!validation['number']!) missingRequirements.add('number');
      if (!validation['special']!) missingRequirements.add('special character');

      _fieldErrors['password'] =
          'Password must contain: ${missingRequirements.join(', ')}';
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

  // Password strength indicator widget
  Widget _buildPasswordStrengthIndicator(String password) {
    if (password.isEmpty) return const SizedBox.shrink();

    final validation = _validatePassword(password);
    final strength = _getPasswordStrength(password);

    Color strengthColor;
    String strengthText;

    switch (strength) {
      case 0:
      case 1:
        strengthColor = Colors.red;
        strengthText = 'Weak';
        break;
      case 2:
        strengthColor = Colors.orange;
        strengthText = 'Medium';
        break;
      case 3:
        strengthColor = Colors.lightGreen;
        strengthText = 'Good';
        break;
      case 4:
        strengthColor = Colors.green;
        strengthText = 'Strong';
        break;
      default:
        strengthColor = Colors.grey;
        strengthText = 'Weak';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Password Strength: ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                strengthText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: strengthColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Strength bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.grey[300],
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: strength / 4,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: strengthColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Requirements list
          Column(
            children: [
              _buildRequirementRow(
                  'At least 8 characters', validation['length']!),
              _buildRequirementRow(
                  'Uppercase letter (A-Z)', validation['uppercase']!),
              _buildRequirementRow(
                  'Lowercase letter (a-z)', validation['lowercase']!),
              _buildRequirementRow('Number (0-9)', validation['number']!),
              _buildRequirementRow(
                  'Special character (!@#\$%^&*)', validation['special']!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String requirement, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isMet ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requirement,
              style: TextStyle(
                fontSize: 11,
                color: isMet ? Colors.green : Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build input field
  Widget buildInputField(TextEditingController controller, String label,
      {String? errorText, bool isDatePicker = false}) {
    bool isPassword = label.toLowerCase().contains('password');
    bool isPhoneNumber = label.toLowerCase().contains('contact') ||
        label.toLowerCase().contains('phone');

    // Debug print for middle name field
    if (label.contains('Middle Name')) {
      print(
          'Middle Name Debug - errorText: "$errorText", hasError: ${errorText != null && errorText.isNotEmpty}, controller.text: "${controller.text}", controller.text.isEmpty: ${controller.text.isEmpty}');
    }

    // Check if there's an error with this field - handle both null and empty string cases
    bool hasError = errorText != null && errorText.isNotEmpty;

    // Special handling for optional fields - don't show error styling when empty
    bool isOptionalField = label.toLowerCase().contains('optional');

    // Only show error text if form has been submitted or if the field has been edited and has an error
    String? displayErrorText =
        (_formSubmitted || (controller.text.isNotEmpty && hasError))
            ? errorText
            : null;

    // Use error styling if there's an error and the field has content
    // For optional fields, never show error styling when empty
    bool useErrorStyling = hasError &&
        controller.text.isNotEmpty &&
        !(isOptionalField && controller.text.isEmpty);

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
        readOnly:
            isDatePicker, // Make the field read-only if it's a date picker
        onTap: isDatePicker
            ? () => _selectBirthDate(context)
            : null, // Show date picker when tapped
        inputFormatters: isPhoneNumber
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ]
            : null,
        keyboardType: isPhoneNumber ? TextInputType.phone : null,
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
          suffixIcon: isDatePicker
              ? const Icon(Icons.calendar_today, color: Colors.grey)
              : (isPassword
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
                  : null),
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
      // Debug log start of registration
      print(
          'Starting registration process for email: ${emailController.text.trim()}');

      // Combine first, middle, and last name into full name
      String fullName = firstNameController.text.trim();
      if (middleNameController.text.trim().isNotEmpty) {
        fullName += " ${middleNameController.text.trim()}";
      }
      fullName += " ${lastNameController.text.trim()}";

      print(
          'Calling authProvider.signUp with email: ${emailController.text.trim()}, name: $fullName');

      await authProvider.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        firstName: firstNameController.text.trim(),
        middleName: middleNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        birthDate: _selectedBirthDate,
        contactNumber: contactNumberController.text.trim(),
        emergencyContact: emergencyContactController.text.trim(),
        sex: _selectedSex,
      );

      print('authProvider.signUp completed successfully');

      // Reset validation states after successful registration
      setState(() {
        _resetFieldErrors();
        _formSubmitted = false;
      });

      // Check if widget is still mounted before showing dialog
      if (!mounted) {
        print('❌ Widget not mounted, cannot show success dialog');
        return;
      }

      print('🎉 Showing success dialog...');
      // Show success dialog using global navigator to prevent it from being dismissed
      showDialog(
        context: rootNavigatorKey.currentContext ?? context,
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
      // Check if widget is still mounted before showing error
      if (!mounted) return;

      String errorMessage = e.toString();
      print('Registration error: $errorMessage');

      // Clean up the error message
      if (errorMessage.contains('Exception: ')) {
        errorMessage = errorMessage.replaceAll('Exception: ', '');
      }

      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              // Dismiss the snackbar early
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
                        _buildStepIndicator(),
                        const SizedBox(height: 12),
                        if (_currentStep == 0) ...[
                          // Personal
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
                            birthDateController,
                            "Birth Date",
                            errorText: _fieldErrors['birthDate'],
                            isDatePicker: true,
                          ),
                          const SizedBox(height: 15),
                          _buildSexDropdown(),
                        ] else if (_currentStep == 1) ...[
                          // Contact
                          buildInputField(
                            contactNumberController,
                            "Contact Number",
                            errorText: _fieldErrors['contactNumber'],
                          ),
                          const SizedBox(height: 15),
                          buildInputField(
                            emergencyContactController,
                            "Emergency Contact Number",
                            errorText: _fieldErrors['emergencyContact'],
                          ),
                        ] else ...[
                          // Account
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
                          _buildPasswordStrengthIndicator(
                              passwordController.text),
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
                                    child: ClickableTermsText(),
                                  ),
                                ],
                              ),
                              if (_formSubmitted &&
                                  (_fieldErrors['terms']?.isNotEmpty ?? false))
                                Padding(
                                  padding: const EdgeInsets.only(left: 12.0),
                                  child: Text(
                                    _fieldErrors['terms'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        _buildStepNavigation(authProvider),
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

  Widget _buildStepIndicator() {
    // Dot-based indicator: active step is a pill, others small circles
    Widget dot(int index) {
      final bool active = index == _currentStep;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: active ? 28 : 10,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2D9254) : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(100),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [dot(0), dot(1), dot(2)],
    );
  }

  Widget _buildStepNavigation(AuthProvider authProvider) {
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == 2;

    Future<bool> validateCurrentStep() async {
      // Run partial validation for current step only, set errors accordingly
      _resetFieldErrors();
      bool ok = true;
      if (_currentStep == 0) {
        // Personal
        if (firstNameController.text.trim().isEmpty) {
          _fieldErrors['firstName'] = 'First name is required';
          ok = false;
        } else if (firstNameController.text.trim().length < 2) {
          _fieldErrors['firstName'] =
              'First name must be at least 2 characters';
          ok = false;
        } else if (!_isValidName(firstNameController.text.trim())) {
          _fieldErrors['firstName'] =
              'Numbers and special characters are not allowed';
          ok = false;
        }

        if (lastNameController.text.trim().isEmpty) {
          _fieldErrors['lastName'] = 'Last name is required';
          ok = false;
        } else if (lastNameController.text.trim().length < 2) {
          _fieldErrors['lastName'] = 'Last name must be at least 2 characters';
          ok = false;
        } else if (!_isValidName(lastNameController.text.trim())) {
          _fieldErrors['lastName'] =
              'Numbers and special characters are not allowed';
          ok = false;
        }

        if (_selectedBirthDate == null) {
          _fieldErrors['birthDate'] = 'Birth date is required';
          ok = false;
        }
        if (_selectedSex == null) {
          _fieldErrors['sex'] = 'Please select a sex';
          ok = false;
        }
      } else if (_currentStep == 1) {
        // Contact
        if (contactNumberController.text.trim().isEmpty) {
          _fieldErrors['contactNumber'] = 'Contact number is required';
          ok = false;
        } else if (!_isValidPhoneNumber(contactNumberController.text.trim())) {
          _fieldErrors['contactNumber'] = 'Please enter a valid phone number';
          ok = false;
        }
        if (emergencyContactController.text.trim().isEmpty) {
          _fieldErrors['emergencyContact'] =
              'Emergency contact number is required';
          ok = false;
        } else if (!_isValidPhoneNumber(
            emergencyContactController.text.trim())) {
          _fieldErrors['emergencyContact'] =
              'Please enter a valid phone number';
          ok = false;
        }
      } else {
        // Account
        if (emailController.text.trim().isEmpty) {
          _fieldErrors['email'] = 'Email is required';
          ok = false;
        } else if (!_isValidEmail(emailController.text.trim())) {
          _fieldErrors['email'] = 'Please enter a valid email address';
          ok = false;
        }

        if (passwordController.text.isEmpty) {
          _fieldErrors['password'] = 'Password is required';
          ok = false;
        } else if (!_isPasswordValid(passwordController.text)) {
          final validation = _validatePassword(passwordController.text);
          List<String> missingRequirements = [];
          if (!validation['length']!) missingRequirements.add('8+ characters');
          if (!validation['uppercase']!)
            missingRequirements.add('uppercase letter');
          if (!validation['lowercase']!)
            missingRequirements.add('lowercase letter');
          if (!validation['number']!) missingRequirements.add('number');
          if (!validation['special']!)
            missingRequirements.add('special character');
          _fieldErrors['password'] =
              'Password must contain: ${missingRequirements.join(', ')}';
          ok = false;
        }

        if (confirmPasswordController.text.isEmpty) {
          _fieldErrors['confirmPassword'] = 'Please confirm your password';
          ok = false;
        } else if (passwordController.text != confirmPasswordController.text) {
          _fieldErrors['confirmPassword'] = 'Passwords do not match';
          ok = false;
        }

        if (!agreeToTerms) {
          _fieldErrors['terms'] = 'You must agree to the Terms & Privacy';
          ok = false;
        }
      }
      setState(() {});
      return ok;
    }

    return Row(
      children: [
        if (!isFirst)
          Expanded(
            child: OutlinedButton(
              onPressed: authProvider.isLoading
                  ? null
                  : () => setState(() => _currentStep -= 1),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Back'),
            ),
          ),
        if (!isFirst) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: authProvider.isLoading
                ? null
                : () async {
                    // Force-show validation messages for empty fields
                    setState(() => _formSubmitted = true);
                    final ok = await validateCurrentStep();
                    if (!ok) return; // stay on step, errors are shown

                    // Clear submit flag when proceeding
                    if (!isLast) {
                      setState(() {
                        _formSubmitted = false;
                        _currentStep += 1;
                      });
                    } else {
                      // Final submit (full validation remains in _submit)
                      _submit(context);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3AA772),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                : Text(isLast ? 'Sign Up' : 'Next'),
          ),
        ),
      ],
    );
  }

  // Removed _isCurrentStepReady(); Next button validates on press

  Widget _buildSexDropdown() {
    // Check if there's an error with this field
    bool hasError = _fieldErrors['sex']?.isNotEmpty == true;

    // Only show error text if form has been submitted or if the field has been edited and has an error
    String? displayErrorText =
        (_formSubmitted || (_selectedSex != null && hasError))
            ? _fieldErrors['sex']
            : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedSex,
        decoration: InputDecoration(
          labelText: 'Sex',
          errorText: displayErrorText,
          errorStyle: const TextStyle(color: Colors.red),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF00634A)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        onChanged: (String? newValue) {
          setState(() {
            _selectedSex = newValue;
            // Clear error when user selects a sex
            _fieldErrors['sex'] = null;
          });
        },
        items: _sexOptions.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        hint: const Text('Select Sex'),
      ),
    );
  }
}
