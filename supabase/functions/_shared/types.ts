// Shared TypeScript types for edge functions

export interface Company {
  id: string;
  name: string;
  slug: string;
  stripe_customer_id?: string;
  stripe_subscription_id?: string;
  subscription_status: 'trial' | 'active' | 'canceled' | 'past_due';
  subscription_tier: 'starter' | 'professional' | 'enterprise';
  trial_ends_at?: string;
  settings: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface User {
  id: string;
  email: string;
  full_name?: string;
  avatar_url?: string;
  notification_preferences: {
    email: boolean;
    push: boolean;
  };
  created_at: string;
  updated_at: string;
}

export interface CompanyMember {
  id: string;
  company_id: string;
  user_id: string;
  role: 'owner' | 'admin' | 'member' | 'viewer';
  invited_by?: string;
  invited_at: string;
  joined_at?: string;
  status: 'active' | 'suspended' | 'invited';
  created_at: string;
  updated_at: string;
}

export interface CompanyOS {
  id: string;
  company_id: string;
  file_name: string;
  file_path?: string;
  file_size_bytes?: number;
  structured_json?: Record<string, unknown>;
  raw_text?: string;
  status: 'processing' | 'ready' | 'failed';
  processing_error?: string;
  created_by?: string;
  created_at: string;
  updated_at: string;
}

export interface Agent {
  id: string;
  company_id: string;
  name: string;
  description?: string;
  avatar_url?: string;
  system_prompt: string;
  model: string;
  temperature: number;
  max_tokens: number;
  use_company_os: boolean;
  use_playbooks: boolean;
  max_context_chunks: number;
  tools: unknown[];
  chain_to_agents?: string[];
  is_active: boolean;
  created_by?: string;
  created_at: string;
  updated_at: string;
}

export interface Document {
  id: string;
  company_id: string;
  document_type: 'company_os' | 'agent_specific' | 'playbook';
  file_name?: string;
  agent_id?: string; // null = all agents can access
  content: string;
  embedding?: number[]; // 1536-dimensional vector
  metadata: {
    chunk_index?: number;
    total_chunks?: number;
    source?: string;
    file_name?: string;
    created_at?: string;
    [key: string]: unknown;
  };
  created_at: string;
}

export interface Playbook {
  id: string;
  company_id: string;
  title: string;
  description?: string;
  category?: string;
  content: string;
  is_public: boolean;
  created_by?: string;
  created_at: string;
  updated_at: string;
}

export interface Channel {
  id: string;
  company_id: string;
  name: string;
  description?: string;
  is_private: boolean;
  is_dm: boolean;
  created_by?: string;
  created_at: string;
  updated_at: string;
}

export interface ChannelMember {
  id: string;
  channel_id: string;
  user_id?: string;
  agent_id?: string;
  role: 'admin' | 'member';
  joined_at: string;
}

export interface ChatMessage {
  id: string;
  channel_id: string;
  user_id?: string;
  agent_id?: string;
  content: string;
  mentioned_user_ids?: string[];
  mentioned_agent_ids?: string[];
  parent_message_id?: string;
  thread_count: number;
  ai_model?: string;
  context_used?: Record<string, unknown>;
  tokens_used?: number;
  attachments: unknown[];
  is_edited: boolean;
  edited_at?: string;
  created_at: string;
}

// Context retrieval types
export interface ContextChunk {
  source: string;
  content: string;
  document_type: string;
  file_name?: string;
  relevance_score: number;
  metadata: Record<string, unknown>;
}

export interface SearchResult {
  id: string;
  content: string;
  document_type: string;
  file_name?: string;
  similarity?: number;
  semantic_score?: number;
  keyword_score?: number;
  combined_score?: number;
  metadata: Record<string, unknown>;
}

// API request/response types
export interface ChatRequest {
  message: string;
  channel_id: string;
  agent_id?: string;
  user_id?: string;
  parent_message_id?: string;
}

export interface ChatResponse {
  message_id: string;
  content: string;
  tokens_used: number;
  context_chunks: number;
  model_used: string;
}

export interface DocumentProcessRequest {
  file_path: string;
  company_id: string;
  document_type: 'company_os' | 'agent_specific' | 'playbook';
  agent_id?: string;
  metadata?: Record<string, unknown>;
}

export interface DocumentProcessResponse {
  success: boolean;
  document_id?: string;
  chunks_created: number;
  error?: string;
}

export interface EmbeddingRequest {
  texts: string[];
  model?: string;
}

export interface EmbeddingResponse {
  embeddings: number[][];
  total_tokens: number;
}

// Error types
export class AppError extends Error {
  constructor(
    message: string,
    public statusCode: number = 500,
    public code?: string
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export class ValidationError extends AppError {
  constructor(message: string) {
    super(message, 400, 'VALIDATION_ERROR');
    this.name = 'ValidationError';
  }
}

export class AuthenticationError extends AppError {
  constructor(message: string = 'Authentication required') {
    super(message, 401, 'AUTHENTICATION_ERROR');
    this.name = 'AuthenticationError';
  }
}

export class AuthorizationError extends AppError {
  constructor(message: string = 'Insufficient permissions') {
    super(message, 403, 'AUTHORIZATION_ERROR');
    this.name = 'AuthorizationError';
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string) {
    super(`${resource} not found`, 404, 'NOT_FOUND');
    this.name = 'NotFoundError';
  }
}

export class RateLimitError extends AppError {
  constructor(message: string = 'Rate limit exceeded') {
    super(message, 429, 'RATE_LIMIT_ERROR');
    this.name = 'RateLimitError';
  }
}
