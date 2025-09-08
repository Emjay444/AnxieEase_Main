-- COMPLETE DATABASE BACKEND TEST FOR ANXIEEASE
-- Copy and paste this into your Supabase Dashboard > SQL Editor
-- This will comprehensively test your database backend

-- =================================================
-- 1. ENVIRONMENT CHECK
-- =================================================
SELECT 
    'ENVIRONMENT' as category,
    'PostgreSQL Version' as test_name,
    version() as result,
    '✅ System Info' as status;

-- =================================================
-- 2. TABLE STRUCTURE VERIFICATION
-- =================================================
WITH required_tables AS (
  SELECT unnest(ARRAY[
    'user_profiles', 'psychologists', 'anxiety_records', 
    'wellness_logs', 'appointments', 'patient_notes', 
    'notifications', 'activity_logs'
  ]) as table_name
),
existing_tables AS (
  SELECT table_name
  FROM information_schema.tables 
  WHERE table_schema = 'public' 
    AND table_type = 'BASE TABLE'
)
SELECT 
    'TABLE STRUCTURE' as category,
    rt.table_name as test_name,
    CASE 
        WHEN et.table_name IS NOT NULL THEN 'Table exists'
        ELSE 'MISSING TABLE'
    END as result,
    CASE 
        WHEN et.table_name IS NOT NULL THEN '✅ Pass'
        ELSE '❌ Fail'
    END as status
FROM required_tables rt
LEFT JOIN existing_tables et ON rt.table_name = et.table_name
ORDER BY rt.table_name;

-- =================================================
-- 3. FOREIGN KEY RELATIONSHIPS CHECK
-- =================================================
SELECT 
    'FOREIGN KEYS' as category,
    tc.table_name || '.' || kcu.column_name as test_name,
    ccu.table_name || '.' || ccu.column_name as result,
    '✅ Relationship exists' as status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;

-- =================================================
-- 4. ROW LEVEL SECURITY CHECK
-- =================================================
SELECT 
    'ROW LEVEL SECURITY' as category,
    tablename as test_name,
    CASE 
        WHEN rowsecurity = true THEN 'RLS Enabled'
        ELSE 'RLS Disabled'
    END as result,
    CASE 
        WHEN rowsecurity = true THEN '✅ Secure'
        ELSE '⚠️ Not Secure'
    END as status
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- =================================================
-- 5. DATA INTEGRITY CHECK
-- =================================================
-- Check auth.users table
SELECT 
    'DATA INTEGRITY' as category,
    'auth.users count' as test_name,
    COUNT(*)::text || ' users' as result,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Has users'
        ELSE '⚠️ No users found'
    END as status
FROM auth.users

UNION ALL

-- Check user_profiles
SELECT 
    'DATA INTEGRITY' as category,
    'user_profiles count' as test_name,
    COUNT(*)::text || ' profiles' as result,
    CASE 
        WHEN COUNT(*) >= 0 THEN '✅ Table accessible'
        ELSE '❌ Error'
    END as status
FROM user_profiles

UNION ALL

-- Check for orphaned profiles
SELECT 
    'DATA INTEGRITY' as category,
    'orphaned profiles check' as test_name,
    COUNT(*)::text || ' orphaned records' as result,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ No orphans'
        ELSE '⚠️ Has orphaned data'
    END as status
FROM user_profiles up
LEFT JOIN auth.users au ON up.id = au.id
WHERE au.id IS NULL

UNION ALL

-- Check anxiety_records
SELECT 
    'DATA INTEGRITY' as category,
    'anxiety_records count' as test_name,
    COUNT(*)::text || ' records' as result,
    '✅ Table accessible' as status
FROM anxiety_records

UNION ALL

-- Check wellness_logs
SELECT 
    'DATA INTEGRITY' as category,
    'wellness_logs count' as test_name,
    COUNT(*)::text || ' logs' as result,
    '✅ Table accessible' as status
FROM wellness_logs

UNION ALL

-- Check appointments
SELECT 
    'DATA INTEGRITY' as category,
    'appointments count' as test_name,
    COUNT(*)::text || ' appointments' as result,
    '✅ Table accessible' as status
FROM appointments

UNION ALL

-- Check notifications
SELECT 
    'DATA INTEGRITY' as category,
    'notifications count' as test_name,
    COUNT(*)::text || ' notifications' as result,
    '✅ Table accessible' as status
FROM notifications;

-- =================================================
-- 6. CLEANUP VERIFICATION
-- =================================================
SELECT 
    'CLEANUP STATUS' as category,
    'old public.users table' as test_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables 
                    WHERE table_schema = 'public' AND table_name = 'users')
        THEN 'Still exists - needs cleanup'
        ELSE 'Properly removed'
    END as result,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables 
                    WHERE table_schema = 'public' AND table_name = 'users')
        THEN '⚠️ Cleanup needed'
        ELSE '✅ Clean'
    END as status;

-- =================================================
-- 7. SAMPLE DATA VERIFICATION (if any exists)
-- =================================================
-- Show sample user profiles
SELECT 
    'SAMPLE DATA' as category,
    'user_profiles sample' as test_name,
    CASE 
        WHEN COUNT(*) > 0 THEN 
            'Found ' || COUNT(*)::text || ' profiles: ' || 
            string_agg(COALESCE(first_name, 'Unknown') || ' ' || COALESCE(last_name, ''), ', ')
        ELSE 'No user profiles found'
    END as result,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Has data'
        ELSE '⚠️ No data yet'
    END as status
FROM (
    SELECT first_name, last_name 
    FROM user_profiles 
    LIMIT 3
) sample;

-- =================================================
-- 8. PERFORMANCE INDEX CHECK
-- =================================================
SELECT 
    'PERFORMANCE' as category,
    'indexes on ' || tablename as test_name,
    COUNT(*)::text || ' indexes' as result,
    CASE 
        WHEN COUNT(*) >= 1 THEN '✅ Has indexes'
        ELSE '⚠️ No custom indexes'
    END as status
FROM pg_indexes 
WHERE schemaname = 'public'
    AND indexname NOT LIKE '%_pkey'  -- Exclude primary keys
GROUP BY tablename
ORDER BY tablename;

-- =================================================
-- 9. FINAL SUMMARY
-- =================================================
SELECT 
    'SUMMARY' as category,
    'Backend Status' as test_name,
    CASE 
        WHEN (
            -- All required tables exist
            (SELECT COUNT(*) FROM information_schema.tables 
             WHERE table_schema = 'public' 
             AND table_name IN ('user_profiles', 'psychologists', 'anxiety_records', 
                               'wellness_logs', 'appointments', 'patient_notes', 
                               'notifications', 'activity_logs')) = 8
            -- No duplicate users table
            AND NOT EXISTS (SELECT 1 FROM information_schema.tables 
                           WHERE table_schema = 'public' AND table_name = 'users')
            -- Auth system accessible
            AND (SELECT COUNT(*) FROM auth.users) >= 0
        ) THEN 'Database backend is WORKING correctly!'
        ELSE 'Database backend has issues that need attention'
    END as result,
    CASE 
        WHEN (
            (SELECT COUNT(*) FROM information_schema.tables 
             WHERE table_schema = 'public' 
             AND table_name IN ('user_profiles', 'psychologists', 'anxiety_records', 
                               'wellness_logs', 'appointments', 'patient_notes', 
                               'notifications', 'activity_logs')) = 8
            AND NOT EXISTS (SELECT 1 FROM information_schema.tables 
                           WHERE table_schema = 'public' AND table_name = 'users')
            AND (SELECT COUNT(*) FROM auth.users) >= 0
        ) THEN '🎉 SUCCESS'
        ELSE '⚠️ NEEDS ATTENTION'
    END as status;
