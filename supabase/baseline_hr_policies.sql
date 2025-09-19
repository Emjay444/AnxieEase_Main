-- RLS and constraints for resting heart rate (baseline) and devices
-- Run this in Supabase SQL editor

-- Enable RLS
ALTER TABLE IF EXISTS public.baseline_heart_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.wearable_devices ENABLE ROW LEVEL SECURITY;

-- Baseline heart rate policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='baseline_heart_rates' AND policyname='Users select own baselines'
  ) THEN
    CREATE POLICY "Users select own baselines" ON public.baseline_heart_rates
      FOR SELECT USING (user_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='baseline_heart_rates' AND policyname='Users insert own baselines'
  ) THEN
    CREATE POLICY "Users insert own baselines" ON public.baseline_heart_rates
      FOR INSERT WITH CHECK (user_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='baseline_heart_rates' AND policyname='Users update own baselines'
  ) THEN
    CREATE POLICY "Users update own baselines" ON public.baseline_heart_rates
      FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

-- Wearable devices policies (allow linking and updates by owner)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='wearable_devices' AND policyname='Users select own or unassigned devices'
  ) THEN
    CREATE POLICY "Users select own or unassigned devices" ON public.wearable_devices
      FOR SELECT USING (user_id = auth.uid() OR user_id IS NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='wearable_devices' AND policyname='Users insert own devices'
  ) THEN
    CREATE POLICY "Users insert own devices" ON public.wearable_devices
      FOR INSERT WITH CHECK (user_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='wearable_devices' AND policyname='Users update own or claim unassigned device'
  ) THEN
    -- Can update rows they own; can also claim an unassigned row by setting user_id to themselves
    CREATE POLICY "Users update own or claim unassigned device" ON public.wearable_devices
      FOR UPDATE USING (user_id = auth.uid() OR user_id IS NULL)
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

-- Ensure exactly one baseline row per user+device
-- If you want historical baselines, move them to another table; here we keep a single canonical row
CREATE UNIQUE INDEX IF NOT EXISTS unique_baseline_per_device
ON public.baseline_heart_rates (user_id, device_id);

-- Optional: allow users to delete their baseline (cleanup / reset)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='baseline_heart_rates' AND policyname='Users delete own baselines'
  ) THEN
    CREATE POLICY "Users delete own baselines" ON public.baseline_heart_rates
      FOR DELETE USING (user_id = auth.uid());
  END IF;
END $$;
