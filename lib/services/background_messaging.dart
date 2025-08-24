import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// This function handles background messages when the app is terminated or in background.
/// It must be a top-level function (not inside a class) to work properly.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    debugPrint('🔔 Background FCM received: ${message.notification?.title}');
    debugPrint('📊 Background FCM data: ${message.data}');
    
    // Handle the background message here
    // You can save data locally, show local notifications, etc.
    // Note: You cannot update UI from here since the app is in background
    
    // Example: Log important information
    if (message.data.containsKey('severity')) {
      debugPrint('🚨 Background alert severity: ${message.data['severity']}');
    }
    
    // You could also save critical data to local storage here if needed
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setString('last_background_message', message.notification?.title ?? '');
    
  } catch (e) {
    debugPrint('❌ Error handling background FCM: $e');
  }
}
