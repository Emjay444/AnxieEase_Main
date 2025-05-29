import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'profile.dart';
import 'services/supabase_service.dart';
import 'providers/notification_provider.dart';
import 'utils/settings_helper.dart';
import 'auth.dart'; // Import for AuthScreen
import 'services/notification_service.dart';
// Import for logout navigation

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Anxiety prevention reminder settings
  bool _anxietyRemindersEnabled = false;
  int _reminderIntervalHours = 6;
  final NotificationService _notificationService = NotificationService();

  // Interval options for the dropdown (in hours)
  final List<int> _intervalOptions = [3, 6, 12, 24];

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
  }

  // Load the anxiety reminder settings
  Future<void> _loadReminderSettings() async {
    final bool enabled = await _notificationService.isAnxietyReminderEnabled();
    final int intervalHours =
        await _notificationService.getAnxietyReminderInterval();

    setState(() {
      _anxietyRemindersEnabled = enabled;
      _reminderIntervalHours = intervalHours;
    });
  }

  // Save the anxiety reminder settings
  Future<void> _saveReminderSettings() async {
    await _notificationService.setAnxietyReminderEnabled(
      _anxietyRemindersEnabled,
      intervalHours: _reminderIntervalHours,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_anxietyRemindersEnabled
              ? 'Anxiety prevention reminders enabled'
              : 'Anxiety prevention reminders disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Customize your experience',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 16,
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
                          subtitle: 'Manage your personal information',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ProfilePage(isEditable: false),
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
                                      await SupabaseService().signOut();
                                      if (mounted) {
                                        Navigator.of(context)
                                            .pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const AuthScreen(
                                              showLogin: true,
                                            ),
                                          ),
                                          (route) => false,
                                        );
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
                        _buildSettingsTile(
                          icon: Icons.info_outline,
                          title: 'About',
                          subtitle: 'App version and information',
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
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.watch_later_outlined,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          title: Text(
            'Anxiety Prevention Reminders',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
          ),
          subtitle: Text(
            _anxietyRemindersEnabled
                ? 'Reminders every $_reminderIntervalHours hours'
                : 'Reminders are disabled',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
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
        ),
        if (_anxietyRemindersEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Regular reminders can help you practice anxiety management techniques and prevent anxiety attacks.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reminder Frequency:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    DropdownButton<int>(
                      value: _reminderIntervalHours,
                      items: _intervalOptions.map((int hours) {
                        return DropdownMenuItem<int>(
                          value: hours,
                          child: Text(hours == 24
                              ? 'Once daily'
                              : 'Every $hours hours'),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _reminderIntervalHours = newValue;
                          });
                          _saveReminderSettings();
                        }
                      },
                      underline: Container(
                        height: 1,
                        color: const Color(0xFF2D9254),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your next reminder will arrive in about $_reminderIntervalHours hours.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
      ],
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
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: items,
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
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AnxieEase'),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('A breathing exercise app to help reduce anxiety.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
