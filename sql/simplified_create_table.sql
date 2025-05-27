-- Simplified direct creation of appointments table

-- Create the appointments table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.appointments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  psychologist_id uuid NOT NULL,
  appointment_date timestamp with time zone NOT NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  response_message text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- Basic policy
CREATE POLICY "Allow all access to authenticated users" 
  ON public.appointments 
  FOR ALL 
  TO authenticated 
  USING (true); 