# 🔧 Fix: Baseline Not Syncing from Supabase to Firebase

## Problem

After setting up your baseline in the app, it's saved to Supabase's `baseline_heart_rates` table, but **Firebase still shows `baseline_hr: null`** under `/devices/{deviceId}/assignment/supabaseSync/`.

## Root Cause

There's no automatic sync mechanism between:

- **Supabase `baseline_heart_rates` table** → **Firebase `/devices/{deviceId}/assignment/supabaseSync/baselineHR`**

## Solution Options

### ✅ **Option 1: Use Database Trigger (RECOMMENDED - Simplest)**

This automatically updates `wearable_devices.baseline_hr` when you record a baseline, which then syncs to Firebase via the existing webhook.

#### Steps:

1. **Run this SQL in Supabase SQL Editor:**

```sql
-- File: supabase/sync_baseline_to_devices_table.sql
-- Run in Supabase Dashboard → SQL Editor

CREATE OR REPLACE FUNCTION update_device_baseline_on_change()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE wearable_devices
  SET
    baseline_hr = NEW.baseline_hr,
    baseline_updated_at = NOW(),
    updated_at = NOW()
  WHERE
    device_id = NEW.device_id
    AND user_id = NEW.user_id;

  RAISE NOTICE 'Updated baseline for device % to % BPM', NEW.device_id, NEW.baseline_hr;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_update_device_baseline
  AFTER INSERT OR UPDATE ON baseline_heart_rates
  FOR EACH ROW
  WHEN (NEW.is_active = true)
  EXECUTE FUNCTION update_device_baseline_on_change();
```

2. **Manually sync existing baselines (one-time):**

```sql
UPDATE wearable_devices wd
SET
  baseline_hr = bhr.baseline_hr,
  baseline_updated_at = NOW(),
  updated_at = NOW()
FROM baseline_heart_rates bhr
WHERE
  wd.device_id = bhr.device_id
  AND wd.user_id = bhr.user_id
  AND bhr.is_active = true;
```

3. **Verify:**

```sql
SELECT
  device_id,
  user_id,
  baseline_hr,
  baseline_updated_at
FROM wearable_devices
WHERE baseline_hr IS NOT NULL;
```

4. **Check Firebase** - The `baseline_hr` should now appear in:
   - Firebase Console → Realtime Database
   - Path: `/devices/AnxieEase001/assignment/supabaseSync/baselineHR`

---

### Option 2: Use Supabase Webhook (More Complex)

This requires enabling `pg_net` extension and setting up a direct webhook.

#### Steps:

1. **Enable pg_net extension:**

   - Supabase Dashboard → Database → Extensions
   - Search for "pg_net" → Enable

2. **Run webhook setup SQL:**
   - See `supabase/setup_baseline_sync_webhook.sql`

---

## How It Works Now

### Data Flow:

```
1. User records baseline in app
   ↓
2. App saves to Supabase: baseline_heart_rates table
   ↓
3. Trigger updates: wearable_devices.baseline_hr
   ↓
4. Supabase webhook (if configured) → Firebase Cloud Function
   OR
   Periodic sync job updates Firebase
   ↓
5. Firebase: /devices/{deviceId}/assignment/supabaseSync/baselineHR
   ↓
6. Cloud Function reads baseline for anxiety detection
```

---

## Testing After Fix

### 1. Verify Supabase Has Baseline

```sql
SELECT
  user_id,
  device_id,
  baseline_hr,
  is_active,
  created_at
FROM baseline_heart_rates
WHERE user_id = '24a689fe-3eec-46ee-8374-81a81914f530'
ORDER BY created_at DESC
LIMIT 1;
```

### 2. Verify wearable_devices Table Updated

```sql
SELECT
  device_id,
  user_id,
  baseline_hr,
  baseline_updated_at
FROM wearable_devices
WHERE device_id = 'AnxieEase001';
```

### 3. Verify Firebase Updated

- Open Firebase Console → Realtime Database
- Navigate to: `/devices/AnxieEase001/assignment/supabaseSync/`
- Should see: `baselineHR: 92` (or your actual baseline value)

### 4. Test Anxiety Detection

Once baseline appears in Firebase, the Cloud Function will:

- ✅ Find baseline from Supabase (primary)
- ✅ Fall back to Firebase if Supabase query fails
- ✅ Calculate personalized thresholds based on YOUR baseline
- ❌ **No longer use default 70 BPM**

---

## What Changed in Cloud Functions

The `getUserBaseline()` function now queries in this order:

1. **Supabase `baseline_heart_rates` table** (PRIMARY - most reliable)
2. Firebase `/devices/{deviceId}/assignment/supabaseSync/baselineHR` (fallback)
3. Firebase `/users/{userId}/baseline/heartRate` (legacy fallback)
4. **NULL** if none found (no more 70 BPM default!)

---

## Files Created

1. ✅ `supabase/sync_baseline_to_devices_table.sql` - Database trigger (RECOMMENDED)
2. ✅ `supabase/setup_baseline_sync_webhook.sql` - Webhook alternative
3. ✅ `BASELINE_SETUP_REQUIREMENT.md` - Documentation
4. ✅ `verify_baseline_requirement.js` - Testing script

---

## Why We Need to Deploy Firebase Functions

**Q: Why deploy every time?**

**A:** We only need to deploy when we **change the Cloud Function code**.

In this case, we changed:

- `getUserBaseline()` function to query Supabase first
- Removed the 70 BPM default fallback
- Added proper null handling

**Future changes:** After this fix, you only need to:

- ✅ Run the SQL trigger in Supabase (one-time)
- ✅ Manually sync existing baselines (one-time)
- ❌ No more Firebase deployments needed for baseline issues

---

## Quick Fix Summary

**Run this in Supabase SQL Editor RIGHT NOW:**

```sql
-- 1. Create trigger
CREATE OR REPLACE FUNCTION update_device_baseline_on_change()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE wearable_devices
  SET baseline_hr = NEW.baseline_hr, baseline_updated_at = NOW(), updated_at = NOW()
  WHERE device_id = NEW.device_id AND user_id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_update_device_baseline
  AFTER INSERT OR UPDATE ON baseline_heart_rates
  FOR EACH ROW WHEN (NEW.is_active = true)
  EXECUTE FUNCTION update_device_baseline_on_change();

-- 2. Sync existing baselines
UPDATE wearable_devices wd
SET baseline_hr = bhr.baseline_hr, baseline_updated_at = NOW()
FROM baseline_heart_rates bhr
WHERE wd.device_id = bhr.device_id
  AND wd.user_id = bhr.user_id
  AND bhr.is_active = true;

-- 3. Verify
SELECT device_id, baseline_hr FROM wearable_devices WHERE baseline_hr IS NOT NULL;
```

Done! Your baseline should now sync automatically! 🎉
