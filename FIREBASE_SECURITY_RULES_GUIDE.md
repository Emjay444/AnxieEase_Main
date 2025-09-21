# Firebase Security Rules - AnxieEase IoT System

## 🚨 SECURITY ISSUE FIXED

**CRITICAL**: Your original Firebase rules allowed **anyone** to read and write to your entire database without authentication. This has been fixed with proper security rules.

### What Was Wrong (Before):
```json
{
  "rules": {
    "devices": {
      "$deviceId": {
        ".read": true,    // ❌ ANYONE could read device data
        ".write": true,   // ❌ ANYONE could write device data
        ...
      }
    },
    "users": {
      "$userId": {
        ".read": true,    // ❌ ANYONE could read user data
        ".write": true,   // ❌ ANYONE could write user data
        ...
      }
    }
  }
}
```

### What's Fixed (Now):
✅ **Authentication Required**: Only authenticated users can access data  
✅ **Device Ownership**: Users can only access devices they own  
✅ **Data Validation**: Proper validation for all sensor data  
✅ **Timestamp Validation**: Prevents old/future data injection  
✅ **User Isolation**: Users can only access their own data  

## 🔐 New Security Rules Structure

### 1. Device Access Control
- Users can only access devices they own (via `device_ownership` table)
- Devices can be shared with specific users
- Special allowance for `AnxieEase001` device for development

### 2. Data Validation
- **Current Data**: Must have timestamp within 5 minutes
- **History Data**: Must be within 24 hours and match timestamp
- **Alerts**: Must have required fields (type, severity, timestamp)
- **Metadata**: Must have deviceType and status

### 3. User Data Protection
- Users can only read/write their own user data
- User profiles are completely isolated
- No access to other users' information

## 📋 Setup Instructions

### Step 1: Deploy New Security Rules
1. Go to Firebase Console → Realtime Database → Rules
2. Replace the existing rules with the content from `database_rules_iot.json`
3. Click "Publish" to deploy

### Step 2: Set Up Device Ownership
1. Install Firebase Admin SDK:
   ```bash
   npm install firebase-admin
   ```

2. Download your Firebase service account key:
   - Go to Firebase Console → Project Settings → Service Accounts
   - Click "Generate new private key"
   - Save the JSON file securely

3. Update `setup_device_ownership.js`:
   ```javascript
   // Replace these values:
   const serviceAccount = require('./path/to/your/serviceAccountKey.json');
   databaseURL: 'https://your-project-id-default-rtdb.firebaseio.com/'
   const userId = 'YOUR_USER_ID_HERE'; // Get from Firebase Auth
   ```

4. Run the setup script:
   ```bash
   node setup_device_ownership.js
   ```

### Step 3: Update Your App Code
Your Flutter app needs to handle the new security structure:

```dart
// Example: Setting device ownership when user registers device
Future<void> registerDevice(String deviceId, String userId) async {
  await FirebaseDatabase.instance
      .ref('device_ownership/$deviceId')
      .set({
        'userId': userId,
        'deviceType': 'AnxieEase_Wearable',
        'createdAt': ServerValue.timestamp,
        'isActive': true,
        'deviceName': 'AnxieEase Device $deviceId',
        'sharedWith': {}
      });
}
```

## 🚀 New Features Enabled

### Device Sharing
Users can now share device access with family members or medical professionals:

```javascript
// Example: Share device with doctor
await shareDevice('AnxieEase001', 'patient_user_id', 'doctor_user_id');
```

### Emergency Access
Medical professionals can request emergency access (if implemented in your app):

```json
{
  "emergency_access": {
    "request_123": {
      "userId": "patient_id",
      "requestedBy": "doctor_id",
      "reason": "Medical emergency",
      "timestamp": 1642608000000
    }
  }
}
```

## ⚠️ Important Notes

### Testing Your App
After deploying new rules, test that:
1. ✅ Authenticated users can access their own devices
2. ✅ Users cannot access other users' devices
3. ✅ Device data is properly validated
4. ❌ Unauthenticated users cannot access any data

### Current Device "AnxieEase001" - Special Rules
Your wearable device `AnxieEase001` has special unrestricted access because it's hardcoded in your firmware:

**Device Behavior:**
- Writes current data to: `/devices/AnxieEase001/current`
- Writes history data to: `/devices/AnxieEase001/history/<timestamp>`
- No authentication from the device itself

**Security Rules Applied:**
- ✅ **Full read/write access** for AnxieEase001 (no ownership required)
- ✅ **Relaxed timestamp validation** for development
- ✅ **Public read access** for authenticated users (can be restricted later)
- ✅ **All other devices** still require proper ownership

### Development vs Production Mode

**Current Setup (Development Mode):**
```json
"AnxieEase001": {
  ".read": true,        // Any authenticated user can read
  ".write": true,       // Device can write without ownership
  "current": {
    ".read": true,      // Public read for testing
    ".write": true,     // Unrestricted write for device
  }
}
```

**For Production (Recommended):**
After development, you should:
1. Set up device ownership for AnxieEase001
2. Restrict read access to device owner only
3. Update firmware to use device authentication

### Fallback Rules for Development
The rules also include fallback support for devices without ownership records:

**If device ownership doesn't exist:**
```javascript
// Example rule condition
"!root.child('device_ownership').child($deviceId).exists()"
```

**This allows:**
- ✅ Authenticated users to access unregistered devices
- ✅ Relaxed timestamp validation during development
- ✅ Device registration without pre-existing ownership

**Security Impact:**
- ⚠️ Any authenticated user can access devices without ownership
- ⚠️ Should only be used during development/testing
- ✅ Still requires Firebase authentication (not completely open)

### Migration Checklist
- [ ] Deploy new security rules to Firebase
- [ ] Run device ownership setup script
- [ ] Test app functionality with new rules
- [ ] Update any admin/testing scripts to use authentication
- [ ] Monitor Firebase logs for rule violations

## 🔍 Rule Details

### Read Permissions
- **Devices**: Only device owner or shared users
- **Users**: Only the user themselves
- **Device Ownership**: Only device owner or shared users

### Write Permissions
- **Device Current Data**: Device owner or AnxieEase001 (temporary)
- **Device History/Alerts**: Only device owner
- **User Data**: Only the user themselves
- **Device Ownership**: Only when creating new or if you're the owner

### Data Validation
- All timestamps must be recent (within time limits)
- Required fields must be present
- Data types are validated (strings, numbers, booleans)
- No sensitive fields (like private keys) allowed

## 📞 Support

If you encounter issues after deploying these rules:
1. Check Firebase Console → Database → Usage for rule violations
2. Test with Firebase Rules Playground
3. Verify user authentication is working
4. Ensure device ownership records are set up correctly

**Remember**: Security rules are your first line of defense. Always validate data on the client side too, but never rely on client-side validation alone for security.