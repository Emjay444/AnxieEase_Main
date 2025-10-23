-- ============================================================================
-- COMPLETE BASELINE SYNC FIX - Run this entire script in Supabase SQL Editor
-- ============================================================================
-- This fixes the issue where baseline_heart_rates data doesn't sync to Firebase
-- Works for BOTH new accounts (INSERT) and existing accounts (UPDATE)
-- ============================================================================

-- STEP 1: Create the auto-sync function with UPSERT logic
-- ============================================================================
CREATE OR REPLACE FUNCTION update_device_baseline_on_change()
RETURNS TRIGGER AS $$
DECLARE
  rows_affected INT;
BEGIN
  -- Try to update existing wearable_devices row
  UPDATE wearable_devices
  SET 
    baseline_hr = NEW.baseline_hr,
    baseline_updated_at = NOW(),
    updated_at = NOW()
  WHERE 
    device_id = NEW.device_id 
    AND user_id = NEW.user_id;
  
  GET DIAGNOSTICS rows_affected = ROW_COUNT;
  
  -- If device doesn't exist yet (NEW ACCOUNT), insert it
  IF rows_affected = 0 THEN
    INSERT INTO wearable_devices (
      device_id,
      device_name,
      user_id,
      baseline_hr,
      baseline_updated_at,
      is_active,
      status,
      created_at,
      updated_at
    ) VALUES (
      NEW.device_id,
      'AnxieEase Sensor #' || SUBSTRING(NEW.device_id FROM '[0-9]+$'),  -- Extract number from device_id
      NEW.user_id,
      NEW.baseline_hr,
      NOW(),
      true,
      'assigned',
      NOW(),
      NOW()
    )
    ON CONFLICT (device_id) DO UPDATE
    SET 
      baseline_hr = EXCLUDED.baseline_hr,
      baseline_updated_at = NOW(),
      updated_at = NOW(),
      user_id = EXCLUDED.user_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 2: Create/Replace the trigger
-- ============================================================================
DROP TRIGGER IF EXISTS trigger_update_device_baseline ON baseline_heart_rates;

CREATE TRIGGER trigger_update_device_baseline
  AFTER INSERT OR UPDATE ON baseline_heart_rates
  FOR EACH ROW
  WHEN (NEW.is_active = true)
  EXECUTE FUNCTION update_device_baseline_on_change();

-- STEP 3: Sync all existing baselines (including yours!)
-- ============================================================================
-- Only sync the MOST RECENT baseline for each device to avoid duplicates
INSERT INTO wearable_devices (
  device_id,
  device_name,
  user_id,
  baseline_hr,
  baseline_updated_at,
  is_active,
  status,
  created_at,
  updated_at
)
SELECT DISTINCT ON (bhr.device_id)
  bhr.device_id,
  'AnxieEase Sensor #' || SUBSTRING(bhr.device_id FROM '[0-9]+$'),
  bhr.user_id,
  bhr.baseline_hr,
  NOW(),
  true,
  'assigned',
  NOW(),
  NOW()
FROM baseline_heart_rates bhr
WHERE bhr.is_active = true
ORDER BY bhr.device_id, bhr.recorded_at DESC  -- Get most recent baseline per device
ON CONFLICT (device_id) DO UPDATE
SET 
  baseline_hr = EXCLUDED.baseline_hr,
  baseline_updated_at = NOW(),
  updated_at = NOW(),
  user_id = EXCLUDED.user_id;

-- STEP 4: Verify it worked
-- ============================================================================
SELECT 
  'Baseline Sync Verification' as check_type,
  COUNT(*) as total_baselines
FROM baseline_heart_rates
WHERE is_active = true;

SELECT 
  'Synced Devices' as check_type,
  device_id,
  user_id,
  baseline_hr,
  baseline_updated_at
FROM wearable_devices
WHERE baseline_hr IS NOT NULL
ORDER BY baseline_updated_at DESC;

-- Done! Your baseline should now be in wearable_devices.baseline_hr
-- The Supabase webhook will automatically sync this to Firebase
