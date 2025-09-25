# 🔔 Notification Testing Guide

## 🎯 **What Was Fixed**

The issue was that **FCM notifications received while the app was open** were only showing in-app banners but **NOT being saved to Supabase** for display in the notifications screen.

### **Before the Fix:**

- ❌ FCM notifications (app open) → In-app banner only, no storage
- ❌ Firebase realtime data → Local notification only, no storage
- ✅ FCM notifications (app closed) → Worked fine (handled by Cloud Functions)

### **After the Fix:**

- ✅ FCM notifications (app open) → In-app banner + Supabase storage
- ✅ Firebase realtime data → Local notification + Supabase storage
- ✅ FCM notifications (app closed) → Still works fine
- ✅ All notifications now appear in notifications screen

## 🧪 **Testing Steps**

### **Test 1: Anxiety Alert Notifications**

1. **Trigger an anxiety alert:**

   - Use your IoT device to send elevated heart rate data
   - OR manually update Firebase: `/devices/{deviceId}/current/heartRate` to a high value

2. **Expected Results:**

   ```
   ✅ In-app banner appears (if app is open)
   ✅ Local notification shows
   ✅ Notification appears in Notifications Screen
   ✅ Notification appears on Home Screen (Recent Notifications)
   ✅ Notification count updates
   ```

3. **Check Logs:**
   ```
   📥 Foreground FCM received: [title] - [body]
   ✅ Stored anxiety alert in Supabase: [title]
   ✅ Triggered notification refresh in home screen
   ```

### **Test 2: Wellness Reminders**

1. **Trigger a wellness reminder:**

   - Wait for scheduled wellness reminder
   - OR send FCM with `type: 'wellness_reminder'`

2. **Expected Results:**
   ```
   ✅ In-app banner appears
   ✅ Local notification shows
   ✅ Notification stored in Supabase
   ✅ Appears in notifications screen
   ```

### **Test 3: Breathing Exercise Reminders**

1. **Trigger breathing reminder:**

   - Send FCM with `type: 'reminder'` and `related_screen: 'breathing_screen'`

2. **Expected Results:**
   ```
   ✅ In-app banner with "Breathe" button
   ✅ Tapping "Breathe" navigates to breathing screen
   ✅ Notification stored and visible in app
   ```

## 🔍 **Debugging Commands**

### **Check Firebase Data:**

```javascript
// In Firebase Console > Realtime Database
/devices/AnxieEase001/current/heartRate = 95
```

### **Send Test FCM:**

```bash
# Use your FCM test script or Firebase Console
{
  "notification": {
    "title": "🟠 Test Anxiety Alert",
    "body": "Heart rate: 95 BPM (25% above baseline)"
  },
  "data": {
    "type": "anxiety_alert",
    "severity": "moderate",
    "heartRate": "95",
    "baseline": "70",
    "percentageAbove": "25"
  }
}
```

### **Check Supabase:**

```sql
-- Check if notifications are being stored
SELECT * FROM notifications
WHERE user_id = 'your-user-id'
ORDER BY created_at DESC;
```

## 📱 **UI Testing Checklist**

### **Home Screen:**

- [ ] "Recent Notifications" section shows new notifications
- [ ] Notification count updates automatically
- [ ] Tapping "See All" navigates to Notifications Screen

### **Notifications Screen:**

- [ ] All notification types appear (anxiety_alert, wellness_reminder, etc.)
- [ ] Notifications are grouped by date
- [ ] Unread notifications have visual indicators
- [ ] Tapping notifications marks them as read
- [ ] Filter chips work (All, Alerts, Reminders, etc.)

### **In-App Experience:**

- [ ] In-app banners appear for foreground notifications
- [ ] Banners have appropriate colors (red for anxiety, blue for wellness)
- [ ] Action buttons work (View, Breathe, etc.)
- [ ] Banners auto-dismiss after 6 seconds

## 🚨 **Common Issues & Solutions**

### **Issue: Notifications not appearing in app**

**Solution:** Check these logs:

```
❌ Error storing anxiety alert notification: [error]
❌ Error triggering notification refresh: [error]
```

### **Issue: Duplicate notifications**

**Solution:** Rate limiting is working - check cooldown periods:

```
🛑 Skipping duplicate moderate within 180s (client-side)
📵 User [userId] previously responded "no" - using extended cooldown: 3600s
```

### **Issue: Home screen not refreshing**

**Solution:** Check notification provider:

```
✅ Triggered notification refresh in home screen
🔄 NotificationService: Requesting global notification refresh
```

## 🔄 **Notification Flow Summary**

```
1. IoT Device/Cloud Function → FCM Notification
2. FCM received in app → _configureFCM() handler
3. Handler processes message type → Shows in-app banner
4. Handler calls _storeAnxietyAlertNotification()
5. Notification stored in Supabase → createNotification()
6. UI refresh triggered → _triggerNotificationRefresh()
7. Home screen refreshes → Shows new notification
8. Notifications screen shows → All stored notifications
```

## ✅ **Success Indicators**

When everything is working correctly, you should see:

1. **Console Logs:**

   ```
   📥 Foreground FCM received: 🟠 Moderate Alert - Heart rate: 95 BPM
   ✅ Stored anxiety alert in Supabase: 🟠 Moderate Anxiety Alert
   ✅ Triggered notification refresh in home screen
   💾 Saved severity notification to Supabase: 🟠 Moderate Alert
   ```

2. **UI Updates:**

   - In-app banner appears immediately
   - Home screen "Recent Notifications" updates
   - Notifications screen shows new entries
   - Badge counts update correctly

3. **Database:**
   - New rows in `notifications` table
   - Proper `type`, `title`, `message` fields
   - Correct `user_id` association

The notification system should now work seamlessly across all scenarios! 🎉
