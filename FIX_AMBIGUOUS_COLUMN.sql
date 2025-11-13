-- ============================================================================
-- FIX AMBIGUOUS COLUMN REFERENCE IN SIGNUP FUNCTION
-- ============================================================================
-- Fixes error: "column reference 'slug' is ambiguous"
-- ============================================================================

-- Drop and recreate with fully qualified column names
DROP FUNCTION IF EXISTS public.create_company_and_link_profile(text, uuid);

CREATE FUNCTION public.create_company_and_link_profile(
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
  -- FIX: Fully qualify the column name to avoid ambiguity
  IF EXISTS (SELECT 1 FROM public.companies c WHERE c.slug = v_slug) THEN
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
-- SUCCESS
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Function fixed! Try signing up again.';
END $$;
