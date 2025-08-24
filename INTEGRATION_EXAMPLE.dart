// Example: How to integrate unified notifications in your mood logging

// In your calendar_screen.dart or wherever you save mood logs:

Future<void> _saveDailyLogWithNotifications(
    DateTime date,
    List<String> selectedMoods,
    double stressLevel,
    List<String> selectedSymptoms,
    [DailyLog? existingLog,
    String? journal]) async {
  try {
    // 1. Save to local database first (existing code)
    await _saveDailyLog(date, selectedMoods, stressLevel, selectedSymptoms,
        existingLog, journal);

    // 2. NEW: Send mood data to Firebase for unified notifications
    final notificationService =
        Provider.of<NotificationService>(context, listen: false);
    const userId = 'your_user_id'; // Get from your auth system

    // This will trigger Firebase Cloud Functions for mood-based encouragement
    await notificationService.sendMoodEncouragement(
        selectedMoods, stressLevel, userId);

    // 3. NEW: Check for high stress and send immediate alert
    await notificationService.checkAndSendStressAlert(stressLevel, userId);

    debugPrint('✅ Mood saved with unified notification support');
  } catch (e) {
    debugPrint('❌ Error saving mood with notifications: $e');
  }
}

// Example: Send custom encouragement message
Future<void> sendPersonalEncouragement() async {
  final notificationService =
      Provider.of<NotificationService>(context, listen: false);

  await notificationService.sendCustomCheerup(
      "You're making great progress with your mental health journey! 🌟",
      userId: 'your_user_id');
}

// Example: Test the unified notification system
Future<void> testUnifiedNotifications() async {
  final notificationService =
      Provider.of<NotificationService>(context, listen: false);

  // Test anxiety alert
  await notificationService.testCloudFunctionNotification(
      severity: 'severe', heartRate: 140);

  // Test mood encouragement
  await notificationService
      .sendMoodEncouragement(['anxious', 'stressed'], 8.0, 'test_user');

  // Test custom cheerup
  await notificationService
      .sendCustomCheerup("This is a test encouragement message!");
}
