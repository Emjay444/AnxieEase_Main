# 🎯 REAL USER ANXIETY DETECTION TESTING GUIDE

## Overview

This guide will help you test your AnxieEase anxiety detection system with real user scenarios, including background notifications when the app is closed.

## ✅ Prerequisites Confirmed

- ✅ Device `AnxieEase001` assigned to user `5efad7d4-3dcd-4333-ba4b-41f86`
- ✅ FCM token extracted from Flutter app
- ✅ Firebase configuration fixed
- ✅ User baseline: 70 BPM → 84 BPM anxiety threshold

---

## 🧪 Test Scenarios

### Test 1: Background Anxiety Detection (Full System Test)

**Purpose:** Verify complete anxiety detection works when app is closed

**Steps:**

1. **Close your Flutter app completely** (swipe away from recent apps)
2. **Lock your phone** or put it aside
3. Run the background test script:
   ```powershell
   node test_background_anxiety_detection.js
   ```
4. **Wait for notification** during Step 5 (sustained anxiety simulation)

**Expected Results:**

- ✅ Steps 1-4: No notifications (normal/brief elevated heart rate)
- 🔔 **Step 5: YOU SHOULD GET A NOTIFICATION** on your locked phone
- ✅ Console shows anxiety alert created in Firebase

---

### Test 2: Direct FCM Notification Test

**Purpose:** Verify notifications work to your specific device

**Steps:**

1. **Close Flutter app and lock phone**
2. Run direct notification test:
   ```powershell
   node test_direct_notification.js
   ```
3. Check your phone for test notification

**Expected Result:**

- 🔔 Immediate test notification appears on locked screen

---

### Test 3: Manual Heart Rate Threshold Testing

**Purpose:** Understand exactly when anxiety detection triggers

**Heart Rate Thresholds:**

- **Baseline:** 70 BPM (your personal baseline)
- **Anxiety Threshold:** 84 BPM (70 + 20% = anxiety detection starts)
- **Sustained Duration:** 30+ seconds (required for alert)

**Test Pattern:**

1. **Normal Range (65-80 BPM):** ✅ No alerts
2. **Brief Elevation (85-95 BPM for 15s):** ✅ No alerts
3. **Sustained Anxiety (85+ BPM for 35+ seconds):** 🚨 **ALERT + NOTIFICATION**

---

## 🔧 Quick Testing Commands

### Check Current Device Assignment

```powershell
node check_device_assignment.js
```

### Run Complete Background Test (Recommended)

```powershell
node test_background_anxiety_detection.js
```

### Test Just Notifications

```powershell
node test_direct_notification.js
```

---

## 📱 Phone Setup for Testing

### For Maximum Realism:

1. **Close the AnxieEase Flutter app completely**
2. **Lock your phone screen**
3. **Keep phone nearby but don't touch it**
4. **Wait for notifications during testing**

### Notification Settings Check:

- ✅ Allow notifications from AnxieEase app
- ✅ Allow notifications when phone is locked
- ✅ Keep phone volume on or vibration enabled

---

## 🎯 What You're Testing

### Background Processing

- ✅ **Firebase Cloud Functions** process heart rate data automatically
- ✅ **Real-time anxiety detection** works without app open
- ✅ **FCM notifications** reach your phone when app is closed
- ✅ **Multi-user isolation** (only your assigned device triggers alerts for you)

### Anxiety Detection Logic

- ✅ **Personal baselines** (your 70 BPM baseline vs others)
- ✅ **Sustained detection** (must be 30+ seconds elevated)
- ✅ **Threshold calculation** (20% above your baseline = 84 BPM)
- ✅ **False positive prevention** (brief spikes don't trigger alerts)

---

## 🚨 Expected Test Results

### Background Test Timeline:

```
Step 1: ✅ Device assignment verified
Step 2: ✅ User profile setup
Step 3: ✅ Normal HR (75-79 BPM) - No alerts
Step 4: ✅ Brief elevation (88-93 BPM, 20s) - No alerts
Step 5: 🔔 SUSTAINED ANXIETY (90-98 BPM, 40s) - NOTIFICATION!
Step 6: ✅ Alert recorded in Firebase
```

### Success Criteria:

- 🔔 **You receive a notification during Step 5**
- ✅ **Console shows "anxiety alert created"**
- ✅ **No notifications during Steps 3-4** (false positive prevention)

---

## 🐛 Troubleshooting

### If No Notifications Received:

1. **Check FCM token is current:**

   - Restart Flutter app
   - Check console logs for new FCM token
   - Update `test_background_anxiety_detection.js` if token changed

2. **Verify Firebase Functions are running:**

   - Check Firebase Console → Functions
   - Look for `realTimeSustainedAnxietyDetection` function

3. **Test direct notifications first:**
   ```powershell
   node test_direct_notification.js
   ```

### If Getting False Positives:

- Check your baseline is set correctly (70 BPM)
- Verify anxiety threshold calculation (84 BPM)

---

## 📊 Understanding Your Results

### Normal Operation:

- **Heart rate < 84 BPM:** No anxiety detection
- **Brief spikes:** Ignored (< 30 seconds)
- **Sustained elevation:** Anxiety alert + notification

### Real-World Usage:

- Your wearable sends data continuously
- System monitors YOUR specific threshold (84 BPM)
- Only sustained anxiety episodes trigger alerts
- Notifications work even when app is closed

---

## 🎉 Ready to Test?

1. **Make sure your phone can receive notifications**
2. **Close the Flutter app completely**
3. **Run the background test:**
   ```powershell
   node test_background_anxiety_detection.js
   ```
4. **Wait for the notification during Step 5!**

The system is designed to work in the background, just like a real anxiety monitoring system should! 🎯
