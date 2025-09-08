-- Cleanup Script: Remove New Tables Added by Migration
-- This script removes tables that were added but are not needed

-- ========================================
-- DROP NEW TABLES (if they exist)
-- ========================================

-- Drop emergency_contacts table if it exists
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables 
               WHERE table_schema = 'public' 
               AND table_name = 'emergency_contacts') THEN
        DROP TABLE public.emergency_contacts CASCADE;
        RAISE NOTICE 'Dropped emergency_contacts table';
    ELSE
        RAISE NOTICE 'emergency_contacts table does not exist';
    END IF;
END $$;

-- Drop coping_strategies table if it exists
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables 
               WHERE table_schema = 'public' 
               AND table_name = 'coping_strategies') THEN
        DROP TABLE public.coping_strategies CASCADE;
        RAISE NOTICE 'Dropped coping_strategies table';
    ELSE
        RAISE NOTICE 'coping_strategies table does not exist';
    END IF;
END $$;

-- ========================================
-- REMOVE EXCESSIVE ENHANCEMENTS FROM EXISTING TABLES
-- ========================================

-- Remove extra columns from wellness_logs if they were added
DO $$ 
BEGIN
    -- Remove mood_score if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'wellness_logs' 
               AND column_name = 'mood_score') THEN
        ALTER TABLE public.wellness_logs DROP COLUMN mood_score;
        RAISE NOTICE 'Removed mood_score column from wellness_logs';
    END IF;

    -- Remove energy_level if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'wellness_logs' 
               AND column_name = 'energy_level') THEN
        ALTER TABLE public.wellness_logs DROP COLUMN energy_level;
        RAISE NOTICE 'Removed energy_level column from wellness_logs';
    END IF;

    -- Remove sleep_hours if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'wellness_logs' 
               AND column_name = 'sleep_hours') THEN
        ALTER TABLE public.wellness_logs DROP COLUMN sleep_hours;
        RAISE NOTICE 'Removed sleep_hours column from wellness_logs';
    END IF;

    -- Remove sleep_quality if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'wellness_logs' 
               AND column_name = 'sleep_quality') THEN
        ALTER TABLE public.wellness_logs DROP COLUMN sleep_quality;
        RAISE NOTICE 'Removed sleep_quality column from wellness_logs';
    END IF;
END $$;

-- Remove extra columns from anxiety_records if they were added
DO $$ 
BEGIN
    -- Remove triggers if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'anxiety_records' 
               AND column_name = 'triggers') THEN
        ALTER TABLE public.anxiety_records DROP COLUMN triggers;
        RAISE NOTICE 'Removed triggers column from anxiety_records';
    END IF;

    -- Remove symptoms if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'anxiety_records' 
               AND column_name = 'symptoms') THEN
        ALTER TABLE public.anxiety_records DROP COLUMN symptoms;
        RAISE NOTICE 'Removed symptoms column from anxiety_records';
    END IF;

    -- Remove duration_minutes if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'anxiety_records' 
               AND column_name = 'duration_minutes') THEN
        ALTER TABLE public.anxiety_records DROP COLUMN duration_minutes;
        RAISE NOTICE 'Removed duration_minutes column from anxiety_records';
    END IF;

    -- Remove location_context if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'anxiety_records' 
               AND column_name = 'location_context') THEN
        ALTER TABLE public.anxiety_records DROP COLUMN location_context;
        RAISE NOTICE 'Removed location_context column from anxiety_records';
    END IF;
END $$;

-- Remove extra columns from psychologists if they were added
DO $$ 
BEGIN
    -- Remove specializations if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'psychologists' 
               AND column_name = 'specializations') THEN
        ALTER TABLE public.psychologists DROP COLUMN specializations;
        RAISE NOTICE 'Removed specializations column from psychologists';
    END IF;

    -- Remove years_of_experience if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'psychologists' 
               AND column_name = 'years_of_experience') THEN
        ALTER TABLE public.psychologists DROP COLUMN years_of_experience;
        RAISE NOTICE 'Removed years_of_experience column from psychologists';
    END IF;

    -- Remove is_verified if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'psychologists' 
               AND column_name = 'is_verified') THEN
        ALTER TABLE public.psychologists DROP COLUMN is_verified;
        RAISE NOTICE 'Removed is_verified column from psychologists';
    END IF;
END $$;

-- Remove extra columns from appointments if they were added
DO $$ 
BEGIN
    -- Remove duration_minutes if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'appointments' 
               AND column_name = 'duration_minutes') THEN
        ALTER TABLE public.appointments DROP COLUMN duration_minutes;
        RAISE NOTICE 'Removed duration_minutes column from appointments';
    END IF;

    -- Remove appointment_type if it exists
    IF EXISTS (SELECT FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'appointments' 
               AND column_name = 'appointment_type') THEN
        ALTER TABLE public.appointments DROP COLUMN appointment_type;
        RAISE NOTICE 'Removed appointment_type column from appointments';
    END IF;
END $$;

-- Final completion message
DO $$ 
BEGIN
    RAISE NOTICE 'Cleanup completed successfully!';
    RAISE NOTICE 'Removed all unnecessary tables and enhancements';
    RAISE NOTICE 'Your database now only has essential improvements';
END $$;
