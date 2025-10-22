# Notification Troubleshooting Guide

## ✅ Tests Passed

- FCM Token exists in Firebase RTDB
- Token is valid (Firebase accepted the message)
- Cloud Functions are deployed

## ❓ If You're NOT Receiving Notifications

### 1. **Check App is Running**

- App must be OPEN or in BACKGROUND (not force-closed)
- For foreground testing, keep app open on screen

### 2. **Check Notification Permissions**

```
Settings → Apps → AnxieEase → Notifications
- ALL notification categories must be ENABLED:
  ✓ Anxiety Alerts
  ✓ Mild Anxiety Alerts
  ✓ Moderate Anxiety Alerts
  ✓ Severe Anxiety Alerts
  ✓ Critical Anxiety Alerts
  ✓ Wellness Reminders
```

### 3. **Check Do Not Disturb**

- Swipe down notification panel
- Make sure Do Not Disturb is OFF
- Or add AnxieEase to DND exception list

### 4. **Check Battery Optimization**

```
Settings → Apps → AnxieEase → Battery → Unrestricted
```

- Battery optimization can block background notifications
- Set to "Unrestricted" or "Not optimized"

### 5. **Check Notification Channels in Code**

Run this in your app to verify channels are created:

```dart
// In main.dart or notification setup
AwesomeNotifications().listAllChannels().then((channels) {
  print('Notification channels: $channels');
});
```

### 6. **Test Different Notification Types**

Run these tests to isolate the issue:

#### Test 1: Direct FCM (bypasses app code)

```bash
node check_fcm_status.js
```

- If you DON'T receive this: **Device/OS issue**
- If you DO receive this: **App code issue**

#### Test 2: Cloud Function Alert

```bash
node test_real_notifications.js direct mild
```

- Triggers onNativeAlertCreate function
- Check logs: `npx firebase-tools functions:log -n 20`

#### Test 3: Topic Notifications

```bash
node test_all_notifications.js
```

- Tests wellness and breathing reminders via topics

### 7. **Common Issues & Solutions**

| Issue                               | Solution                                  |
| ----------------------------------- | ----------------------------------------- |
| Token valid but no notification     | Check notification permissions & channels |
| "Token expired" error               | Restart app to get fresh token            |
| Works in foreground, not background | Check battery optimization                |
| Notifications delayed               | Check data saver / power saving mode      |
| Sound not playing                   | Check channel sound settings in code      |

### 8. **Verify App Notification Handling**

Check `lib/main.dart`:

```dart
// Make sure this is called
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('📩 Foreground message: ${message.data}');
  // Should create local notification here
});

FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
```

### 9. **Check Logs**

#### Device Logs (Android Studio)

```bash
flutter run --debug
```

Look for:

- `FCM Token:` (token generation)
- `📩 Foreground message:` (message received)
- `onMessage:` (notification displayed)

#### Cloud Function Logs

```bash
npx firebase-tools functions:log -n 30
```

Look for:

- `onNativeAlertCreate: Processing MANUAL test alert`
- `✅ FCM sent to specific user token`
- Any error messages

### 10. **Nuclear Option: Fresh Start**

If nothing works:

1. Uninstall app completely
2. Clear Flutter build: `flutter clean`
3. Rebuild: `flutter run --release`
4. Grant ALL permissions when prompted
5. Check Firebase console → Cloud Messaging → Test send message

## Test Results Checklist

Run each test and check off:

- [ ] `node check_fcm_status.js` - Receives test notification
- [ ] `node test_real_notifications.js direct mild` - Receives anxiety alert
- [ ] Scheduled wellness reminders work (8 AM, 12 PM, 4 PM, 8 PM, 10 PM)
- [ ] Scheduled breathing reminder works (2 PM daily)
- [ ] App shows notifications in Notifications screen (Supabase)

## Contact Points

If all tests pass but still no notifications:

1. Check phone model - some manufacturers (Xiaomi, Huawei) aggressively kill background apps
2. Check Android version - FCM behavior changed in Android 12+
3. Check Google Play Services version - update if outdated
