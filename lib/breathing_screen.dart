import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'services/breathing_service.dart';
import 'dart:async';

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with TickerProviderStateMixin {
  AudioPlayer? _audioPlayer;
  AnimationController? _animationController;
  String _currentPhase = 'Inhale';
  bool _isPlaying = false;
  bool _isPaused = false;
  final ValueNotifier<String> _motivationalMessage = ValueNotifier<String>('');
  bool _isDisposed = false;
  BreathingExercise? selectedExercise;
  int _selectedMinutes = 5; // Default 5 minutes
  int _selectedSeconds = 0; // Default 0 seconds
  bool _showDurationSelection = false;

  // Add timer-related variables
  Timer? _sessionTimer;
  Timer? _messageTimer;
  int _remainingSeconds = 0;
  int _currentMessageIndex = 0;
  String get _formattedRemainingTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  final List<String> _motivationalMessages = [
    "You're doing great, keep breathing",
    "Let go of your worries with each breath",
    "Feel your anxiety melting away",
    "You are stronger than your anxiety",
    "Stay present in this moment",
    "You're taking control of your peace",
    "Each breath brings more calmness",
    "Trust in your inner strength",
    "You're safe and in control",
    "This feeling will pass",
    "Focus on your breath, nothing else matters",
    "Notice the rhythm of your breathing",
    "Be here, in this peaceful moment",
    "Your breath is your anchor",
    "Feel the tension leaving your body",
    "With each breath, you become more relaxed",
    "Your body knows how to find peace",
    "Embrace the feeling of calmness",
    "You have the power to calm your mind",
    "You're building inner strength",
    "Every breath makes you stronger",
    "You're taking care of yourself",
    "You're doing something positive for yourself",
    "Keep going, you're doing well",
    "This is your time for peace",
    "You deserve this moment of calm",
    "Anxiety cannot control you",
    "You are bigger than your worries",
    "Your breath is your safe space",
    "Peace is within your reach",
    "Feel your feet on the ground",
    "Notice the rise and fall of your chest",
    "Your breath connects mind and body",
    "You are grounded and secure",
    "Be gentle with yourself",
    "You're worth this moment of peace",
    "Accept yourself as you are",
    "You're taking positive steps",
    "This is your moment of peace",
    "Right here, right now, you're okay",
    "Each breath is a fresh start",
    "Find peace in this moment",
    // Additional comfort messages
    "You are loved and you matter",
    "Your courage brought you here today",
    "Every small step counts",
    "You're learning to be kind to yourself",
    "This too shall pass, breathe through it",
    "You're not alone in this journey",
    "Your heart is healing with each breath",
    "Trust the process of your healing",
    "You're becoming more resilient",
    "Your inner wisdom guides you",
    "You choose peace over panic",
    "This moment is a gift to yourself",
    "You're practicing self-compassion",
    "Your breath is medicine for your soul",
    "You're creating space for calm",
    "Each exhale releases what doesn't serve you",
    "You're exactly where you need to be",
    "Your presence is enough",
    "You're writing a new story of peace",
    "Your nervous system is learning to relax",
    "You honor your feelings with kindness",
    "This pause is powerful",
    "You're investing in your wellbeing",
    "Your future self will thank you",
    "You're planting seeds of tranquility",
    "Your breath reminds you that you're alive",
    "You're the author of your calm",
    "This practice strengthens your peace",
    "You're learning the art of letting go",
    "Your mindfulness grows with each session",
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _motivationalMessage.dispose();
    _animationController?.dispose();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _sessionTimer?.cancel();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        print('System back button/gesture detected');
        if (selectedExercise != null) {
          print('Exercise selected, showing confirmation dialog');
          await _showExitConfirmationDialog();
          return false; // Prevent default back behavior
        } else {
          print('No exercise selected, allowing back navigation');
          return true; // Allow default back behavior
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            selectedExercise == null
                ? 'Breathing Exercises'
                : selectedExercise!.name,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green.shade500,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () {
              print('Back button pressed. selectedExercise: ${selectedExercise?.name}, _showDurationSelection: $_showDurationSelection');
              if (selectedExercise != null) {
                print('Showing exit confirmation dialog');
                _showExitConfirmationDialog();
              } else {
                print('No exercise selected, navigating back to homepage');
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.green.shade400,
                Colors.green.shade50,
              ],
            ),
          ),
          child: Builder(
            builder: (context) {
              // Debug output
              print('Build: selectedExercise=${selectedExercise?.name}, _showDurationSelection=$_showDurationSelection, _isPlaying=$_isPlaying, _isPaused=$_isPaused');
              
              if (selectedExercise == null) {
                return _buildTechniqueSelection();
              } else if (_showDurationSelection) {
                return _buildDurationSelection();
              } else {
                return _buildExerciseScreen();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTechniqueSelection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          decoration: BoxDecoration(
            color: Colors.green.shade500,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: const Text(
            'Choose a breathing technique to help reduce anxiety and find your inner peace',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: BreathingExercise.anxietyExercises.length,
            itemBuilder: (context, index) {
              final exercise = BreathingExercise.anxietyExercises[index];
              return _buildBreathingExerciseCard(exercise);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSelection() {
    // List of available minutes (from 0 to 30)
    final List<int> minutes = List.generate(31, (index) => index);

    // List of available seconds (0 to 59)
    final List<int> seconds = List.generate(60, (index) => index);

    // Calculate the initial item for both pickers
    final int initialMinutesItem = minutes.indexOf(_selectedMinutes);
    final int initialSecondsItem = seconds.indexOf(_selectedSeconds);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Select Session Length',
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 40),

        // Time picker container
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            children: [
              // Minutes picker
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 50,
                  perspective: 0.005,
                  diameterRatio: 1.2,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(
                      initialItem: initialMinutesItem),
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _selectedMinutes = minutes[index];
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: minutes.length,
                    builder: (context, index) {
                      return Center(
                        child: Text(
                          '${minutes[index]}',
                          style: TextStyle(
                            fontSize: index == initialMinutesItem ? 30 : 20,
                            fontWeight: index == initialMinutesItem
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: index == initialMinutesItem
                                ? Colors.white
                                : Colors.white70,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Center divider
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: const Text(
                    ':',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Seconds picker
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 50,
                  perspective: 0.005,
                  diameterRatio: 1.2,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(
                      initialItem: initialSecondsItem),
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _selectedSeconds = seconds[index];
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: seconds.length,
                    builder: (context, index) {
                      return Center(
                        child: Text(
                          seconds[index].toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: index == initialSecondsItem ? 30 : 20,
                            fontWeight: index == initialSecondsItem
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: index == initialSecondsItem
                                ? Colors.white
                                : Colors.white70,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // Start button
        ElevatedButton(
          onPressed: () {
            print('Start Session button pressed');
            if (_selectedMinutes == 0 && _selectedSeconds == 0) {
              // Show error if no time selected
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a valid duration'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            print('Showing headphones reminder modal');
            _showTemporaryHeadphoneReminder();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            minimumSize: const Size(200, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: const Text(
            'Start Session',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            _resetToTechniqueSelection();
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.red.shade400,
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _showTemporaryHeadphoneReminder() {
    bool isModalDismissed = false;
    
    showDialog(
      context: context,
      barrierDismissible: true, // Allow tapping outside to dismiss
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: () {
            print('Modal tapped! isModalDismissed: $isModalDismissed');
            if (!isModalDismissed) {
              isModalDismissed = true;
              print('Headphones modal tapped, calling _startSession');
              // Dismiss modal and start session when tapped
              Navigator.of(context, rootNavigator: true).pop();
              _startSession();
            } else {
              print('Modal already dismissed, ignoring tap');
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.headphones,
                  size: 60,
                  color: Colors.green.shade600,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Best Experience with Headphones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'For optimal relaxation, we recommend using headphones',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap to continue',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      // When dialog is dismissed (by any means), mark as dismissed
      print('Headphones modal .then() callback triggered');
      if (!isModalDismissed) {
        isModalDismissed = true;
        print('Modal auto-dismissed, calling _startSession');
        _startSession();
      }
    });

    // Auto-dismiss after 3 seconds (as backup if user doesn't tap)
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isDisposed && !isModalDismissed && Navigator.of(context, rootNavigator: true).canPop()) {
        isModalDismissed = true;
        print('Auto-dismissing modal after 3 seconds');
        Navigator.of(context, rootNavigator: true).pop();
        // Ensure _startSession is called after auto-dismiss
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_isDisposed) {
            print('Calling _startSession after auto-dismiss');
            _startSession();
          }
        });
      }
    });
  }

  void _startSession() {
    print('_startSession called');
    setState(() {
      _showDurationSelection = false;
    });
    print('_showDurationSelection set to false');
    _setupAudio();
    // Start the exercise automatically after transitioning to exercise screen
    Future.delayed(const Duration(milliseconds: 100), () {
      print('Starting exercise after delay');
      _startExercise();
    });
  }

  Future<void> _showExitConfirmationDialog() async {
    print('_showExitConfirmationDialog called');
    // Show confirmation modal if we have a selected exercise and we're in the exercise screen
    if (selectedExercise != null && !_showDurationSelection) {
      print('In exercise screen, checking if session is active');
      // If exercise is currently active, show confirmation
      if (_isPlaying || _isPaused) {
        print('Session is active, showing active session confirmation');
        return showDialog<void>(
          context: context,
          barrierDismissible: false, // User must choose an option
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade600,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'End Session?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Your breathing session is currently active. Are you sure you want to end it and return to the technique selection?',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog, continue session
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                  child: const Text(
                    'Continue Session',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    _resetToTechniqueSelection(); // End session and reset
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text(
                    'End Session',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        // Exercise screen is showing but not active, show simpler confirmation
        print('Session not active, showing simple confirmation');
        return showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Return to Selection?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: const Text(
                'Are you sure you want to return to the breathing technique selection?',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    _resetToTechniqueSelection(); // Reset to selection
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text(
                    'Return',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    }
    
    // If no exercise selected, just reset
    _resetToTechniqueSelection();
  }

  Widget _buildExerciseScreen() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              // Add remaining time indicator
              if (_isPlaying || _isPaused)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer, color: Colors.green.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _formattedRemainingTime,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                selectedExercise?.description ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const Divider(height: 20),
              Text(
                selectedExercise?.technique ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: _buildBreathingAnimation(),
          ),
        ),
        // Add motivational message display
        if (_isPlaying && !_isPaused)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ValueListenableBuilder<String>(
              valueListenable: _motivationalMessage,
              builder: (context, message, child) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    message,
                    key: ValueKey(message),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade700,
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _isPaused
                    ? _resumeExercise
                    : (_isPlaying ? _pauseExercise : _startExercise),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPlaying
                      ? (_isPaused ? Colors.green : Colors.orange)
                      : Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  _isPaused
                      ? 'Resume'
                      : (_isPlaying ? 'Pause' : 'Start Exercise'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  _showExitConfirmationDialog();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                ),
                child: const Text(
                  'Return to Selection',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreathingAnimation() {
    return AnimatedBuilder(
      animation: _animationController ?? const AlwaysStoppedAnimation(0),
      builder: (context, child) {
        // Calculate breathing circle scale
        double scale = 1.0;

        if (_animationController != null && _isPlaying && !_isPaused) {
          final value = _animationController!.value;
          final totalDuration = _getTotalCycleDuration().toDouble();

          if (totalDuration <= 0) return child ?? const SizedBox();

          final inhaleDuration = selectedExercise!.inhaleTime / totalDuration;
          final holdDuration = selectedExercise!.holdTime / totalDuration;
          final exhaleDuration = selectedExercise!.exhaleTime / totalDuration;
          final restDuration = selectedExercise!.holdOutTime / totalDuration;

          // Handle all the phases in proper sequence
          if (value < inhaleDuration) {
            // Inhale phase - grow
            scale = 0.8 + (value / inhaleDuration) * 0.4;
            _currentPhase = 'Inhale';
          } else if (value < inhaleDuration + holdDuration) {
            // Hold phase - stay big
            scale = 1.2;
            _currentPhase = 'Hold';
          } else if (value < inhaleDuration + holdDuration + exhaleDuration) {
            // Exhale phase - shrink
            final exhaleProgress =
                (value - (inhaleDuration + holdDuration)) / exhaleDuration;
            scale = 1.2 - exhaleProgress * 0.4;
            _currentPhase = 'Exhale';
          } else {
            // Rest phase - stay small
            scale = 0.8;
            _currentPhase = 'Rest';
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            // Background ripples
            ...List.generate(3, (index) {
              final rippleScale = 1.0 + (index * 0.2);
              return Container(
                width: 220 * rippleScale,
                height: 220 * rippleScale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.1 - (index * 0.03)),
                ),
              );
            }),

            // Breathing circle with improved animation
            AnimatedScale(
              scale: scale,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade300,
                      Colors.green.shade600,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPhase,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (_isPlaying)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text(
                            selectedExercise!.name,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green.shade300,
        ),
        child: const Center(
          child: Text(
            "Ready",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreathingExerciseCard(BreathingExercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              selectedExercise = exercise;
              _showDurationSelection = true;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.air,
                        color: Colors.green.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_calculateTotalDuration(exercise)}s per cycle',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  exercise.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                _buildBreathingPattern(exercise),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreathingPattern(BreathingExercise exercise) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (exercise.inhaleTime > 0)
          _buildBreathingStep(
              'Inhale', exercise.inhaleTime, Colors.blue.shade100),
        if (exercise.holdTime > 0)
          _buildBreathingStep(
              'Hold', exercise.holdTime, Colors.yellow.shade100),
        if (exercise.exhaleTime > 0)
          _buildBreathingStep(
              'Exhale', exercise.exhaleTime, Colors.green.shade100),
        if (exercise.holdOutTime > 0)
          _buildBreathingStep(
              'Rest', exercise.holdOutTime, Colors.purple.shade100),
      ],
    );
  }

  Widget _buildBreathingStep(String label, int duration, Color color) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              duration.toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _setupAudio() async {
    try {
      if (selectedExercise?.soundUrl != null) {
        print('Setting up audio for ${selectedExercise!.name}');
        await _audioPlayer?.setAsset(selectedExercise!.soundUrl!);
        await _audioPlayer?.setLoopMode(LoopMode.one);
        print('Audio setup completed');
      }
    } catch (e) {
      print('Audio setup error: $e');
    }
  }

  void _startExercise() {
    if (selectedExercise == null) return;

    if (_animationController != null) {
      _animationController!.dispose();
      _animationController = null;
    }

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _getTotalCycleDuration()),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController!.reset();
          _animationController!.forward();
        }
      });

    // Calculate total session duration in seconds
    _remainingSeconds = (_selectedMinutes * 60) + _selectedSeconds;

    // Set up session timer
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return; // Don't decrement time if paused

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          // Session complete
          _completeSession();
          timer.cancel();
        }
      });
    });

    // Set up motivational message timer
    _messageTimer?.cancel();
    _currentMessageIndex = 0;
    _updateMotivationalMessage();
    _messageTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (_isPaused) return; // Don't update messages if paused
      _updateMotivationalMessage();
    });

    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });

    _animationController!.forward();
    _audioPlayer?.play();
  }

  void _pauseExercise() {
    if (!_isPlaying) return;

    setState(() {
      _isPaused = true;
    });

    _animationController?.stop();
    _audioPlayer?.pause();
  }

  void _resumeExercise() {
    if (!_isPaused) return;

    setState(() {
      _isPaused = false;
    });

    _animationController?.forward();
    _audioPlayer?.play();
  }

  void _updateMotivationalMessage() {
    if (_motivationalMessages.isNotEmpty) {
      _currentMessageIndex = (_currentMessageIndex + 1) % _motivationalMessages.length;
      _motivationalMessage.value = _motivationalMessages[_currentMessageIndex];
    }
  }

  void _stopExercise() {
    if (!_isPlaying && !_isPaused) return;

    setState(() {
      _isPlaying = false;
      _isPaused = false;
    });

    _animationController?.stop();
    _audioPlayer?.pause();
    _sessionTimer?.cancel();
    _messageTimer?.cancel();
    _motivationalMessage.value = ''; // Clear the message
  }

  void _resetToTechniqueSelection() {
    // Stop everything first
    _stopExercise();
    
    // Dispose and reset animation controller
    _animationController?.dispose();
    _animationController = null;
    
    // Reset audio
    _audioPlayer?.stop();
    
    setState(() {
      selectedExercise = null;
      _selectedMinutes = 5;
      _selectedSeconds = 0;
      _showDurationSelection = false;
      _remainingSeconds = 0;
      _currentMessageIndex = 0;
      _isPlaying = false;
      _isPaused = false;
    });
    _motivationalMessage.value = '';
    
    // Debug print to verify state
    print('Reset completed: selectedExercise=${selectedExercise}, _showDurationSelection=${_showDurationSelection}');
  }

  void _completeSession() {
    _stopExercise();

    // Show completion dialog
    if (!_isDisposed && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 60,
                  color: Colors.green.shade600,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Session Complete',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Great job! You\'ve completed your breathing session.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _resetToTechniqueSelection();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Return to Selection',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  int _calculateTotalDuration(BreathingExercise exercise) {
    return exercise.inhaleTime +
        exercise.holdTime +
        exercise.exhaleTime +
        exercise.holdOutTime;
  }

  int _getTotalCycleDuration() {
    if (selectedExercise == null) return 0;
    return _calculateTotalDuration(selectedExercise!);
  }
}
