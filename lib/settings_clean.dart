import 'package:flutter/material.dart';
// Import for AuthScreen
// Import for StorageService
// Import for AppTheme

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              pinned: true,
              title: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D9254),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: screenWidth > 600 ? 600 : screenWidth,
                ),
                margin: EdgeInsets.symmetric(
                  horizontal: screenWidth > 600 ? (screenWidth - 600) / 2 : 16,
                ),
                child: Column(
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // Notifications Section
                          _buildSettingsTile(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Notifications are enabled',
                            trailing: Switch(
                              value: true,
                              onChanged: (value) {
                                // Cloud Functions handle all notifications automatically
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Cloud Functions manage all notifications automatically'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              activeColor: const Color(0xFF2D9254),
                            ),
                            onTap: () {},
                          ),
                          // Cloud Functions handle all wellness notifications (3x daily)
                          // Removed: anxiety reminders, wellness tester, FCM test - no longer needed
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

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
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
            Icons.chevron_right,
            color: Colors.grey[400],
          ),
      onTap: onTap,
    );
  }

  // Helper method to show about dialog
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About AnxieEase'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text(
                'A wellness app focused on anxiety management and mental health support.'),
            SizedBox(height: 8),
            Text('Features:'),
            Text('• Cloud Functions wellness messages (3x daily)'),
            Text('• Real-time anxiety detection'),
            Text('• Breathing exercises and meditation'),
            Text('• Wellness tracking and analytics'),
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
