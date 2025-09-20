-- AnxieEase anxiety_records Table Optimization (Final - No Heart Rate Stored)
-- This version aligns with the app decision to NOT store heart rate in anxiety_records.

-- CURRENT SCHEMA ANALYSIS:
-- ✅ Keep: id, user_id, severity_level, timestamp (core anxiety tracking)
-- ✅ Keep: is_manual (distinguishes auto vs manual entries)
-- ⚠️  Review: created_at (optional, keep if you want server insert time)
-- ✅ Keep: source (origin label like app_detection/manual_entry)
-- ✅ Keep: details (nullable free text)
-- ❌ Remove: heart_rate (per app decision, notifications don’t include HR)

-- FINAL RECOMMENDATION (minimal & app-aligned):
-- 1) DROP COLUMN heart_rate from public.anxiety_records
-- 2) Keep source as varchar(50) for descriptive origin (e.g., 'app_detection', 'manual_entry')
-- 3) Keep details as nullable text
-- 4) Optionally keep created_at with default now() (or drop if redundant for you)

-- ==================================================
-- FINAL: Apply minimal DDL to remove heart_rate and align columns
-- ==================================================
-- Ensure uuid extension exists (safe no-op if already present)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop heart_rate column (requested)
ALTER TABLE public.anxiety_records DROP COLUMN IF EXISTS heart_rate;

-- Keep source as varchar(50)
ALTER TABLE public.anxiety_records ALTER COLUMN source TYPE character varying(50);

-- Restrict severity_level to values used by the app and cap size
ALTER TABLE public.anxiety_records ALTER COLUMN severity_level TYPE character varying(10);
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema='public' AND table_name='anxiety_records'
      AND constraint_name='anxiety_records_severity_check'
  ) THEN
    ALTER TABLE public.anxiety_records
      ADD CONSTRAINT anxiety_records_severity_check
      CHECK (severity_level IN ('mild','moderate','severe'));
  END IF;
END$$;

-- Keep is_manual boolean with default
ALTER TABLE public.anxiety_records
  ALTER COLUMN is_manual SET NOT NULL,
  ALTER COLUMN is_manual SET DEFAULT false;

-- Optionally keep created_at with default now() if the column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='anxiety_records' AND column_name='created_at'
  ) THEN
    EXECUTE 'ALTER TABLE public.anxiety_records ALTER COLUMN created_at SET DEFAULT now()';
  END IF;
END$$;

-- Helpful indexes (idempotent creation)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind='i' AND c.relname='anxiety_records_user_timestamp_idx' AND n.nspname='public'
  ) THEN
    CREATE INDEX anxiety_records_user_timestamp_idx
      ON public.anxiety_records (user_id, timestamp DESC);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind='i' AND c.relname='anxiety_records_severity_idx' AND n.nspname='public'
  ) THEN
    CREATE INDEX anxiety_records_severity_idx
      ON public.anxiety_records (severity_level);
  END IF;
END$$;

-- Note: Old “new table/migration” plan removed to avoid confusion. The above minimal DDL is sufficient.

-- ==================================================
-- SIMPLIFIED: Keep existing table structure with minor improvements
-- ==================================================
-- Your existing anxiety_records table is fine! Just improve source descriptions:

-- Increase source column size for better descriptions
ALTER TABLE public.anxiety_records ALTER COLUMN source TYPE character varying(50);

-- Update existing source values to be more descriptive (no heart_rate dependency)
UPDATE public.anxiety_records 
SET source = CASE 
  WHEN source = 'app' THEN 'app_detection'
  ELSE COALESCE(source, 'unknown')
END;

-- Verify the current table structure (should be sufficient as-is)
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'anxiety_records' 
  AND table_schema = 'public'
ORDER BY ordinal_position;