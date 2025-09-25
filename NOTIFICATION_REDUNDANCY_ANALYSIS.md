🔍 NOTIFICATION REDUNDANCY ANALYSIS REPORT
═══════════════════════════════════════════════════════════════

📊 EXECUTIVE SUMMARY:
Your AnxieEase app has MULTIPLE REDUNDANT notification systems running simultaneously,
causing users to receive duplicate notifications. This analysis identifies 4 major
redundancy issues and provides specific solutions.

🚨 CRITICAL REDUNDANCIES FOUND:

1. ❌ DOUBLE FCM TOPIC SUBSCRIPTIONS
   Location: lib/main.dart lines 820 & 828
   Problem: App subscribes to 'anxiety_alerts' and 'wellness_reminders' topics EVERY app launch
   Effect: Multiple subscriptions = Multiple identical notifications
   Severity: HIGH - Users get 2-5x duplicate notifications
2. ❌ DOUBLE BREATHING REMINDERS  
   Local Scheduling: lib/settings.dart lines 135-155 (every 30 minutes)
   Cloud Scheduling: functions/src/index.ts lines 355-365 (wellness_reminders topic)
   Problem: Same breathing reminders from 2 different systems
   Effect: Users get breathing reminders from BOTH local AND cloud systems
   Severity: HIGH - Annoying duplicate reminders

3. ⚠️ INCONSISTENT NOTIFICATION CHANNELS
   Used Channels:

   - 'wellness_reminders' (breathing reminders in settings.dart)
   - 'reminders_channel' (anxiety prevention in notification_service.dart)
   - 'anxiety_alerts' (FCM topic notifications)
     Problem: 3 different channels for similar reminder notifications
     Effect: Inconsistent user experience, different notification styles
     Severity: MEDIUM - Confusing UX

4. ⚠️ POTENTIAL OVER-SUBSCRIPTION
   Problem: FCM topics subscriptions not tracking previous subscriptions
   Effect: Firebase may register multiple subscriptions for same device
   Severity: MEDIUM - Backend inefficiency

═══════════════════════════════════════════════════════════════

🔧 SPECIFIC FIXES REQUIRED:

FIX #1: FCM TOPIC SUBSCRIPTION REDUNDANCY
─────────────────────────────────────────────
Current Code (main.dart:820-828):

```dart
// These run EVERY app launch - causing multiple subscriptions
await FirebaseMessaging.instance.subscribeToTopic('anxiety_alerts');
await FirebaseMessaging.instance.subscribeToTopic('wellness_reminders');
```

✅ SOLUTION: Add subscription tracking

```dart
Future<void> _subscribeToTopicsOnce() async {
  final prefs = await SharedPreferences.getInstance();

  // Only subscribe to anxiety_alerts once per installation
  bool subscribedToAnxiety = prefs.getBool('subscribed_anxiety_alerts') ?? false;
  if (!subscribedToAnxiety) {
    await FirebaseMessaging.instance.subscribeToTopic('anxiety_alerts');
    await prefs.setBool('subscribed_anxiety_alerts', true);
    debugPrint('✅ First-time subscription to anxiety_alerts');
  }

  // Only subscribe to wellness_reminders once per installation
  bool subscribedToWellness = prefs.getBool('subscribed_wellness_reminders') ?? false;
  if (!subscribedToWellness) {
    await FirebaseMessaging.instance.subscribeToTopic('wellness_reminders');
    await prefs.setBool('subscribed_wellness_reminders', true);
    debugPrint('✅ First-time subscription to wellness_reminders');
  }
}
```

FIX #2: BREATHING REMINDER REDUNDANCY
────────────────────────────────────────
Current Problem:

- Local: settings.dart schedules every 30 minutes using AwesomeNotifications
- Cloud: functions/src/index.ts sends to wellness_reminders topic

✅ SOLUTION: Choose ONE system (Recommended: Use Cloud Functions)

Option A - Disable Local, Use Cloud (RECOMMENDED):

```dart
// In settings.dart - COMMENT OUT local scheduling
Future<void> _scheduleBreathingReminders() async {
  // DISABLED - Using cloud-based reminders instead
  debugPrint('ℹ️ Breathing reminders handled by cloud functions');

  // Instead, just store the preference for cloud functions to use
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('breathing_reminders_enabled', true);
}
```

Option B - Disable Cloud, Use Local:

```dart
// In Firebase Functions - disable wellness reminders
// Comment out or remove sendWellnessReminder function
```

FIX #3: NOTIFICATION CHANNEL STANDARDIZATION
───────────────────────────────────────────────
Current Channels:

- 'wellness_reminders' → Keep for ALL wellness content
- 'reminders_channel' → REMOVE (redundant)
- 'anxiety_alerts' → Keep for anxiety-specific alerts

✅ SOLUTION: Update notification_service.dart

```dart
// Change line ~205 in notification_service.dart:
channelKey: 'wellness_reminders', // Changed from 'reminders_channel'
```

FIX #4: ADD NOTIFICATION DEDUPLICATION
─────────────────────────────────────────
✅ SOLUTION: Check for recent similar notifications

```dart
Future<bool> _isDuplicateNotification(String type, String content) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'last_${type}_notification';
  final lastTime = prefs.getInt(key) ?? 0;
  final lastContent = prefs.getString('${key}_content') ?? '';

  final now = DateTime.now().millisecondsSinceEpoch;
  const duplicateWindow = 30 * 60 * 1000; // 30 minutes

  if (now - lastTime < duplicateWindow && lastContent == content) {
    return true; // It's a duplicate
  }

  // Store this notification
  await prefs.setInt(key, now);
  await prefs.setString('${key}_content', content);
  return false;
}
```

═══════════════════════════════════════════════════════════════

🎯 IMPLEMENTATION PRIORITY:

1. 🔥 HIGH PRIORITY - Fix FCM topic subscriptions (immediate impact)
2. 🔥 HIGH PRIORITY - Choose ONE breathing reminder system
3. 🟡 MEDIUM PRIORITY - Standardize notification channels
4. 🟢 LOW PRIORITY - Add deduplication (enhancement)

🚀 QUICK TEST:
After implementing fixes, test with:

1. Fresh app install → Should only get 1 of each notification type
2. Multiple app restarts → Should not increase notification frequency
3. Settings toggle → Should cleanly enable/disable without conflicts

═══════════════════════════════════════════════════════════════

📈 EXPECTED RESULTS AFTER FIXES:
✅ Users receive exactly 1 copy of each notification type
✅ No duplicate breathing reminders
✅ Consistent notification styling across app
✅ Cleaner, more professional user experience
✅ Reduced server load from fewer redundant FCM calls

Would you like me to implement any of these fixes?
