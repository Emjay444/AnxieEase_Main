# Custom Notification Sounds Guide

## Step 1: Get Sound Files

Download or create 3 sound files:

1. **mild_alert.mp3** - Gentle notification sound (soft chime, bell)
2. **moderate_alert.mp3** - More noticeable sound (double beep, ding)
3. **severe_alert.mp3** - Urgent, attention-grabbing sound (alarm, siren, urgent beeping)

### Recommended Sound Types:
- **Mild**: Soft chime, gentle bell, water drop
- **Moderate**: Double beep, notification ding, soft alarm
- **Severe**: Alarm clock, siren, urgent beeping, emergency alert

### Sound Requirements:
- Format: `.mp3` or `.wav`
- Duration: 1-10 seconds (shorter is better)
- File size: Under 1MB each
- Quality: 44.1kHz, 16-bit (standard quality)

## Step 2: Add Files to Project

1. Place your sound files in this directory:
   ```
   AnxieEase_Main/android/app/src/main/res/raw/
   ```

2. Name them exactly:
   - `mild_alert.mp3`
   - `moderate_alert.mp3`
   - `severe_alert.mp3`

## Step 3: Update the Code

The code is already configured to use these files. Once you add them, the notifications will automatically use:

- **Mild alerts**: `mild_alert.mp3`
- **Moderate alerts**: `moderate_alert.mp3`
- **Severe alerts**: `severe_alert.mp3`

## Step 4: Test

1. Add the sound files
2. Run `flutter clean`
3. Run `flutter run`
4. Test notifications - they should now use your custom sounds!

## Free Sound Resources

### Websites:
- [Zedge](https://www.zedge.net/ringtones) - Free ringtones and notifications
- [Freesound](https://freesound.org/) - Creative Commons sounds
- [Notification Sounds](https://notificationsounds.com/) - Free notification sounds
- [Pixabay](https://pixabay.com/sound-effects/) - Free sound effects

### Search Terms:
- "notification sound"
- "alert sound"
- "alarm sound"
- "emergency alert"
- "beep sound"
- "chime sound"

## Example Sound Ideas

### Mild Alert:
- Soft bell chime
- Water drop sound
- Gentle ding
- Soft piano note

### Moderate Alert:
- Double beep
- Notification ding
- Soft alarm
- Phone ring tone (short)

### Severe Alert:
- Alarm clock sound
- Emergency siren
- Urgent beeping
- Fire alarm
- Medical alert sound

## Troubleshooting

If sounds don't work:
1. Check file names are exactly correct
2. Ensure files are in the right directory
3. Run `flutter clean` and rebuild
4. Check file format is supported (.mp3 or .wav)
5. Ensure files aren't corrupted
