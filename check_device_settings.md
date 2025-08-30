# Device Settings Troubleshooting Checklist

## 🔴 CRITICAL: Check These Settings First

### 1. **Notification Permissions**

- Go to: **Settings > Apps > AnxieEase > Notifications**
- Ensure **"Allow notifications"** is ON
- Find **"Anxiety Alerts"** channel and ensure it's ON
- Set channel importance to **"High"** or **"Urgent"**
- Enable **"Show on lock screen"**

### 2. **Battery Optimization (MOST COMMON ISSUE)**

- Go to: **Settings > Apps > AnxieEase > Battery**
- Set to **"Unrestricted"** or **"Don't optimize"**
- OR: Settings > Battery > Battery Optimization > AnxieEase > Don't optimize

### 3. **Background App Restrictions**

- Settings > Apps > AnxieEase > Battery > Background activity: **ALLOW**
- Settings > Apps > AnxieEase > Mobile data & Wi-Fi > Background data: **ALLOW**

### 4. **Do Not Disturb**

- Check if DND is enabled
- If yes: Settings > Do Not Disturb > Apps > AnxieEase > Allow

## 📱 Manufacturer-Specific Settings

### Samsung Galaxy/One UI:

1. **Device Care**: Settings > Device care > Battery > Background usage limits
2. Remove AnxieEase from **"Sleeping apps"** list
3. Add AnxieEase to **"Never sleeping apps"**
4. Settings > Apps > AnxieEase > Battery > **"Allow background activity"**

### Xiaomi/MIUI:

1. **Security**: Settings > Apps > Manage apps > AnxieEase
2. **Autostart**: Enable
3. **Battery saver**: Choose apps > AnxieEase > No restrictions
4. **MIUI Optimization**: Settings > Additional settings > Developer options > Turn off MIUI optimization

### OnePlus/OxygenOS:

1. **Battery optimization**: Settings > Battery > Battery optimization
2. **Advanced optimization**: Settings > Battery > More battery settings > Advanced optimization
3. **Sleep standby optimization**: Turn OFF for AnxieEase

### Huawei/EMUI:

1. **App launch**: Settings > Apps > AnxieEase > App launch
2. **Manage manually**: Enable all three options:
   - Auto-launch
   - Secondary launch
   - Run in background

### Honor:

1. **Phone Manager**: Phone Manager > Protected apps > AnxieEase > Enable
2. **Ignore optimizations**: Settings > Apps > AnxieEase > Battery > Ignore optimizations

### Realme/ColorOS:

1. **App Auto-Start**: Settings > App management > App auto-start manager > AnxieEase > Enable
2. **High background app limit**: Settings > Battery > High background app limit > AnxieEase

## 🧪 Testing Steps

### Step 1: After Changing Settings

1. **Restart your device** (important!)
2. Open AnxieEase app once to refresh tokens
3. Close app completely (remove from recent apps)
4. Run: `node debug_fcm_step_by_step.js [your_fcm_token]`

### Step 2: Alternative Test Method

If still not working, test with Firebase Console:

1. Go to Firebase Console > Cloud Messaging
2. Click **"Send your first message"**
3. Target: **Single device** (paste your FCM token)
4. This bypasses all app code and tests pure FCM delivery

### Step 3: Check Google Play Services

1. **Update Google Play Services**: Play Store > My apps & games > Google Play Services
2. **Clear cache**: Settings > Apps > Google Play Services > Storage > Clear cache
3. **Restart device**

## 🔍 Advanced Debugging

### Check ADB Logs (if you have Android SDK):

```bash
adb logcat | grep -i "fcm\|firebase\|notification"
```

### Check Notification History:

- Settings > Notifications > Notification history (if available)
- Or Settings > Apps & notifications > Notifications > Notification history

### Test Notification Channels:

```bash
adb shell dumpsys notification
```

Look for your app's channels and their settings.

## ⚠️ Known Issues

### Android 12+ (API 31+):

- **Exact alarms**: May need special permission
- **Background restrictions**: Much more aggressive
- **Notification trampolines**: Restricted

### Common Manufacturer Issues:

- **Xiaomi**: Very aggressive battery optimization by default
- **Huawei**: No Google services on newer devices
- **Samsung**: Multiple battery optimization layers
- **OnePlus**: Gaming mode can block notifications

## 💡 Quick Fixes to Try

1. **Airplane mode toggle**: Turn on airplane mode for 10 seconds, then off
2. **Restart device**: Clears Android's notification cache
3. **Reinstall app**: Fresh start with permissions
4. **Test on different device**: Isolate if it's device-specific
5. **Test other apps**: See if other apps receive push notifications

## ✅ Success Indicators

You'll know it's working when:

- Direct token test shows notification immediately
- Topic test shows notification within 10 seconds
- Notifications appear even when app is force-closed
- Lock screen shows the notification

If none of these work after checking all settings, the issue might be:

- Device manufacturer restrictions
- Network/firewall blocking FCM
- Google Play Services issues
- Regional FCM restrictions


