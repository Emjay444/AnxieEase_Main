-- SQL to remove temperature and location fields from anxiety_records table
ALTER TABLE public.anxiety_records
DROP COLUMN IF EXISTS temperature,
DROP COLUMN IF EXISTS location_latitude,
DROP COLUMN IF EXISTS location_longitude;

-- Note: This is a destructive change that will permanently remove these columns and their data
-- Make sure to have a backup before running this SQL 