# 🧪 **Custom Notification Sounds Testing Guide**

## **Quick Start - What to Test Right Now**

### **🚀 Option 1: In-App Testing (Easiest)**

1. **Run your Flutter app**:
   ```bash
   flutter run
   ```

2. **Look for the notification bell icon** (🔔) in your Health Dashboard app bar

3. **Tap the notification icon** → Choose a test option:
   - Individual buttons for each severity
   - "Test All" to hear all 4 sounds with 2-second delays
   - "Open Full Tester" for advanced testing

### **🚀 Option 2: Node.js Server Testing**

```bash
# Test all severity sounds (3 seconds apart)
node test_server_notifications.js

# Test individual severity
node test_server_notifications.js mild
node test_server_notifications.js moderate  
node test_server_notifications.js severe
node test_server_notifications.js critical
```

### **🚀 Option 3: Flutter Test Script**

```bash
# Run the dedicated test script
flutter run lib/test_notification_sounds.dart
```

---

## **📱 What You Should See/Hear**

When testing, you'll get **4 different notification experiences**:

### **🟢 Mild Alert**
- **Sound**: Gentle chime (from `mild_alert.mp3`)
- **Color**: Light green notification
- **Behavior**: Standard notification
- **Message**: "Testing gentle notification sound..."

### **🟠 Moderate Alert** 
- **Sound**: Clear notification tone (from `moderate_alert.mp3`)
- **Color**: Orange notification
- **Behavior**: Higher priority, more noticeable
- **Message**: "Testing medium priority sound..."

### **🔴 Severe Alert**
- **Sound**: Urgent tone (from `severe_alert.mp3`) 
- **Color**: Red notification
- **Behavior**: High priority, wake screen, action buttons
- **Actions**: "I'm OK" and "Open App" buttons

### **🚨 Critical Alert**
- **Sound**: Emergency tone (from `critical_alert.mp3`)
- **Color**: Dark red notification  
- **Behavior**: Maximum priority, full screen intent, emergency actions
- **Actions**: "I'm OK", "Open App", and "Get Help" buttons

---

## **🔧 Troubleshooting**

### **No Sound Playing?**

1. **Check device volume** - Turn up notification volume
2. **Disable Do Not Disturb** - Check notification settings
3. **Grant permissions** - Allow notifications for AnxieEase
4. **Replace sound files** - Current files are placeholders (see below)

### **Notifications Not Appearing?**

```bash
# Check notification permissions
flutter run
# Grant all notification permissions when prompted
```

### **Same Sound for All Severities?**

**This is expected!** The current sound files are just placeholders. You need to replace them with actual MP3 files.

---

## **📁 Replace Placeholder Sound Files**

### **Current Placeholder Locations**:
```
assets/audio/
├── mild_alert.mp3     ← Replace with gentle chime
├── moderate_alert.mp3 ← Replace with clear tone  
├── severe_alert.mp3   ← Replace with urgent sound
└── critical_alert.mp3 ← Replace with emergency tone

android/app/src/main/res/raw/
├── mild_alert.mp3     ← Replace with same files
├── moderate_alert.mp3
├── severe_alert.mp3
└── critical_alert.mp3
```

### **Sound Requirements**:
- **Format**: MP3 or WAV
- **Duration**: 1-5 seconds 
- **Quality**: 44.1 kHz, 16-bit minimum
- **Volume**: Appropriate for each severity level

---

## **🎯 Advanced Testing**

### **Test Real Anxiety Detection**

To test with your actual IoT sensor data:

1. **Increase your heart rate** to 89+ BPM (light exercise, then sit still)
2. **Wait 30 seconds** for sustained detection
3. **Listen for the appropriate severity sound** based on your heart rate elevation

### **Test Firebase Cloud Functions**

```bash
# This tests the server-side notification system
node test_server_notifications.js severe your_user_id
```

### **Test Rate Limiting**

```bash
# Send multiple of the same severity quickly
node test_server_notifications.js severe
node test_server_notifications.js severe  # Should be rate limited
```

### **Test Notification Channels**

Each severity uses a different Android notification channel, so you can:
1. Go to Android Settings → Apps → AnxieEase → Notifications
2. See separate channels for each severity level
3. Customize sound/vibration per channel if desired

---

## **🔍 What to Verify**

### **✅ Checklist When Testing**

- [ ] **Four different notification sounds** (even if placeholders)
- [ ] **Different notification colors** (green, orange, red, dark red)
- [ ] **Severe/Critical have action buttons** ("I'm OK", "Open App", "Get Help")
- [ ] **Critical notifications are full screen** (if device locked)
- [ ] **Notifications appear in notification panel**
- [ ] **Rate limiting works** (duplicate notifications blocked)
- [ ] **Notifications stored in app** (check notifications screen)

### **📊 Expected Results**

```
🟢 Mild:     Gentle → Standard notification
🟠 Moderate: Clear  → High priority notification  
🔴 Severe:   Urgent → Wake screen + action buttons
🚨 Critical: Emergency → Full screen + emergency actions
```

---

## **🚨 Common Issues & Solutions**

### **"No sound files found"**
- **Solution**: Replace placeholder files with actual MP3 files

### **"Same sound for all"** 
- **Solution**: This is normal with placeholders - replace with different sounds

### **"Permission denied"**
- **Solution**: Grant notification permissions in device settings

### **"Firebase Admin error"**
- **Solution**: Make sure `service-account-key.json` exists for Node.js tests

### **"Channel not found"**
- **Solution**: Restart app to reinitialize notification channels

---

## **🎵 Next Steps**

1. **Test the system** with current placeholder files
2. **Verify all 4 severity levels** have different behaviors  
3. **Find/create actual MP3 sound files** that match your app's therapeutic approach
4. **Replace placeholder files** with real audio
5. **Test again** to hear the custom sounds
6. **Get user feedback** on sound appropriateness
7. **Consider user customization** (let users preview/choose sounds)

---

**🎯 TL;DR**: Tap the 🔔 bell icon in your Health Dashboard app bar and test all the sounds! Replace the placeholder MP3 files with real audio when you're ready.