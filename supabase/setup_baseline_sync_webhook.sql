-- ============================================================================
-- SUPABASE WEBHOOK SETUP: Baseline Heart Rate Sync to Firebase
-- ============================================================================
-- This webhook automatically syncs baseline changes to Firebase when:
-- 1. A new baseline is inserted into baseline_heart_rates table
-- 2. An existing baseline is updated
-- ============================================================================

-- STEP 1: Create a function to sync baseline to Firebase via webhook
CREATE OR REPLACE FUNCTION sync_baseline_to_firebase()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url TEXT;
  payload JSON;
BEGIN
  -- Get the Firebase Cloud Function webhook URL
  -- IMPORTANT: Replace this with your actual Firebase Function URL
  webhook_url := 'https://us-central1-anxieease-sensors.cloudfunctions.net/syncDeviceAssignment';
  
  -- Build the payload with wearable_devices format (includes baseline_hr)
  -- This matches the expected format for deviceAssignmentSync function
  SELECT json_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'record', json_build_object(
      'device_id', NEW.device_id,
      'user_id', NEW.user_id,
      'baseline_hr', NEW.baseline_hr,
      'is_active', NEW.is_active,
      'created_at', NEW.created_at,
      'updated_at', NOW()
    ),
    'old_record', CASE 
      WHEN TG_OP = 'UPDATE' THEN json_build_object(
        'device_id', OLD.device_id,
        'user_id', OLD.user_id,
        'baseline_hr', OLD.baseline_hr,
        'is_active', OLD.is_active
      )
      ELSE NULL
    END
  ) INTO payload;

  -- Send webhook to Firebase Cloud Function
  -- Note: This requires pg_net extension to be enabled
  PERFORM
    net.http_post(
      url := webhook_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := payload::jsonb
    );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 2: Create trigger on baseline_heart_rates table
DROP TRIGGER IF EXISTS trigger_baseline_sync_to_firebase ON baseline_heart_rates;

CREATE TRIGGER trigger_baseline_sync_to_firebase
  AFTER INSERT OR UPDATE ON baseline_heart_rates
  FOR EACH ROW
  WHEN (NEW.is_active = true)  -- Only sync active baselines
  EXECUTE FUNCTION sync_baseline_to_firebase();

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check if trigger was created successfully
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'trigger_baseline_sync_to_firebase';

-- Test the webhook (optional - only run after enabling pg_net extension)
-- SELECT sync_baseline_to_firebase_test();

-- ============================================================================
-- IMPORTANT: ENABLE pg_net EXTENSION (Run in Supabase SQL Editor)
-- ============================================================================
-- 
-- Before the webhook will work, you MUST enable the pg_net extension:
--
-- 1. Go to Supabase Dashboard > Database > Extensions
-- 2. Search for "pg_net"
-- 3. Enable it
--
-- OR run this SQL:
-- CREATE EXTENSION IF NOT EXISTS pg_net;
--
-- ============================================================================

COMMENT ON FUNCTION sync_baseline_to_firebase() IS 
'Webhook function that syncs baseline_heart_rates changes to Firebase Cloud Functions';

COMMENT ON TRIGGER trigger_baseline_sync_to_firebase ON baseline_heart_rates IS 
'Automatically syncs baseline changes to Firebase when inserted or updated';

-- ============================================================================
-- MANUAL SYNC FOR EXISTING BASELINES
-- ============================================================================
-- Run this to sync all existing active baselines to Firebase:
/*
SELECT sync_baseline_to_firebase_manual(
  device_id,
  user_id,
  baseline_hr
)
FROM baseline_heart_rates
WHERE is_active = true;
*/
