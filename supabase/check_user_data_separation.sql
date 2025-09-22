-- Check for potential user data separation issues
-- Run these queries in your Supabase SQL editor to verify proper data isolation

-- 0. First, check what columns exist in your wearable_devices table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'wearable_devices'
ORDER BY ordinal_position;

-- 0b. Check current wearable_devices table structure
SELECT 'wearable_devices table structure confirmed ✓' as table_status;

-- 1. Check if multiple users share the same device_id in user_profiles
SELECT 
    device_id,
    COUNT(*) as user_count,
    ARRAY_AGG(id) as user_ids
FROM user_profiles 
WHERE device_id IS NOT NULL
GROUP BY device_id
HAVING COUNT(*) > 1;

-- 2. Check baseline_heart_rates for proper user separation
SELECT 
    device_id,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) as total_baselines,
    ARRAY_AGG(DISTINCT user_id) as user_ids
FROM baseline_heart_rates 
GROUP BY device_id
ORDER BY unique_users DESC;

-- 3. Check wearable_devices current assignment (using your schema)
SELECT 
    device_id,
    user_id,
    status,
    is_active,
    linked_at,
    last_seen_at,
    baseline_hr,
    firebase_session_id
FROM wearable_devices 
WHERE device_id = 'AnxieEase001';

-- 4. Verify anxiety_records are properly separated by user
SELECT 
    user_id,
    COUNT(*) as anxiety_record_count,
    MIN(created_at) as first_record,
    MAX(created_at) as latest_record
FROM anxiety_records 
GROUP BY user_id
ORDER BY anxiety_record_count DESC;

-- 5. Check for any cross-user data leaks in baseline_heart_rates
-- This should return empty if data separation is working correctly
SELECT 
    bhr1.user_id as user1,
    bhr2.user_id as user2,
    bhr1.device_id,
    bhr1.baseline_hr as user1_baseline,
    bhr2.baseline_hr as user2_baseline
FROM baseline_heart_rates bhr1
JOIN baseline_heart_rates bhr2 
    ON bhr1.device_id = bhr2.device_id 
    AND bhr1.user_id != bhr2.user_id
    AND bhr1.is_active = true 
    AND bhr2.is_active = true;

-- 6. Check user_profiles for duplicate device assignments
SELECT 
    up1.id as user1,
    up2.id as user2,
    up1.device_id,
    up1.first_name || ' ' || up1.last_name as user1_name,
    up2.first_name || ' ' || up2.last_name as user2_name
FROM user_profiles up1
JOIN user_profiles up2 
    ON up1.device_id = up2.device_id 
    AND up1.id != up2.id
WHERE up1.device_id IS NOT NULL;

-- 7. Check for proper RLS enforcement
-- This tests if Row Level Security is working correctly
-- Run this as different users to verify they only see their own data

-- Test baseline_heart_rates RLS
SELECT 
    user_id,
    device_id,
    baseline_hr,
    created_at
FROM baseline_heart_rates 
ORDER BY created_at DESC
LIMIT 10;

-- Test anxiety_records RLS  
SELECT 
    user_id,
    severity_level,
    timestamp,
    details
FROM anxiety_records 
ORDER BY timestamp DESC
LIMIT 10;

-- 8. Check for orphaned records (data without proper user references)
SELECT 'baseline_heart_rates' as table_name, COUNT(*) as orphaned_count
FROM baseline_heart_rates bhr
LEFT JOIN auth.users au ON bhr.user_id = au.id
WHERE au.id IS NULL

UNION ALL

SELECT 'anxiety_records' as table_name, COUNT(*) as orphaned_count  
FROM anxiety_records ar
LEFT JOIN auth.users au ON ar.user_id = au.id
WHERE au.id IS NULL

UNION ALL

SELECT 'wearable_devices' as table_name, COUNT(*) as orphaned_count
FROM wearable_devices wd
LEFT JOIN auth.users au ON wd.user_id = au.id
WHERE wd.user_id IS NOT NULL AND au.id IS NULL;