-- ============================================================================
-- SIMPLER SOLUTION: Update wearable_devices table when baseline changes
-- ============================================================================
-- This approach updates the baseline_hr column in wearable_devices table
-- when a new baseline is created, which will trigger the existing webhook
-- ============================================================================

-- Create function to update wearable_devices baseline when baseline_heart_rates changes
CREATE OR REPLACE FUNCTION update_device_baseline_on_change()
RETURNS TRIGGER AS $$
DECLARE
  rows_affected INT;
BEGIN
  -- Try to update existing row in wearable_devices table
  UPDATE wearable_devices
  SET 
    baseline_hr = NEW.baseline_hr,
    baseline_updated_at = NOW(),
    updated_at = NOW()
  WHERE 
    device_id = NEW.device_id 
    AND user_id = NEW.user_id;
  
  -- Check how many rows were updated
  GET DIAGNOSTICS rows_affected = ROW_COUNT;
  
  -- If no rows were updated, it means the device doesn't exist in wearable_devices yet
  -- This can happen for new accounts - insert the device
  IF rows_affected = 0 THEN
    RAISE NOTICE 'Device % not found in wearable_devices, creating new entry', NEW.device_id;
    
    INSERT INTO wearable_devices (
      device_id,
      user_id,
      baseline_hr,
      baseline_updated_at,
      is_active,
      status,
      created_at,
      updated_at
    ) VALUES (
      NEW.device_id,
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
      baseline_hr = NEW.baseline_hr,
      baseline_updated_at = NOW(),
      updated_at = NOW(),
      user_id = NEW.user_id;
    
    RAISE NOTICE 'Created/updated device % with baseline % BPM', NEW.device_id, NEW.baseline_hr;
  ELSE
    RAISE NOTICE 'Updated baseline for device % to % BPM', NEW.device_id, NEW.baseline_hr;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on baseline_heart_rates
DROP TRIGGER IF EXISTS trigger_update_device_baseline ON baseline_heart_rates;

CREATE TRIGGER trigger_update_device_baseline
  AFTER INSERT OR UPDATE ON baseline_heart_rates
  FOR EACH ROW
  WHEN (NEW.is_active = true)  -- Only for active baselines
  EXECUTE FUNCTION update_device_baseline_on_change();

-- ============================================================================
-- VERIFY THE TRIGGER
-- ============================================================================
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'trigger_update_device_baseline';

-- ============================================================================
-- MANUALLY SYNC EXISTING BASELINES (Run this once after creating trigger)
-- ============================================================================
-- This handles both existing devices AND creates missing device entries
INSERT INTO wearable_devices (
  device_id,
  user_id,
  baseline_hr,
  baseline_updated_at,
  is_active,
  status,
  created_at,
  updated_at
)
SELECT 
  bhr.device_id,
  bhr.user_id,
  bhr.baseline_hr,
  NOW(),
  true,
  'assigned',
  NOW(),
  NOW()
FROM baseline_heart_rates bhr
WHERE bhr.is_active = true
ON CONFLICT (device_id) DO UPDATE
SET 
  baseline_hr = EXCLUDED.baseline_hr,
  baseline_updated_at = NOW(),
  updated_at = NOW(),
  user_id = EXCLUDED.user_id;

-- Verify the update
SELECT 
  device_id,
  user_id,
  baseline_hr,
  baseline_updated_at,
  updated_at
FROM wearable_devices
WHERE baseline_hr IS NOT NULL;

COMMENT ON FUNCTION update_device_baseline_on_change() IS 
'Automatically updates wearable_devices.baseline_hr when baseline_heart_rates changes';

COMMENT ON TRIGGER trigger_update_device_baseline ON baseline_heart_rates IS 
'Keeps wearable_devices.baseline_hr in sync with baseline_heart_rates table';
