# 🧪 AnxieEase IoT System Testing Guide

## 📋 Complete Testing Checklist

### **Phase 1: Pre-Test Setup**

#### 1.1 Flutter App Preparation

```bash
# Clean and rebuild the app
flutter clean
flutter pub get
flutter run --debug

# Check that the app builds without errors
flutter analyze
```

#### 1.2 Device Pairing Setup

1. **Bluetooth Pairing**:

   - Go to phone Settings → Bluetooth
   - Pair your ESP32 device (should appear as "ESP32_HealthMonitor")
   - Return to AnxieEase app

2. **Device Setup in App**:
   - Open AnxieEase app
   - Navigate to Watch tab
   - If not set up, tap "Set Up Device"
   - Select your paired ESP32 device
   - Complete setup process

#### 1.3 Firebase Configuration

```bash
# Get your FCM token from Flutter app logs
flutter run --debug
# Look for log: "🔑 FCM registration token: your_token_here"
# Copy this token to update comprehensive_iot_test.js
```

---

### **Phase 2: Component Testing**

#### 2.1 Bluetooth Connection Test

**Objective**: Verify Bluetooth connectivity and data reception

**Steps**:

1. Open AnxieEase app → Watch tab
2. Ensure IoT Gateway shows "Active"
3. Check for real-time sensor data updates
4. Verify heart rate, SpO2, battery data appears

**Expected Results**:

- ✅ Gateway status: "IoT Gateway Active - ESP32_HealthMonitor"
- ✅ Real-time data updates every 1-2 seconds
- ✅ Heart rate shows when device is worn
- ✅ Battery percentage updates

#### 2.2 Firebase Data Flow Test

**Objective**: Verify data reaches Firebase Realtime Database

**Steps**:

1. Open Firebase Console: https://console.firebase.google.com
2. Navigate to Realtime Database
3. Go to `/devices/AnxieEase001/current`
4. Watch for real-time data updates

**Expected Results**:

- ✅ Data updates in real-time
- ✅ Sensor data structure is correct
- ✅ Timestamps are current
- ✅ Anxiety detection data appears

#### 2.3 Automated IoT Testing

**Objective**: Run comprehensive automated tests

**Steps**:

```bash
# Run the comprehensive test suite
node comprehensive_iot_test.js

# Follow the interactive menu:
# 1. Choose option 2 for "Run Full Test Suite"
# 2. Keep your Flutter app open to see real-time updates
# 3. Watch for notifications on your device
```

**Expected Results**:

- ✅ All 5 test scenarios execute successfully
- ✅ Firebase data updates for each test
- ✅ Notifications appear for anxiety levels
- ✅ No errors in test console

---

### **Phase 3: System Integration Testing**

#### 3.1 Cloud Functions Test

**Objective**: Verify anxiety detection triggers notifications

**Manual Test**:

```javascript
# Run specific anxiety scenario tests
node comprehensive_iot_test.js
# Choose option 1 → Select "Severe Anxiety Attack"
# Watch for high-priority notification
```

**Expected Results**:

- ✅ Cloud Function processes data change
- ✅ FCM notification sent to device
- ✅ Notification appears with correct severity
- ✅ No duplicate notifications

#### 3.2 Background Persistence Test

**Objective**: Verify IoT gateway continues when app is backgrounded

**Steps**:

1. Start IoT Gateway in app
2. Verify data is flowing (Watch tab shows updates)
3. Press home button to background the app
4. Wait 2-3 minutes
5. Check Firebase Console for continued data updates
6. Return to app and verify connection still active

**Expected Results**:

- ✅ Data continues flowing when app is backgrounded
- ✅ Bluetooth connection remains stable
- ✅ Firebase updates continue
- ✅ App shows "Active" status when returned to

#### 3.3 App Termination Test

**Objective**: Verify system handles complete app closure

**Steps**:

1. Start IoT Gateway
2. Completely close AnxieEase app (swipe away from recent apps)
3. Check Firebase Console for 5 minutes
4. Restart app and check connection status

**Expected Results**:

- ✅ Android Service continues briefly after app closure
- ✅ Connection eventually times out (expected behavior)
- ✅ App auto-reconnects when restarted
- ✅ No data corruption or errors

---

### **Phase 4: Real-World Testing**

#### 4.1 Device Wearing Test

**Objective**: Test actual device wearing detection

**Steps**:

1. Put on the ESP32 health monitor device
2. Verify "Device Worn: true" in app
3. Remove device
4. Verify "Device Worn: false" and heart rate goes null

**Expected Results**:

- ✅ Wearing detection works accurately
- ✅ Heart rate data only when worn
- ✅ UI reflects wearing status correctly

#### 4.2 Range Testing

**Objective**: Test Bluetooth connection range and recovery

**Steps**:

1. Start with device close to phone
2. Gradually move device away until connection lost
3. Return device within range
4. Verify auto-reconnection

**Expected Results**:

- ✅ Connection lost at expected Bluetooth range (~10m)
- ✅ Auto-reconnection when back in range
- ✅ Data resumes flowing after reconnection
- ✅ Connection status updates correctly in UI

#### 4.3 Battery Monitoring Test

**Objective**: Verify battery level monitoring

**Steps**:

1. Monitor battery percentage in app
2. Verify it decreases over time
3. Check for low battery warnings (if implemented)

**Expected Results**:

- ✅ Battery percentage updates accurately
- ✅ Battery level reflects actual device state
- ✅ Low battery notifications (if configured)

---

### **Phase 5: Stress Testing**

#### 5.1 Rapid Data Generation Test

```javascript
# Test high-frequency data updates
node comprehensive_iot_test.js
# Choose option 2 and run multiple times rapidly
```

#### 5.2 Long Duration Test

**Objective**: Test system stability over extended periods

**Steps**:

1. Start IoT Gateway
2. Let system run for 2-4 hours
3. Monitor for memory leaks, crashes, or disconnections
4. Check Firebase data consistency

**Expected Results**:

- ✅ No memory leaks or crashes
- ✅ Stable connection over time
- ✅ Consistent data quality
- ✅ No duplicate notifications

---

### **Phase 6: Error Scenario Testing**

#### 6.1 Network Interruption Test

**Steps**:

1. Start IoT Gateway
2. Turn off WiFi/mobile data
3. Turn back on after 2 minutes
4. Verify system recovery

#### 6.2 Bluetooth Interference Test

**Steps**:

1. Start IoT Gateway
2. Turn Bluetooth off and on
3. Verify auto-reconnection
4. Test with other Bluetooth devices active

#### 6.3 Low Memory Test

**Steps**:

1. Open many apps to consume memory
2. Keep AnxieEase running
3. Verify IoT Gateway remains stable

---

## 🔧 **Troubleshooting Common Issues**

### **Issue**: No data appearing in app

**Solutions**:

1. Check Bluetooth pairing
2. Verify device is powered on
3. Check Firebase Console for data
4. Restart IoT Gateway

### **Issue**: Notifications not appearing

**Solutions**:

1. Check notification permissions
2. Verify FCM token in logs
3. Test with manual notification script
4. Check Cloud Functions logs

### **Issue**: Connection keeps dropping

**Solutions**:

1. Check Bluetooth range
2. Verify device battery level
3. Check for interference
4. Update device pairing

### **Issue**: Data appears delayed

**Solutions**:

1. Check network connection
2. Verify Firebase rules
3. Check for rate limiting
4. Monitor Cloud Functions execution time

---

## 📊 **Test Results Template**

```
=== ANXIEEASE IOT TESTING RESULTS ===
Date: ___________
Tester: ___________
App Version: ___________
Device: ___________

COMPONENT TESTS:
[ ] Bluetooth Connection: PASS/FAIL
[ ] Firebase Data Flow: PASS/FAIL
[ ] Cloud Functions: PASS/FAIL
[ ] FCM Notifications: PASS/FAIL

INTEGRATION TESTS:
[ ] Background Persistence: PASS/FAIL
[ ] App Termination Recovery: PASS/FAIL
[ ] Range Testing: PASS/FAIL
[ ] Battery Monitoring: PASS/FAIL

STRESS TESTS:
[ ] Rapid Data Generation: PASS/FAIL
[ ] Long Duration (2+ hours): PASS/FAIL
[ ] Network Interruption: PASS/FAIL
[ ] Bluetooth Interference: PASS/FAIL

NOTES:
_________________________________
_________________________________
```

Run these tests systematically to ensure your IoT system is robust and reliable! 🚀
