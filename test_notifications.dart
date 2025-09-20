import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

/// Quick notification test - run this to verify notifications work
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("🔔 NOTIFICATION SYSTEM TEST");
  print("=".padRight(50, '='));

  try {
    // Initialize AwesomeNotifications
    print("🚀 Initializing notification system...");

    await AwesomeNotifications().initialize(
      'resource://drawable/res_app_icon', // App icon
      [
        NotificationChannel(
          channelKey: 'test_alerts',
          channelName: 'Test Anxiety Alerts',
          channelDescription: 'Test notifications for anxiety detection',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
      ],
    );
    print("✅ Notification system initialized");

    // Request permission
    print("📋 Requesting notification permissions...");
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      print("❌ Notifications not allowed - requesting permission...");
      await AwesomeNotifications().requestPermissionToSendNotifications();

      final isNowAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isNowAllowed) {
        print("❌ User denied notification permission");
        return;
      } else {
        print("✅ Permission granted!");
      }
    } else {
      print("✅ Notifications already allowed");
    }

    // Send test notifications
    print("\n📱 Sending test notifications...");

    // Test 1: Normal notification
    print("  📤 Sending normal anxiety alert...");
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'test_alerts',
        title: '🟡 Mild Anxiety Detected',
        body:
            'Heart rate slightly elevated (75% confidence). Tap to confirm if you\'re feeling anxious.',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
        wakeUpScreen: false,
      ),
    );
    print("  ✅ Mild anxiety notification sent");

    // Wait 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    // Test 2: High priority notification
    print("  📤 Sending high priority alert...");
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 2,
        channelKey: 'test_alerts',
        title: '🔴 High Anxiety Alert',
        body:
            'Significant anxiety detected (95% confidence). Heart rate: 125 bpm, SpO2: 92%',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Alarm,
        wakeUpScreen: true,
        criticalAlert: true,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'DISMISS',
          label: 'I\'m OK',
          actionType: ActionType.DismissAction,
        ),
        NotificationActionButton(
          key: 'HELP',
          label: 'Get Help',
          actionType: ActionType.Default,
        ),
      ],
    );
    print("  ✅ High anxiety notification sent");

    // Wait 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    // Test 3: Critical emergency notification
    print("  📤 Sending critical emergency alert...");
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 3,
        channelKey: 'test_alerts',
        title: '🚨 EMERGENCY: Critical SpO2',
        body:
            'Blood oxygen level critically low: 88%. Seek immediate medical attention!',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Alarm,
        wakeUpScreen: true,
        fullScreenIntent: true,
        criticalAlert: true,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'EMERGENCY',
          label: 'Call 911',
          actionType: ActionType.Default,
        ),
        NotificationActionButton(
          key: 'DISMISS',
          label: 'Dismiss',
          actionType: ActionType.DismissAction,
        ),
      ],
    );
    print("  ✅ Emergency notification sent");

    print("\n" + "=".padRight(50, '='));
    print("🎉 NOTIFICATION TEST COMPLETED!");
    print("\n📱 Check your device notifications now:");
    print("   • You should see 3 notifications");
    print("   • Different priority levels");
    print("   • Action buttons on higher priority alerts");
    print("\n💡 If you don't see notifications:");
    print("   1. Check notification permissions in Settings");
    print("   2. Ensure 'Do Not Disturb' is off");
    print("   3. Check notification sound is enabled");
    print("   4. Try pulling down notification panel");
  } catch (e) {
    print("❌ Notification test failed: $e");
    print("\n🔧 Troubleshooting:");
    print("  - Ensure app has notification permissions");
    print("  - Check device notification settings");
    print("  - Restart the app and try again");
  }
}
