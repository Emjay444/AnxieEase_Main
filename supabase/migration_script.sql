-- Migration Script: Update Existing Schema to Recommended Structure
-- This script safely migrates your existing database to the recommended schema

-- ========================================
-- STEP 1: CREATE USER_PROFILES TABLE
-- ========================================

-- Check if user_profiles table exists, if not create it
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM information_schema.tables 
                   WHERE table_schema = 'public' 
                   AND table_name = 'user_profiles') THEN
        
        CREATE TABLE public.user_profiles (
            id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
            first_name text,
            middle_name text,
            last_name text,
            contact_number text,
            emergency_contact text,
            birth_date date,
            sex text CHECK (sex IN ('male', 'female', 'other', 'prefer_not_to_say')),
            role character varying NOT NULL DEFAULT 'patient' CHECK (role IN ('patient', 'psychologist', 'admin')),
            assigned_psychologist_id uuid,
            is_email_verified boolean DEFAULT false,
            avatar_url text,
            created_at timestamp with time zone DEFAULT now(),
            updated_at timestamp with time zone DEFAULT now(),
            CONSTRAINT user_profiles_pkey PRIMARY KEY (id)
        );
        
        RAISE NOTICE 'Created user_profiles table';
    ELSE
        RAISE NOTICE 'user_profiles table already exists';
    END IF;
END $$;

-- ========================================
-- STEP 2: UPDATE PSYCHOLOGISTS TABLE
-- ========================================

-- Add missing columns to psychologists table if they don't exist
DO $$ 
BEGIN
    -- Add user_id column if it doesn't exist
    IF NOT EXISTS (SELECT FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'psychologists' 
                   AND column_name = 'user_id') THEN
        ALTER TABLE public.psychologists 
        ADD COLUMN user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Added user_id column to psychologists table';
    END IF;

    -- Add license_number column if it doesn't exist (only if needed for your app)
    IF NOT EXISTS (SELECT FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'psychologists' 
                   AND column_name = 'license_number') THEN
        ALTER TABLE public.psychologists 
        ADD COLUMN license_number text UNIQUE;
        
        RAISE NOTICE 'Added license_number column to psychologists table';
    END IF;
END $$;

-- Add unique constraint on user_id if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM information_schema.table_constraints 
                   WHERE table_schema = 'public' 
                   AND table_name = 'psychologists' 
                   AND constraint_name = 'psychologists_user_id_unique') THEN
        ALTER TABLE public.psychologists 
        ADD CONSTRAINT psychologists_user_id_unique UNIQUE (user_id);
        
        RAISE NOTICE 'Added unique constraint on psychologists.user_id';
    END IF;
END $$;

-- ========================================
-- STEP 3: UPDATE APPOINTMENTS TABLE
-- ========================================

-- Add user_id column to appointments if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'appointments' 
                   AND column_name = 'user_id') THEN
        ALTER TABLE public.appointments 
        ADD COLUMN user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Added user_id column to appointments table';
    END IF;
END $$;

-- ========================================
-- STEP 4: UPDATE PATIENT_NOTES TABLE
-- ========================================

-- Add psychologist_id to patient_notes if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'patient_notes' 
                   AND column_name = 'psychologist_id') THEN
        ALTER TABLE public.patient_notes 
        ADD COLUMN psychologist_id uuid REFERENCES public.psychologists(id);
        
        RAISE NOTICE 'Added psychologist_id column to patient_notes table';
    END IF;

    -- Update patient_notes to reference auth.users instead of public.users
    IF EXISTS (SELECT FROM information_schema.table_constraints 
               WHERE table_schema = 'public' 
               AND table_name = 'patient_notes' 
               AND constraint_name = 'patient_notes_patient_id_fkey') THEN
        
        -- Drop old foreign key constraint
        ALTER TABLE public.patient_notes 
        DROP CONSTRAINT patient_notes_patient_id_fkey;
        
        -- Add new foreign key constraint to auth.users
        ALTER TABLE public.patient_notes 
        ADD CONSTRAINT patient_notes_patient_id_fkey 
        FOREIGN KEY (patient_id) REFERENCES auth.users(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Updated patient_notes foreign key to reference auth.users';
    END IF;
END $$;

-- ========================================
-- STEP 5: ADD FOREIGN KEY CONSTRAINT TO USER_PROFILES
-- ========================================

-- Add foreign key constraint from user_profiles to psychologists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM information_schema.table_constraints 
                   WHERE table_schema = 'public' 
                   AND table_name = 'user_profiles' 
                   AND constraint_name = 'user_profiles_assigned_psychologist_id_fkey') THEN
        ALTER TABLE public.user_profiles 
        ADD CONSTRAINT user_profiles_assigned_psychologist_id_fkey 
        FOREIGN KEY (assigned_psychologist_id) REFERENCES public.psychologists(id);
        
        RAISE NOTICE 'Added foreign key constraint from user_profiles to psychologists';
    END IF;
END $$;

-- ========================================
-- STEP 6: MINIMAL ESSENTIAL ENHANCEMENTS ONLY
-- ========================================

-- Only add essential missing relationships - no new features
DO $$ 
BEGIN
    RAISE NOTICE 'Keeping existing table structure - no unnecessary enhancements added';
END $$;

-- ========================================
-- STEP 7: CREATE INDEXES FOR PERFORMANCE
-- ========================================

-- Create indexes if they don't exist
DO $$ 
BEGIN
    -- User profiles indexes
    IF NOT EXISTS (SELECT FROM pg_indexes WHERE tablename = 'user_profiles' AND indexname = 'idx_user_profiles_role') THEN
        CREATE INDEX idx_user_profiles_role ON public.user_profiles(role);
        RAISE NOTICE 'Created index on user_profiles.role';
    END IF;

    -- Anxiety records indexes
    IF NOT EXISTS (SELECT FROM pg_indexes WHERE tablename = 'anxiety_records' AND indexname = 'idx_anxiety_records_user_timestamp') THEN
        CREATE INDEX idx_anxiety_records_user_timestamp ON public.anxiety_records(user_id, timestamp DESC);
        RAISE NOTICE 'Created index on anxiety_records(user_id, timestamp)';
    END IF;

    -- Appointments indexes
    IF NOT EXISTS (SELECT FROM pg_indexes WHERE tablename = 'appointments' AND indexname = 'idx_appointments_user') THEN
        CREATE INDEX idx_appointments_user ON public.appointments(user_id);
        RAISE NOTICE 'Created index on appointments.user_id';
    END IF;

    IF NOT EXISTS (SELECT FROM pg_indexes WHERE tablename = 'appointments' AND indexname = 'idx_appointments_psychologist') THEN
        CREATE INDEX idx_appointments_psychologist ON public.appointments(psychologist_id);
        RAISE NOTICE 'Created index on appointments.psychologist_id';
    END IF;
END $$;

-- ========================================
-- STEP 8: CREATE UPDATE TRIGGER FUNCTION
-- ========================================

-- Create update trigger function if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_proc WHERE proname = 'update_updated_at_column') THEN
        CREATE OR REPLACE FUNCTION public.update_updated_at_column()
        RETURNS TRIGGER AS '
        BEGIN
            NEW.updated_at = now();
            RETURN NEW;
        END;
        ' language plpgsql;
        
        RAISE NOTICE 'Created update_updated_at_column function';
    END IF;
END $$;

-- Add triggers if they don't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM information_schema.triggers 
                   WHERE trigger_name = 'update_user_profiles_updated_at') THEN
        CREATE TRIGGER update_user_profiles_updated_at 
        BEFORE UPDATE ON public.user_profiles 
        FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
        
        RAISE NOTICE 'Created trigger for user_profiles.updated_at';
    END IF;

    IF NOT EXISTS (SELECT FROM information_schema.triggers 
                   WHERE trigger_name = 'update_psychologists_updated_at') THEN
        CREATE TRIGGER update_psychologists_updated_at 
        BEFORE UPDATE ON public.psychologists 
        FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
        
        RAISE NOTICE 'Created trigger for psychologists.updated_at';
    END IF;
END $$;

-- ========================================
-- STEP 9: DATA MIGRATION (if public.users exists)
-- ========================================

-- Migrate data from public.users to user_profiles if public.users exists
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables 
               WHERE table_schema = 'public' 
               AND table_name = 'users') THEN
        
        -- Only migrate users that exist in auth.users
        INSERT INTO public.user_profiles (
            id, first_name, middle_name, last_name, contact_number, 
            emergency_contact, birth_date, sex, role, 
            assigned_psychologist_id, is_email_verified, created_at, updated_at
        )
        SELECT 
            u.id, u.first_name, u.middle_name, u.last_name, u.contact_number,
            u.emergency_contact, u.birth_date, u.sex, u.role,
            u.assigned_psychologist_id, u.is_email_verified, u.created_at, u.updated_at
        FROM public.users u
        INNER JOIN auth.users au ON u.id = au.id  -- Only users that exist in auth.users
        WHERE u.id NOT IN (SELECT id FROM public.user_profiles WHERE id IS NOT NULL)
        ON CONFLICT (id) DO NOTHING;
        
        -- Report migration results
        DECLARE
            migrated_count INTEGER;
            total_public_users INTEGER;
            auth_users_count INTEGER;
        BEGIN
            SELECT COUNT(*) INTO total_public_users FROM public.users;
            SELECT COUNT(*) INTO auth_users_count FROM auth.users;
            SELECT COUNT(*) INTO migrated_count FROM public.user_profiles;
            
            RAISE NOTICE 'Migration Summary:';
            RAISE NOTICE '- Total users in public.users: %', total_public_users;
            RAISE NOTICE '- Total users in auth.users: %', auth_users_count;
            RAISE NOTICE '- Users migrated to user_profiles: %', migrated_count;
            
            IF total_public_users > auth_users_count THEN
                RAISE NOTICE 'WARNING: % users in public.users do not exist in auth.users', (total_public_users - auth_users_count);
                RAISE NOTICE 'These users were not migrated and may need manual review';
            END IF;
        END;
        
        -- Note: Don't drop public.users automatically for safety
        RAISE NOTICE 'WARNING: public.users table still exists. Review data migration and drop manually when safe.';
    ELSE
        RAISE NOTICE 'No public.users table found - no data migration needed';
    END IF;
END $$;

-- ========================================
-- STEP 10: ENABLE ROW LEVEL SECURITY
-- ========================================

-- Enable RLS on key tables
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.psychologists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.anxiety_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wellness_logs ENABLE ROW LEVEL SECURITY;

-- Final completion message
DO $$ 
BEGIN
    RAISE NOTICE 'Migration completed successfully!';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Review the migrated data';
    RAISE NOTICE '2. Update your application code to use the new schema';
    RAISE NOTICE '3. Apply RLS policies from rls_policies.sql';
    RAISE NOTICE '4. Test thoroughly before dropping old tables';
END $$;
