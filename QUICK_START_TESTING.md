# 🚀 **QUICK START TESTING - STEP BY STEP**

## **Current Status**: Flutter is building after fixing Android SDK issue ✅

While your Flutter app is building, here's the exact order to test everything:

---

## **📱 Step 1: Get FCM Token (Once Flutter finishes building)**

**Wait for Flutter to finish building and launch on your device, then:**

1. **Look for this in the console logs**:
   ```
   🔑 FCM registration token: [VERY_LONG_TOKEN_HERE]
   ```
2. **Copy the ENTIRE token** (it's ~150+ characters long)
3. **Keep your phone/emulator nearby** for testing notifications

---

## **🧪 Step 2: Test Direct Notification (2 minutes)**

**This tests if FCM works at all:**

1. **Edit `test_direct_notification.js`**:

   ```javascript
   // Line 22: Replace with your copied FCM token
   const USER_FCM_TOKEN = "your_real_token_here";
   ```

2. **Run the test**:

   ```bash
   node test_direct_notification.js
   ```

3. **Expected result**: You get a test notification on your phone/emulator

---

## **🏥 Step 3: Admin Dashboard Setup**

**Only if direct notification worked:**

1. **Open `admin_dashboard.html` in browser**
2. **Update Supabase credentials** (if not done already)
3. **Login with admin account**
4. **Assign AnxieEase001** to a test user

---

## **🚨 Step 4: Full Anxiety Detection Test**

**The complete system test:**

1. **Get User ID** from admin dashboard (the UUID of assigned user)
2. **Edit `test_real_user_anxiety_detection.js`**:

   ```javascript
   // Line 29: Your FCM token from Step 1
   const USER_FCM_TOKEN = "your_real_token";

   // Line 30: User ID from admin dashboard
   const TEST_USER_ID = "uuid-from-admin-dashboard";
   ```

3. **Run the test**:

   ```bash
   node test_real_user_anxiety_detection.js
   ```

4. **Expected result**: You get an anxiety alert notification

---

## **🔍 Step 5: Debug Firebase Data (If Issues)**

**If notifications don't work:**

```bash
node debug_firebase_data.js
```

This shows you exactly what data is stored in Firebase.

---

## **⚡ Quick Commands Ready to Use**

**Once you have your FCM token:**

```bash
# Test 1: Direct notification
node test_direct_notification.js

# Test 2: Debug what's in Firebase
node debug_firebase_data.js

# Test 3: Full anxiety detection
node test_real_user_anxiety_detection.js
```

---

## **🎯 What to Expect**

### **✅ If Everything Works**:

1. Direct notification appears on your phone
2. Admin dashboard shows device assignment
3. Anxiety test sends personalized alert
4. Firebase shows user data under `/users/[USER_ID]/`

### **❌ Common Issues & Quick Fixes**:

- **No FCM token**: Check Flutter console logs
- **Token invalid**: Get fresh token from app
- **No notification**: Check phone notification settings
- **Wrong user ID**: Copy exact UUID from admin dashboard
- **Firebase empty**: Run tests first to create data

---

## **📱 Your Current Status**

✅ **Android SDK fixed** - Flutter should build successfully  
⏳ **Flutter building** - Wait for completion  
⏳ **FCM token needed** - Get from console logs once app launches  
⏳ **Ready for testing** - All scripts are prepared

**🚀 Once Flutter launches, just follow the 5 steps above in order!**
