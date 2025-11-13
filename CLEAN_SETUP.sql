-- ============================================================================
-- CLEAN ARCHITECTURE - COMPLETE SETUP
-- ============================================================================
-- This script applies all clean architecture migrations in order.
-- Run this in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/znpbeicliyymvyoaojzz/sql/new
-- ============================================================================

-- ============================================================================
-- PART 1: EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS http;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ============================================================================
-- PART 2: CORE TABLES
-- ============================================================================

-- Companies table
CREATE TABLE IF NOT EXISTS public.companies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  stripe_customer_id TEXT UNIQUE,
  stripe_subscription_id TEXT,
  subscription_status TEXT DEFAULT 'trial',
  subscription_tier TEXT DEFAULT 'starter',
  trial_ends_at TIMESTAMPTZ,
  settings JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_companies_slug ON public.companies(slug);
CREATE INDEX IF NOT EXISTS idx_companies_stripe_customer ON public.companies(stripe_customer_id);

-- Users table (synced with auth.users)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  notification_preferences JSONB DEFAULT '{"email": true, "push": true}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);

-- Auto-create user profile when someone signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Company members
CREATE TABLE IF NOT EXISTS public.company_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member',
  invited_by UUID REFERENCES public.users(id),
  invited_at TIMESTAMPTZ DEFAULT NOW(),
  joined_at TIMESTAMPTZ,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(company_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_company_members_company ON public.company_members(company_id);
CREATE INDEX IF NOT EXISTS idx_company_members_user ON public.company_members(user_id);

-- Company OS (Tier 1 knowledge)
CREATE TABLE IF NOT EXISTS public.company_os (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_path TEXT,
  file_size_bytes BIGINT,
  structured_json JSONB,
  raw_text TEXT,
  status TEXT DEFAULT 'processing',
  processing_error TEXT,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(company_id)
);

CREATE INDEX IF NOT EXISTS idx_company_os_company ON public.company_os(company_id);

-- Agents
CREATE TABLE IF NOT EXISTS public.agents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  system_prompt TEXT NOT NULL,
  model TEXT DEFAULT 'gpt-4o',
  temperature NUMERIC(2,1) DEFAULT 0.7,
  max_tokens INTEGER DEFAULT 4000,
  use_company_os BOOLEAN DEFAULT true,
  use_playbooks BOOLEAN DEFAULT true,
  max_context_chunks INTEGER DEFAULT 10,
  tools JSONB DEFAULT '[]'::jsonb,
  chain_to_agents UUID[],
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agents_company ON public.agents(company_id);
CREATE INDEX IF NOT EXISTS idx_agents_active ON public.agents(is_active);

-- Documents with vector embeddings (Tier 2 knowledge)
CREATE TABLE IF NOT EXISTS public.documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL,
  file_name TEXT,
  agent_id UUID REFERENCES public.agents(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  embedding vector(1536),
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_documents_company ON public.documents(company_id);
CREATE INDEX IF NOT EXISTS idx_documents_type ON public.documents(document_type);
CREATE INDEX IF NOT EXISTS idx_documents_agent ON public.documents(agent_id);
CREATE INDEX IF NOT EXISTS idx_documents_embedding ON public.documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Playbooks (Tier 3 knowledge)
CREATE TABLE IF NOT EXISTS public.playbooks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT,
  content TEXT NOT NULL,
  is_public BOOLEAN DEFAULT false,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_playbooks_company ON public.playbooks(company_id);

-- Channels (Slack-like interface)
CREATE TABLE IF NOT EXISTS public.channels (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  is_private BOOLEAN DEFAULT false,
  is_dm BOOLEAN DEFAULT false,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(company_id, name)
);

CREATE INDEX IF NOT EXISTS idx_channels_company ON public.channels(company_id);

-- Channel members (humans and AI)
CREATE TABLE IF NOT EXISTS public.channel_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  agent_id UUID REFERENCES public.agents(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member',
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (
    (user_id IS NOT NULL AND agent_id IS NULL) OR
    (user_id IS NULL AND agent_id IS NOT NULL)
  ),
  UNIQUE(channel_id, user_id),
  UNIQUE(channel_id, agent_id)
);

CREATE INDEX IF NOT EXISTS idx_channel_members_channel ON public.channel_members(channel_id);

-- Chat messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  agent_id UUID REFERENCES public.agents(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  mentioned_user_ids UUID[],
  mentioned_agent_ids UUID[],
  parent_message_id UUID REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  ai_model TEXT,
  context_used JSONB,
  tokens_used INTEGER,
  attachments JSONB DEFAULT '[]'::jsonb,
  is_edited BOOLEAN DEFAULT false,
  edited_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (
    (user_id IS NOT NULL AND agent_id IS NULL) OR
    (user_id IS NULL AND agent_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_channel ON public.chat_messages(channel_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created ON public.chat_messages(created_at DESC);

-- Usage tracking
CREATE TABLE IF NOT EXISTS public.usage_tracking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  period_start TIMESTAMPTZ NOT NULL,
  period_end TIMESTAMPTZ NOT NULL,
  total_tokens_used BIGINT DEFAULT 0,
  total_messages_sent INTEGER DEFAULT 0,
  total_documents_processed INTEGER DEFAULT 0,
  estimated_cost_usd NUMERIC(10,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(company_id, period_start)
);

CREATE INDEX IF NOT EXISTS idx_usage_tracking_company ON public.usage_tracking(company_id);

-- Platform admins table
CREATE TABLE IF NOT EXISTS public.platform_admins (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PART 3: STORAGE BUCKETS
-- ============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('company-os', 'company-os', false),
  ('agent-documents', 'agent-documents', false),
  ('chat-attachments', 'chat-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- PART 4: ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
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

-- Helper function: Get user's companies
CREATE OR REPLACE FUNCTION public.get_user_companies(user_uuid UUID)
RETURNS TABLE(company_uuid UUID) AS $$
BEGIN
  RETURN QUERY
  SELECT company_id FROM public.company_members WHERE user_id = user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function: Check if platform admin
CREATE OR REPLACE FUNCTION public.is_platform_admin()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
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

-- Companies policies
DROP POLICY IF EXISTS "Users can view their companies" ON public.companies;
CREATE POLICY "Users can view their companies" ON public.companies
  FOR SELECT USING (id IN (SELECT get_user_companies(auth.uid())));

DROP POLICY IF EXISTS "Users can create companies" ON public.companies;
CREATE POLICY "Users can create companies" ON public.companies
  FOR INSERT WITH CHECK (true);

-- Users policies
DROP POLICY IF EXISTS "Users are viewable by members of their companies" ON public.users;
CREATE POLICY "Users are viewable by members of their companies" ON public.users
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- Documents policies (multi-tenant isolation)
DROP POLICY IF EXISTS "Users can view documents from their companies" ON public.documents;
CREATE POLICY "Users can view documents from their companies" ON public.documents
  FOR SELECT USING (company_id IN (SELECT get_user_companies(auth.uid())));

DROP POLICY IF EXISTS "Users can insert documents to their companies" ON public.documents;
CREATE POLICY "Users can insert documents to their companies" ON public.documents
  FOR INSERT WITH CHECK (company_id IN (SELECT get_user_companies(auth.uid())));

-- Storage bucket policies
DROP POLICY IF EXISTS "Users can upload to company-os bucket" ON storage.objects;
CREATE POLICY "Users can upload to company-os bucket" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'company-os' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can read from company-os bucket" ON storage.objects;
CREATE POLICY "Users can read from company-os bucket" ON storage.objects
  FOR SELECT USING (bucket_id = 'company-os' AND auth.role() = 'authenticated');

-- ============================================================================
-- PART 5: VECTOR SEARCH FUNCTIONS
-- ============================================================================

-- Hybrid search function (vector + keyword)
CREATE OR REPLACE FUNCTION public.hybrid_search_documents(
  query_embedding vector(1536),
  query_text TEXT,
  match_company_id UUID,
  match_agent_id UUID DEFAULT NULL,
  match_count INTEGER DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  document_type TEXT,
  file_name TEXT,
  similarity FLOAT,
  metadata JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.content,
    d.document_type,
    d.file_name,
    1 - (d.embedding <=> query_embedding) AS similarity,
    d.metadata
  FROM public.documents d
  WHERE d.company_id = match_company_id
    AND (match_agent_id IS NULL OR d.agent_id IS NULL OR d.agent_id = match_agent_id)
    AND (
      d.embedding <=> query_embedding < 0.5  -- Vector similarity threshold
      OR d.content ILIKE '%' || query_text || '%'  -- Keyword match
    )
  ORDER BY similarity DESC
  LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- Context retrieval for chat
CREATE OR REPLACE FUNCTION public.get_chat_context(
  user_message TEXT,
  message_embedding vector(1536),
  for_company_id UUID,
  for_agent_id UUID DEFAULT NULL,
  max_chunks INTEGER DEFAULT 10
)
RETURNS TABLE (
  chunk_content TEXT,
  chunk_type TEXT,
  chunk_file TEXT,
  chunk_similarity FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    content AS chunk_content,
    document_type AS chunk_type,
    file_name AS chunk_file,
    1 - (embedding <=> message_embedding) AS chunk_similarity
  FROM public.documents
  WHERE company_id = for_company_id
    AND (for_agent_id IS NULL OR agent_id IS NULL OR agent_id = for_agent_id)
  ORDER BY embedding <=> message_embedding
  LIMIT max_chunks;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Clean architecture setup complete!';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '1. Sign up at your Vercel app with: joe@upupdndn.ai';
  RAISE NOTICE '2. Run this SQL to make yourself platform admin:';
  RAISE NOTICE '   INSERT INTO platform_admins (user_id)';
  RAISE NOTICE '   SELECT id FROM users WHERE email = ''joe@upupdndn.ai'';';
  RAISE NOTICE '';
  RAISE NOTICE '3. Upload a 90-page CompanyOS document to test!';
END $$;
