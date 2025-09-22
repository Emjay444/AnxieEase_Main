# AnxieEase Unified System - Environment Configuration Guide

This guide helps you set up the environment variables and configuration needed for the unified AnxieEase system connecting Flutter app, Firebase, Supabase, and web admin dashboard.

## Required Environment Variables

### 1. Firebase Configuration

#### For Firebase Functions:
```bash
firebase functions:config:set supabase.url="YOUR_SUPABASE_URL"
firebase functions:config:set supabase.service_role_key="YOUR_SUPABASE_SERVICE_ROLE_KEY"
firebase functions:config:set firebase.project_id="YOUR_FIREBASE_PROJECT_ID"
```

#### For Flutter App (lib/firebase_options.dart):
```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: "YOUR_FIREBASE_API_KEY",
  appId: "YOUR_FIREBASE_APP_ID",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  projectId: "YOUR_FIREBASE_PROJECT_ID",
  databaseURL: "https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com",
  storageBucket: "YOUR_PROJECT_ID.appspot.com",
);
```

### 2. Supabase Configuration

#### For Flutter App (create lib/supabase_config.dart):
```dart
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

#### For Web Admin Dashboard (create web_config.js):
```javascript
export const supabaseConfig = {
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY'
};

export const firebaseConfig = {
  apiKey: "YOUR_FIREBASE_API_KEY",
  authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
  databaseURL: "https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT_ID.appspot.com",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_FIREBASE_APP_ID"
};
```

## Supabase Database Setup

### Required Tables:

#### 1. user_profiles
```sql
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT UNIQUE NOT NULL,
  email TEXT,
  name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### 2. device_assignments
```sql
CREATE TABLE device_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  assigned_by TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance')),
  UNIQUE(device_id, user_id)
);
```

#### 3. device_analytics
```sql
CREATE TABLE device_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id TEXT NOT NULL,
  user_id TEXT,
  session_duration INTEGER,
  sensor_data_count INTEGER,
  emergency_alerts INTEGER DEFAULT 0,
  last_activity TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### 4. device_alerts
```sql
CREATE TABLE device_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id TEXT NOT NULL,
  user_id TEXT,
  alert_type TEXT NOT NULL,
  severity TEXT DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  message TEXT,
  sensor_data JSONB,
  acknowledged BOOLEAN DEFAULT FALSE,
  acknowledged_by TEXT,
  acknowledged_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### 5. admin_activity_logs
```sql
CREATE TABLE admin_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id TEXT NOT NULL,
  action TEXT NOT NULL,
  resource_type TEXT,
  resource_id TEXT,
  details JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Row Level Security (RLS) Policies:

```sql
-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_activity_logs ENABLE ROW LEVEL SECURITY;

-- Basic policies (adjust based on your authentication system)
CREATE POLICY "Users can view own profile" ON user_profiles FOR SELECT USING (auth.uid()::text = user_id);
CREATE POLICY "Users can update own profile" ON user_profiles FOR UPDATE USING (auth.uid()::text = user_id);

-- Admin policies (assuming admin role)
CREATE POLICY "Admins can view all" ON device_assignments FOR ALL USING (auth.jwt() ->> 'role' = 'admin');
CREATE POLICY "Admins can manage analytics" ON device_analytics FOR ALL USING (auth.jwt() ->> 'role' = 'admin');
CREATE POLICY "Admins can manage alerts" ON device_alerts FOR ALL USING (auth.jwt() ->> 'role' = 'admin');
```

## Firebase Realtime Database Structure

### Recommended Database Structure:
```json
{
  "device_sessions": {
    "DEVICE_ID": {
      "userId": "USER_ID",
      "status": "active",
      "startTime": 1234567890,
      "lastSensorUpdate": 1234567890,
      "sensorData": {
        "TIMESTAMP": {
          "heartRate": 75,
          "temperature": 36.5,
          "accelerometer": {"x": 0.1, "y": 0.2, "z": 0.9},
          "timestamp": 1234567890,
          "deviceId": "DEVICE_ID",
          "userId": "USER_ID"
        }
      }
    }
  },
  "emergency_alerts": {
    "ALERT_ID": {
      "deviceId": "DEVICE_ID",
      "userId": "USER_ID",
      "alertType": "panic_button",
      "sensorData": {...},
      "timestamp": 1234567890,
      "processed": false
    }
  }
}
```

### Firebase Realtime Database Rules:
```json
{
  "rules": {
    "device_sessions": {
      "$deviceId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    },
    "emergency_alerts": {
      ".read": "auth != null",
      ".write": "auth != null"
    }
  }
}
```

## Deployment Steps

### 1. Deploy Firebase Functions:
```bash
./deploy_firebase_functions.ps1
```

### 2. Deploy Web Admin Dashboard:
1. Update web configuration files with your credentials
2. Build and deploy to your hosting service (Vercel, Netlify, etc.)

### 3. Configure Flutter App:
1. Update `lib/firebase_options.dart` with your Firebase config
2. Create `lib/supabase_config.dart` with your Supabase config
3. Build and deploy your Flutter app

## Testing the Integration

### 1. Test Firebase Functions:
```bash
# Check function logs
firebase functions:log

# Test a specific function
curl -X POST https://YOUR_REGION-YOUR_PROJECT_ID.cloudfunctions.net/syncDeviceSession \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"test_device","userId":"test_user"}'
```

### 2. Test Web Dashboard:
1. Open your deployed web dashboard
2. Check Firebase connection status
3. Verify device management features
4. Test real-time data updates

### 3. Test Flutter App:
1. Initialize a device session
2. Send test sensor data
3. Trigger an emergency alert
4. Verify data appears in web dashboard

## Monitoring and Maintenance

### Firebase Console:
- Functions: https://console.firebase.google.com/project/YOUR_PROJECT_ID/functions
- Database: https://console.firebase.google.com/project/YOUR_PROJECT_ID/database

### Supabase Dashboard:
- Database: https://app.supabase.com/project/YOUR_PROJECT_ID/editor
- Auth: https://app.supabase.com/project/YOUR_PROJECT_ID/auth

### Logs and Monitoring:
- Firebase Functions logs: `firebase functions:log`
- Supabase logs: Available in Supabase dashboard
- Web dashboard: Browser developer tools

## Troubleshooting

### Common Issues:

1. **Firebase connection errors**: Check API keys and project ID
2. **Supabase RLS blocking requests**: Verify policies and authentication
3. **CORS issues**: Configure CORS settings in Firebase and Supabase
4. **Real-time updates not working**: Check WebSocket connections and subscriptions

### Debug Commands:
```bash
# Check Firebase project status
firebase projects:list

# Test Supabase connection
curl -X GET "YOUR_SUPABASE_URL/rest/v1/user_profiles?select=*" \
  -H "apikey: YOUR_SUPABASE_ANON_KEY"

# Check Flutter dependencies
flutter doctor
flutter pub deps
```