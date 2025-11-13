// Context Retriever Edge Function
// Retrieves relevant context for a query using hybrid search
// Returns formatted context ready to be injected into AI chat

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import {
  createJsonResponse,
  createErrorResponse,
  handleCorsPreFlight,
} from '../_shared/cors.ts';
import {
  createServiceClient,
  getAuthenticatedUser,
  verifyCompanyAccess,
} from '../_shared/supabase.ts';
import { generateEmbedding } from '../_shared/openai.ts';
import {
  withErrorHandling,
  parseRequestBody,
  validateRequired,
  validateUUID,
} from '../_shared/errors.ts';
import {
  ContextChunk,
  AuthorizationError,
  NotFoundError,
} from '../_shared/types.ts';

interface ContextRequest {
  query: string;
  company_id: string;
  agent_id: string;
  max_chunks?: number;
}

interface ContextResponse {
  chunks: ContextChunk[];
  total_found: number;
  context_formatted: string;
}

serve(
  withErrorHandling(async (req: Request) => {
    const origin = req.headers.get('Origin');

    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
      return handleCorsPreFlight(req);
    }

    // Only POST allowed
    if (req.method !== 'POST') {
      return createErrorResponse('Method not allowed', 405, undefined, origin);
    }

    // Get authenticated user
    const user = await getAuthenticatedUser(req);

    // Parse and validate request
    const body = await parseRequestBody<ContextRequest>(req);
    validateRequired(body, ['query', 'company_id', 'agent_id']);
    validateUUID(body.company_id, 'company_id');
    validateUUID(body.agent_id, 'agent_id');

    const { query, company_id, agent_id, max_chunks = 10 } = body;

    console.log(`🔍 Retrieving context for query: "${query.slice(0, 50)}..."`);
    console.log(`   Company: ${company_id}`);
    console.log(`   Agent: ${agent_id}`);
    console.log(`   Max chunks: ${max_chunks}`);

    // Verify user has access to company
    const hasAccess = await verifyCompanyAccess(user.id, company_id);
    if (!hasAccess) {
      throw new AuthorizationError('No access to this company');
    }

    const supabase = createServiceClient();

    // Verify agent exists and belongs to company
    const { data: agent, error: agentError } = await supabase
      .from('agents')
      .select('*')
      .eq('id', agent_id)
      .eq('company_id', company_id)
      .single();

    if (agentError || !agent) {
      throw new NotFoundError('Agent');
    }

    console.log(`🤖 Agent: ${agent.name}`);
    console.log(`   Company OS: ${agent.use_company_os ? 'Yes' : 'No'}`);
    console.log(`   Playbooks: ${agent.use_playbooks ? 'Yes' : 'No'}`);

    // Generate embedding for query
    console.log('🧠 Generating query embedding...');
    const queryEmbedding = await generateEmbedding(query);
    console.log('✅ Query embedding generated');

    // Call hybrid search function
    console.log('🔎 Searching documents...');
    const { data: searchResults, error: searchError } = await supabase.rpc(
      'get_chat_context',
      {
        user_message: query,
        message_embedding: queryEmbedding,
        for_company_id: company_id,
        for_agent_id: agent_id,
        max_chunks: max_chunks,
      }
    );

    if (searchError) {
      console.error('Search error:', searchError);
      throw new Error(`Search failed: ${searchError.message}`);
    }

    const chunks: ContextChunk[] = searchResults || [];

    console.log(`✅ Found ${chunks.length} relevant chunks`);

    // Log breakdown by type
    const companyOSCount = chunks.filter((c) => c.document_type === 'company_os')
      .length;
    const agentDocsCount = chunks.filter(
      (c) => c.document_type === 'agent_specific'
    ).length;
    const playbooksCount = chunks.filter((c) => c.document_type === 'playbook')
      .length;

    console.log(`   📋 Company OS: ${companyOSCount}`);
    console.log(`   📄 Agent Docs: ${agentDocsCount}`);
    console.log(`   📚 Playbooks: ${playbooksCount}`);

    // Format context for injection
    let contextFormatted = '';

    if (chunks.length > 0) {
      contextFormatted = '# Relevant Context\n\n';

      // Group by source type
      const companyOSChunks = chunks.filter(
        (c) => c.document_type === 'company_os'
      );
      const agentChunks = chunks.filter(
        (c) => c.document_type === 'agent_specific'
      );
      const playbookChunks = chunks.filter((c) => c.document_type === 'playbook');

      // Add Company OS context
      if (companyOSChunks.length > 0) {
        contextFormatted += '## Company OS (Brand Guide, Mission, Values)\n\n';
        companyOSChunks.forEach((chunk, index) => {
          contextFormatted += `### Excerpt ${index + 1} (Relevance: ${(chunk.relevance_score * 100).toFixed(1)}%)\n`;
          contextFormatted += `${chunk.content}\n\n`;
          contextFormatted += '---\n\n';
        });
      }

      // Add Agent-specific context
      if (agentChunks.length > 0) {
        contextFormatted += '## Agent-Specific Documents\n\n';
        agentChunks.forEach((chunk, index) => {
          contextFormatted += `### ${chunk.file_name || 'Document'} - Excerpt ${index + 1} (Relevance: ${(chunk.relevance_score * 100).toFixed(1)}%)\n`;
          contextFormatted += `${chunk.content}\n\n`;
          contextFormatted += '---\n\n';
        });
      }

      // Add Playbook context
      if (playbookChunks.length > 0) {
        contextFormatted += '## Playbooks\n\n';
        playbookChunks.forEach((chunk, index) => {
          contextFormatted += `### ${chunk.file_name || 'Playbook'} - Excerpt ${index + 1} (Relevance: ${(chunk.relevance_score * 100).toFixed(1)}%)\n`;
          contextFormatted += `${chunk.content}\n\n`;
          contextFormatted += '---\n\n';
        });
      }
    } else {
      contextFormatted =
        '# No Relevant Context Found\n\nNo documents matched the query.';
    }

    const response: ContextResponse = {
      chunks,
      total_found: chunks.length,
      context_formatted: contextFormatted,
    };

    console.log('🎉 Context retrieval complete!');

    return createJsonResponse(response, 200, origin);
  })
);
