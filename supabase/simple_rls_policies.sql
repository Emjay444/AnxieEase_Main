-- Row Level Security Policies for Your Current Schema
-- These policies ensure users can only access their own data

-- ========================================
-- ENABLE RLS ON DEVICE-RELATED TABLES
-- ========================================
ALTER TABLE public.wearable_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.baseline_heart_rates ENABLE ROW LEVEL SECURITY;

-- ========================================
-- WEARABLE DEVICES POLICIES (for your current schema)
-- ========================================

-- Drop any existing policies first
DROP POLICY IF EXISTS "Users can access assigned devices" ON public.wearable_devices;
DROP POLICY IF EXISTS "Users can update own device sessions" ON public.wearable_devices;
DROP POLICY IF EXISTS "Device access policy" ON public.wearable_devices;

-- Users can view devices assigned to them or available devices
CREATE POLICY "Users can view assigned or available devices" ON public.wearable_devices
    FOR SELECT USING (
        user_id = auth.uid() OR           -- Own device
        user_id IS NULL OR                -- Unassigned device  
        status = 'available'              -- Available device
    );

-- Users can update their own assigned devices
CREATE POLICY "Users can update own devices" ON public.wearable_devices
    FOR UPDATE USING (user_id = auth.uid());

-- Allow insertion of new devices (for device registration)
CREATE POLICY "Allow device registration" ON public.wearable_devices
    FOR INSERT WITH CHECK (true);

-- ========================================
-- BASELINE HEART RATES POLICIES  
-- ========================================

-- Drop any existing policies first
DROP POLICY IF EXISTS "Users can manage own baselines" ON public.baseline_heart_rates;
DROP POLICY IF EXISTS "Psychologists can view patient baselines" ON public.baseline_heart_rates;

-- Users can only access their own baseline data
CREATE POLICY "Users can manage own baseline data" ON public.baseline_heart_rates
    FOR ALL USING (user_id = auth.uid());

-- Psychologists can view baseline data of their assigned patients
CREATE POLICY "Psychologists can view assigned patient baselines" ON public.baseline_heart_rates
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.psychologists p
            WHERE p.user_id = auth.uid() 
            AND p.id = (
                SELECT up.assigned_psychologist_id 
                FROM public.user_profiles up 
                WHERE up.id = baseline_heart_rates.user_id
            )
        )
    );

-- ========================================
-- VERIFY RLS IS WORKING
-- ========================================

-- Test query for baseline separation (run as different users)
-- Each user should only see their own baselines
SELECT 
    device_id,
    user_id,
    baseline_hr,
    recording_start_time,
    CASE 
        WHEN user_id = auth.uid() THEN 'Own baseline data ✓'
        ELSE 'Leaked data from another user ❌' 
    END as data_ownership,
    auth.uid() as current_user_id
FROM baseline_heart_rates 
ORDER BY recording_start_time DESC
LIMIT 10;

-- Test query for device access (run as different users)
-- Users should only see their devices or available devices
SELECT 
    device_id,
    user_id,
    status,
    is_active,
    CASE 
        WHEN user_id = auth.uid() THEN 'Own device ✓'
        WHEN user_id IS NULL THEN 'Unassigned device (OK to see) ✓'
        WHEN status = 'available' THEN 'Available device (OK to see) ✓'
        ELSE 'Another user''s device ❌'
    END as access_status,
    auth.uid() as current_user_id
FROM wearable_devices
ORDER BY device_id;

-- ========================================
-- USER DATA SEPARATION TEST
-- ========================================

-- This query helps verify that each user only sees their own data
-- Run this as different users to confirm separation
SELECT 
    'Current User ID: ' || auth.uid() as session_info,
    (SELECT COUNT(*) FROM baseline_heart_rates WHERE user_id = auth.uid()) as my_baselines,
    (SELECT COUNT(*) FROM anxiety_records WHERE user_id = auth.uid()) as my_anxiety_records,
    (SELECT COUNT(*) FROM wearable_devices WHERE user_id = auth.uid()) as my_devices,
    (SELECT COUNT(*) FROM wearable_devices WHERE user_id IS NULL OR status = 'available') as available_devices;

COMMENT ON POLICY "Users can view assigned or available devices" ON public.wearable_devices IS 
'Users can view devices assigned to them, unassigned devices, or devices marked as available';

COMMENT ON POLICY "Users can update own devices" ON public.wearable_devices IS
'Users can only update devices that are assigned to them';

COMMENT ON POLICY "Users can manage own baseline data" ON public.baseline_heart_rates IS
'Users can only access baseline heart rate data they recorded themselves';

COMMENT ON POLICY "Psychologists can view assigned patient baselines" ON public.baseline_heart_rates IS  
'Psychologists can view baseline data for their assigned patients only';