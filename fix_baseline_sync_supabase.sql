-- FIX BASELINE SYNC ISSUE IN SUPABASE
-- This SQL function will be triggered when device assignments change
-- It ensures wearable_devices.baseline_hr always matches the user's real baseline

-- ========================================
-- STEP 1: CREATE FUNCTION TO SYNC BASELINES
-- ========================================

CREATE OR REPLACE FUNCTION sync_device_baseline()
RETURNS TRIGGER AS $$
BEGIN
    -- When device assignment changes, fetch user's real baseline
    IF (TG_OP = 'UPDATE' AND OLD.user_id IS DISTINCT FROM NEW.user_id) OR TG_OP = 'INSERT' THEN
        -- Update the baseline_hr in wearable_devices with user's actual baseline
        UPDATE wearable_devices 
        SET baseline_hr = (
            SELECT baseline_hr 
            FROM baseline_heart_rates 
            WHERE user_id = NEW.user_id
            LIMIT 1
        )
        WHERE id = NEW.id;
        
        -- Log the baseline sync
        RAISE NOTICE 'Device % assigned to user %, baseline synced: %', 
            NEW.device_id, 
            NEW.user_id, 
            (SELECT baseline_hr FROM baseline_heart_rates WHERE user_id = NEW.user_id LIMIT 1);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- STEP 2: CREATE TRIGGER ON DEVICE ASSIGNMENTS
-- ========================================

-- Remove existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_sync_device_baseline ON wearable_devices;

-- Create new trigger
CREATE TRIGGER trigger_sync_device_baseline
    AFTER INSERT OR UPDATE OF user_id ON wearable_devices
    FOR EACH ROW
    EXECUTE FUNCTION sync_device_baseline();

-- ========================================
-- STEP 3: FIX EXISTING INCONSISTENT DATA
-- ========================================

-- Update all current device assignments to use correct baselines
UPDATE wearable_devices 
SET baseline_hr = (
    SELECT bhr.baseline_hr 
    FROM baseline_heart_rates bhr 
    WHERE bhr.user_id = wearable_devices.user_id
    LIMIT 1
)
WHERE user_id IS NOT NULL;

-- ========================================
-- STEP 4: VERIFICATION QUERY
-- ========================================

-- Check if baselines are now consistent
SELECT 
    wd.device_id,
    wd.user_id,
    wd.baseline_hr as device_baseline,
    bhr.baseline_hr as user_baseline,
    CASE 
        WHEN wd.baseline_hr = bhr.baseline_hr THEN '✅ SYNCED'
        WHEN wd.baseline_hr IS NULL AND bhr.baseline_hr IS NULL THEN '✅ BOTH NULL'
        ELSE '❌ MISMATCH'
    END as sync_status
FROM wearable_devices wd
LEFT JOIN baseline_heart_rates bhr ON wd.user_id = bhr.user_id
WHERE wd.user_id IS NOT NULL
ORDER BY wd.device_id;

-- ========================================
-- NOTES:
-- ========================================
/*
This solution:

1. AUTOMATIC SYNC: Creates trigger that runs whenever device assignment changes
2. FETCHES REAL BASELINE: Always gets baseline from baseline_heart_rates table
3. HANDLES NULL BASELINES: If user has no baseline, uses null (as requested)
4. FIXES EXISTING DATA: Updates current assignments to use correct baselines
5. VERIFIES SYNC: Query to check if all baselines are now consistent

BEHAVIOR:
- When admin assigns device to user → automatically fetches user's real baseline
- If user has no baseline in baseline_heart_rates → device baseline becomes null
- When user sets up baseline later → can manually trigger sync or update baseline_heart_rates

FIREBASE SYNC:
- Our webhook will now receive the correct baseline from wearable_devices
- Firebase anxiety detection will use user's actual baseline
- No more baseline mismatches!
*/