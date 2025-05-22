# Quick Guide: Download Free Notification Sounds

## Option 1: Direct Download Links (Free Sounds)

### Mild Alert Sound (Gentle):
1. Go to: https://www.zedge.net/ringtones/categories/notification
2. Search for: "gentle chime" or "soft bell"
3. Download and rename to: `mild_alert.mp3`

### Moderate Alert Sound (Attention-grabbing):
1. Go to: https://freesound.org/search/?q=notification+beep
2. Search for: "double beep" or "notification ding"
3. Download and rename to: `moderate_alert.mp3`

### Severe Alert Sound (URGENT):
1. Go to: https://freesound.org/search/?q=alarm+urgent
2. Search for: "emergency alarm" or "urgent beep"
3. Download and rename to: `severe_alert.mp3`

## Option 2: Use Your Phone's Built-in Sounds

### Android:
1. Go to Settings > Sound > Notification sound
2. Record or copy the sounds you like
3. Convert to MP3 if needed

### iPhone:
1. Go to Settings > Sounds & Haptics > Text Tone
2. Use a screen recorder to capture the sounds
3. Convert to MP3

## Option 3: Create Your Own

### Using Audacity (Free):
1. Download Audacity: https://www.audacityteam.org/
2. Generate tones:
   - **Mild**: Generate > Tone > Sine wave, 800Hz, 0.5 seconds
   - **Moderate**: Generate > Tone > Square wave, 1000Hz, 1 second
   - **Severe**: Generate > Tone > Sawtooth wave, 1200Hz, 2 seconds
3. Export as MP3

## Quick Test Sounds (Copy these URLs):

### Free Sound Downloads:
- **Gentle Chime**: Search "notification gentle" on freesound.org
- **Double Beep**: Search "beep notification" on freesound.org  
- **Urgent Alarm**: Search "alarm urgent" on freesound.org

## After Downloading:

1. **Rename files** to exactly:
   - `mild_alert.mp3`
   - `moderate_alert.mp3`
   - `severe_alert.mp3`

2. **Place in directory**:
   ```
   AnxieEase_Main/android/app/src/main/res/raw/
   ```

3. **Replace the placeholder files** I created

4. **Test**:
   ```bash
   flutter clean
   flutter run
   ```

## File Requirements:
- Format: MP3 or WAV
- Duration: 1-10 seconds
- Size: Under 1MB each
- Quality: Standard (44.1kHz, 16-bit)

The sounds will automatically work once you replace the placeholder files!
