-- Final Cleanup: Remove Old public.users Table
-- Run this ONLY after verifying everything works with user_profiles

-- ========================================
-- STEP 1: VERIFY MIGRATION COMPLETED
-- ========================================

-- Check data counts
DO $$ 
DECLARE
    users_count INTEGER;
    profiles_count INTEGER;
    auth_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO users_count FROM public.users;
    SELECT COUNT(*) INTO profiles_count FROM public.user_profiles;
    SELECT COUNT(*) INTO auth_count FROM auth.users;
    
    RAISE NOTICE 'Data Summary:';
    RAISE NOTICE '- public.users: % records', users_count;
    RAISE NOTICE '- user_profiles: % records', profiles_count;
    RAISE NOTICE '- auth.users: % records', auth_count;
    
    IF users_count > profiles_count THEN
        RAISE NOTICE 'WARNING: public.users has more records than user_profiles!';
        RAISE NOTICE 'Migration may be incomplete. Review before proceeding.';
    ELSE
        RAISE NOTICE 'Migration appears complete.';
    END IF;
END $$;

-- ========================================
-- STEP 2: CHECK FOR DEPENDENCIES
-- ========================================

-- Check if any tables still reference public.users
DO $$ 
DECLARE
    dep_count INTEGER;
    rec RECORD;
BEGIN
    -- Simpler approach: Check if public.users table has any dependent objects
    SELECT COUNT(*) INTO dep_count
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    JOIN pg_class r ON c.confrelid = r.oid
    JOIN pg_namespace rn ON r.relnamespace = rn.oid
    WHERE r.relname = 'users' 
        AND rn.nspname = 'public'
        AND c.contype = 'f';
    
    IF dep_count > 0 THEN
        RAISE NOTICE 'WARNING: % foreign key constraints still reference public.users', dep_count;
        RAISE NOTICE 'You must update these constraints before dropping the table.';
        
        -- Show which constraints need updating
        FOR rec IN 
            SELECT 
                tn.nspname AS table_schema,
                t.relname AS table_name,
                c.conname AS constraint_name,
                a.attname AS column_name
            FROM pg_constraint c
            JOIN pg_class t ON c.conrelid = t.oid
            JOIN pg_namespace tn ON t.relnamespace = tn.oid
            JOIN pg_class r ON c.confrelid = r.oid
            JOIN pg_namespace rn ON r.relnamespace = rn.oid
            JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(c.conkey)
            WHERE r.relname = 'users' 
                AND rn.nspname = 'public'
                AND c.contype = 'f'
        LOOP
            RAISE NOTICE 'Table: %.% column % (constraint: %) still references public.users', 
                rec.table_schema, rec.table_name, rec.column_name, rec.constraint_name;
        END LOOP;
    ELSE
        RAISE NOTICE 'No foreign key dependencies found.';
    END IF;
END $$;

-- ========================================
-- STEP 3: FINAL CLEANUP (UNCOMMENT WHEN READY)
-- ========================================

-- IMPORTANT: Only run this after:
-- 1. Verifying data migration is complete
-- 2. Updating your application code to use user_profiles
-- 3. Testing all functionality works
-- 4. Backing up your database

-- Uncomment the lines below when you're ready:

DO $$ 
BEGIN
    DROP TABLE IF EXISTS public.users CASCADE;
    RAISE NOTICE 'Dropped public.users table successfully!';
    RAISE NOTICE 'Cleanup completed. You now have a clean, single-source user system.';
END $$;

-- For now, just show what would be dropped:
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables 
               WHERE table_schema = 'public' 
               AND table_name = 'users') THEN
        RAISE NOTICE 'public.users table exists and can be dropped when ready.';
        RAISE NOTICE 'To drop it, uncomment the DROP TABLE statement above.';
    ELSE
        RAISE NOTICE 'public.users table does not exist - cleanup already complete.';
    END IF;
END $$;
