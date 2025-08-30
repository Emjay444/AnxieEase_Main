# Simple Firebase deployment guide

## 🚀 **DEPLOY CLOUD FUNCTIONS**

Your Cloud Functions are built but not deployed. Here's how to deploy them:

### **Method 1: Manual Deployment (Recommended)**

1. **Open a new PowerShell/Command Prompt**
2. **Navigate to your project root:**

   ```powershell
   cd "C:\Users\molin\OneDrive\Desktop\Capstone\AnxieEase\AnxieEase_Main"
   ```

3. **Login to Firebase (if not already logged in):**

   ```powershell
   npx firebase-tools login
   ```

4. **Set the project:**

   ```powershell
   npx firebase-tools use anxieease-sensors
   ```

5. **Deploy the functions:**
   ```powershell
   npx firebase-tools deploy --only functions
   ```

### **Method 2: Direct npm deployment**

1. **Navigate to functions directory:**

   ```powershell
   cd functions
   ```

2. **Deploy using npm:**
   ```powershell
   npx firebase-tools deploy --only functions --project anxieease-sensors
   ```

---

## 📱 **AFTER DEPLOYMENT**

### **Test Anxiety Alerts:**

1. Run: `node test_database_trigger.js`
2. Check your phone for notifications
3. Should receive notifications for mild, moderate, severe alerts

### **Test Wellness Reminders:**

1. Run: `node test_fcm_wellness_simple.js`
2. Should receive wellness reminder notifications

### **Verify in Firebase Console:**

1. Go to: https://console.firebase.google.com/project/anxieease-sensors/functions
2. Check if functions are listed and active

---

## 🔍 **TROUBLESHOOTING**

If deployment fails:

1. Check if you're logged into the correct Google account
2. Verify project permissions
3. Try: `npx firebase-tools login --reauth`

---

**Status**: ⏳ **READY TO DEPLOY**
**Next**: Run deployment commands above to fix notification system
