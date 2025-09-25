import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
// package_info_plus removed from About to avoid runtime plugin issues
import 'profile.dart';
import 'providers/notification_provider.dart';
import 'providers/auth_provider.dart';
import 'utils/settings_helper.dart';
import 'auth.dart'; // Import for AuthScreen
import 'services/notification_service.dart';
import 'screens/developer_test_screen.dart';
import 'screens/baseline_recording_screen.dart';
import 'widgets/notification_sound_tester.dart';
// Import for logout navigation

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Anxiety prevention reminder settings
  bool _anxietyRemindersEnabled = false;
  // Breathing exercise reminder settings
  bool _breathingRemindersEnabled = false;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
    _loadBreathingReminderSettings();
  }

  // Load the anxiety reminder settings
  Future<void> _loadReminderSettings() async {
    final bool enabled = await _notificationService.isAnxietyReminderEnabled();

    setState(() {
      _anxietyRemindersEnabled = enabled;
    });
  }

  // Save the anxiety reminder settings
  Future<void> _saveReminderSettings() async {
    await _notificationService.setAnxietyReminderEnabled(
      _anxietyRemindersEnabled,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_anxietyRemindersEnabled
              ? 'Wellness reminders enabled'
              : 'Wellness reminders disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Load the breathing reminder settings
  Future<void> _loadBreathingReminderSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('breathing_reminders_enabled') ?? false;

      setState(() {
        _breathingRemindersEnabled = enabled;
      });

      // If reminders were enabled, make sure they're still scheduled
      if (enabled) {
        await _scheduleBreathingReminders();
      }
    } catch (e) {
      debugPrint('Error loading breathing reminder settings: $e');
    }
  }

  // Save the breathing reminder settings
  Future<void> _saveBreathingReminderSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          'breathing_reminders_enabled', _breathingRemindersEnabled);

      if (_breathingRemindersEnabled) {
        // Schedule breathing exercise reminders using AwesomeNotifications
        await _scheduleBreathingReminders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '🫁 Breathing reminders enabled - you\'ll receive notifications every 30 minutes'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Cancel all breathing reminder notifications
        await _cancelBreathingReminders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Breathing reminders disabled'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving breathing reminder settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error updating breathing reminder settings'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _scheduleBreathingReminders() async {
    try {
      // Cancel any existing breathing reminders first
      await _cancelBreathingReminders();

      // DISABLED LOCAL SCHEDULING - Using cloud-based reminders instead
      // This prevents duplicate breathing reminders (local + cloud)
      debugPrint('ℹ️ Breathing reminders handled by Firebase cloud functions');
      debugPrint('ℹ️ Local scheduling disabled to prevent duplicates');

      // Store preference for user settings, but don't schedule locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('breathing_reminders_enabled', true);

      /* COMMENTED OUT - CAUSES DUPLICATE NOTIFICATIONS WITH CLOUD FUNCTIONS
      // Schedule repeating notifications every 30 minutes
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 100, // Unique ID for breathing reminders
          channelKey: 'wellness_reminders',
          title: '🫁 Breathing Exercise Reminder',
          body:
              'Take a moment to relax and breathe. Your mental health matters.',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
          payload: {
            'type': 'reminder',
            'related_screen': 'breathing_screen',
          },
        ),
        schedule: NotificationInterval(
          interval: const Duration(minutes: 30), // 30 minutes
          timeZone: await AwesomeNotifications().getLocalTimeZoneIdentifier(),
          preciseAlarm: true,
          repeats: true,
        ),
      );
      */

      debugPrint(
          '✅ Breathing reminder preference saved (cloud-based reminders active)');
    } catch (e) {
      debugPrint('❌ Error managing breathing reminders: $e');
    }
  }

  Future<void> _cancelBreathingReminders() async {
    try {
      await AwesomeNotifications().cancel(100); // Cancel by ID
      debugPrint('✅ Breathing exercise reminders cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling breathing reminders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Custom App Bar
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6F2), Color(0xFFF7FBF9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customize your experience',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            color: Colors.black.withOpacity(0.55),
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // Settings Sections
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSettingsSection(
                      'Account',
                      [
                        _buildSettingsTile(
                          icon: Icons.person_outline,
                          title: 'Profile',
                          subtitle: 'View and edit your personal information',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D9254),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ProfilePage(isEditable: true),
                              ),
                            );
                          },
                        ),
                        _buildSettingsTile(
                          icon: Icons.logout,
                          title: 'Logout',
                          subtitle: 'Sign out of your account',
                          onTap: () async {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Logout'),
                                content: const Text(
                                    'Are you sure you want to logout?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(
                                          context); // Close dialog first
                                      try {
                                        // Use AuthProvider to properly sign out
                                        final authProvider =
                                            Provider.of<AuthProvider>(context,
                                                listen: false);
                                        await authProvider.signOut();

                                        if (mounted) {
                                          Navigator.of(context)
                                              .pushAndRemoveUntil(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const AuthScreen(
                                                showLogin: true,
                                                message:
                                                    'You have been logged out',
                                              ),
                                            ),
                                            (route) => false,
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content:
                                                  Text('Error logging out: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('Logout',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    _buildSettingsSection(
                      'App Settings',
                      [
                        _buildSettingsTile(
                          icon: Icons.refresh,
                          title: 'Recalibrate Baseline',
                          subtitle: 'Run a quick 5-minute resting HR session',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const BaselineRecordingScreen()),
                            );
                          },
                        ),
                        Consumer<NotificationProvider>(
                          builder: (context, notificationProvider, child) {
                            return _buildSettingsTile(
                              icon: Icons.notifications_outlined,
                              title: 'Notifications',
                              subtitle:
                                  notificationProvider.isNotificationEnabled
                                      ? 'Notifications are enabled'
                                      : 'Notifications are disabled',
                              trailing: Switch(
                                value:
                                    notificationProvider.isNotificationEnabled,
                                onChanged: (value) async {
                                  if (value) {
                                    // Request notification permissions
                                    final granted = await notificationProvider
                                        .requestNotificationPermissions();
                                    if (!granted) {
                                      if (context.mounted) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                                'Notification Permission'),
                                            content: const Text(
                                                'To receive notifications, you need to grant permission in your device settings.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  SettingsHelper
                                                      .openNotificationSettings();
                                                },
                                                child:
                                                    const Text('Open Settings'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    // Inform user they need to disable in system settings
                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text(
                                              'Disable Notifications'),
                                          content: const Text(
                                              'To disable notifications, you need to turn them off in your device settings.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                SettingsHelper
                                                    .openNotificationSettings();
                                              },
                                              child:
                                                  const Text('Open Settings'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  }

                                  // Refresh status after returning from settings
                                  await notificationProvider
                                      .refreshNotificationStatus();
                                },
                                activeColor: const Color(0xFF2D9254),
                              ),
                              onTap: () {},
                            );
                          },
                        ),
                        // Add anxiety prevention reminder settings
                        _buildAnxietyReminderTile(),
                        // Add breathing exercise reminder settings
                        _buildBreathingReminderTile(),
                        // Add notification sound testing
                        _buildSettingsTile(
                          icon: Icons.notifications_active,
                          title: 'Test Notification Sounds',
                          subtitle: 'Test custom sounds for different anxiety levels',
                          onTap: () {
                            _showNotificationTestOptions(context);
                          },
                        ),
                        _buildSettingsTile(
                          icon: Icons.developer_mode,
                          title: 'Developer Test',
                          subtitle: 'Test anxiety detection system',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const DeveloperTestScreen(),
                              ),
                            );
                          },
                        ),
                        _buildSettingsTile(
                          icon: Icons.psychology,
                          title: 'About AnxieEase',
                          subtitle: 'Version, features & information',
                          onTap: () {
                            _showAboutDialog(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build anxiety prevention reminder settings tile
  Widget _buildAnxietyReminderTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2D9254).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.watch_later_outlined,
          color: const Color(0xFF2D9254),
          size: 24,
        ),
      ),
      title: Text(
        'Wellness Reminder',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: Text(
        _anxietyRemindersEnabled
            ? 'Receive wellness messages'
            : 'Reminders are disabled',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: Colors.black.withOpacity(0.6),
            ),
      ),
      trailing: Switch(
        value: _anxietyRemindersEnabled,
        onChanged: (value) {
          setState(() {
            _anxietyRemindersEnabled = value;
          });
          _saveReminderSettings();
        },
        activeColor: const Color(0xFF2D9254),
      ),
    );
  }

  // Build breathing exercise reminder settings tile
  Widget _buildBreathingReminderTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.air,
          color: Colors.blue,
          size: 24,
        ),
      ),
      title: Text(
        'Breathing Exercise Reminder',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: Text(
        _breathingRemindersEnabled
            ? 'Receive breathing exercise reminders every 30 minutes'
            : 'Breathing reminders are disabled',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: Colors.black.withOpacity(0.6),
            ),
      ),
      trailing: Switch(
        value: _breathingRemindersEnabled,
        onChanged: (value) {
          setState(() {
            _breathingRemindersEnabled = value;
          });
          _saveBreathingReminderSettings();
        },
        activeColor: Colors.blue,
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border(
              left: BorderSide(
                color: const Color(0xFF2D9254).withOpacity(0.6),
                width: 3,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i != items.length - 1)
                  Divider(
                    height: 1,
                    indent: 72, // align under text, past the leading icon
                    color: Colors.grey.withOpacity(0.15),
                  ),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2D9254).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF2D9254),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
            ),
      ),
      trailing: trailing ??
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
      onTap: onTap,
    );
  }

  void _showAboutDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _ModernAboutHeader(),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3AA772).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF3AA772).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            color: const Color(0xFF3AA772),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'What AnxieEase offers:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const _ModernBulletPoint(
                        icon: Icons.air,
                        text:
                            'Guided grounding (5-4-3-2-1) and breathing exercises',
                        color: Color(0xFF3AA772),
                      ),
                      const _ModernBulletPoint(
                        icon: Icons.mood,
                        text: 'Track moods and view patterns over time',
                        color: Color(0xFF007AFF),
                      ),
                      const _ModernBulletPoint(
                        icon: Icons.notifications_none,
                        text: 'Set gentle reminders to practice techniques',
                        color: Color(0xFFFF9500),
                      ),
                      const _ModernBulletPoint(
                        icon: Icons.watch,
                        text:
                            'Real-time health monitoring with wearable devices',
                        color: Color(0xFF8E44AD),
                      ),
                      const _ModernBulletPoint(
                        icon: Icons.person_outline,
                        text: 'Comprehensive wellness profile management',
                        color: Color(0xFF00BCD4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite,
                        color: Colors.red.shade400,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Supporting mental wellness, one breath at a time',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show notification sound test options
  void _showNotificationTestOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '🔔 Test Notification Sounds',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Test different severity notification sounds to hear how they will sound during anxiety detection:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              _buildQuickTestButton('🟢 Mild Alert', 'mild', Colors.green),
              const SizedBox(height: 8),
              _buildQuickTestButton('🟠 Moderate Alert', 'moderate', Colors.orange),
              const SizedBox(height: 8),
              _buildQuickTestButton('🔴 Severe Alert', 'severe', Colors.red),
              const SizedBox(height: 8),
              _buildQuickTestButton('🚨 Critical Alert', 'critical', Colors.red[900]!),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _testAllNotificationSounds(context),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Test All Sounds (2s apart)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3AA772),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationSoundTester(),
                    ),
                  );
                },
                icon: const Icon(Icons.science, size: 18),
                label: const Text('Open Full Test Screen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build quick test button for individual severity
  Widget _buildQuickTestButton(String title, String severity, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _testIndividualNotificationSound(severity),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// Test individual severity sound
  Future<void> _testIndividualNotificationSound(String severity) async {
    try {
      await _notificationService.initialize();
      await _notificationService.testSeverityNotification(
        severity, 
        DateTime.now().millisecond,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔔 $severity notification sent! Check your notification panel.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Test all severity sounds with delays
  Future<void> _testAllNotificationSounds(BuildContext context) async {
    try {
      Navigator.of(context).pop(); // Close dialog first
      
      await _notificationService.initialize();
      await _notificationService.testAllSeverityNotifications();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎵 All severity notifications sent! Check your notification panel.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error testing notifications: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class _ModernAboutHeader extends StatelessWidget {
  const _ModernAboutHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AnxieEase Logo from assets
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3AA772).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'assets/images/greenribbon.png',
                width: 56,
                height: 56,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // App name and version
        const Text(
          'AnxieEase',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF3AA772).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Version 1.0.0 (1)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3AA772),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Your companion for mental wellness and anxiety management',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModernBulletPoint extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ModernBulletPoint({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  color: Color(0xFF1A1A1A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
