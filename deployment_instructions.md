# Firebase Multi-User Device Testing Setup

## 🎯 Solution Overview

This setup allows multiple users to test your single physical wearable device (`AnxieEase001`) while keeping their data completely separated. When an admin assigns the device to a user, all subsequent device data is automatically copied to that user's personal session history.

## 📁 File Structure

```
functions/
├── src/
│   ├── deviceDataCopyService.ts     # Main Cloud Functions
│   └── index.ts                     # Export functions
├── package.json
└── firebase.json

project-root/
├── firebase_database_schema.json    # Database structure reference
├── admin_device_assignment_helpers.js # Admin utility functions
└── deployment_instructions.md       # This file
```

## 🚀 Deployment Steps

### 1. Install Firebase CLI (if not already installed)
```bash
npm install -g firebase-tools
firebase login
```

### 2. Initialize Firebase Functions (if not already done)
```bash
cd /your/project/root
firebase init functions
# Select TypeScript
# Install dependencies
```

### 3. Install Required Dependencies
```bash
cd functions
npm install firebase-functions firebase-admin
npm install --save-dev @types/node typescript
```

### 4. Add the Cloud Functions

Copy the content from `deviceDataCopyService.ts` to your `functions/src/` directory.

Update your `functions/src/index.ts`:
```typescript
// Export all functions from deviceDataCopyService
export {
  copyDeviceDataToUserSession,
  copyDeviceCurrentToUserSession,
  assignDeviceToUser,
  getDeviceAssignment,
  cleanupOldSessions
} from './deviceDataCopyService';
```

### 5. Configure TypeScript (functions/tsconfig.json)
```json
{
  "compilerOptions": {
    "module": "commonjs",
    "noImplicitReturns": true,
    "noUnusedLocals": false,
    "outDir": "lib",
    "sourceMap": true,
    "strict": true,
    "target": "es2017",
    "resolveJsonModule": true,
    "skipLibCheck": true
  },
  "compileOnSave": true,
  "include": [
    "src"
  ]
}
```

### 6. Deploy the Functions
```bash
firebase deploy --only functions
```

### 7. Update Database Security Rules

Add these rules to your `database.rules.json`:

```json
{
  "rules": {
    "devices": {
      "AnxieEase001": {
        "assignment": {
          ".read": "auth != null",
          ".write": "auth != null && auth.token.admin == true"
        },
        "current": {
          ".read": "auth != null",
          ".write": true
        },
        "history": {
          ".read": "auth != null",
          ".write": true
        }
      }
    },
    "users": {
      "$userId": {
        ".read": "auth != null && (auth.uid == $userId || auth.token.admin == true)",
        ".write": "auth != null && (auth.uid == $userId || auth.token.admin == true)",
        "sessions": {
          "$sessionId": {
            ".validate": "newData.hasChildren(['metadata']) && newData.child('metadata').hasChildren(['deviceId', 'startTime'])"
          }
        }
      }
    },
    "system": {
      ".read": "auth != null && auth.token.admin == true",
      ".write": "auth != null && auth.token.admin == true"
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only database
```

## 📊 How It Works

### 1. Device Assignment Flow
```
Admin → assignDeviceToUser() → /devices/AnxieEase001/assignment
                            → /users/{userId}/sessions/{sessionId}/metadata
```

### 2. Data Copy Flow  
```
Wearable Device → /devices/AnxieEase001/history/{timestamp}
                ↓ (Cloud Function Trigger)
                → /users/{userId}/sessions/{sessionId}/history/{timestamp}
```

### 3. Real-time Updates
```
Wearable Device → /devices/AnxieEase001/current
                ↓ (Cloud Function Trigger)  
                → /users/{userId}/sessions/{sessionId}/current
```

## 🔧 Admin Usage Examples

### Assign Device to User
```javascript
// In your admin interface
await assignDeviceToUser('user_123', 'session_456', 'Testing anxiety monitoring');
```

### Check Assignment Status
```javascript
const status = await getDeviceAssignmentStatus();
console.log(status.assignedUser); // "user_123"
```

### Unassign Device
```javascript
await unassignDevice();
```

### Listen to User Data in Real-time
```javascript
listenToUserSession('user_123', 'session_456', (sessionData) => {
  console.log('Latest heart rate:', sessionData.current.heartRate);
  console.log('Total data points:', sessionData.metadata.totalDataPoints);
});
```

## 🛡️ Security Features

- ✅ **Admin-only assignment**: Only authenticated admins can assign/unassign devices
- ✅ **User data isolation**: Users can only access their own session data
- ✅ **Automatic cleanup**: Old completed sessions are automatically deleted after 30 days
- ✅ **Error logging**: All errors are logged to `/system/errors` for debugging
- ✅ **Data validation**: All copied data includes metadata for traceability

## 📈 Benefits

1. **Data Separation**: Each user gets their own complete dataset
2. **Real-time Sync**: User data updates automatically when device sends data
3. **Session Management**: Complete session lifecycle tracking
4. **Analytics Ready**: Data structure supports easy analytics computation
5. **Scalable**: Can easily support multiple devices in the future
6. **Admin Control**: Full administrative control over device assignments

## 🔍 Monitoring & Debugging

### Check Function Logs
```bash
firebase functions:log
```

### Monitor Real-time Database
Go to Firebase Console → Realtime Database to see data flow in real-time.

### View Error Logs
Check `/system/errors` in your database for any copy failures.

## 🚨 Troubleshooting

### Function Not Triggering
1. Check function deployment: `firebase functions:list`
2. Verify database rules allow writes to `/devices/AnxieEase001/history`
3. Check function logs for errors

### Data Not Copying
1. Verify device assignment exists: `/devices/AnxieEase001/assignment`
2. Check user session exists: `/users/{userId}/sessions/{sessionId}`
3. Look for errors in `/system/errors`

### Permission Errors
1. Ensure admin users have `admin: true` custom claim
2. Verify database rules are deployed correctly
3. Check authentication tokens in function context

## 📞 Support

If you encounter issues:
1. Check Firebase Functions logs
2. Verify database rules
3. Test with the provided helper functions
4. Check network connectivity for device data writes