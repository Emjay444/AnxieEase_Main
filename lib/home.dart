import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'services/supabase_service.dart';
import 'services/notification_service.dart';

import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';

import 'breathing_screen.dart';
import 'calendar_screen.dart';
import 'grounding_screen.dart';
import 'profile.dart';
import 'psychologist_profile.dart';
import 'screens/notifications_screen.dart';
import 'search.dart';
import 'watch.dart';

// Task class removed

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class StressLabel extends StatelessWidget {
  final String label;
  final String range;

  const StressLabel({super.key, required this.label, required this.range});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          range,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late double screenWidth;
  late double screenHeight;
  int _currentTechniqueIndex = 0;
  late PageController _techniquePageController;
  // Looping carousel config
  static const int _techniquesCount = 3;
  static const int _loopingBase =
      1000; // large base to allow bidirectional scroll
  Timer? _techniqueAutoTimer;

  void _stopTechniqueAutoPlay() {
    _techniqueAutoTimer?.cancel();
    _techniqueAutoTimer = null;
  }

  // Subtle pulsing animation toggles were removed; we animate only icons now
  // (Icon animations now use controllers, not boolean toggles)
  // Controllers for continuous icon+ring breathing
  AnimationController? _breathingController;
  AnimationController? _groundingController;

  void _initControllers() {
    _breathingController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _groundingController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  final List<String> moods = [
    'Happy',
    'Fearful',
    'Excited',
    'Angry',
    'Calm',
    'Pain',
    'Boredom',
    'Sad',
    'Awe',
    'Confused',
    'Anxious',
    'Relief',
    'Satisfied'
  ];
  final Set<String> selectedMoods = {};
  double stressLevel = 3;
  final Map<String, bool> symptoms = {
    'Rapid heartbeat': false,
    'Shortness of breath': false,
    'Dizziness': false,
    'Headache': false,
    'Fatigue': false,
    'Sweating': false,
    'Muscle tension': false,
    'Nausea': false,
    'Shaking or trembling': false,
  };

  @override
  void initState() {
    super.initState();

    // Initialize page controller
    _techniquePageController = PageController(
      viewportFraction: 0.9,
      initialPage: _techniquesCount * _loopingBase,
    );

    // Looping controllers for icon/ring breathing
    _initControllers();

    // Gentle auto-play for the technique carousel
    _techniqueAutoTimer?.cancel();
    _techniqueAutoTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      if (_techniquePageController.hasClients) {
        final current = _techniquePageController.page?.round() ??
            (_techniquesCount * _loopingBase);
        _techniquePageController.animateToPage(
          current + 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void reassemble() {
    // Ensure controllers exist after hot reload
    _initControllers();
    super.reassemble();

    // Clear image cache on initialization
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // Set up the connection between NotificationService and NotificationProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationService =
          Provider.of<NotificationService>(context, listen: false);
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);

      // Set the callback so NotificationService can trigger notification refreshes
      notificationService.setOnNotificationAddedCallback(() {
        notificationProvider.triggerNotificationRefresh();
      });
    });
  }

  // Helper method to create test notifications if none exist
  Future<void> _createTestNotificationsIfNeeded() async {
    final supabaseService = SupabaseService();
    try {
      // Check if there are any notifications
      final notifications = await supabaseService.getNotifications();

      // If no notifications, create some test ones
      if (notifications.isEmpty) {
        await supabaseService.createNotification(
          title: 'High Stress Level Detected',
          message:
              'Your stress level was recorded as 8/10. Consider using breathing exercises.',
          type: 'alert',
          relatedScreen: 'calendar',
        );

        await supabaseService.createNotification(
          title: 'Anxiety Symptoms Logged',
          message:
              'You reported experiencing: Rapid heartbeat, Shortness of breath',
          type: 'log',
          relatedScreen: 'calendar',
        );

        await supabaseService.createNotification(
          title: 'Mood Pattern Alert',
          message:
              'You\'ve been feeling anxious or fearful. Would you like to try some calming exercises?',
          type: 'reminder',
          relatedScreen: 'breathing_screen',
        );
      }
    } catch (e) {
      debugPrint('Error creating test notifications: $e');
    }
  }

  @override
  void dispose() {
    _techniquePageController.dispose();
    _breathingController?.dispose();
    _groundingController?.dispose();
    _techniqueAutoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const HomeContent(),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String label, {String? date}) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  icon,
                  color: Colors.grey[800],
                  size: 24,
                ),
              ),
              if (date != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Text(
                    date,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildFeelingCard(
      String title, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: iconColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Task-related methods removed

  void _showBreathingExercises() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BreathingScreen()),
    );
  }

  void _showGroundingTechnique() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GroundingScreen()),
    );
  }

  void _showHealthMonitoringOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3AA772).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Color(0xFF3AA772),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Health Monitoring',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Connect and monitor your health metrics',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Options
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _buildHealthOption(
                      title: 'Link Device',
                      subtitle: 'Connect your wearable device',
                      icon: Icons.link,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/device-linking');
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildHealthOption(
                      title: 'Your Wearable',
                      subtitle: 'View real-time health metrics',
                      icon: Icons.dashboard,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WatchScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildHealthOption(
                      title: 'Record Baseline',
                      subtitle: 'Set your resting heart rate baseline',
                      icon: Icons.monitor_heart,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/baseline-recording');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHealthOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showMoodTracker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A90E2)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.mood,
                                color: Color(0xFF4A90E2),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'How are you feeling?',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1,
                      ),
                      itemCount: moods.length,
                      itemBuilder: (context, index) {
                        final mood = moods[index];
                        final isSelected = selectedMoods.contains(mood);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selectedMoods.remove(mood);
                              } else {
                                selectedMoods.add(mood);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4A90E2)
                                      .withValues(alpha: 0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF4A90E2)
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getMoodIcon(mood),
                                  color: isSelected
                                      ? const Color(0xFF4A90E2)
                                      : Colors.grey[600],
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  mood,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF4A90E2)
                                        : Colors.grey[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton(
                      onPressed: () {
                        // Save selected moods
                        _saveMoodsToSupabase(selectedMoods, "");
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Save Mood',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _getMoodIcon(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'fearful':
        return Icons.sentiment_very_dissatisfied;
      case 'excited':
        return Icons.mood;
      case 'angry':
        return Icons.mood_bad;
      case 'calm':
        return Icons.sentiment_satisfied;
      case 'pain':
        return Icons.healing;
      case 'boredom':
        return Icons.sentiment_neutral;
      case 'sad':
        return Icons.sentiment_dissatisfied;
      case 'awe':
        return Icons.star;
      case 'confused':
        return Icons.psychology;
      case 'anxious':
        return Icons.warning;
      case 'relief':
        return Icons.spa;
      case 'satisfied':
        return Icons.thumb_up;
      default:
        return Icons.mood;
    }
  }

  void _showStressTracker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Color getColor(double v) => Colors.teal[700]!;
          String label(double v) => v <= 3
              ? 'Low Stress'
              : v <= 6
                  ? 'Moderate Stress'
                  : 'High Stress';

          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Stress Level',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: getColor(stressLevel).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label(stressLevel),
                        style: TextStyle(
                            color: getColor(stressLevel),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'How stressed are you feeling right now?',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 30),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StressLabel(label: 'Not at all', range: '0-3'),
                    StressLabel(label: 'Moderate', range: '4-6'),
                    StressLabel(label: 'Extreme', range: '7-10'),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: getColor(stressLevel),
                    inactiveTrackColor:
                        getColor(stressLevel).withValues(alpha: 0.2),
                    thumbColor: getColor(stressLevel),
                    overlayColor: getColor(stressLevel).withValues(alpha: 0.2),
                    trackHeight: 8,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 12),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 24),
                  ),
                  child: Slider(
                    value: stressLevel,
                    min: 0,
                    max: 10,
                    divisions: 10,
                    onChanged: (v) => setState(() => stressLevel = v),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    stressLevel.toInt().toString(),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: getColor(stressLevel),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Save Stress Level',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPhysicalSymptomsTracker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF50E3C2)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.healing,
                                color: Color(0xFF50E3C2),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Physical Symptoms',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: symptoms.length,
                      itemBuilder: (context, index) {
                        final symptom = symptoms.keys.elementAt(index);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: symptoms[symptom]!
                                ? const Color(0xFF50E3C2).withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: symptoms[symptom]!
                                  ? const Color(0xFF50E3C2)
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              setState(() {
                                symptoms[symptom] = !symptoms[symptom]!;
                              });
                            },
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: symptoms[symptom]!
                                    ? const Color(0xFF50E3C2)
                                        .withValues(alpha: 0.1)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getSymptomIcon(symptom),
                                color: symptoms[symptom]!
                                    ? const Color(0xFF50E3C2)
                                    : Colors.grey[600],
                              ),
                            ),
                            title: Text(
                              symptom,
                              style: TextStyle(
                                color: symptoms[symptom]!
                                    ? const Color(0xFF2C3E50)
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: symptoms[symptom]!
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF50E3C2),
                                  )
                                : Icon(
                                    Icons.circle_outlined,
                                    color: Colors.grey[400],
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton(
                      onPressed: () {
                        // Save symptoms
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Save Symptoms',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _getSymptomIcon(String symptom) {
    switch (symptom.toLowerCase()) {
      case 'rapid heartbeat':
        return Icons.favorite;
      case 'shortness of breath':
        return Icons.air;
      case 'dizziness':
        return Icons.motion_photos_on;
      case 'headache':
        return Icons.sick;
      case 'fatigue':
        return Icons.battery_alert;
      case 'sweating':
        return Icons.water_drop;
      case 'muscle tension':
        return Icons.fitness_center;
      case 'nausea':
        return Icons.sick_outlined;
      case 'shaking or trembling':
        return Icons.vibration;
      default:
        return Icons.healing;
    }
  }

  void _showActivitiesTracker() {
    final List<Map<String, dynamic>> activities = [
      {
        'title': 'Exercise',
        'icon': Icons.directions_run,
        'color': const Color(0xFF9013FE),
        'duration': '30 min',
        'completed': false,
      },
      {
        'title': 'Meditation',
        'icon': Icons.self_improvement,
        'color': const Color(0xFF9013FE),
        'duration': '15 min',
        'completed': false,
      },
      {
        'title': 'Reading',
        'icon': Icons.book,
        'color': const Color(0xFF9013FE),
        'duration': '20 min',
        'completed': false,
      },
      {
        'title': 'Journaling',
        'icon': Icons.edit,
        'color': const Color(0xFF9013FE),
        'duration': '10 min',
        'completed': false,
      },
      {
        'title': 'Walking',
        'icon': Icons.directions_walk,
        'color': const Color(0xFF9013FE),
        'duration': '45 min',
        'completed': false,
      },
      {
        'title': 'Medication',
        'icon': Icons.medication,
        'color': const Color(0xFF9013FE),
        'duration': '5 min',
        'completed': false,
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9013FE)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.directions_run,
                                color: Color(0xFF9013FE),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Daily Activities',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: activity['completed']
                                ? const Color(0xFF9013FE).withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: activity['completed']
                                  ? const Color(0xFF9013FE)
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              setState(() {
                                activity['completed'] = !activity['completed'];
                              });
                            },
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: activity['completed']
                                    ? const Color(0xFF9013FE)
                                        .withValues(alpha: 0.1)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                activity['icon'] as IconData,
                                color: activity['completed']
                                    ? const Color(0xFF9013FE)
                                    : Colors.grey[600],
                              ),
                            ),
                            title: Text(
                              activity['title'] as String,
                              style: TextStyle(
                                color: activity['completed']
                                    ? const Color(0xFF2C3E50)
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              activity['duration'] as String,
                              style: TextStyle(
                                color: activity['completed']
                                    ? const Color(0xFF9013FE)
                                    : Colors.grey[500],
                              ),
                            ),
                            trailing: activity['completed']
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF9013FE),
                                  )
                                : Icon(
                                    Icons.circle_outlined,
                                    color: Colors.grey[400],
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton(
                      onPressed: () {
                        // Save activities
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Save Activities',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Task-related methods removed

  // New Notifications Section
  Widget _buildNotificationsSection() {
    final supabaseService = SupabaseService();

    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey(notificationProvider.refreshCounter),
          future: supabaseService.getNotifications(),
          builder: (context, snapshot) {
            Widget buildHeader() {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('Recent Notifications'),
                  TextButton(
                    onPressed: () async {
                      final bool? notificationsModified =
                          await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );

                      if (mounted && notificationsModified == true) {
                        notificationProvider.triggerNotificationRefresh();
                      }
                    },
                    child: Text(
                      'See All',
                      style: TextStyle(
                        color: Colors.teal[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildHeader(),
                SizedBox(height: screenHeight * 0.02),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snapshot.hasError)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 48,
                          color: Colors.orange[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Connection Error',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Unable to load notifications.\nCheck your internet connection.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Trigger a refresh by calling setState or notificationProvider
                            final notificationProvider =
                                Provider.of<NotificationProvider>(context,
                                    listen: false);
                            notificationProvider.triggerNotificationRefresh();
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true))
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 48,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount:
                        snapshot.data!.length > 3 ? 3 : snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final notification = snapshot.data![index];
                      final DateTime createdAt =
                          DateTime.parse(notification['created_at']);
                      final String timeAgo = timeago.format(createdAt);

                      IconData icon;
                      String type;

                      switch (notification['type']) {
                        case 'alert':
                          icon = Icons.warning_amber;
                          type = 'alert';
                          break;
                        case 'reminder':
                          icon = Icons.notifications_active;
                          type = 'info';
                          break;
                        case 'log':
                          icon = Icons.check_circle;
                          type = 'warning';
                          break;
                        default:
                          icon = Icons.notifications;
                          type = 'info';
                      }

                      return _buildNotificationCard(
                        title: notification['title'],
                        message: notification['message'],
                        time: timeAgo,
                        type: type,
                        icon: icon,
                        notification:
                            notification, // Pass full notification data
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.teal[700],
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: screenWidth * 0.02),
        Text(
          title,
          style: TextStyle(
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E2432),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String message,
    required String time,
    required String type,
    required IconData icon,
    Map<String, dynamic>? notification, // Add notification parameter
  }) {
    Color getTypeColor() {
      switch (type) {
        case 'warning':
          return Colors.orange;
        case 'alert':
          return Colors.red;
        case 'info':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    Color getBackgroundColor() {
      switch (type) {
        case 'alert':
          return const Color(0xFFFFF3E0); // Light orange/red background
        case 'info':
          return const Color(0xFFE3F2FD); // Light blue background
        case 'warning':
          return const Color(0xFFFFF8E1); // Light yellow background
        default:
          return const Color(0xFFF5F5F5); // Light grey background
      }
    }

    // Determine if this is an important notification
    bool isHighPriority =
        type == 'alert' || title.contains('🚨') || title.contains('Alert');

    // Check if this is a reminder notification (should not be clickable)
    bool isReminder = type == 'reminder' ||
        title.contains('Anxiety Check-in') ||
        title.contains('Anxiety Prevention') ||
        title.contains('Wellness Reminder') ||
        title.contains('Mental Health Moment') ||
        title.contains('Relaxation Reminder');

    // Wrap in GestureDetector only if it's not a reminder
    Widget notificationCard = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighPriority ? getBackgroundColor() : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isHighPriority
            ? Border.all(color: getTypeColor().withOpacity(0.3), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: getTypeColor().withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: getTypeColor(),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: const Color(0xFF1E2432),
                          height: 1.3,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.grey[650],
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isReminder) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: getTypeColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View details',
                              style: TextStyle(
                                color: getTypeColor(),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 10,
                              color: getTypeColor(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // Wrap in GestureDetector only if it's not a reminder
    if (!isReminder) {
      return GestureDetector(
        onTap: () => _navigateToNotificationDetails(notification),
        child: notificationCard,
      );
    } else {
      return notificationCard;
    }
  }

  // Navigate to notifications screen and open specific notification
  void _navigateToNotificationDetails(
      Map<String, dynamic>? notification) async {
    if (notification == null) return;

    // Safely convert notification data to ensure proper types
    final Map<String, dynamic> safeNotification =
        Map<String, dynamic>.from(notification);

    // Navigate to notifications screen with the specific notification data
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
        settings: RouteSettings(
          arguments: {
            'show': 'notification',
            'title': safeNotification['title']?.toString() ?? '',
            'message': safeNotification['message']?.toString() ?? '',
            'type': safeNotification['type']?.toString() ?? 'alert',
            'severity': _extractSeverityFromTitle(
                safeNotification['title']?.toString() ?? ''),
            'createdAt': safeNotification['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'notificationId': safeNotification['id']?.toString(),
            'notification':
                safeNotification, // Pass safely converted notification
          },
        ),
      ),
    );
  }

  // Helper function to extract severity from notification title
  String _extractSeverityFromTitle(String title) {
    final titleLower = title.toLowerCase();
    if (titleLower.contains('critical') || title.contains('🚨'))
      return 'critical';
    if (titleLower.contains('severe') || title.contains('🔴')) return 'severe';
    if (titleLower.contains('moderate') || title.contains('🟠'))
      return 'moderate';
    if (titleLower.contains('mild') || title.contains('🟢')) return 'mild';
    return 'mild'; // default
  }

  void _showNotificationDetails(
      String title, String message, String time, String type, IconData icon) {
    Color getTypeColor() {
      switch (type) {
        case 'warning':
          return Colors.orange;
        case 'alert':
          return Colors.red;
        case 'info':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    // Helper function to categorize notifications - not displayed to user
    String getSeverityLevel() {
      if (title.contains('🟢') || title.contains('Mild')) return 'Mild';
      if (title.contains('🟠') || title.contains('Moderate')) return 'Moderate';
      if (title.contains('🔴') || title.contains('Severe')) return 'Severe';
      if (title.contains('Mood Pattern')) return 'Informational';
      return 'Normal';
    }

    String getRecommendation() {
      if (title.contains('Mood Pattern')) {
        return 'Consider using calming exercises to help manage anxiety when feeling anxious or fearful.';
      } else if (title.contains('High Stress')) {
        return 'Try breathing exercises to help reduce stress levels and promote relaxation.';
      } else if (title.contains('Symptom')) {
        return 'Monitor your symptoms and use appropriate techniques to manage your anxiety.';
      } else {
        return 'Consider using the breathing exercises and other tools available in the app.';
      }
    }

    List<String> getActionItems() {
      if (title.contains('Mood Pattern')) {
        return [
          'Use breathing exercises',
          'Practice mindfulness meditation',
          'Record your triggers in journal',
          'Try progressive muscle relaxation'
        ];
      } else if (title.contains('High Stress')) {
        return [
          'Practice 4-7-8 breathing technique',
          'Take a short break from current activities',
          'Use guided meditation',
          'Find a quiet space to relax'
        ];
      } else if (title.contains('Symptom')) {
        return [
          'Track your symptoms in the journal',
          'Use appropriate breathing techniques',
          'Consider relaxation exercises',
          'Monitor changes in symptoms'
        ];
      } else if (getSeverityLevel() == 'Severe') {
        // For severe alerts, show safety plan with crisis hotlines
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final emergencyContact = authProvider.currentUser?.emergencyContact;

        return [
          'Consider finding nearest clinic',
          'NCMH: (Landline) 1553, (Mobile) 0917-899-8727',
          'DOH Hopeline: 0917-558-4673',
          'Emergency Contact: ${emergencyContact ?? "Not set - update in profile"}',
          'Use breathing exercises',
          'Monitor symptoms',
          'Practice self-care activities'
        ];
      } else {
        return [
          'Use breathing exercises',
          'Monitor symptoms',
          'Practice self-care activities',
          'Use the app resources'
        ];
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: getTypeColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: getTypeColor(),
                        size: 32,
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
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2432),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            time,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Details Section
                      const Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2432),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Recommendation Section
                      const Text(
                        'Recommendation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2432),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                color: Colors.blue[600]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                getRecommendation(),
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Items Section
                      Text(
                        getSeverityLevel() == 'Severe'
                            ? 'Safety Plan'
                            : 'Suggested Actions',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2432),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...getActionItems()
                          .map((action) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: getTypeColor(),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        action,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF1E2432),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Action Button - Updated to match the See All screen
              Container(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to breathing exercise screen
                      Navigator.pushNamed(context, '/breathing');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: getTypeColor(),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Try Breathing Exercise',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreathingCard(bool isActive) {
    return GestureDetector(
      onTap: _showBreathingExercises,
      child: _buildBreathingCardContent(isActive: isActive),
    );
  }

  Widget _buildBreathingCardContent({required bool isActive}) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green[400]!,
            Colors.green[300]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(screenWidth * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(isActive ? 0.35 : 0.18),
            blurRadius: isActive ? 22 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenHeight * 0.008,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(screenWidth * 0.05),
                  ),
                  child: Text(
                    'Featured',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.035,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                Text(
                  'Breathing Exercise',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.055,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  'Reduce anxiety with guided breathing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.035,
                  ),
                ),
              ],
            ),
          ),
          // Icon with pulsing ring + bobbing (only icon/circle breathes)
          AnimatedBuilder(
            animation:
                _breathingController ?? const AlwaysStoppedAnimation(0.0),
            builder: (context, _) {
              final v = _breathingController?.value ?? 0.0; // 0..1
              final ringScale =
                  isActive ? (0.92 + 0.16 * v) : 1.0; // 0.92..1.08
              final circleScale =
                  isActive ? (0.98 + 0.04 * v) : 1.0; // 0.98..1.02
              final dy = isActive ? ((v * 2 - 1) * 3) : 0.0; // -3..3 px

              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: ringScale,
                    child: Container(
                      width: screenWidth * 0.22,
                      height: screenWidth * 0.22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              Colors.white.withOpacity(isActive ? 0.35 : 0.0),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: circleScale,
                      child: Container(
                        width: screenWidth * 0.2,
                        height: screenWidth * 0.2,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.air,
                          color: Colors.white,
                          size: screenWidth * 0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGroundingCard(bool isActive) {
    return GestureDetector(
      onTap: _showGroundingTechnique,
      child: _buildGroundingCardContent(isActive: isActive),
    );
  }

  Widget _buildGroundingCardContent({required bool isActive}) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue[500]!,
            Colors.blue[400]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(screenWidth * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(isActive ? 0.35 : 0.18),
            blurRadius: isActive ? 22 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenHeight * 0.008,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(screenWidth * 0.05),
                  ),
                  child: Text(
                    'New',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.035,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                Text(
                  '5-4-3-2-1 Grounding',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.055,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  'Interrupt anxiety with sensory grounding',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.035,
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation:
                _groundingController ?? const AlwaysStoppedAnimation(0.0),
            builder: (context, _) {
              final v = _groundingController?.value ?? 0.0; // 0..1
              final ringScale = isActive ? (0.92 + 0.16 * v) : 1.0;
              final circleScale = isActive ? (0.98 + 0.04 * v) : 1.0;
              final dy = isActive ? ((v * 2 - 1) * -3) : 0.0; // inverse bob

              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: ringScale,
                    child: Container(
                      width: screenWidth * 0.22,
                      height: screenWidth * 0.22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              Colors.white.withOpacity(isActive ? 0.35 : 0.0),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: circleScale,
                      child: Container(
                        width: screenWidth * 0.2,
                        height: screenWidth * 0.2,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.touch_app,
                          color: Colors.white,
                          size: screenWidth * 0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMonitoringCard(bool isActive) {
    return GestureDetector(
      onTap: _showHealthMonitoringOptions,
      child: _buildHealthMonitoringCardContent(isActive: isActive),
    );
  }

  Widget _buildHealthMonitoringCardContent({required bool isActive}) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3AA772), // AnxieEase primary green
            const Color(0xFF2E8B57), // Darker green
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(screenWidth * 0.05),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3AA772).withOpacity(isActive ? 0.35 : 0.18),
            blurRadius: isActive ? 22 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenHeight * 0.008,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(screenWidth * 0.05),
                  ),
                  child: Text(
                    'Monitor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.035,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                Text(
                  'Health Tracking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.055,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  'Connect your wearable device',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.035,
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation:
                _breathingController ?? const AlwaysStoppedAnimation(0.0),
            builder: (context, _) {
              final v = _breathingController?.value ?? 0.0;
              final ringScale = isActive ? (0.92 + 0.16 * v) : 1.0;
              final circleScale = isActive ? (0.98 + 0.04 * v) : 1.0;
              final dy = isActive ? ((v * 2 - 1) * -3) : 0.0;

              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: ringScale,
                    child: Container(
                      width: screenWidth * 0.22,
                      height: screenWidth * 0.22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              Colors.white.withOpacity(isActive ? 0.35 : 0.0),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: circleScale,
                      child: Container(
                        width: screenWidth * 0.2,
                        height: screenWidth * 0.2,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: screenWidth * 0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTechniqueCarousel() {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setCarouselState) {
        // Number of technique cards (looping)

        return Column(
          children: [
            // Carousel indicator
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    'Health & Coping',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const Spacer(),
                  // Swipe indicator
                  Row(
                    children: [
                      Icon(
                        Icons.swipe,
                        size: 16,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Swipe',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: screenHeight * 0.02),

            // Carousel
            SizedBox(
              height: screenHeight * 0.22, // Fixed height for the carousel
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (_) => _stopTechniqueAutoPlay(),
                child: PageView.builder(
                  controller: _techniquePageController,
                  onPageChanged: (index) {
                    final normalized = index % _techniquesCount;
                    setCarouselState(() {
                      _currentTechniqueIndex = normalized;
                    });
                    setState(() {
                      _currentTechniqueIndex = normalized;
                    });
                  },
                  // No itemCount => allows infinite scrolling
                  itemBuilder: (context, index) {
                    final normalizedIndex = index % _techniquesCount;
                    final isCurrentPage =
                        normalizedIndex == _currentTechniqueIndex;
                    return AnimatedScale(
                      scale: isCurrentPage ? 1.0 : 0.9,
                      duration: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.02),
                        child: normalizedIndex == 0
                            ? _buildHealthMonitoringCard(isCurrentPage)
                            : (normalizedIndex == 1
                                ? _buildBreathingCard(isCurrentPage)
                                : _buildGroundingCard(isCurrentPage)),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: screenHeight * 0.015),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _techniquesCount,
                  (index) => GestureDetector(
                    onTap: () {
                      _stopTechniqueAutoPlay();
                      _techniquePageController.animateToPage(
                        (_techniquesCount * _loopingBase) + index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: index == _currentTechniqueIndex ? 16 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: index == _currentTechniqueIndex
                            ? Theme.of(context).primaryColor
                            : Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionsGrid() {
    final List<Map<String, dynamic>> actions = [
      {
        'icon': Icons.psychology,
        'title': 'Psychologist',
        'color': const Color(0xFF00634A),
        'screen': const PsychologistProfilePage(),
      },
      {
        'icon': Icons.watch_outlined,
        'title': 'Wearable',
        'color': const Color(0xFF3EAD7A),
        'screen': const WatchScreen(),
      },
      {
        'icon': Icons.calendar_today,
        'title': 'Calendar',
        'color': const Color(0xFF3EAD7A),
        'screen': const CalendarScreen(),
      },
      {
        'icon': Icons.navigation,
        'title': 'Clinics',
        'color': const Color(0xFF3EAD7A),
        'screen': const SearchScreen(),
      },
    ];

    return SizedBox(
      height: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List<Widget>.from(actions.map(
          (action) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildActionCard(
                icon: action['icon'],
                title: action['title'],
                color: action['color'],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => action['screen'],
                  ),
                ),
              ),
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isCalendar = title == 'Calendar';
    final now = DateTime.now();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              isCalendar
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getMonthAbbreviation(now.month).toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${now.day}',
                          style: TextStyle(
                            color: color,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ],
                    )
                  : Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 22,
                      ),
                    ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1E2432),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthAbbreviation(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }

  // Helper method to save moods to Supabase wellness_logs table
  Future<void> _saveMoodsToSupabase(
      Set<String> selectedMoods, String customMood) async {
    try {
      final supabaseService = SupabaseService();
      final now = DateTime.now();
      final date =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Create a list of feelings that includes both selected moods and custom mood if provided
      final List<String> feelings = selectedMoods.toList();
      if (customMood.isNotEmpty) {
        feelings.add("Custom: $customMood");
      }

      if (feelings.isEmpty) {
        debugPrint('No moods selected or entered, not saving to database');
        return;
      }

      // Create the wellness log entry
      final Map<String, dynamic> logEntry = {
        'date': date,
        'feelings': feelings,
        'stress_level': stressLevel.toInt(),
        'symptoms': symptoms.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList(),
        'journal': '', // No journal entry in this context
        'timestamp': now.toIso8601String(),
      };

      // Save to Supabase
      await supabaseService.saveWellnessLog(logEntry);
      debugPrint(
          'Successfully saved mood log to Supabase: ${feelings.join(", ")}');

      // Show a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mood saved: ${feelings.join(", ")}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving mood log to Supabase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save mood: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  @override
  void initState() {
    super.initState();

    // Set up the connection between NotificationService and NotificationProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationService =
          Provider.of<NotificationService>(context, listen: false);
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);

      // Set the callback so NotificationService can trigger notification refreshes
      notificationService.setOnNotificationAddedCallback(() {
        notificationProvider.triggerNotificationRefresh();
      });
    });
  }

  // Method to load the profile image from the application documents directory
  Future<File?> _loadProfileImage(String? userId) async {
    if (userId == null) return null;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      List<FileSystemEntity> profileImages = [];

      // Collect all profile images for this user
      await for (var entity in dir.list()) {
        if (entity is File) {
          final filename = path.basename(entity.path);
          if (filename.startsWith('profile_$userId')) {
            profileImages.add(entity);
          }
        }
      }

      if (profileImages.isNotEmpty) {
        // Sort to get the most recent one (assuming timestamp in filename)
        profileImages.sort((a, b) => b.path.compareTo(a.path));
        final latestImage = profileImages.first as File;

        debugPrint(
            'Found most recent profile image for home screen: ${latestImage.path}');
        return latestImage;
      } else {
        debugPrint(
            'No profile images found for user ID: $userId in home screen');
      }
    } catch (e) {
      debugPrint('Error loading profile image in home screen: $e');
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          // Top Bar (white card with shadow)
          Material(
            elevation: 4,
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenWidth * 0.03,
              ),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          // Show loading state while authentication is being resolved
                          if (authProvider.isLoading ||
                              !authProvider.isInitialized) {
                            return Container(
                              height: screenWidth *
                                  0.055 *
                                  1.2, // Match text height
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.colorScheme.primary
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Loading...',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontSize: screenWidth * 0.055,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Improved user name display with better fallback logic
                          String displayName = 'Guest';
                          final user = authProvider.currentUser;
                          
                          if (user != null) {
                            // Priority 1: Use first name if available
                            if (user.firstName != null && user.firstName!.trim().isNotEmpty) {
                              displayName = user.firstName!.trim();
                            } 
                            // Priority 2: Extract from full name if available
                            else if (user.fullName != null && user.fullName!.trim().isNotEmpty) {
                              final parts = user.fullName!.trim().split(' ');
                              if (parts.isNotEmpty) {
                                displayName = parts.first;
                              }
                            }
                            // Priority 3: Use email prefix as fallback
                            else if (user.email.isNotEmpty) {
                              final emailParts = user.email.split('@');
                              if (emailParts.isNotEmpty && emailParts.first.isNotEmpty) {
                                displayName = emailParts.first.replaceAll('.', ' ').split(' ').map((word) => 
                                  word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
                                ).join(' ');
                              }
                            }
                          }

                          // Show loading state if still loading and no user data
                          if (authProvider.isLoading && user == null) {
                            return Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.textTheme.titleLarge?.color ?? Colors.black
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Loading...',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: screenWidth * 0.055,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }

                          return Text(
                            'Hello $displayName',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: screenWidth * 0.055,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      Text(
                        'Welcome back',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: screenWidth * 0.035,
                        ),
                      ),
                      // (No date chip in the white card design)
                    ],
                  ),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      );

                      // Refresh image cache when returning from profile page
                      setState(() {
                        PaintingBinding.instance.imageCache.clear();
                        PaintingBinding.instance.imageCache.clearLiveImages();
                      });
                    },
                    child: Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        // Check if user has an avatar URL first, then fallback to local file
                        final user = authProvider.currentUser;
                        final avatarUrl = user?.avatarUrl;

                        // Debug logging to see avatar URL status
                        debugPrint(
                            '🖼️ Avatar debug - User: ${user?.firstName}, Avatar URL: $avatarUrl');

                        // If we have an avatar URL, try to use network image with error handling
                        if (avatarUrl != null && avatarUrl.isNotEmpty) {
                          return CircleAvatar(
                            radius: screenWidth * 0.06,
                            backgroundColor: const Color(0xFF3AA772),
                            child: ClipOval(
                              child: Image.network(
                                avatarUrl,
                                width: screenWidth * 0.12,
                                height: screenWidth * 0.12,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint(
                                      'Error loading network avatar: $error');
                                  // Fallback to first letter if network image fails
                                  String firstLetter = 'G';
                                  if (user != null &&
                                      user.firstName != null &&
                                      user.firstName!.isNotEmpty) {
                                    firstLetter =
                                        user.firstName![0].toUpperCase();
                                  }
                                  return Center(
                                    child: Text(
                                      firstLetter,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }

                        // Fallback to local file system
                        debugPrint(
                            '🖼️ Avatar debug - No URL found, checking local files for user: ${user?.id}');
                        return FutureBuilder<File?>(
                          future:
                              _loadProfileImage(authProvider.currentUser?.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return CircleAvatar(
                                radius: screenWidth * 0.06,
                                backgroundColor:
                                    theme.primaryColor.withValues(alpha: 0.1),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.primaryColor,
                                ),
                              );
                            }

                            if (snapshot.hasData && snapshot.data != null) {
                              // Use the actual profile image from local storage
                              return CircleAvatar(
                                radius: screenWidth * 0.06,
                                backgroundImage: FileImage(
                                  snapshot.data!,
                                  scale: 1.0,
                                ),
                                key: ValueKey(snapshot.data!.path),
                              );
                            } else {
                              // If no profile image, show first letter of name or fallback icon
                              String firstLetter = 'G';
                              if (authProvider.currentUser != null &&
                                  authProvider.currentUser!.firstName != null &&
                                  authProvider
                                      .currentUser!.firstName!.isNotEmpty) {
                                firstLetter = authProvider
                                    .currentUser!.firstName![0]
                                    .toUpperCase();
                              }

                              return CircleAvatar(
                                radius: screenWidth * 0.06,
                                backgroundColor: const Color(0xFF3AA772),
                                child: Text(
                                  firstLetter,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: screenWidth * 0.05),
                    child: homeState?._buildTechniqueCarousel() ?? Container(),
                  ),
                ),

                // Quick Actions Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 20,
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Text(
                              'Quick Actions',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        homeState?._buildQuickActionsGrid() ?? Container(),
                      ],
                    ),
                  ),
                ),

                // New Notifications Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(screenWidth * 0.05),
                    child: homeState?._buildNotificationsSection(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
