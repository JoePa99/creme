-- Clean Architecture Migration - Core Schema
-- Phase 1: Foundation for multi-tenant SaaS with 3-tier knowledge architecture
-- Created: 2025-11-12

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable vector similarity search (for embeddings)
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable HTTP requests (for webhooks, API calls)
CREATE EXTENSION IF NOT EXISTS http;

-- Enable network requests (for async operations)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Companies: Multi-tenant isolation
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.companies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,

  -- Subscription & billing
  stripe_customer_id TEXT UNIQUE,
  stripe_subscription_id TEXT,
  subscription_status TEXT DEFAULT 'trial', -- trial, active, canceled, past_due
  subscription_tier TEXT DEFAULT 'starter', -- starter, professional, enterprise
  trial_ends_at TIMESTAMPTZ,

  -- Settings
  settings JSONB DEFAULT '{}'::jsonb,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast slug lookups
CREATE INDEX idx_companies_slug ON public.companies(slug);
CREATE INDEX idx_companies_stripe_customer ON public.companies(stripe_customer_id);

-- ----------------------------------------------------------------------------
-- Users: Authentication & profile (synced with Supabase Auth)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT,
  avatar_url TEXT,

  -- Settings
  notification_preferences JSONB DEFAULT '{"email": true, "push": true}'::jsonb,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_email ON public.users(email);

-- ----------------------------------------------------------------------------
-- Company Members: User-to-Company relationships with roles
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.company_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

  -- Role-based access control
  role TEXT NOT NULL DEFAULT 'member', -- owner, admin, member, viewer

  -- Invitation tracking
  invited_by UUID REFERENCES public.users(id),
  invited_at TIMESTAMPTZ DEFAULT NOW(),
  joined_at TIMESTAMPTZ,

  -- Status
  status TEXT DEFAULT 'active', -- active, suspended, invited

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  UNIQUE(company_id, user_id)
);

CREATE INDEX idx_company_members_company ON public.company_members(company_id);
CREATE INDEX idx_company_members_user ON public.company_members(user_id);
CREATE INDEX idx_company_members_role ON public.company_members(role);

-- ----------------------------------------------------------------------------
-- TIER 1 KNOWLEDGE: Company OS (Global context for all agents)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.company_os (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,

  -- File tracking
  file_name TEXT NOT NULL,
  file_path TEXT, -- Storage bucket path
  file_size_bytes BIGINT,

  -- Processed content
  structured_json JSONB, -- Parsed structure (mission, values, brand guide, etc.)
  raw_text TEXT, -- Full extracted text

  -- Processing status
  status TEXT DEFAULT 'processing', -- processing, ready, failed
  processing_error TEXT,

  -- Metadata
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Only one active Company OS per company
  UNIQUE(company_id)
);

CREATE INDEX idx_company_os_company ON public.company_os(company_id);
CREATE INDEX idx_company_os_status ON public.company_os(status);

-- ----------------------------------------------------------------------------
-- AI Agents: Configurable AI employees
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.agents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,

  -- Agent identity
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,

  -- Agent configuration
  system_prompt TEXT NOT NULL,
  model TEXT DEFAULT 'gpt-4o', -- gpt-4o, claude-3-5-sonnet, gemini-2.0-flash, etc.
  temperature NUMERIC(2,1) DEFAULT 0.7,
  max_tokens INTEGER DEFAULT 4000,

  -- Context configuration
  use_company_os BOOLEAN DEFAULT true, -- Access to Company OS?
  use_playbooks BOOLEAN DEFAULT true, -- Access to Playbooks?
  max_context_chunks INTEGER DEFAULT 10, -- How many document chunks to inject

  -- Behavior
  tools JSONB DEFAULT '[]'::jsonb, -- Available tools/functions
  chain_to_agents UUID[], -- Agent IDs this agent can hand off to

  -- Status
  is_active BOOLEAN DEFAULT true,

  -- Metadata
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_agents_company ON public.agents(company_id);
CREATE INDEX idx_agents_active ON public.agents(is_active);

-- ----------------------------------------------------------------------------
-- TIER 2 KNOWLEDGE: Documents (Vector store with scoping)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,

  -- Document metadata
  document_type TEXT NOT NULL, -- company_os, agent_specific, playbook
  file_name TEXT,

  -- Scoping: Who can access this document?
  agent_id UUID REFERENCES public.agents(id) ON DELETE CASCADE, -- NULL = all agents

  -- Content & embedding
  content TEXT NOT NULL, -- Chunk of text
  embedding vector(1536), -- OpenAI text-embedding-ada-002 dimension

  -- Chunk tracking
  metadata JSONB DEFAULT '{}'::jsonb, -- chunk_index, total_chunks, source, etc.

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for vector search and filtering
CREATE INDEX idx_documents_company ON public.documents(company_id);
CREATE INDEX idx_documents_type ON public.documents(document_type);
CREATE INDEX idx_documents_agent ON public.documents(agent_id);
CREATE INDEX idx_documents_embedding ON public.documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- ----------------------------------------------------------------------------
-- TIER 3 KNOWLEDGE: Playbooks (General RAG knowledge base)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.playbooks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,

  -- Playbook identity
  title TEXT NOT NULL,
  description TEXT,
  category TEXT, -- sales, marketing, operations, hr, etc.

  -- Content
  content TEXT NOT NULL, -- Full playbook text

  -- Visibility
  is_public BOOLEAN DEFAULT false, -- Can other companies see this?

  -- Metadata
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_playbooks_company ON public.playbooks(company_id);
CREATE INDEX idx_playbooks_category ON public.playbooks(category);
CREATE INDEX idx_playbooks_public ON public.playbooks(is_public) WHERE is_public = true;

-- ----------------------------------------------------------------------------
-- Slack-like Interface: Channels
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.channels (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,

  -- Channel identity
  name TEXT NOT NULL,
  description TEXT,

  -- Channel type
  is_private BOOLEAN DEFAULT false,
  is_dm BOOLEAN DEFAULT false, -- Direct message channel

  -- Metadata
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(company_id, name)
);

CREATE INDEX idx_channels_company ON public.channels(company_id);
CREATE INDEX idx_channels_private ON public.channels(is_private);

-- ----------------------------------------------------------------------------
-- Channel Members: Who's in each channel (humans and AI)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.channel_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,

  -- Member can be human OR AI
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  agent_id UUID REFERENCES public.agents(id) ON DELETE CASCADE,

  -- Only one of user_id or agent_id should be set
  CHECK (
    (user_id IS NOT NULL AND agent_id IS NULL) OR
    (user_id IS NULL AND agent_id IS NOT NULL)
  ),

  -- Membership
  role TEXT DEFAULT 'member', -- admin, member
  joined_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicates
  UNIQUE(channel_id, user_id),
  UNIQUE(channel_id, agent_id)
);

CREATE INDEX idx_channel_members_channel ON public.channel_members(channel_id);
CREATE INDEX idx_channel_members_user ON public.channel_members(user_id);
CREATE INDEX idx_channel_members_agent ON public.channel_members(agent_id);

-- ----------------------------------------------------------------------------
-- Chat Messages: Conversations in channels
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,

  -- Message author (human or AI)
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  agent_id UUID REFERENCES public.agents(id) ON DELETE CASCADE,

  -- Only one of user_id or agent_id should be set
  CHECK (
    (user_id IS NOT NULL AND agent_id IS NULL) OR
    (user_id IS NULL AND agent_id IS NOT NULL)
  ),

  -- Message content
  content TEXT NOT NULL,

  -- @mentions parsing
  mentioned_user_ids UUID[], -- Array of user IDs mentioned
  mentioned_agent_ids UUID[], -- Array of agent IDs mentioned

  -- Threading
  parent_message_id UUID REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  thread_count INTEGER DEFAULT 0,

  -- AI-specific metadata
  ai_model TEXT, -- Which model generated this (if from AI)
  context_used JSONB, -- What context was injected (for debugging)
  tokens_used INTEGER,

  -- Attachments
  attachments JSONB DEFAULT '[]'::jsonb,

  -- Status
  is_edited BOOLEAN DEFAULT false,
  edited_at TIMESTAMPTZ,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_messages_channel ON public.chat_messages(channel_id);
CREATE INDEX idx_chat_messages_user ON public.chat_messages(user_id);
CREATE INDEX idx_chat_messages_agent ON public.chat_messages(agent_id);
CREATE INDEX idx_chat_messages_parent ON public.chat_messages(parent_message_id);
CREATE INDEX idx_chat_messages_created ON public.chat_messages(created_at DESC);

-- ----------------------------------------------------------------------------
-- Usage Tracking: Token/request limits per company
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.usage_tracking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,

  -- Usage period
  period_start TIMESTAMPTZ NOT NULL,
  period_end TIMESTAMPTZ NOT NULL,

  -- Metrics
  total_tokens_used BIGINT DEFAULT 0,
  total_messages_sent INTEGER DEFAULT 0,
  total_documents_processed INTEGER DEFAULT 0,

  -- Cost tracking (optional)
  estimated_cost_usd NUMERIC(10,2) DEFAULT 0,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(company_id, period_start)
);

CREATE INDEX idx_usage_tracking_company ON public.usage_tracking(company_id);
CREATE INDEX idx_usage_tracking_period ON public.usage_tracking(period_start DESC);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_companies_updated_at BEFORE UPDATE ON public.companies
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_company_members_updated_at BEFORE UPDATE ON public.company_members
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_company_os_updated_at BEFORE UPDATE ON public.company_os
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_agents_updated_at BEFORE UPDATE ON public.agents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_playbooks_updated_at BEFORE UPDATE ON public.playbooks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_channels_updated_at BEFORE UPDATE ON public.channels
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- STORAGE BUCKETS
-- ============================================================================

-- Create storage buckets for file uploads
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('company-os', 'company-os', false),
  ('agent-documents', 'agent-documents', false),
  ('chat-attachments', 'chat-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE public.companies IS 'Multi-tenant companies. Each company is isolated.';
COMMENT ON TABLE public.users IS 'User profiles synced with Supabase Auth.';
COMMENT ON TABLE public.company_members IS 'Links users to companies with roles.';
COMMENT ON TABLE public.company_os IS 'Tier 1: Global context document (90-page brand guide, etc.) accessible by all agents.';
COMMENT ON TABLE public.agents IS 'AI employees with configurable behavior and context access.';
COMMENT ON TABLE public.documents IS 'Tier 2: Vector store with embeddings. Can be scoped to specific agents or global.';
COMMENT ON TABLE public.playbooks IS 'Tier 3: General knowledge base for RAG (sales playbooks, processes, etc.)';
COMMENT ON TABLE public.channels IS 'Slack-like channels for conversations.';
COMMENT ON TABLE public.channel_members IS 'Channel membership for both humans and AI agents.';
COMMENT ON TABLE public.chat_messages IS 'Messages in channels with @mention support for humans and AI.';
COMMENT ON TABLE public.usage_tracking IS 'Track token usage and costs per company for billing.';

COMMENT ON COLUMN public.documents.document_type IS 'company_os = from Company OS doc, agent_specific = assigned to specific agent, playbook = from playbook';
COMMENT ON COLUMN public.documents.agent_id IS 'NULL = accessible by all agents in company. Set = only this agent can access.';
COMMENT ON COLUMN public.documents.embedding IS '1536-dimension vector from OpenAI text-embedding-ada-002';
