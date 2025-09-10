import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:math' as math;

class GroundingScreen extends StatefulWidget {
  const GroundingScreen({super.key});

  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingScreenState extends State<GroundingScreen>
    with TickerProviderStateMixin {
  AudioPlayer? _audioPlayer;
  bool _isDisposed = false;
  bool _audioEnabled = false;
  int _currentStep = 0;
  final TextEditingController _inputController = TextEditingController();
  final List<String> _userResponses = List.filled(5, '');
  bool _showingInput = false;
  bool _showIntroduction = true; // Flag to show introduction screen first

  // Timer for auto-navigation
  Timer? _autoNavigationTimer;

  // Animation controllers for introduction screen
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Add this field to store individual text controllers
  final List<TextEditingController> _individualControllers = [];

  // Animation controllers
  late AnimationController _iconAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  // Define the steps of the 5-4-3-2-1 technique with calming colors
  final List<GroundingStep> _steps = [
    GroundingStep(
      sense: 'SEE',
      count: 5,
      instruction: 'Look around and name 5 things you can see.',
      examples: [
        'A plant',
        'A book',
        'Your hands',
        'A window',
        'A piece of furniture'
      ],
      color: const Color(0xFF3AA772), // Calming green
      icon: Icons.visibility,
      audioPrompt: 'assets/audio/Bilateral1.mp3',
      quickOptions: [
        QuickOption(text: 'Plant', icon: Icons.eco),
        QuickOption(text: 'Window', icon: Icons.window),
        QuickOption(text: 'Furniture', icon: Icons.chair),
        QuickOption(text: 'Book', icon: Icons.book),
        QuickOption(text: 'Light', icon: Icons.lightbulb_outline),
      ],
      illustration: 'assets/images/see_illustration.png',
    ),
    GroundingStep(
      sense: 'TOUCH',
      count: 4,
      instruction: 'Notice 4 things you can physically feel.',
      examples: [
        'The texture of your clothes',
        'The surface you\'re sitting on',
        'The temperature of the air',
        'Your feet on the ground'
      ],
      color: const Color(0xFF5E8B7E), // Soft teal
      icon: Icons.touch_app,
      audioPrompt: 'assets/audio/Bilateral2.mp3',
      quickOptions: [
        QuickOption(text: 'Clothes', icon: Icons.checkroom),
        QuickOption(text: 'Chair', icon: Icons.event_seat),
        QuickOption(text: 'Temperature', icon: Icons.thermostat),
        QuickOption(text: 'Floor', icon: Icons.layers),
      ],
      illustration: 'assets/images/touch_illustration.png',
    ),
    GroundingStep(
      sense: 'HEAR',
      count: 3,
      instruction: 'Listen for 3 sounds you can hear.',
      examples: [
        'Traffic outside',
        'The hum of appliances',
        'Your own breathing'
      ],
      color: const Color(0xFF7B9E89), // Muted sage
      icon: Icons.hearing,
      audioPrompt: 'assets/audio/Bilateral3.mp3',
      quickOptions: [
        QuickOption(text: 'Traffic', icon: Icons.directions_car),
        QuickOption(text: 'Appliance', icon: Icons.kitchen),
        QuickOption(text: 'Breathing', icon: Icons.air),
        QuickOption(text: 'Voices', icon: Icons.record_voice_over),
      ],
      illustration: 'assets/images/hear_illustration.png',
    ),
    GroundingStep(
      sense: 'SMELL',
      count: 2,
      instruction: 'Identify 2 things you can smell.',
      examples: ['Fresh air', 'Coffee', 'Soap', 'Food'],
      color: const Color(0xFF6A8CAF), // Soft blue
      icon: Icons.air,
      audioPrompt: 'assets/audio/Bilateral1.mp3',
      quickOptions: [
        QuickOption(text: 'Food', icon: Icons.restaurant_menu),
        QuickOption(text: 'Coffee', icon: Icons.coffee),
        QuickOption(text: 'Fresh Air', icon: Icons.nature),
        QuickOption(text: 'Soap', icon: Icons.soap),
      ],
      illustration: 'assets/images/smell_illustration.png',
    ),
    GroundingStep(
      sense: 'TASTE',
      count: 1,
      instruction: 'Acknowledge 1 thing you can taste.',
      examples: [
        'The taste in your mouth',
        'A drink you just had',
        'Mint gum',
        'Toothpaste'
      ],
      color: const Color(0xFF8E9AAF), // Soft lavender
      icon: Icons.restaurant,
      audioPrompt: 'assets/audio/Bilateral2.mp3',
      quickOptions: [
        QuickOption(text: 'Drink', icon: Icons.local_drink),
        QuickOption(text: 'Mint', icon: Icons.spa),
        QuickOption(text: 'Food', icon: Icons.fastfood),
        QuickOption(text: 'Toothpaste', icon: Icons.wash),
      ],
      illustration: 'assets/images/taste_illustration.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Initialize animation controllers
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(
            parent: _pulseAnimationController, curve: Curves.easeInOut));

    // Initialize introduction screen animations
    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Start introduction animations
    _fadeAnimationController.forward();
    _slideAnimationController.forward();

    // Initialize individual controllers for multi-field input
    _initializeIndividualControllers();
  }

  void _initializeIndividualControllers() {
    // Clear existing controllers
    for (final controller in _individualControllers) {
      controller.dispose();
    }
    _individualControllers.clear();

    // Create new controllers for the current step
    final currentStep = _steps[_currentStep];
    for (int i = 0; i < currentStep.count; i++) {
      _individualControllers.add(TextEditingController());
    }

    // If editing, populate with existing response
    if (_userResponses[_currentStep].isNotEmpty) {
      final lines = _userResponses[_currentStep].split('\n');
      for (int i = 0; i < currentStep.count && i < lines.length; i++) {
        _individualControllers[i].text = lines[i];
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _inputController.dispose();
    // Dispose individual controllers
    for (final controller in _individualControllers) {
      controller.dispose();
    }
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _iconAnimationController.dispose();
    _pulseAnimationController.dispose();
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _autoNavigationTimer?.cancel();
    super.dispose();
  }

  Future<void> _setupAudio(String audioPath) async {
    if (!_audioEnabled) return;

    try {
      await _audioPlayer?.setAsset(audioPath);
      await _audioPlayer?.play();
    } catch (e) {
      print('Audio setup error: $e');
    }
  }

  void _moveToNextStep() {
    // Cancel any pending auto-navigation
    _autoNavigationTimer?.cancel();

    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _showingInput = false;
        // Initialize controllers for the new step
        _initializeIndividualControllers();
      });

      if (_audioEnabled) {
        _setupAudio(_steps[_currentStep].audioPrompt);
      }
    } else {
      _showCompletionScreen();
    }
  }

  void _moveToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _showingInput = false;
        // Initialize controllers for the new step
        _initializeIndividualControllers();
      });

      if (_audioEnabled) {
        _setupAudio(_steps[_currentStep].audioPrompt);
      }
    }
  }

  void _submitResponse() {
    // For multi-field input, combine all responses
    if (_steps[_currentStep].count > 1) {
      final responses = _individualControllers
          .map((controller) => controller.text.trim())
          .toList();
      // Filter out empty responses
      final nonEmptyResponses =
          responses.where((text) => text.isNotEmpty).toList();

      if (nonEmptyResponses.isNotEmpty) {
        setState(() {
          _userResponses[_currentStep] = nonEmptyResponses.join('\n');
          _showingInput = false;
        });
  // Haptic feedback for confirmation
  HapticFeedback.mediumImpact();

        // Cancel any existing timer
        _autoNavigationTimer?.cancel();

        // Auto-advance after 2 seconds to give time to view the response
        _autoNavigationTimer = Timer(const Duration(seconds: 2), () {
          if (!_isDisposed) {
            _moveToNextStep();
          }
        });
      } else {
        // Show validation popup for empty input
        _showEmptyInputAlert();
      }
    }
    // For single field input
    else if (_inputController.text.isNotEmpty) {
      setState(() {
        _userResponses[_currentStep] = _inputController.text;
        _inputController.clear();
        _showingInput = false;
      });
  HapticFeedback.mediumImpact();

      // Cancel any existing timer
      _autoNavigationTimer?.cancel();

      // Auto-advance after 2 seconds to give time to view the response
      _autoNavigationTimer = Timer(const Duration(seconds: 2), () {
        if (!_isDisposed) {
          _moveToNextStep();
        }
      });
    } else {
      // Show validation popup for empty input
      _showEmptyInputAlert();
    }
  }

  // New method to show empty input alert
  void _showEmptyInputAlert() {
    final currentStep = _steps[_currentStep];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: currentStep.color,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Text('Input Required'),
          ],
        ),
        content: Text(
          'Please enter at least one ${currentStep.sense.toLowerCase()} item to proceed.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: currentStep.color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 5,
        titleTextStyle: TextStyle(
          color: Colors.grey[800],
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _selectQuickOption(String option) {
    setState(() {
      _userResponses[_currentStep] = option;
      _showingInput = false;
    });

    // Cancel any existing timer
    _autoNavigationTimer?.cancel();

    // Show confirmation animation and advance after 2 seconds
    _autoNavigationTimer = Timer(const Duration(seconds: 2), () {
      if (!_isDisposed) {
        _moveToNextStep();
      }
    });
  }

  void _showCompletionScreen() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration animation
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(seconds: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3AA772).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 70,
                    color: Color(0xFF3AA772),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: const Text(
                  'Well done',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                onEnd: () {},
                child: Transform.translate(
                  offset: const Offset(0, 0),
                  child: Text(
                    'You\'re here and grounded.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeIn,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _currentStep = 0;
                      for (int i = 0; i < _userResponses.length; i++) {
                        _userResponses[i] = '';
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3AA772),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Return to Start',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _steps[_currentStep];

    return WillPopScope(
      onWillPop: () async {
        if (_showIntroduction) {
          Navigator.pop(context);
          return true;
        } else {
          _showExitConfirmation(context);
          return false; // Prevent default back button behavior
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _showIntroduction ? 'Grounding Technique' : '5-4-3-2-1 Grounding',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor:
              _showIntroduction ? const Color(0xFF3AA772) : currentStep.color,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () {
              if (_showIntroduction) {
                Navigator.pop(context);
              } else {
                _showExitConfirmation(context);
              }
            },
          ),
          actions: [
            if (!_showIntroduction)
              IconButton(
                icon: Icon(
                  _audioEnabled ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _audioEnabled = !_audioEnabled;
                    if (_audioEnabled) {
                      _setupAudio(currentStep.audioPrompt);
                    } else {
                      _audioPlayer?.pause();
                    }
                  });
                },
              ),
          ],
        ),
        resizeToAvoidBottomInset: false,
        body: _showIntroduction
            ? _buildIntroductionScreen()
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      currentStep.color.withOpacity(0.7),
                      currentStep.color.withOpacity(0.1),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Progress steps
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _steps.length,
                            (index) => Container(
                              width: 45,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: index <= _currentStep
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: PageTransitionSwitcher(
                          transitionBuilder:
                              (child, primaryAnimation, secondaryAnimation) {
                            return FadeThroughTransition(
                              animation: primaryAnimation,
                              secondaryAnimation: secondaryAnimation,
                              child: child,
                            );
                          },
                          child: _showingInput
                              ? _buildInputScreen()
                              : _buildInstructionScreen(),
                        ),
                      ),

                      // Navigation buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Row(
                          children: [
                            if (_currentStep > 0)
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _moveToPreviousStep,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withOpacity(0.3),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                  child: const Text(
                                    'Previous',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            if (_currentStep > 0) const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_showingInput) {
                                    _submitResponse();
                                  } else if (_userResponses[_currentStep]
                                      .isEmpty) {
                                    setState(() {
                                      _showingInput = true;
                                      // Auto-focus the text field for better UX
                                      FocusScope.of(context)
                                          .requestFocus(FocusNode());
                                    });
                                  } else {
                                    // If response exists, move to next step
                                    _moveToNextStep();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: currentStep.color,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  elevation: 2,
                                ),
                                child: Text(
                                  _showingInput
                                      ? 'Submit'
                                      : _userResponses[_currentStep].isEmpty
                                          ? 'Continue'
                                          : 'Next',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // New method to build the introduction screen
  Widget _buildIntroductionScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF3AA772).withOpacity(0.7),
            const Color(0xFF3AA772).withOpacity(0.1),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Custom animation at the top
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: SizedBox(
                            height: 200,
                            child: _buildCustomAnimation(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title with animation
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: const Text(
                            '5-4-3-2-1 Grounding Technique',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Explanation text with animation
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildExplanationSection(
                                  icon: Icons.psychology,
                                  title: 'What is Grounding?',
                                  content:
                                      'Grounding is a powerful technique that helps anchor you to the present moment when feeling overwhelmed by anxiety, stress, or intrusive thoughts.',
                                ),
                                const Divider(height: 30),
                                _buildExplanationSection(
                                  icon: Icons.touch_app,
                                  title: 'How It Works',
                                  content:
                                      'The 5-4-3-2-1 technique engages your five senses to help shift focus away from distressing feelings and bring your attention to the present environment.',
                                ),
                                const Divider(height: 30),
                                _buildExplanationSection(
                                  icon: Icons.favorite,
                                  title: 'Benefits',
                                  content:
                                      '• Reduces anxiety and stress\n• Helps manage panic attacks\n• Brings you back to the present\n• Creates mental space from overwhelming thoughts\n• Can be done anywhere, anytime',
                                ),
                                const Divider(height: 30),
                                _buildExplanationSection(
                                  icon: Icons.lightbulb,
                                  title: 'How to Practice',
                                  content:
                                      'You\'ll be guided through identifying:\n• 5 things you can SEE\n• 4 things you can TOUCH\n• 3 things you can HEAR\n• 2 things you can SMELL\n• 1 thing you can TASTE',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Start button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showIntroduction = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3AA772),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'Begin Grounding Exercise',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build explanation sections
  Widget _buildExplanationSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF3AA772).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF3AA772),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3AA772),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Custom animation widget
  Widget _buildCustomAnimation() {
    return AnimatedBuilder(
      animation: _pulseAnimationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing circles
            ...List.generate(
              5,
              (index) => Transform.scale(
                scale: 1.0 + (0.1 * index * _pulseAnimation.value),
                child: Container(
                  width: 150 - (index * 20),
                  height: 150 - (index * 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3AA772)
                        .withOpacity(0.1 - (index * 0.015)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ).reversed,

            // Center icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3AA772).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.spa,
                    size: 40,
                    color: Color(0xFF3AA772),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Ground",
                    style: TextStyle(
                      color: Color(0xFF3AA772),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Animated elements representing the senses
            ...List.generate(
              5,
              (index) {
                final angle = (index * (math.pi * 2 / 5)) +
                    (_pulseAnimationController.value * math.pi / 8);
                const radius = 90.0;
                final x = radius * math.cos(angle);
                final y = radius * math.sin(angle);

                final icons = [
                  Icons.visibility, // SEE
                  Icons.touch_app, // TOUCH
                  Icons.hearing, // HEAR
                  Icons.face, // SMELL (nose)
                  Icons.restaurant, // TASTE
                ];

                return Transform.translate(
                  offset: Offset(x, y),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      icons[index],
                      size: 20,
                      color: const Color(0xFF3AA772),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionScreen() {
    final currentStep = _steps[_currentStep];

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon with illustration
              Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing background
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),

                  // Icon container
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: currentStep.color.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        currentStep.icon,
                        size: 60,
                        color: currentStep.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sense pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                ),
                child: Text(
                  currentStep.sense,
                  style: const TextStyle(
                    letterSpacing: 1.2,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Step title with animation
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Text(
                  '${currentStep.count} things you can ${currentStep.sense}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // Step instruction
              Text(
                currentStep.instruction,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Quick option chips
              if (currentStep.quickOptions.isNotEmpty && _userResponses[_currentStep].isEmpty)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: 1,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: currentStep.quickOptions.map((q) {
                      final isSelected = _userResponses[_currentStep] == q.text;
                      return InkWell(
                        onTap: () => _selectQuickOption(q.text),
                        borderRadius: BorderRadius.circular(28),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(colors: [currentStep.color, currentStep.color.withOpacity(0.6)])
                                : LinearGradient(colors: [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.6)]),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? currentStep.color.withOpacity(0.4)
                                    : Colors.black.withOpacity(0.05),
                                blurRadius: isSelected ? 16 : 6,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.7)
                                  : currentStep.color.withOpacity(0.3),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                q.icon,
                                size: 18,
                                color: isSelected ? Colors.white : currentStep.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                q.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : currentStep.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (currentStep.quickOptions.isNotEmpty && _userResponses[_currentStep].isEmpty)
                const SizedBox(height: 20),

              // Removed white box container completely

              // User response (if already provided) - improved display
              if (_userResponses[_currentStep].isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: currentStep.color,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: currentStep.color.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: currentStep.color.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_circle,
                                  color: currentStep.color,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Your Response:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: currentStep.color,
                                ),
                              ),
                            ],
                          ),
                          // Edit button with improved styling
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _inputController.text =
                                    _userResponses[_currentStep];
                                _showingInput = true;

                                // Initialize individual controllers with existing response
                                final lines =
                                    _userResponses[_currentStep].split('\n');
                                for (int i = 0;
                                    i < _individualControllers.length &&
                                        i < lines.length;
                                    i++) {
                                  _individualControllers[i].text = lines[i];
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: currentStep.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: currentStep.color.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: currentStep.color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: currentStep.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Display responses with improved formatting
                      ...(_userResponses[_currentStep]
                          .split('\n')
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final text = entry.value;
                        if (text.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (currentStep.count > 1)
                                Container(
                                  width: 24,
                                  height: 24,
                                  margin:
                                      const EdgeInsets.only(right: 10, top: 2),
                                  decoration: BoxDecoration(
                                    color: currentStep.color.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: currentStep.color,
                                      ),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[800],
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList()),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputScreen() {
    final currentStep = _steps[_currentStep];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'What ${currentStep.count} thing${currentStep.count > 1 ? 's' : ''} can you ${currentStep.sense.toLowerCase()}?',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Text(
              currentStep.sense == 'SEE'
                  ? 'Take your time to notice details, colors, shapes, and textures.'
                  : currentStep.instruction,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Quick options replicated inside input screen for convenience
            if (currentStep.quickOptions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: currentStep.quickOptions.map((q) {
                    return GestureDetector(
                      onTap: () => _selectQuickOption(q.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(q.icon, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              q.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Properly styled text field
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label inside the white container
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 16, top: 12, bottom: 0),
                    child: Row(
                      children: [
                        Icon(
                          currentStep.icon,
                          color: currentStep.color,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Your Response:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: currentStep.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Text field without additional decoration
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: [
                        // Numbered input fields for multiple items
                        if (currentStep.count > 1) ...[
                          ...List.generate(
                            currentStep.count,
                            (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Numbered circle with improved styling
                                  Container(
                                    width: 28,
                                    height: 28,
                                    margin: const EdgeInsets.only(
                                        top: 8, right: 10),
                                    decoration: BoxDecoration(
                                      color: currentStep.color,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: currentStep.color
                                              .withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Improved input field
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        controller:
                                            _individualControllers[index],
                                        autofocus: index == 0,
                                        maxLines: null,
                                        minLines: 1,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[800],
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Item ${index + 1}...',
                                          hintStyle: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 16,
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: currentStep.color
                                                  .withOpacity(0.3),
                                              width: 1.5,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: currentStep.color
                                                  .withOpacity(0.3),
                                              width: 1.5,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: currentStep.color,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          // Update the combined response
                                          final lines =
                                              _inputController.text.split('\n');
                                          if (lines.length <
                                              currentStep.count) {
                                            lines.addAll(List.filled(
                                                currentStep.count -
                                                    lines.length,
                                                ''));
                                          }
                                          lines[index] = value;
                                          _inputController.text =
                                              lines.join('\n');
                                        },
                                        onSubmitted: (_) {
                                          // Move to next field or submit
                                          if (index < currentStep.count - 1) {
                                            FocusScope.of(context).nextFocus();
                                          } else {
                                            _submitResponse();
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else
                          // Single input field for count=1
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _inputController,
                              autofocus: true,
                              maxLines: 3,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[800],
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type your response here...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: currentStep.color.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: currentStep.color.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: currentStep.color,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              onSubmitted: (_) => _submitResponse(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to show exit confirmation
  void _showExitConfirmation(BuildContext context) {
    final currentStep = _steps[_currentStep];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: currentStep.color,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Text('Exit Grounding?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit? Your progress will not be saved.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Stay',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit to previous screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStep.color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Exit',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 5,
        titleTextStyle: TextStyle(
          color: Colors.grey[800],
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}

// Class to represent a quick option with text and icon
class QuickOption {
  final String text;
  final IconData icon;

  QuickOption({required this.text, required this.icon});
}

class GroundingStep {
  final String sense;
  final int count;
  final String instruction;
  final List<String> examples;
  final Color color;
  final IconData icon;
  final String audioPrompt;
  final List<QuickOption> quickOptions;
  final String? illustration;

  GroundingStep({
    required this.sense,
    required this.count,
    required this.instruction,
    required this.examples,
    required this.color,
    required this.icon,
    required this.audioPrompt,
    this.quickOptions = const [],
    this.illustration,
  });
}

class PageTransitionSwitcher extends StatelessWidget {
  final Widget child;
  final Widget Function(Widget, Animation<double>, Animation<double>)
      transitionBuilder;

  const PageTransitionSwitcher({
    Key? key,
    required this.child,
    required this.transitionBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: child,
    );
  }
}

class FadeThroughTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const FadeThroughTransition({
    Key? key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
