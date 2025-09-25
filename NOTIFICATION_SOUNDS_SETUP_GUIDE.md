# 🔔 Custom Notification Sounds Setup Guide

## Overview
Your AnxieEase app now supports custom notification sounds for different anxiety severity levels, helping users immediately understand the urgency of alerts.

## 🎵 Sound File Requirements

### File Specifications
- **Format**: MP3 (recommended) or WAV
- **Quality**: 44.1 kHz, 16-bit or higher
- **Duration**: 
  - Mild: 1-2 seconds
  - Moderate: 1-2 seconds  
  - Severe: 2-3 seconds
  - Critical: 3-5 seconds

### Volume Guidelines
- **Mild**: Gentle, non-startling (30-40% max volume)
- **Moderate**: Clear and noticeable (50-60% max volume)
- **Severe**: Attention-demanding (70-80% max volume)
- **Critical**: Emergency level (90-100% max volume)

## 📁 File Locations

You need to replace the placeholder files in these locations:

### Assets Directory (Flutter)
```
assets/audio/
├── mild_alert.mp3
├── moderate_alert.mp3
├── severe_alert.mp3
└── critical_alert.mp3
```

### Android Raw Resources
```
android/app/src/main/res/raw/
├── mild_alert.mp3
├── moderate_alert.mp3
├── severe_alert.mp3
└── critical_alert.mp3
```

### iOS Resources (if supporting iOS)
Add to `ios/Runner/` directory and update `Info.plist`

## 🎨 Sound Recommendations

### Mild Alerts 🟢
- **Style**: Gentle chime, soft bell, quiet notification tone
- **Examples**: Wind chime, soft piano note, gentle bell
- **Mood**: Calming, non-intrusive, supportive

### Moderate Alerts 🟠
- **Style**: Clear notification tone, attention-getting but not alarming
- **Examples**: Standard notification sound, clear bell, brief musical note
- **Mood**: Alert but not panic-inducing

### Severe Alerts 🔴
- **Style**: Urgent but supportive tone
- **Examples**: Firm notification, urgent bell, attention-demanding chime
- **Mood**: Serious attention required, but still supportive

### Critical Alerts 🚨
- **Style**: Emergency tone, immediate attention required
- **Examples**: Emergency alert, urgent alarm (but not panic-inducing)
- **Mood**: Immediate action needed, emergency support

## 🔧 Implementation Status

✅ **Completed Features:**
- Severity-specific notification channels
- Custom sound integration
- Different vibration patterns per severity
- Color-coded notifications
- Enhanced critical alert behaviors (full screen, wake screen)
- Test functionality for all sound types

✅ **Testing:**
- Use the NotificationSoundTester widget to test all sounds
- Individual severity testing available
- Automatic testing of all severities with delays

## 🎯 How It Works

### Client-Side (Flutter App)
1. **Channel Selection**: Each severity uses a dedicated notification channel
2. **Sound Mapping**: Severity levels map to specific sound files
3. **Behavior Control**: Critical/severe alerts have enhanced behaviors (wake screen, full screen intent)

### Server-Side (Firebase Cloud Functions)  
1. **FCM Integration**: Cloud Functions send notifications with severity-specific channels
2. **Sound Assignment**: Server specifies custom sound based on anxiety level
3. **Cross-Platform**: Works for both Android and iOS push notifications

## 📱 User Experience

### Sound Hierarchy
- **Mild**: "I should check this when convenient"
- **Moderate**: "This needs my attention soon"
- **Severe**: "I need to address this now"
- **Critical**: "This requires immediate action"

### Additional Features
- **Vibration Patterns**: Each severity has unique vibration
- **Visual Cues**: Color-coded notifications and LED colors
- **Action Buttons**: Severe/critical alerts include quick action buttons
- **Rate Limiting**: Prevents notification spam while respecting urgency

## 🔊 Testing Your Sounds

Run the notification sound tester:
```dart
// Add to your debug menu or create a test screen
NotificationSoundTester()
```

Or test programmatically:
```dart
final notificationService = NotificationService();
await notificationService.initialize();

// Test individual severity
await notificationService.testSeverityNotification('severe', 1);

// Test all severities
await notificationService.testAllSeverityNotifications();
```

## 📋 Next Steps

1. **Find/Create Sound Files**: Source or create MP3 files that match your app's therapeutic approach
2. **Replace Placeholders**: Replace the placeholder files with actual audio
3. **Test Extensively**: Use the testing tools to verify all sounds work correctly
4. **User Feedback**: Consider allowing users to customize or preview sounds in settings
5. **Accessibility**: Ensure sounds work well with hearing accessibility features

## 🎵 Sound Resources

### Free Sound Libraries
- **Freesound.org**: Community-driven sound library
- **Zapsplat**: Professional sound effects (free tier available)
- **OpenGameArt**: Open source audio resources
- **YouTube Audio Library**: Free sounds for projects

### Therapeutic Sound Guidelines
- Avoid harsh, jarring, or panic-inducing sounds
- Choose sounds that feel supportive rather than punitive
- Consider cultural sensitivity in sound selection
- Test with actual users experiencing anxiety for feedback

---

**Important**: The current placeholder files are just text files. You MUST replace them with actual MP3 audio files for the custom sounds to work!