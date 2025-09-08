-- QUICK DATABASE BACKEND TEST
-- Copy and paste this into your Supabase Dashboard > SQL Editor
-- This will verify your database is working correctly

-- ========================================
-- QUICK HEALTH CHECK
-- ========================================

-- Test 1: Check all tables exist
SELECT 
    'TABLE CHECK' as test_type,
    table_name,
    CASE 
        WHEN table_name IN ('user_profiles', 'psychologists', 'anxiety_records', 
                           'wellness_logs', 'appointments', 'patient_notes', 
                           'notifications', 'activity_logs') 
        THEN '✅ Required table exists'
        ELSE '⚠️ Unexpected table found'
    END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
    AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Test 2: Check foreign key relationships
SELECT 
    'FOREIGN KEY CHECK' as test_type,
    tc.table_name || '.' || kcu.column_name as from_column,
    ccu.table_name || '.' || ccu.column_name as to_column,
    '✅ Relationship exists' as status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_schema = 'public'
ORDER BY tc.table_name;

-- Test 3: Check Row Level Security
SELECT 
    'RLS CHECK' as test_type,
    tablename as table_name,
    CASE 
        WHEN rowsecurity = true THEN '✅ RLS Enabled'
        ELSE '❌ RLS Disabled'
    END as status
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- Test 4: Data counts
SELECT 
    'DATA COUNT' as test_type,
    'auth.users' as table_name,
    COUNT(*)::text || ' users' as status
FROM auth.users
UNION ALL
SELECT 
    'DATA COUNT',
    'user_profiles',
    COUNT(*)::text || ' profiles'
FROM user_profiles
UNION ALL
SELECT 
    'DATA COUNT',
    'anxiety_records',
    COUNT(*)::text || ' records'
FROM anxiety_records
UNION ALL
SELECT 
    'DATA COUNT',
    'wellness_logs',
    COUNT(*)::text || ' logs'
FROM wellness_logs
UNION ALL
SELECT 
    'DATA COUNT',
    'appointments',
    COUNT(*)::text || ' appointments'
FROM appointments
UNION ALL
SELECT 
    'DATA COUNT',
    'notifications',
    COUNT(*)::text || ' notifications'
FROM notifications;

-- Test 5: Check for old public.users table (should not exist)
SELECT 
    'CLEANUP CHECK' as test_type,
    'public.users' as table_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables 
                    WHERE table_schema = 'public' AND table_name = 'users')
        THEN '❌ Old users table still exists'
        ELSE '✅ Cleanup complete - no duplicate users table'
    END as status;
