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
  int _remainingSeconds = 0;
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
  ];

  final int _lastMessageIndex = -1;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            _stopExercise();
            if (selectedExercise != null) {
              setState(() {
                selectedExercise = null;
                _selectedMinutes = 5;
                _selectedSeconds = 0;
                _showDurationSelection = false;
              });
            } else {
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
        child: selectedExercise == null
            ? _buildTechniqueSelection()
            : _showDurationSelection
                ? _buildDurationSelection()
                : _buildExerciseScreen(),
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
            setState(() {
              selectedExercise = null;
              _selectedMinutes = 5;
              _selectedSeconds = 0;
              _showDurationSelection = false;
            });
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
            ],
          ),
        ),
      ),
    );

    // Auto-dismiss after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!_isDisposed && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
        _startSession();
      }
    });
  }

  void _startSession() {
    setState(() {
      _showDurationSelection = false;
    });
    _setupAudio();
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
                  _stopExercise();
                  setState(() {
                    selectedExercise = null;
                    _selectedMinutes = 5;
                    _selectedSeconds = 0;
                    _showDurationSelection = false;
                  });
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

  void _stopExercise() {
    if (!_isPlaying && !_isPaused) return;

    setState(() {
      _isPlaying = false;
      _isPaused = false;
    });

    _animationController?.stop();
    _audioPlayer?.pause();
    _sessionTimer?.cancel();
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
                    setState(() {
                      selectedExercise = null;
                      _selectedMinutes = 5;
                      _selectedSeconds = 0;
                      _showDurationSelection = false;
                    });
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
