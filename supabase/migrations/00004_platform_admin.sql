-- Platform Admin Support for Clean Architecture
-- Allows designated users to access admin dashboard and see all companies/users

-- ============================================================================
-- PLATFORM ADMINS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.platform_admins (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PLATFORM ADMIN HELPER FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_platform_admin()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.platform_admins WHERE user_id = auth.uid()
  ) INTO v_is_admin;

  RETURN COALESCE(v_is_admin, false);
END;
$$;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE public.platform_admins IS 'Platform administrators with access to all companies and admin dashboard';
COMMENT ON FUNCTION public.is_platform_admin IS 'Check if the current user is a platform administrator';
