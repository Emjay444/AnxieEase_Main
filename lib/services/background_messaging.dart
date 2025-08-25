import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

/// This function handles background messages when the app is terminated or in background.
/// It must be a top-level function (not inside a class) to work properly.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize Firebase if not already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    debugPrint('🔔 Background FCM received: ${message.notification?.title}');
    debugPrint('📊 Background FCM data: ${message.data}');

    // Handle different message types
    final messageType = message.data['type'];
    debugPrint('📱 Message type: $messageType');

    if (messageType == 'wellness_reminder') {
      debugPrint('🧘 Wellness reminder received in background');
      debugPrint('   Category: ${message.data['category']}');
      debugPrint('   Message Type: ${message.data['messageType']}');
    } else if (messageType == 'anxiety_alert') {
      debugPrint('🚨 Anxiety alert received in background');
      debugPrint('   Severity: ${message.data['severity']}');
    }

    // DON'T create additional local notifications in background handler
    // The Cloud Function FCM message already contains the notification
    // Android will automatically display FCM notifications when app is closed
    debugPrint('📥 Background FCM message received - Android will display the notification automatically');
    
    // Only log the data for debugging
    if (message.notification != null) {
      final notification = message.notification!;
      final data = message.data;
      
      debugPrint('📊 Background notification data:');
      debugPrint('   Title: ${notification.title}');
      debugPrint('   Body: ${notification.body}');
      debugPrint('   Severity: ${data['severity']}');
    }

    // Save critical data for when app reopens
    if (message.data.containsKey('severity')) {
      debugPrint('🚨 Background alert severity: ${message.data['severity']}');
      // Note: You can save to local storage here if needed
    }
  } catch (e) {
    debugPrint('❌ Error handling background FCM: $e');
  }
}
