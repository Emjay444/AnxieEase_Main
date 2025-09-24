# 🧪 **COMPLETE STEP-BY-STEP REAL USER TESTING GUIDE**

## 🎯 **Testing Without Physical Device First**

### **Phase 1: Basic Notification Test (5 minutes)**

#### **Step 1A: Get User FCM Token**

1. **Run Flutter app** on your phone/emulator
2. **Login** with any test user account
3. **Check console logs** for:
   ```
   🔑 FCM registration token: [COPY_THIS_LONG_TOKEN]
   ```
4. **Copy the entire token** (it's very long, ~150+ characters)

#### **Step 1B: Test Direct FCM Notification**

1. **Create test file**: `test_direct_notification.js`

   ```javascript
   const admin = require("firebase-admin");
   const serviceAccount = require("./service-account-key.json");

   if (!admin.apps.length) {
     admin.initializeApp({
       credential: admin.credential.cert(serviceAccount),
       databaseURL:
         "https://anxiease-c855c-default-rtdb.asia-southeast1.firebasedatabase.app/",
     });
   }

   const messaging = admin.messaging();

   async function testDirectNotification() {
     const FCM_TOKEN = "PASTE_YOUR_TOKEN_HERE"; // Replace with real token

     const message = {
       token: FCM_TOKEN,
       notification: {
         title: "🧪 Test Notification",
         body: "If you see this, FCM is working perfectly!",
       },
       data: {
         type: "test",
         timestamp: Date.now().toString(),
       },
     };

     try {
       const response = await messaging.send(message);
       console.log("✅ Notification sent successfully:", response);
     } catch (error) {
       console.error("❌ Notification failed:", error);
     }
   }

   testDirectNotification();
   ```

2. **Replace** `PASTE_YOUR_TOKEN_HERE` with your real FCM token
3. **Run test**: `node test_direct_notification.js`
4. **Check your phone** - you should get a notification!

---

## 🏥 **Phase 2: Full Anxiety Detection Test (Without Device)**

### **Step 2A: Admin Dashboard Setup**

1. **Open** `admin_dashboard.html` in your browser
2. **Update Supabase credentials** in the file (lines 75-76):
   ```javascript
   const SUPABASE_URL = "https://your-actual-project.supabase.co";
   const SUPABASE_ANON_KEY = "your-actual-anon-key";
   ```
3. **Login** with your admin credentials
4. **Assign AnxieEase001** to a test user:
   - Select user from dropdown
   - Add notes: "Anxiety detection test"
   - Click "Assign Device"

### **Step 2B: Get User Information**

1. **Note the User ID** from admin dashboard (you'll see it in the assignment)
2. **Or check Supabase** → Authentication → Users → Copy the UUID
3. **Make sure** the user you assigned is the same one with the FCM token

### **Step 2C: Run Complete Anxiety Test**

1. **Edit** `test_real_user_anxiety_detection.js`:

   ```javascript
   // Line 29: Your real FCM token from Step 1A
   const USER_FCM_TOKEN = "your_real_fcm_token_here";

   // Line 30: The exact user ID from admin dashboard
   const TEST_USER_ID = "12345678-1234-1234-1234-123456789abc";
   ```

2. **Run the test**:

   ```bash
   node test_real_user_anxiety_detection.js
   ```

3. **Expected Output**:

   ```
   🎯 TESTING REAL USER ANXIETY DETECTION - ADMIN INTEGRATED
   ✅ Admin has assigned device to user: [USER_ID]
   ✅ FCM token stored for user
   ✅ User baseline set to 70 BPM (threshold: 84 BPM)
   🚨 SUSTAINED ANXIETY DETECTED! 30s at avg 97 BPM
   ✅ Notification sent successfully to user
   ```

4. **Check your phone** - you should get an anxiety alert notification!

---

## 📊 **Phase 3: View User History in Firebase**

### **Step 3A: Check Firebase Console**

1. **Go to** [Firebase Console](https://console.firebase.google.com)
2. **Select your project**: `anxiease-c855c` (or whatever yours is named)
3. **Click** "Realtime Database"
4. **Navigate to** these paths:

#### **User FCM Tokens**:

```
/users/[USER_ID]/fcmToken
```

#### **User Baselines**:

```
/users/[USER_ID]/baseline
```

#### **User Sessions**:

```
/users/[USER_ID]/sessions/
```

#### **User Anxiety Alerts**:

```
/users/[USER_ID]/anxiety_alerts/
```

#### **Device Assignments**:

```
/device_assignments/AnxieEase001
```

### **Step 3B: Firebase Database Structure**

Your data should look like this:

```json
{
  "users": {
    "12345-user-id-here": {
      "fcmToken": "fcm-token-here",
      "baseline": {
        "heartRate": 70,
        "timestamp": 1234567890,
        "source": "user_profile"
      },
      "sessions": {
        "session-1234567890": {
          "startTime": 1234567890,
          "deviceId": "AnxieEase001",
          "status": "active",
          "data": {
            "1234567890": {
              "heartRate": 97,
              "timestamp": 1234567890,
              "source": "AnxieEase001"
            }
          }
        }
      },
      "anxiety_alerts": {
        "alert-1234567890": {
          "severity": "moderate",
          "heartRate": 97,
          "duration": 35,
          "timestamp": 1234567890
        }
      }
    }
  },
  "device_assignments": {
    "AnxieEase001": {
      "userId": "12345-user-id-here",
      "assignedAt": 1234567890,
      "status": "active"
    }
  }
}
```

---

## 🔧 **Troubleshooting Common Issues**

### **❌ "No FCM token found"**

**Solution**:

1. Make sure user is logged into Flutter app
2. Check console logs for the FCM token
3. Verify token is stored in Firebase at `/users/[USER_ID]/fcmToken`

### **❌ "Device not assigned by admin"**

**Solution**:

1. Check admin dashboard shows assignment
2. Verify user ID matches exactly
3. Check `/device_assignments/AnxieEase001` in Firebase

### **❌ "Notification not received"**

**Solution**:

1. Test direct notification first (Step 1B)
2. Check phone notification settings
3. Verify FCM token is correct and recent

### **❌ "Can't see user data in Firebase"**

**Solution**:

1. Go to Firebase Console → Realtime Database
2. Make sure you're looking at the correct region (asia-southeast1)
3. Navigate to `/users/[exact-user-id]/`
4. Check Firebase rules allow reading

---

## 🎉 **Phase 4: With Real Device (Optional)**

### **Step 4A: Device Setup**

1. **Ensure AnxieEase001** is sending data to Firebase
2. **Check** `/devices/AnxieEase001/current` has live heart rate data
3. **Verify** device is sending data every 10 seconds

### **Step 4B: Real Sustained Anxiety**

1. **Wear the device** (assigned user)
2. **Do physical activity** to raise heart rate above 84 BPM
3. **Keep heart rate elevated** for 30+ continuous seconds
4. **Wait for notification** (should arrive within 2 minutes)

---

## 📱 **Expected Notification Examples**

### **Mild Anxiety (85-89 BPM)**:

```
🟡 Mild Anxiety Detected
Your heart rate was sustained at 87 BPM (24% above your baseline)
for 35s. Take a moment to breathe deeply.
```

### **Moderate Anxiety (90-99 BPM)**:

```
⚠️ Moderate Anxiety Detected
Your heart rate was elevated to 94 BPM (34% above your baseline)
for 40s. Take a moment to relax.
```

### **Severe Anxiety (100+ BPM)**:

```
🚨 Severe Anxiety Detected
Your heart rate was sustained at 105 BPM (50% above your baseline)
for 45s. Consider deep breathing exercises.
```

---

## ✅ **Success Checklist**

- [ ] **Direct FCM notification works** (Step 1B)
- [ ] **Admin can assign device** via dashboard
- [ ] **User FCM token stored** in Firebase
- [ ] **User baseline set** (70 BPM → 84 BPM threshold)
- [ ] **Anxiety test triggers** sustained detection
- [ ] **Push notification received** by assigned user
- [ ] **User data visible** in Firebase console
- [ ] **Other users isolated** (don't get alerts)

**🚀 Once all checkboxes are ✅, your system is production-ready for real users!**
