# FCM Background Notification Troubleshooting Guide

## Your FCM Setup Status: ✅ PROPERLY CONFIGURED

Based on my analysis, your FCM setup is correctly configured:

### ✅ What's Working:
1. **FCM Token Generation**: Your app generates valid FCM tokens
2. **Topic Subscription**: Successfully subscribes to "anxiety_alerts" topic
3. **Background Handler**: Properly registered background message handler
4. **Android Manifest**: Correctly configured with all required permissions
5. **Cloud Functions**: Properly set up to send notifications on anxiety detection

### 🔧 Potential Issues & Solutions:

#### 1. **Android Battery Optimization**
Modern Android devices aggressively manage background apps. To ensure notifications work:

**Solution:**
1. Go to **Settings** > **Apps** > **AnxieEase**
2. Select **Battery** > **Battery Optimization**
3. Set to **"Don't optimize"** or **"Unrestricted"**
4. Also check **Background App Refresh** is enabled

#### 2. **Notification Channel Settings**
Your device might block notifications for the specific channel:

**Solution:**
1. Go to **Settings** > **Apps** > **AnxieEase** > **Notifications**
2. Ensure **"Anxiety Alerts"** channel is enabled
3. Set importance to **"High"** or **"Urgent"**
4. Enable **"Show on lock screen"**

#### 3. **Do Not Disturb Mode**
Your device's DND settings might block notifications:

**Solution:**
1. Check if **Do Not Disturb** is enabled
2. If needed, add AnxieEase to DND exceptions
3. Allow **"Alarms and other interruptions"**

#### 4. **Data/Network Issues**
FCM requires internet connection:

**Solution:**
1. Ensure device has stable internet (WiFi or mobile data)
2. Check if any VPN is blocking Google services
3. Verify Google Play Services is updated

### 🧪 How to Test:

#### Test 1: Direct FCM (App Closed)
```bash
node test_background_fcm.js
```
**Expected:** Notification appears even with app completely closed

#### Test 2: Cloud Function Trigger
```bash
node test_severity_notification.js moderate
```
**Expected:** Notification appears via Cloud Function automation

#### Test 3: Manual Cloud Function Test
```bash
node test_severity_notification.js severe
```
**Expected:** High-priority notification with alarm category

### 📱 Common Device-Specific Issues:

#### Samsung Devices:
- Check **"Put app to sleep"** settings
- Disable **"Adaptive battery"** for AnxieEase
- Enable **"Auto-start"** permissions

#### Xiaomi/MIUI:
- Go to **Security** > **Permissions** > **Autostart**
- Enable autostart for AnxieEase
- Disable **"Battery Optimization"**

#### OnePlus/OxygenOS:
- Check **"Battery optimization"**
- Enable **"Allow background activity"**
- Check **"Advanced optimization"** settings

#### Huawei:
- Go to **Settings** > **Apps** > **AnxieEase**
- Enable **"Manual management"** under Battery
- Allow **"Auto-launch"**, **"Secondary launch"**, **"Run in background"**

### 🔍 Debugging Steps:

1. **Check FCM Token**:
   - Look for this in your Flutter logs: `🔑 FCM registration token:`
   - If token is null, Google Play Services may need updating

2. **Check Topic Subscription**:
   - Look for: `✅ Subscribed to anxiety_alerts topic`
   - If failed, check network connectivity

3. **Check Background Service**:
   - Look for: `FlutterFirebaseMessagingBackgroundService started!`
   - If missing, background handler may not be registered

4. **Test Immediate Notification**:
   - Run the background test script while monitoring logs
   - Check if notification appears in status bar

### ⚠️ Known Limitations:

1. **Android 12+ Restrictions**: Newer Android versions heavily restrict background processing
2. **Manufacturer Modifications**: Some OEMs (Xiaomi, Huawei, etc.) have aggressive power management
3. **Doze Mode**: Android Doze mode can delay notifications by up to 15 minutes
4. **Network-dependent**: No internet = no FCM notifications

### 🚀 Recommended Testing Process:

1. **First**, test with app in foreground (should always work)
2. **Then**, test with app in background but still in recent apps
3. **Finally**, test with app completely closed (force-stopped)

If notifications work in steps 1-2 but not 3, it's likely a device power management issue.

### 💡 Pro Tips:

1. **High Priority**: Your severe alerts use high priority - these have the best chance of appearing
2. **Persistent Channels**: Your notification channels are properly configured for importance
3. **Wake Screen**: Severe alerts are configured to wake the device screen
4. **Critical Alerts**: iOS-style critical alerts are enabled for severe cases

## Status: Your FCM setup is correct! Issues are likely device-specific power management.
