-- ============================================================================
-- SOLUTION FOR SHARED DEVICE WITH MULTIPLE USER BASELINES
-- ============================================================================
-- 
-- CONTEXT: You have ONE device (AnxieEase001) shared by MULTIPLE users
-- Each user has their own baseline in baseline_heart_rates table
-- wearable_devices table has device_id as PRIMARY KEY (one row per device)
-- Therefore: wearable_devices.baseline_hr can only store ONE baseline
--
-- PROBLEM: Trying to sync multiple user baselines to one device row causes conflicts
--
-- SOLUTION: Don't sync at all! The Cloud Function ALREADY queries 
-- baseline_heart_rates by user_id, which is the correct behavior for shared devices.
--
-- ============================================================================

-- Step 1: Remove any existing trigger that tries to sync baselines
DROP TRIGGER IF EXISTS trigger_update_device_baseline ON baseline_heart_rates;
DROP FUNCTION IF EXISTS update_device_baseline_on_change();

-- ============================================================================
-- VERIFICATION: Your setup is already correct!
-- ============================================================================
-- Your Cloud Function (line 985 in realTimeSustainedAnxietyDetection.ts):
--
--   user_id=eq.${userId}&device_id=eq.${deviceId}&is_active=eq.true
--
-- ✅ This correctly queries baseline_heart_rates by BOTH user_id AND device_id
-- ✅ Each user gets their own baseline from the same shared device
-- ✅ No conflicts, no sync needed!
--
-- ============================================================================

-- Step 2: Verify your baseline is in the database
SELECT 
  'Verification Check' as check_type,
  device_id,
  user_id,
  baseline_hr,
  recorded_at,
  is_active
FROM baseline_heart_rates
WHERE device_id = 'AnxieEase001' 
  AND is_active = true
ORDER BY user_id, recorded_at DESC;

-- Expected result: You should see YOUR baseline (73.2 BPM or similar)
-- If you see it, you're all set! The Cloud Function will find it.

SELECT 
  '✅ Setup Complete!' as status,
  'No sync needed - Cloud Function queries by user_id' as solution,
  'Each user baseline is properly isolated' as benefit;
