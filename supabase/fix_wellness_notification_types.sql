-- Fix Wellness Reminder Notification Types
-- This script corrects any wellness/breathing reminders that were incorrectly stored as 'alert' type

-- Update wellness reminders to have correct type
UPDATE public.notifications
SET type = 'reminder'
WHERE type = 'alert'
  AND (
    -- Match wellness reminder titles
    title ILIKE '%wellness%' OR
    title ILIKE '%breathing%' OR
    title ILIKE '%reflection%' OR
    title ILIKE '%reset%' OR
    title ILIKE '%gratitude%' OR
    title ILIKE '%wind down%' OR
    title ILIKE '%night%' OR
    title ILIKE '%sleep%' OR
    title ILIKE '%peaceful%' OR
    title ILIKE '%transition%' OR
    title ILIKE '%promise%' OR
    title ILIKE '%meditation%' OR
    title ILIKE '%mindful%' OR
    title ILIKE '%grounding%' OR
    -- Match wellness reminder message content
    message ILIKE '%wellness%' OR
    message ILIKE '%breathing exercise%' OR
    message ILIKE '%grounding%' OR
    message ILIKE '%breathe%' OR
    message ILIKE '%take a moment%' OR
    message ILIKE '%check how you''re feeling%'
  )
  -- Safety check: Exclude actual anxiety alerts
  AND title NOT ILIKE '%anxiety detected%'
  AND title NOT ILIKE '%anxiety alert%'
  AND title NOT ILIKE '%elevated heart%'
  AND title NOT ILIKE '%detection%'
  AND message NOT ILIKE '%experiencing anxiety%'
  AND message NOT ILIKE '%heart rate elevated%';

-- Show summary of changes
SELECT 
  'Total wellness reminders corrected:' AS description,
  COUNT(*) AS count
FROM public.notifications
WHERE type = 'reminder'
  AND (
    title ILIKE '%wellness%' OR
    title ILIKE '%breathing%' OR
    title ILIKE '%reflection%' OR
    message ILIKE '%wellness%' OR
    message ILIKE '%breathing exercise%'
  );

-- Show remaining alert notifications (should only be anxiety alerts now)
SELECT 
  'Remaining alerts (should be anxiety only):' AS description,
  COUNT(*) AS count
FROM public.notifications
WHERE type = 'alert';

-- Sample of remaining alerts for verification
SELECT 
  title,
  LEFT(message, 50) AS message_preview,
  created_at
FROM public.notifications
WHERE type = 'alert'
ORDER BY created_at DESC
LIMIT 10;
