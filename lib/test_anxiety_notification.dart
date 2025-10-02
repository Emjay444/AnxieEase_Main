import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

/// Test utility for triggering anxiety notifications manually
/// This is useful for testing the notification modal and Firebase integration
class AnxietyNotificationTester {
  static final NotificationService _notificationService = NotificationService();
  static final SupabaseService _supabaseService = SupabaseService();

  /// Test method to trigger different severity anxiety notifications
  static Future<void> testAnxietyNotification(String severity) async {
    try {
      await _notificationService.initialize();

      // Test data for different severity levels
      final Map<String, Map<String, String>> testData = {
        'mild': {
          'title': '🟢 Gentle Check-in',
          'body':
              'We noticed some changes in your readings. Are you experiencing any anxiety right now?',
        },
        'moderate': {
          'title': '🟠 Checking In With You',
          'body':
              'Your heart rate has been elevated. How are you feeling right now?',
        },
        'severe': {
          'title': '🔴 Are You Okay?',
          'body':
              'We detected concerning changes in your vital signs. Are you experiencing anxiety or distress?',
        },
        'critical': {
          'title': '🚨 Urgent Check-in',
          'body':
              'Critical anxiety levels detected. Please confirm you are safe or seek immediate help.',
        }
      };

      final data = testData[severity] ?? testData['mild']!;

      // Send local notification
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: _getChannelForSeverity(severity),
          title: data['title']!,
          body: data['body']!,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
          wakeUpScreen: severity == 'severe' || severity == 'critical',
          criticalAlert: severity == 'critical',
          payload: {
            'type': 'anxiety_alert',
            'severity': severity,
            'timestamp': DateTime.now().toIso8601String(),
            'requires_confirmation': 'true',
          },
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'CONFIRM_YES',
            label: 'Yes, I need help',
            actionType: ActionType.Default,
          ),
          NotificationActionButton(
            key: 'CONFIRM_NO',
            label: 'I\'m okay',
            actionType: ActionType.DismissAction,
          ),
        ],
      );

      // Also save to Supabase for the notifications screen
      await _supabaseService.createNotification(
        title: data['title']!,
        message: data['body']!,
        type: 'alert',
        severity: severity,
        relatedScreen: 'notifications',
      );

      print('✅ Test $severity anxiety notification sent successfully');
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }

  /// Get the appropriate notification channel for severity
  static String _getChannelForSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'mild':
        return 'mild_anxiety_alerts_v4';
      case 'moderate':
        return 'moderate_anxiety_alerts_v2';
      case 'severe':
        return 'severe_anxiety_alerts_v2';
      case 'critical':
        return 'critical_anxiety_alerts_v2';
      default:
        return 'anxiety_alerts';
    }
  }

  /// Test all severity levels with delay
  static Future<void> testAllSeverityLevels() async {
    const severities = ['mild', 'moderate', 'severe', 'critical'];

    for (int i = 0; i < severities.length; i++) {
      await testAnxietyNotification(severities[i]);

      // Wait 3 seconds between notifications
      if (i < severities.length - 1) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }
}

/// Widget for testing anxiety notifications - can be added to any screen
class AnxietyNotificationTestWidget extends StatelessWidget {
  const AnxietyNotificationTestWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🧪 Test Anxiety Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Test different severity levels to see how notifications appear:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Individual severity test buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTestButton(
                  context,
                  '🟢 Mild',
                  Colors.green,
                  () =>
                      AnxietyNotificationTester.testAnxietyNotification('mild'),
                ),
                _buildTestButton(
                  context,
                  '🟠 Moderate',
                  Colors.orange,
                  () => AnxietyNotificationTester.testAnxietyNotification(
                      'moderate'),
                ),
                _buildTestButton(
                  context,
                  '🔴 Severe',
                  Colors.red,
                  () => AnxietyNotificationTester.testAnxietyNotification(
                      'severe'),
                ),
                _buildTestButton(
                  context,
                  '🚨 Critical',
                  Colors.purple,
                  () => AnxietyNotificationTester.testAnxietyNotification(
                      'critical'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Test all button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    AnxietyNotificationTester.testAllSeverityLevels(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('🚀 Test All Levels (3s delay)'),
              ),
            ),

            const SizedBox(height: 8),
            const Text(
              'Note: Notifications will appear in your device\'s notification panel and the app\'s notifications screen.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
      BuildContext context, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        side: BorderSide(color: color),
      ),
      child: Text(label),
    );
  }
}
