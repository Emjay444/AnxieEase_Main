import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// package_info_plus removed from About to avoid runtime plugin issues
import 'profile.dart';
import 'providers/notification_provider.dart';
import 'providers/auth_provider.dart';
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
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
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
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _AboutHeader(),
            SizedBox(height: 16),
            Text(
              'AnxieEase helps you practice grounding and breathing techniques, log moods, and manage reminders to support anxiety prevention.',
            ),
            SizedBox(height: 10),
            Text('What you can do:', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            _AboutBullet(text: 'Guided grounding (5-4-3-2-1) and breathing exercises'),
            _AboutBullet(text: 'Track moods and view patterns over time'),
            _AboutBullet(text: 'Set gentle reminders to practice techniques'),
            _AboutBullet(text: 'Keep your profile up to date'),
            SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2D9254).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.info_outline, color: Color(0xFF2D9254), size: 28),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AnxieEase', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text('Version 1.0.0 (1)', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutBullet extends StatelessWidget {
  final String text;
  const _AboutBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
