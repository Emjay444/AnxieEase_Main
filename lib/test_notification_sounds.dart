import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Simple test script to run notification sound tests
/// Run this file directly to test all notification sounds

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print("🔔 NOTIFICATION SOUNDS TEST");
  print("=" * 50);
  
  try {
    // Initialize the notification service
    final notificationService = NotificationService();
    await notificationService.initialize();
    print("✅ NotificationService initialized");
    
    // Test individual sounds
    print("\n🎵 Testing individual severity sounds...");
    
    const severities = ['mild', 'moderate', 'severe', 'critical'];
    for (int i = 0; i < severities.length; i++) {
      final severity = severities[i];
      print("Testing $severity alert...");
      
      await notificationService.testSeverityNotification(severity, i + 1);
      print("✅ $severity notification sent");
      
      // Wait 3 seconds between tests to clearly distinguish sounds
      if (i < severities.length - 1) {
        print("   Waiting 3 seconds...");
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    
    print("\n🎉 All notification sound tests completed!");
    print("\n📱 Check your device notifications to hear the different sounds:");
    print("   🟢 Mild: Gentle chime");
    print("   🟠 Moderate: Clear notification tone");
    print("   🔴 Severe: Urgent sound with action buttons");
    print("   🚨 Critical: Emergency tone with full screen intent");
    
    print("\n💡 Note: If sounds don't work, make sure:");
    print("   - Device volume is up");
    print("   - Do Not Disturb is off"); 
    print("   - Notification permissions are granted");
    print("   - Replace placeholder MP3 files with actual audio");
    
  } catch (e) {
    print("❌ Error testing notifications: $e");
    print("\n🔧 Troubleshooting:");
    print("   - Run 'flutter pub get' first");
    print("   - Check notification permissions");
    print("   - Ensure device is connected and app is installed");
  }
}

/// Alternative test function for specific severity
Future<void> testSpecificSeverity(String severity) async {
  print("🔔 Testing $severity notification...");
  
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    await notificationService.testSeverityNotification(severity, 1);
    print("✅ $severity notification sent successfully");
  } catch (e) {
    print("❌ Error: $e");
  }
}

/// Test all sounds at once
Future<void> testAllSoundsRapid() async {
  print("🔔 Testing all notification sounds rapidly...");
  
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    await notificationService.testAllSeverityNotifications();
    print("✅ All notifications sent with 2-second intervals");
  } catch (e) {
    print("❌ Error: $e");
  }
}