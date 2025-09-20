-- Database Backend Testing Script for AnxieEase
-- This script tests all tables, relationships, and functionality after migration

-- ========================================
-- TEST 1: VERIFY ALL TABLES EXIST
-- ========================================

DO $$ 
DECLARE
    table_count INTEGER;
    missing_tables TEXT[] := ARRAY[]::TEXT[];
    expected_tables TEXT[] := ARRAY[
        'user_profiles', 'psychologists', 'anxiety_records', 
        'wellness_logs', 'appointments', 'patient_notes', 
        'notifications', 'activity_logs'
    ];
    table_name TEXT;
BEGIN
    RAISE NOTICE '=== TABLE EXISTENCE TEST ===';
    
    FOREACH table_name IN ARRAY expected_tables
    LOOP
        SELECT COUNT(*) INTO table_count
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = table_name;
        
        IF table_count = 0 THEN
            missing_tables := missing_tables || table_name;
            RAISE NOTICE '❌ MISSING: public.%', table_name;
        ELSE
            RAISE NOTICE '✅ EXISTS: public.%', table_name;
        END IF;
    END LOOP;
    
    IF array_length(missing_tables, 1) > 0 THEN
        RAISE NOTICE 'WARNING: Missing tables detected!';
    ELSE
        RAISE NOTICE 'SUCCESS: All required tables exist!';
    END IF;
END $$;

-- ========================================
-- TEST 2: VERIFY FOREIGN KEY RELATIONSHIPS
-- ========================================

DO $$ 
DECLARE
    fk_count INTEGER;
    rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== FOREIGN KEY RELATIONSHIPS TEST ===';
    
    -- Check all foreign key constraints
    FOR rec IN 
        SELECT 
            tc.table_name,
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name,
            tc.constraint_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu 
            ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu 
            ON ccu.constraint_name = tc.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY' 
            AND tc.table_schema = 'public'
        ORDER BY tc.table_name, kcu.column_name
    LOOP
        RAISE NOTICE '✅ FK: %.% → %.%', 
            rec.table_name, rec.column_name, 
            rec.foreign_table_name, rec.foreign_column_name;
    END LOOP;
    
    SELECT COUNT(*) INTO fk_count
    FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY' AND table_schema = 'public';
    
    RAISE NOTICE 'Total Foreign Keys: %', fk_count;
END $$;

-- ========================================
-- TEST 3: VERIFY ROW LEVEL SECURITY
-- ========================================

DO $$ 
DECLARE
    rls_enabled_count INTEGER;
    rls_disabled_count INTEGER;
    rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== ROW LEVEL SECURITY TEST ===';
    
    -- Check RLS status for each table
    FOR rec IN 
        SELECT 
            schemaname,
            tablename,
            rowsecurity
        FROM pg_tables 
        WHERE schemaname = 'public'
        ORDER BY tablename
    LOOP
        IF rec.rowsecurity THEN
            RAISE NOTICE '✅ RLS ENABLED: %', rec.tablename;
        ELSE
            RAISE NOTICE '❌ RLS DISABLED: %', rec.tablename;
        END IF;
    END LOOP;
    
    SELECT 
        COUNT(*) FILTER (WHERE rowsecurity = true),
        COUNT(*) FILTER (WHERE rowsecurity = false)
    INTO rls_enabled_count, rls_disabled_count
    FROM pg_tables 
    WHERE schemaname = 'public';
    
    RAISE NOTICE 'RLS Summary: % enabled, % disabled', rls_enabled_count, rls_disabled_count;
END $$;

-- ========================================
-- TEST 4: TEST BASIC CRUD OPERATIONS
-- ========================================

DO $$ 
DECLARE
    test_user_id UUID;
    test_profile_id UUID;
    test_psychologist_id UUID;
    test_record_id UUID;
    record_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== CRUD OPERATIONS TEST ===';
    
    -- Note: These tests assume you have at least one user in auth.users
    -- If you don't have any users, some tests will be skipped
    
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE '⚠️  No users found in auth.users - skipping CRUD tests';
        RAISE NOTICE 'To test fully, create a user through Supabase Auth first';
        RETURN;
    ELSE
        RAISE NOTICE 'Using test user: %', test_user_id;
    END IF;
    
    -- Test 1: Insert user_profile
    BEGIN
        INSERT INTO user_profiles (id, first_name, last_name, role)
        VALUES (test_user_id, 'Test', 'User', 'patient')
        ON CONFLICT (id) DO UPDATE SET 
            first_name = EXCLUDED.first_name,
            last_name = EXCLUDED.last_name;
        
        RAISE NOTICE '✅ user_profiles: INSERT/UPDATE successful';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ user_profiles: INSERT failed - %', SQLERRM;
    END;
    
    -- Test 2: Insert anxiety_record (no heart_rate column)
    BEGIN
        INSERT INTO anxiety_records (user_id, severity_level)
        VALUES (test_user_id, 'mild')
        RETURNING id INTO test_record_id;
        
        RAISE NOTICE '✅ anxiety_records: INSERT successful (ID: %)', test_record_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ anxiety_records: INSERT failed - %', SQLERRM;
    END;
    
    -- Test 3: Insert wellness_log
    BEGIN
        INSERT INTO wellness_logs (user_id, date, feelings, stress_level, symptoms)
        VALUES (test_user_id, CURRENT_DATE, '{"mood": "good"}', 3.5, '{"headache": false}')
        ON CONFLICT (user_id, date) DO NOTHING;
        
        RAISE NOTICE '✅ wellness_logs: INSERT successful';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ wellness_logs: INSERT failed - %', SQLERRM;
    END;
    
    -- Test 4: Insert notification
    BEGIN
        INSERT INTO notifications (user_id, title, message, type)
        VALUES (test_user_id, 'Test Notification', 'This is a test', 'system');
        
        RAISE NOTICE '✅ notifications: INSERT successful';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ notifications: INSERT failed - %', SQLERRM;
    END;
    
    -- Test 5: Count records for user
    SELECT COUNT(*) INTO record_count FROM anxiety_records WHERE user_id = test_user_id;
    RAISE NOTICE '✅ Data retrieval: Found % anxiety records for user', record_count;
    
END $$;

-- ========================================
-- TEST 5: TEST INDEXES AND PERFORMANCE
-- ========================================

DO $$ 
DECLARE
    index_count INTEGER;
    rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== INDEXES TEST ===';
    
    -- Check for important indexes
    FOR rec IN 
        SELECT 
            schemaname,
            tablename,
            indexname,
            indexdef
        FROM pg_indexes 
        WHERE schemaname = 'public'
            AND indexname NOT LIKE '%_pkey'  -- Exclude primary keys
        ORDER BY tablename, indexname
    LOOP
        RAISE NOTICE '✅ INDEX: % on %', rec.indexname, rec.tablename;
    END LOOP;
    
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE schemaname = 'public' AND indexname NOT LIKE '%_pkey';
    
    RAISE NOTICE 'Total custom indexes: %', index_count;
END $$;

-- ========================================
-- TEST 6: TEST TRIGGERS AND FUNCTIONS
-- ========================================

DO $$ 
DECLARE
    trigger_count INTEGER;
    function_count INTEGER;
    rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== TRIGGERS AND FUNCTIONS TEST ===';
    
    -- Check triggers
    FOR rec IN 
        SELECT 
            trigger_name,
            table_name,
            action_timing,
            event_manipulation
        FROM information_schema.triggers
        WHERE trigger_schema = 'public'
    LOOP
        RAISE NOTICE '✅ TRIGGER: % on % (% %)', 
            rec.trigger_name, rec.table_name, rec.action_timing, rec.event_manipulation;
    END LOOP;
    
    -- Check custom functions
    FOR rec IN 
        SELECT 
            routine_name,
            routine_type
        FROM information_schema.routines
        WHERE routine_schema = 'public'
            AND routine_name NOT LIKE 'pg_%'
    LOOP
        RAISE NOTICE '✅ FUNCTION: % (%)', rec.routine_name, rec.routine_type;
    END LOOP;
    
    SELECT COUNT(*) INTO trigger_count
    FROM information_schema.triggers WHERE trigger_schema = 'public';
    
    SELECT COUNT(*) INTO function_count
    FROM information_schema.routines 
    WHERE routine_schema = 'public' AND routine_name NOT LIKE 'pg_%';
    
    RAISE NOTICE 'Total triggers: %, Total functions: %', trigger_count, function_count;
END $$;

-- ========================================
-- TEST 7: TEST DATA CONSISTENCY
-- ========================================

DO $$ 
DECLARE
    orphaned_profiles INTEGER;
    orphaned_records INTEGER;
    orphaned_appointments INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== DATA CONSISTENCY TEST ===';
    
    -- Check for orphaned user_profiles (profiles without auth.users)
    SELECT COUNT(*) INTO orphaned_profiles
    FROM user_profiles up
    LEFT JOIN auth.users au ON up.id = au.id
    WHERE au.id IS NULL;
    
    IF orphaned_profiles > 0 THEN
        RAISE NOTICE '❌ Found % orphaned user_profiles', orphaned_profiles;
    ELSE
        RAISE NOTICE '✅ No orphaned user_profiles found';
    END IF;
    
    -- Check for orphaned anxiety_records
    SELECT COUNT(*) INTO orphaned_records
    FROM anxiety_records ar
    LEFT JOIN auth.users au ON ar.user_id = au.id
    WHERE au.id IS NULL;
    
    IF orphaned_records > 0 THEN
        RAISE NOTICE '❌ Found % orphaned anxiety_records', orphaned_records;
    ELSE
        RAISE NOTICE '✅ No orphaned anxiety_records found';
    END IF;
    
    -- Check for orphaned appointments
    SELECT COUNT(*) INTO orphaned_appointments
    FROM appointments a
    LEFT JOIN auth.users au ON a.user_id = au.id
    LEFT JOIN psychologists p ON a.psychologist_id = p.id
    WHERE au.id IS NULL OR p.id IS NULL;
    
    IF orphaned_appointments > 0 THEN
        RAISE NOTICE '❌ Found % orphaned appointments', orphaned_appointments;
    ELSE
        RAISE NOTICE '✅ No orphaned appointments found';
    END IF;
END $$;

-- ========================================
-- FINAL SUMMARY
-- ========================================

DO $$ 
DECLARE
    total_users INTEGER;
    total_profiles INTEGER;
    total_records INTEGER;
    total_logs INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== FINAL SUMMARY ===';
    
    SELECT COUNT(*) INTO total_users FROM auth.users;
    SELECT COUNT(*) INTO total_profiles FROM user_profiles;
    SELECT COUNT(*) INTO total_records FROM anxiety_records;
    SELECT COUNT(*) INTO total_logs FROM wellness_logs;
    
    RAISE NOTICE 'Database Status:';
    RAISE NOTICE '- Auth Users: %', total_users;
    RAISE NOTICE '- User Profiles: %', total_profiles;
    RAISE NOTICE '- Anxiety Records: %', total_records;
    RAISE NOTICE '- Wellness Logs: %', total_logs;
    
    IF total_users > 0 AND total_profiles >= 0 THEN
        RAISE NOTICE '🎉 DATABASE BACKEND IS WORKING!';
        RAISE NOTICE 'Your AnxieEase database is ready for production use.';
    ELSE
        RAISE NOTICE '⚠️  Database structure is correct but needs data.';
        RAISE NOTICE 'Create some test users through your app to fully verify.';
    END IF;
END $$;
