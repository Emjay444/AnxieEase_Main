# Baseline Heart Rate Setup Requirement - Fixed

## Issue Identified

**Problem:** New users were receiving anxiety detection notifications (showing 70 BPM baseline) even though they hadn't set up their baseline heart rate yet.

**Root Cause:** The `realTimeSustainedAnxietyDetection` Cloud Function had a fallback that used a default baseline of **70 BPM** when no user baseline was found.

### Code Location

- **File:** `functions/src/realTimeSustainedAnxietyDetection.ts`
- **Function:** `getUserBaseline(userId, deviceId)`
- **Lines:** 1007-1008 (before fix)

## Fix Applied

### What Changed

**Before (Lines 1006-1008):**

```typescript
// For now, return a reasonable default based on age/demographics
console.log(`⚠️ No baseline found for user ${userId}, using default 70 BPM`);
return { baselineHR: 70 };
```

**After:**

```typescript
// No baseline found - user must set up baseline before anxiety detection
console.log(
  `⚠️ No baseline found for user ${userId} - anxiety detection disabled until baseline is set up`
);
return null;
```

### Impact

✅ **Fixed:** Users without a baseline will NO LONGER receive anxiety detection notifications
✅ **Improved:** System now properly requires baseline setup before anxiety detection
✅ **Better UX:** No false positives for new users who haven't calibrated their baseline

## How Baseline Setup Works

### For New Users

1. **Create Account** → User registers in the app
2. **Link Wearable Device** → User connects their AnxieEase wearable
3. **Set Up Baseline** → User must complete the baseline heart rate recording process
4. **Anxiety Detection Enabled** → Once baseline is set, detection starts working

### Baseline Recording Process

Users should:

1. Be at rest (sitting/lying down comfortably)
2. Record heart rate for **2-5 minutes** in a calm state
3. System calculates average resting heart rate
4. Baseline is stored in:
   - **Supabase:** `baseline_heart_rates` table
   - **Firebase RTDB:** `/devices/{deviceId}/assignment/supabaseSync/baselineHR`

### Detection Thresholds (Based on User's Baseline)

Once baseline is set, thresholds are calculated:

- **Elevated:** Baseline + 10 BPM
- **Mild:** Baseline + 15 BPM
- **Moderate:** Baseline + 25 BPM
- **Severe:** Baseline + 35 BPM
- **Critical:** Baseline + 45 BPM

### Example

If user's baseline = **65 BPM**:

- Elevated: 75 BPM
- Mild: 80 BPM
- Moderate: 90 BPM
- Severe: 100 BPM
- Critical: 110 BPM

If user's baseline = **80 BPM**:

- Elevated: 90 BPM
- Mild: 95 BPM
- Moderate: 105 BPM
- Severe: 115 BPM
- Critical: 125 BPM

## Deployment Status

✅ **TypeScript Updated:** `functions/src/realTimeSustainedAnxietyDetection.ts`
✅ **JavaScript Compiled:** `functions/lib/realTimeSustainedAnxietyDetection.js`
✅ **Deployed to Firebase:** Functions deployed to production

## Testing Recommendations

### Test Case 1: New User Without Baseline

1. Create a new account
2. Link wearable device
3. Send heart rate data to Firebase
4. **Expected:** No anxiety detection notifications (system logs should show "anxiety detection disabled until baseline is set up")

### Test Case 2: User With Baseline

1. User completes baseline setup
2. Send heart rate data above threshold
3. **Expected:** Anxiety detection notifications work correctly with personalized thresholds

### Test Case 3: Baseline Verification

Check Firebase logs for:

```
⚠️ No baseline found for user {userId} - anxiety detection disabled until baseline is set up
```

Or for users with baseline:

```
📊 Found user baseline: {XX} BPM from device assignment
```

## Related Files

### Cloud Functions

- `functions/src/realTimeSustainedAnxietyDetection.ts` - Main detection logic
- `functions/src/personalizedAnxietyDetection.ts` - Personalized thresholds (also has proper null check)
- `functions/src/multiParameterAnxietyDetection.ts` - Multi-parameter detection (also has proper null check)

### App Files (Baseline Recording)

- `lib/services/device_service.dart` - Device management and baseline recording
- `lib/models/baseline_heart_rate.dart` - Baseline data model
- `lib/services/supabase_service.dart` - Baseline storage in Supabase

## Important Notes

⚠️ **Migration:** Existing users who already have baselines set up will NOT be affected by this change. The fix only prevents new users from getting false detections.

⚠️ **User Education:** Ensure users understand they MUST complete baseline setup before anxiety detection will work.

✅ **Security:** This change improves the reliability and accuracy of anxiety detection by ensuring personalized thresholds are always used.

## Date Fixed

October 24, 2025

## Technical Details

### Function Flow (After Fix)

```
1. Heart rate data arrives → realTimeSustainedAnxietyDetection triggers
2. Check device assignment → Get userId
3. Call getUserBaseline(userId, deviceId)
   ├─ Check: /devices/{deviceId}/assignment/supabaseSync/baselineHR
   ├─ Fallback: /users/{userId}/baseline/heartRate
   └─ If both fail → Return NULL (was: Return 70 BPM)
4. If baseline is NULL:
   └─ Log warning and EXIT (no detection)
5. If baseline exists:
   └─ Calculate thresholds and proceed with detection
```

This ensures **no anxiety detection happens without proper baseline calibration**.
