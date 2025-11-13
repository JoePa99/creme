-- Clean Architecture Migration - Row Level Security (RLS)
-- Phase 1: Multi-tenant security with proper isolation
-- Created: 2025-11-12

-- ============================================================================
-- ENABLE RLS ON ALL TABLES
-- ============================================================================

ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_os ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.playbooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_tracking ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- HELPER FUNCTION: Get user's companies
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_companies(user_uuid UUID)
RETURNS TABLE(company_id UUID) AS $$
BEGIN
  RETURN QUERY
  SELECT cm.company_id
  FROM public.company_members cm
  WHERE cm.user_id = user_uuid
    AND cm.status = 'active';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- COMPANIES: RLS Policies
-- ============================================================================

-- Users can view companies they're members of
CREATE POLICY "Users can view their companies"
  ON public.companies FOR SELECT
  USING (
    id IN (SELECT get_user_companies(auth.uid()))
  );

-- Users with 'owner' or 'admin' role can update their companies
CREATE POLICY "Admins can update their companies"
  ON public.companies FOR UPDATE
  USING (
    id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- Users can create companies (will become owner)
CREATE POLICY "Users can create companies"
  ON public.companies FOR INSERT
  WITH CHECK (true);

-- ============================================================================
-- USERS: RLS Policies
-- ============================================================================

-- Users can view their own profile
CREATE POLICY "Users can view own profile"
  ON public.users FOR SELECT
  USING (id = auth.uid());

-- Users can view profiles of users in their companies
CREATE POLICY "Users can view company members"
  ON public.users FOR SELECT
  USING (
    id IN (
      SELECT cm.user_id
      FROM public.company_members cm
      WHERE cm.company_id IN (SELECT get_user_companies(auth.uid()))
    )
  );

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON public.users FOR UPDATE
  USING (id = auth.uid());

-- Users can insert their own profile (on signup)
CREATE POLICY "Users can create own profile"
  ON public.users FOR INSERT
  WITH CHECK (id = auth.uid());

-- ============================================================================
-- COMPANY_MEMBERS: RLS Policies
-- ============================================================================

-- Users can view members of their companies
CREATE POLICY "Users can view company members"
  ON public.company_members FOR SELECT
  USING (
    company_id IN (SELECT get_user_companies(auth.uid()))
  );

-- Admins can add members to their companies
CREATE POLICY "Admins can add company members"
  ON public.company_members FOR INSERT
  WITH CHECK (
    company_id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- Admins can update member roles in their companies
CREATE POLICY "Admins can update company members"
  ON public.company_members FOR UPDATE
  USING (
    company_id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- Admins can remove members from their companies
CREATE POLICY "Admins can remove company members"
  ON public.company_members FOR DELETE
  USING (
    company_id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- ============================================================================
-- COMPANY_OS: RLS Policies
-- ============================================================================

-- Users can view Company OS of their companies
CREATE POLICY "Users can view company OS"
  ON public.company_os FOR SELECT
  USING (
    company_id IN (SELECT get_user_companies(auth.uid()))
  );

-- Admins can upload/update Company OS
CREATE POLICY "Admins can manage company OS"
  ON public.company_os FOR ALL
  USING (
    company_id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- ============================================================================
-- AGENTS: RLS Policies
-- ============================================================================

-- Users can view agents in their companies
CREATE POLICY "Users can view company agents"
  ON public.agents FOR SELECT
  USING (
    company_id IN (SELECT get_user_companies(auth.uid()))
  );

-- Admins can create agents
CREATE POLICY "Admins can create agents"
  ON public.agents FOR INSERT
  WITH CHECK (
    company_id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- Admins can update agents
CREATE POLICY "Admins can update agents"
  ON public.agents FOR UPDATE
  USING (
    company_id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- Admins can delete agents
CREATE POLICY "Admins can delete agents"
  ON public.agents FOR DELETE
  USING (
    company_id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- ============================================================================
-- DOCUMENTS: RLS Policies
-- ============================================================================

-- Users can view documents in their companies
CREATE POLICY "Users can view company documents"
  ON public.documents FOR SELECT
  USING (
    company_id IN (SELECT get_user_companies(auth.uid()))
  );

-- Service role (edge functions) can manage all documents
-- This is handled by using service role key in edge functions

-- Admins can delete documents
CREATE POLICY "Admins can delete documents"
  ON public.documents FOR DELETE
  USING (
    company_id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- ============================================================================
-- PLAYBOOKS: RLS Policies
-- ============================================================================

-- Users can view playbooks in their companies or public playbooks
CREATE POLICY "Users can view playbooks"
  ON public.playbooks FOR SELECT
  USING (
    company_id IN (SELECT get_user_companies(auth.uid()))
    OR is_public = true
  );

-- Admins can create playbooks
CREATE POLICY "Admins can create playbooks"
  ON public.playbooks FOR INSERT
  WITH CHECK (
    company_id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- Admins can update their playbooks
CREATE POLICY "Admins can update playbooks"
  ON public.playbooks FOR UPDATE
  USING (
    company_id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- Admins can delete their playbooks
CREATE POLICY "Admins can delete playbooks"
  ON public.playbooks FOR DELETE
  USING (
    company_id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- ============================================================================
-- CHANNELS: RLS Policies
-- ============================================================================

-- Users can view channels they're members of (or public channels)
CREATE POLICY "Users can view their channels"
  ON public.channels FOR SELECT
  USING (
    -- User is a member of the channel
    id IN (
      SELECT channel_id
      FROM public.channel_members
      WHERE user_id = auth.uid()
    )
    -- OR channel is public in user's company
    OR (
      is_private = false
      AND company_id IN (SELECT get_user_companies(auth.uid()))
    )
  );

-- Users can create channels in their companies
CREATE POLICY "Users can create channels"
  ON public.channels FOR INSERT
  WITH CHECK (
    company_id IN (SELECT get_user_companies(auth.uid()))
  );

-- Channel admins can update channels
CREATE POLICY "Channel admins can update channels"
  ON public.channels FOR UPDATE
  USING (
    id IN (
      SELECT cm.channel_id
      FROM public.channel_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role = 'admin'
    )
  );

-- Channel admins can delete channels
CREATE POLICY "Channel admins can delete channels"
  ON public.channels FOR DELETE
  USING (
    id IN (
      SELECT cm.channel_id
      FROM public.channel_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role = 'admin'
    )
  );

-- ============================================================================
-- CHANNEL_MEMBERS: RLS Policies
-- ============================================================================

-- Users can view members of channels they're in
CREATE POLICY "Users can view channel members"
  ON public.channel_members FOR SELECT
  USING (
    channel_id IN (
      SELECT channel_id
      FROM public.channel_members
      WHERE user_id = auth.uid()
    )
  );

-- Channel admins can add members
CREATE POLICY "Channel admins can add members"
  ON public.channel_members FOR INSERT
  WITH CHECK (
    channel_id IN (
      SELECT cm.channel_id
      FROM public.channel_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role = 'admin'
    )
  );

-- Channel admins can remove members
CREATE POLICY "Channel admins can remove members"
  ON public.channel_members FOR DELETE
  USING (
    channel_id IN (
      SELECT cm.channel_id
      FROM public.channel_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role = 'admin'
    )
  );

-- ============================================================================
-- CHAT_MESSAGES: RLS Policies
-- ============================================================================

-- Users can view messages in channels they're members of
CREATE POLICY "Users can view channel messages"
  ON public.chat_messages FOR SELECT
  USING (
    channel_id IN (
      SELECT channel_id
      FROM public.channel_members
      WHERE user_id = auth.uid()
    )
  );

-- Users can send messages in channels they're members of
CREATE POLICY "Users can send messages"
  ON public.chat_messages FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND channel_id IN (
      SELECT channel_id
      FROM public.channel_members
      WHERE user_id = auth.uid()
    )
  );

-- Users can update their own messages
CREATE POLICY "Users can update own messages"
  ON public.chat_messages FOR UPDATE
  USING (user_id = auth.uid());

-- Users can delete their own messages
CREATE POLICY "Users can delete own messages"
  ON public.chat_messages FOR DELETE
  USING (user_id = auth.uid());

-- ============================================================================
-- USAGE_TRACKING: RLS Policies
-- ============================================================================

-- Admins can view usage for their companies
CREATE POLICY "Admins can view usage tracking"
  ON public.usage_tracking FOR SELECT
  USING (
    company_id IN (
      SELECT cm.company_id
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

-- ============================================================================
-- STORAGE: RLS Policies
-- ============================================================================

-- Company OS bucket: Admins can upload, users can read
CREATE POLICY "Admins can upload to company-os bucket"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'company-os'
    AND (storage.foldername(name))[1] IN (
      SELECT cm.company_id::text
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

CREATE POLICY "Users can read from company-os bucket"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'company-os'
    AND (storage.foldername(name))[1] IN (
      SELECT get_user_companies(auth.uid())::text
    )
  );

-- Agent documents bucket: Admins can upload, users can read
CREATE POLICY "Admins can upload to agent-documents bucket"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'agent-documents'
    AND (storage.foldername(name))[1] IN (
      SELECT cm.company_id::text
      FROM public.company_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
        AND cm.status = 'active'
    )
  );

CREATE POLICY "Users can read from agent-documents bucket"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'agent-documents'
    AND (storage.foldername(name))[1] IN (
      SELECT get_user_companies(auth.uid())::text
    )
  );

-- Chat attachments bucket: Channel members can upload and read
CREATE POLICY "Users can upload to chat-attachments bucket"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'chat-attachments'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT channel_id
      FROM public.channel_members
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can read from chat-attachments bucket"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'chat-attachments'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT channel_id
      FROM public.channel_members
      WHERE user_id = auth.uid()
    )
  );

-- ============================================================================
-- FUNCTIONS FOR EDGE FUNCTIONS (Service Role Access)
-- ============================================================================

-- Function to create company and make user owner (bypasses RLS)
CREATE OR REPLACE FUNCTION public.create_company_with_owner(
  company_name TEXT,
  company_slug TEXT,
  user_uuid UUID
)
RETURNS UUID AS $$
DECLARE
  new_company_id UUID;
BEGIN
  -- Insert company
  INSERT INTO public.companies (name, slug)
  VALUES (company_name, company_slug)
  RETURNING id INTO new_company_id;

  -- Make user owner
  INSERT INTO public.company_members (company_id, user_id, role, status, joined_at)
  VALUES (new_company_id, user_uuid, 'owner', 'active', NOW());

  RETURN new_company_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has access to company
CREATE OR REPLACE FUNCTION public.user_has_company_access(
  user_uuid UUID,
  check_company_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.company_members
    WHERE user_id = user_uuid
      AND company_id = check_company_id
      AND status = 'active'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is admin in company
CREATE OR REPLACE FUNCTION public.user_is_admin(
  user_uuid UUID,
  check_company_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.company_members
    WHERE user_id = user_uuid
      AND company_id = check_company_id
      AND role IN ('owner', 'admin')
      AND status = 'active'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION public.get_user_companies IS 'Helper function to get all company IDs a user belongs to';
COMMENT ON FUNCTION public.create_company_with_owner IS 'Creates a company and assigns the user as owner (bypasses RLS)';
COMMENT ON FUNCTION public.user_has_company_access IS 'Checks if user has access to a company';
COMMENT ON FUNCTION public.user_is_admin IS 'Checks if user is an admin/owner in a company';
