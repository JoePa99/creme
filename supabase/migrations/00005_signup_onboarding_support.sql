-- ============================================================================
-- ADD MISSING SIGNUP/ONBOARDING SUPPORT
-- ============================================================================
-- This adds the functions and tables needed for the signup flow.
-- Run this AFTER running CLEAN_SETUP_FIXED.sql
-- ============================================================================

-- ============================================================================
-- ONBOARDING SESSIONS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.onboarding_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'in_progress', -- in_progress, completed, skipped
  current_step INTEGER DEFAULT 1,
  completed_steps JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  UNIQUE(user_id, company_id)
);

CREATE INDEX IF NOT EXISTS idx_onboarding_sessions_user ON public.onboarding_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_sessions_company ON public.onboarding_sessions(company_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_sessions_status ON public.onboarding_sessions(status);

-- Enable RLS
ALTER TABLE public.onboarding_sessions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for onboarding_sessions
DROP POLICY IF EXISTS "Users can view their own onboarding sessions" ON public.onboarding_sessions;
CREATE POLICY "Users can view their own onboarding sessions" ON public.onboarding_sessions
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own onboarding sessions" ON public.onboarding_sessions;
CREATE POLICY "Users can update their own onboarding sessions" ON public.onboarding_sessions
  FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert their own onboarding sessions" ON public.onboarding_sessions;
CREATE POLICY "Users can insert their own onboarding sessions" ON public.onboarding_sessions
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- CREATE COMPANY AND LINK PROFILE FUNCTION
-- ============================================================================
-- This function is called during signup to atomically create a company
-- and link the user to it as an owner.

CREATE OR REPLACE FUNCTION public.create_company_and_link_profile(
  p_company_name TEXT,
  p_user_id UUID
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  slug TEXT,
  created_at TIMESTAMPTZ
) AS $$
DECLARE
  v_company_id UUID;
  v_slug TEXT;
BEGIN
  -- Generate slug from company name (lowercase, replace spaces with hyphens)
  v_slug := lower(regexp_replace(p_company_name, '[^a-zA-Z0-9]+', '-', 'g'));
  v_slug := trim(both '-' from v_slug);

  -- Ensure slug is unique by appending random suffix if needed
  IF EXISTS (SELECT 1 FROM public.companies WHERE slug = v_slug) THEN
    v_slug := v_slug || '-' || substr(md5(random()::text), 1, 6);
  END IF;

  -- Create the company
  INSERT INTO public.companies (name, slug)
  VALUES (p_company_name, v_slug)
  RETURNING companies.id INTO v_company_id;

  -- Link user to company as owner
  INSERT INTO public.company_members (company_id, user_id, role, status, joined_at)
  VALUES (v_company_id, p_user_id, 'owner', 'active', NOW());

  -- Return the company details
  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.slug,
    c.created_at
  FROM public.companies c
  WHERE c.id = v_company_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Signup/onboarding support added!';
  RAISE NOTICE '';
  RAISE NOTICE 'Added:';
  RAISE NOTICE '- onboarding_sessions table with RLS';
  RAISE NOTICE '- create_company_and_link_profile() function';
  RAISE NOTICE '';
  RAISE NOTICE 'Try signing up again - it should work now!';
END $$;
