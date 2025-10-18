-- ========================================
-- JOURNAL TABLE ROW LEVEL SECURITY POLICIES
-- ========================================
-- This enables journal sharing between patients and their assigned psychologists

-- Enable RLS on journals table
ALTER TABLE public.journals ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view their own journals" ON public.journals;
DROP POLICY IF EXISTS "Users can create their own journals" ON public.journals;
DROP POLICY IF EXISTS "Users can update their own journals" ON public.journals;
DROP POLICY IF EXISTS "Users can delete their own journals" ON public.journals;
DROP POLICY IF EXISTS "Psychologists can view shared journals from assigned patients" ON public.journals;

-- Policy 1: Users can view their own journals
CREATE POLICY "Users can view their own journals" 
ON public.journals 
FOR SELECT 
USING (auth.uid() = user_id);

-- Policy 2: Users can create their own journals
CREATE POLICY "Users can create their own journals" 
ON public.journals 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Policy 3: Users can update their own journals
CREATE POLICY "Users can update their own journals" 
ON public.journals 
FOR UPDATE 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy 4: Users can delete their own journals
CREATE POLICY "Users can delete their own journals" 
ON public.journals 
FOR DELETE 
USING (auth.uid() = user_id);

-- Policy 5: Psychologists can view shared journals from their assigned patients
CREATE POLICY "Psychologists can view shared journals from assigned patients" 
ON public.journals 
FOR SELECT 
USING (
  shared_with_psychologist = true 
  AND EXISTS (
    SELECT 1 
    FROM public.user_profiles up
    JOIN public.psychologists p ON p.id = up.assigned_psychologist_id
    WHERE up.id = journals.user_id
    AND p.user_id = auth.uid()
    AND p.is_active = true
  )
);

-- Create index for better performance on psychologist queries
CREATE INDEX IF NOT EXISTS idx_journals_shared_user ON public.journals(user_id, shared_with_psychologist) 
WHERE shared_with_psychologist = true;

-- Create index for date-based queries
CREATE INDEX IF NOT EXISTS idx_journals_date ON public.journals(date DESC);

-- Verify policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'journals';
