/**
 * Frontend Adapters for Clean Architecture Edge Functions
 *
 * These adapters translate old function calls to the new clean architecture:
 * - OLD: chat-with-agent & chat-with-agent-channel → NEW: chat-handler
 * - OLD: extract-document-text, generate-company-os, etc. → NEW: document-processor
 */

import { supabase } from '@/integrations/supabase/client';

/**
 * Adapter: chat-with-agent → chat-handler
 * Handles 1-on-1 conversations with agents
 */
export async function chatWithAgent(params: {
  message: string;
  agent_id: string;
  conversation_id?: string;
  channel_id?: string;
  user_id: string;
  attachments?: any[];
  client_message_id?: string;
}) {
  // The new chat-handler requires channel_id
  // If we have conversation_id but no channel_id, we need to find/create a DM channel
  // For now, use channel_id if provided, otherwise pass conversation_id as a fallback

  const channelId = params.channel_id || params.conversation_id;

  if (!channelId) {
    throw new Error('Either channel_id or conversation_id must be provided');
  }

  return supabase.functions.invoke('chat-handler', {
    body: {
      message: params.message,
      channel_id: channelId,
      agent_id: params.agent_id,
      user_id: params.user_id,
      attachments: params.attachments,
      client_message_id: params.client_message_id,
    }
  });
}

/**
 * Adapter: chat-with-agent-channel → chat-handler
 * Handles multi-user channel conversations with agents
 */
export async function chatWithAgentChannel(params: {
  message: string;
  agent_id: string;
  channel_id: string;
  user_id?: string;
  attachments?: any[];
}) {
  return supabase.functions.invoke('chat-handler', {
    body: {
      message: params.message,
      channel_id: params.channel_id,
      agent_id: params.agent_id,
      user_id: params.user_id,
      attachments: params.attachments,
    }
  });
}

/**
 * Adapter: generate-company-os-from-document → document-processor
 * Processes Company OS documents with chunking and embedding
 */
export async function processCompanyOSDocument(params: {
  companyId: string;
  filePath: string;
  fileName: string;
}) {
  return supabase.functions.invoke('document-processor', {
    body: {
      file_path: params.filePath,
      company_id: params.companyId,
      document_type: 'company_os',
      metadata: {
        file_name: params.fileName,
      }
    }
  });
}

/**
 * Adapter: extract-document-text → document-processor
 * For general document processing (agent-specific docs, playbooks, etc.)
 */
export async function processDocument(params: {
  filePath: string;
  companyId: string;
  documentType: 'company_os' | 'agent_specific' | 'playbook';
  agentId?: string;
  fileName?: string;
  metadata?: Record<string, any>;
}) {
  return supabase.functions.invoke('document-processor', {
    body: {
      file_path: params.filePath,
      company_id: params.companyId,
      document_type: params.documentType,
      agent_id: params.agentId,
      metadata: {
        file_name: params.fileName,
        ...params.metadata,
      }
    }
  });
}

/**
 * Direct call to context-retriever (new function, no legacy equivalent)
 * Retrieves relevant context chunks for a given query
 */
export async function retrieveContext(params: {
  query: string;
  companyId: string;
  agentId?: string;
  maxChunks?: number;
}) {
  return supabase.functions.invoke('context-retriever', {
    body: {
      query: params.query,
      company_id: params.companyId,
      agent_id: params.agentId,
      max_chunks: params.maxChunks || 10,
    }
  });
}
