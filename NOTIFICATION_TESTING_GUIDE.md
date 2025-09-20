## 🧪 **TESTING YOUR ANXIETY DETECTION NOTIFICATIONS**

### **The Issue:** 
You're clicking "Simulate 30s HR" but not receiving notifications, only the "Test Notification" button works.

### **What I Fixed:**
1. ✅ **Connected sustained HR detection to notification system**
2. ✅ **Made sure anxiety detection triggers real notifications**
3. ✅ **Fixed the 30-second simulation to call notification system**

### **How to Test Notifications Now:**

#### **🎯 Method 1: Using Sustained HR Simulation**

1. **Open your AnxieEase app**
2. **Go to Settings → Developer Test**
3. **Set up anxiety conditions:**
   ```
   Heart Rate: 90 bpm
   Baseline HR: 70 bpm (90 is 28% above 70 = triggers anxiety)
   SpO2: 96%
   Movement: 0.4
   ```
4. **Tap "⏱️ Simulate 30s HR"**
5. **Expected:** After simulation completes, you should get a notification!

#### **🎯 Method 2: Using Preset Buttons (Recommended)**

**Test Mild Anxiety:**
- Tap **"Mild Anxiety"** preset button
- Should trigger: Confirmation-type notification (60-79% confidence)

**Test Panic Attack:**
- Tap **"Panic Attack"** preset button  
- Should trigger: Immediate alert notification (80%+ confidence)

**Test Critical SpO2:**
- Tap **"Critical SpO2"** preset button
- Should trigger: Emergency notification (100% confidence)

#### **🎯 Method 3: Manual Detection**

1. **Set these values manually:**
   ```
   For High Anxiety Detection:
   Heart Rate: 105 bpm  
   Baseline HR: 70 bpm (105 is 50% above 70)
   SpO2: 94%
   Movement: 0.7
   ```
2. **Tap "🔍 Run Detection"**
3. **Should get immediate notification**

### **📱 What to Look For:**

**After triggering anxiety detection, you should see:**
1. **In the test log:** "🔔 Anxiety detected... sending notification"
2. **Device notification:** Pull down notification panel to see alert
3. **Notification sound/vibration** (if enabled)

### **🔍 Troubleshooting If Still No Notifications:**

**Check App Permissions:**
1. Go to Android Settings → Apps → AnxieEase
2. Check "Notifications" are enabled
3. Ensure "Anxiety Alerts" channel is enabled

**Check "Do Not Disturb":**
- Make sure Do Not Disturb mode is OFF
- Check if sound/vibration is enabled

**Verify Anxiety Detection:**
- HR must be **20%+ above baseline** to trigger
- For 70 bpm baseline: need 84+ bpm to trigger anxiety
- Use values like: HR=90, Baseline=70 (28% increase)

### **✅ Expected Behavior:**

**The notifications should now work because:**
1. 🔄 Sustained HR simulation → Calls anxiety detection → Sends notification
2. 📋 Preset buttons → Run sustained simulation → Sends notification  
3. 🔍 Manual detection → If anxiety detected → Sends notification

**Try the "Panic Attack" preset button first - it should definitely send a notification!** 🚨