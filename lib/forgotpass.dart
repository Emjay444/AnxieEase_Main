import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'verify_reset_code.dart';

class Forgotpass extends StatefulWidget {
  const Forgotpass({super.key});

  @override
  State<Forgotpass> createState() => _ForgotpassState();
}

class _ForgotpassState extends State<Forgotpass>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _resetEmailSent = false;

  // Animation controller for simple fade-in effect
  AnimationController? _animationController;
  Animation<double>? _fadeInAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller with simpler animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Reduced duration
    );

    // Single fade-in animation
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeOut, // Simpler curve
      ),
    );

    // Start animation after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController!.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address';
      });
      return;
    }

    // Basic email validation
    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('Requesting password reset for email: $email');
      await SupabaseService().resetPassword(email);
      print('Password reset request successful');

      setState(() {
        _resetEmailSent = true;
        _isLoading = false;
      });

      // Navigate to the verification screen after sending the email
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VerifyResetCodeScreen(
              email: email,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error requesting password reset: $e');
      setState(() {
        _errorMessage = e.toString().contains('Exception:')
            ? e.toString().split('Exception: ')[1]
            : 'Failed to send reset email. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If animations aren't initialized yet, show a simple loading indicator
    if (_fadeInAnimation == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3AA772), // Light green
                  Color(0xFF2D9254), // Medium green
                  Color(0xFF1E714C), // Dark green
                ],
                stops: [0.1, 0.5, 0.9],
              ),
            ),
          ),

          // Content with simple fade animation
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FadeTransition(
                  opacity: _fadeInAnimation!,
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Back Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Lock Icon - Simplified
                      _buildLockIcon(),

                      const SizedBox(height: 30),

                      // Header Text
                      const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Subtitle
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          "Don’t worry! It happens. Enter your email and we’ll send you an OTP.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Card for input and button
                      _buildInputCard(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simplified Lock Icon
  Widget _buildLockIcon() {
    // Modernized lock icon with gradient ring, subtle glow and a smooth scale-in
    const primary = Color(0xFF3AA772);
    const secondary = Color(0xFF2D9254);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.92, end: 1.0),
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      child: SizedBox(
        width: 130,
        height: 130,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft ambient glow
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.35),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),

            // Gradient halo ring
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0x263AA772), // primary 15%
                    Color(0x7F3AA772), // primary 50%
                    Color(0x992D9254), // secondary 60%
                    Color(0x7F3AA772), // primary 50%
                    Color(0x263AA772), // primary 15%
                  ],
                  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                ),
              ),
            ),

            // Inner white 'glass' plate
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),

            // Specular highlight
            Positioned(
              top: 30,
              left: 46,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),

            // Gradient-filled lock glyph
            ShaderMask(
              shaderCallback: (Rect bounds) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, secondary],
              ).createShader(bounds),
              child: const Icon(
                Icons.lock_rounded,
                size: 54,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_resetEmailSent)
              _buildStatusMessage(
                message:
                    'Password reset email sent! Check your inbox for the 6-digit PIN code. You will be redirected to the verification screen.',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF3AA772),
              ),

            if (_errorMessage != null)
              _buildStatusMessage(
                message: _errorMessage!,
                icon: Icons.error_outline,
                color: Colors.red,
              ),

            // Email Input - Simplified
            _buildInputField(),

            const SizedBox(height: 30),

            // Reset Button - Simplified
            _buildButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: TextField(
          controller: _emailController,
          decoration: InputDecoration(
            hintText: "Enter your email",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: Color(0xFF3AA772),
              size: 22,
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading && !_resetEmailSent,
        ),
      ),
    );
  }

  Widget _buildButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3AA772).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading || _resetEmailSent ? null : _resetPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3AA772),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                _resetEmailSent ? "Email Sent" : "Send Reset Link",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildStatusMessage({
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
