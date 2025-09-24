# 🔍 **FIREBASE USER HISTORY TROUBLESHOOTING GUIDE**

## ❌ **Why You Can't See User History in Firebase**

### **Common Reasons:**

1. **Wrong Database Region**: Your Firebase might be in a different region
2. **No Data Created Yet**: User history only appears after testing
3. **Wrong Database URL**: Using default instead of your project's URL
4. **Firebase Rules**: Read permissions might be restricted
5. **Looking in Wrong Place**: User data has specific paths

---

## 🔧 **Step-by-Step Fix**

### **Step 1: Verify Your Firebase Project**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Make sure you're in the correct project
3. Check project ID matches your code

### **Step 2: Check Database Region**

1. In Firebase Console → Realtime Database
2. Look at the URL - should be:
   ```
   https://anxiease-c855c-default-rtdb.asia-southeast1.firebasedatabase.app
   ```
3. If different, update your scripts to match

### **Step 3: Navigate to Correct Paths**

Instead of looking randomly, go directly to these paths:

#### **For User Data**:

```
📁 Root
  📁 users
    📁 [USER_ID] ← This is the UUID from Supabase/Admin dashboard
      📄 fcmToken: "token_here"
      📁 baseline
        📄 heartRate: 70
        📄 timestamp: 1234567890
      📁 sessions
        📁 session-1234567890
          📁 data
            📄 1234567890: {heartRate: 85, timestamp: 1234567890}
      📁 anxiety_alerts
        📁 alert-1234567890
          📄 severity: "moderate"
          📄 heartRate: 94
          📄 duration: 35
```

#### **For Device Assignments**:

```
📁 Root
  📁 device_assignments
    📁 AnxieEase001
      📄 userId: "12345-user-id"
      📄 assignedAt: 1234567890
      📄 status: "active"
```

#### **For Device Data** (if using physical device):

```
📁 Root
  📁 devices
    📁 AnxieEase001
      📁 current
        📄 heartRate: 75
        📄 timestamp: 1234567890
        📄 batteryLevel: 85
```

---

## 🧪 **Create Test Data to See**

### **Option 1: Run Direct Test**

```bash
# This will create user data you can see
node test_direct_notification.js

# Then run this to create full user history
node test_real_user_anxiety_detection.js
```

### **Option 2: Manual Data Creation**

If you want to create test data manually:

1. **Go to Firebase Console** → Realtime Database
2. **Click the "+" button** next to root
3. **Create this structure**:
   ```json
   {
     "users": {
       "test-user-123": {
         "fcmToken": "your_fcm_token_here",
         "baseline": {
           "heartRate": 70,
           "timestamp": 1234567890
         },
         "anxiety_alerts": {
           "alert-001": {
             "severity": "mild",
             "heartRate": 87,
             "duration": 35,
             "timestamp": 1234567890
           }
         }
       }
     }
   }
   ```

---

## 📊 **Verify Data Creation**

### **After Running Tests, Check These Paths**:

1. **User FCM Token**:

   ```
   /users/[your-user-id]/fcmToken
   ```

   Should contain: Long FCM token string

2. **User Baseline**:

   ```
   /users/[your-user-id]/baseline
   ```

   Should contain: `{heartRate: 70, timestamp: xxx, source: "user_profile"}`

3. **User Sessions**:

   ```
   /users/[your-user-id]/sessions/session-[timestamp]
   ```

   Should contain: Session data and heart rate readings

4. **Anxiety Alerts**:

   ```
   /users/[your-user-id]/anxiety_alerts/alert-[timestamp]
   ```

   Should contain: Anxiety detection results

5. **Device Assignment**:
   ```
   /device_assignments/AnxieEase001
   ```
   Should contain: `{userId: "your-user-id", assignedAt: xxx, status: "active"}`

---

## 🔍 **How to Find Your User ID**

### **Method 1: From Admin Dashboard**

1. Open admin dashboard
2. Assign device to user
3. Look at the assignment - user ID is shown

### **Method 2: From Supabase**

1. Go to Supabase Dashboard
2. Authentication → Users
3. Copy the UUID of your test user

### **Method 3: From Flutter App Logs**

If you're logging user info, check console for user ID

---

## ⚡ **Quick Debug Script**

Create `debug_firebase_data.js`:

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

const db = admin.database();

async function debugFirebaseData() {
  try {
    // Check users data
    const usersRef = db.ref("/users");
    const usersSnapshot = await usersRef.once("value");
    console.log("👥 Users data:", usersSnapshot.val());

    // Check device assignments
    const assignmentsRef = db.ref("/device_assignments");
    const assignmentsSnapshot = await assignmentsRef.once("value");
    console.log("📱 Device assignments:", assignmentsSnapshot.val());

    // Check device data
    const deviceRef = db.ref("/devices/AnxieEase001");
    const deviceSnapshot = await deviceRef.once("value");
    console.log("🔧 Device data:", deviceSnapshot.val());
  } catch (error) {
    console.error("❌ Debug failed:", error);
  }
}

debugFirebaseData();
```

Run: `node debug_firebase_data.js`

---

## ✅ **Expected Results After Testing**

After running the test scripts, you should see:

1. **Users section** with your user ID and data
2. **Device assignments** showing AnxieEase001 assigned to your user
3. **User sessions** with heart rate data
4. **Anxiety alerts** if sustained detection triggered

If you still don't see data, the issue is likely:

- Wrong user ID in scripts
- Firebase permissions
- Database region mismatch

**🔧 Follow the debug script above to identify the exact issue!**
