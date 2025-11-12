// Chat Handler Edge Function
// Main chat orchestration: Context Retrieval → AI Generation → Message Storage
// Supports multiple AI providers (OpenAI, Gemini, Claude, etc.)

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
import { generateEmbedding, callOpenAI } from '../_shared/openai.ts';
import {
  withErrorHandling,
  parseRequestBody,
  validateRequired,
  validateUUID,
} from '../_shared/errors.ts';
import {
  ChatRequest,
  ChatResponse,
  AuthorizationError,
  NotFoundError,
  AppError,
} from '../_shared/types.ts';

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
    const body = await parseRequestBody<ChatRequest>(req);
    validateRequired(body, ['message', 'channel_id']);
    validateUUID(body.channel_id, 'channel_id');

    if (body.agent_id) {
      validateUUID(body.agent_id, 'agent_id');
    }
    if (body.parent_message_id) {
      validateUUID(body.parent_message_id, 'parent_message_id');
    }

    const { message, channel_id, agent_id, parent_message_id } = body;

    console.log('💬 Chat request received');
    console.log(`   User: ${user.email}`);
    console.log(`   Message: "${message.slice(0, 50)}..."`);
    console.log(`   Channel: ${channel_id}`);
    if (agent_id) console.log(`   Agent: ${agent_id}`);

    const supabase = createServiceClient();

    // Get channel and verify access
    const { data: channel, error: channelError } = await supabase
      .from('channels')
      .select('*, company_id')
      .eq('id', channel_id)
      .single();

    if (channelError || !channel) {
      throw new NotFoundError('Channel');
    }

    // Verify user has access to company
    const hasAccess = await verifyCompanyAccess(user.id, channel.company_id);
    if (!hasAccess) {
      throw new AuthorizationError('No access to this channel');
    }

    // Verify user is a member of the channel
    const { data: membership } = await supabase
      .from('channel_members')
      .select('id')
      .eq('channel_id', channel_id)
      .eq('user_id', user.id)
      .single();

    if (!membership) {
      throw new AuthorizationError('Not a member of this channel');
    }

    console.log(`✅ Access verified for company: ${channel.company_id}`);

    // Store user's message
    const { data: userMessage, error: userMsgError } = await supabase
      .from('chat_messages')
      .insert({
        channel_id,
        user_id: user.id,
        content: message,
        parent_message_id,
      })
      .select('id')
      .single();

    if (userMsgError) {
      console.error('Error storing user message:', userMsgError);
      throw new Error(`Failed to store message: ${userMsgError.message}`);
    }

    console.log(`✅ User message stored: ${userMessage.id}`);

    // If no agent specified, return early (human-only message)
    if (!agent_id) {
      console.log('No agent specified, message stored successfully');
      return createJsonResponse(
        {
          message_id: userMessage.id,
          content: message,
          ai_response: false,
        },
        200,
        origin
      );
    }

    // Get agent configuration
    const { data: agent, error: agentError } = await supabase
      .from('agents')
      .select('*')
      .eq('id', agent_id)
      .eq('company_id', channel.company_id)
      .single();

    if (agentError || !agent) {
      throw new NotFoundError('Agent');
    }

    if (!agent.is_active) {
      throw new AppError('Agent is not active', 400);
    }

    console.log(`🤖 Agent: ${agent.name} (${agent.model})`);

    // Generate embedding for the message
    console.log('🧠 Generating message embedding...');
    const messageEmbedding = await generateEmbedding(message);

    // Retrieve relevant context
    console.log('🔍 Retrieving context...');
    const { data: searchResults, error: searchError } = await supabase.rpc(
      'get_chat_context',
      {
        user_message: message,
        message_embedding: messageEmbedding,
        for_company_id: channel.company_id,
        for_agent_id: agent_id,
        max_chunks: agent.max_context_chunks || 10,
      }
    );

    if (searchError) {
      console.error('Context retrieval error:', searchError);
      // Non-fatal, continue without context
    }

    const contextChunks = searchResults || [];
    console.log(`✅ Retrieved ${contextChunks.length} context chunks`);

    // Format context
    let contextFormatted = '';
    if (contextChunks.length > 0) {
      contextFormatted = '\n\n# Relevant Context\n\n';

      // Group by document type
      const companyOSChunks = contextChunks.filter(
        (c: any) => c.document_type === 'company_os'
      );
      const agentChunks = contextChunks.filter(
        (c: any) => c.document_type === 'agent_specific'
      );
      const playbookChunks = contextChunks.filter(
        (c: any) => c.document_type === 'playbook'
      );

      console.log(`   📋 Company OS: ${companyOSChunks.length} chunks`);
      console.log(`   📄 Agent Docs: ${agentChunks.length} chunks`);
      console.log(`   📚 Playbooks: ${playbookChunks.length} chunks`);

      // Add context sections
      if (companyOSChunks.length > 0) {
        contextFormatted += '## Company OS (Brand Guide, Mission, Values)\n\n';
        companyOSChunks.forEach((chunk: any, i: number) => {
          contextFormatted += `### Excerpt ${i + 1}\n${chunk.content}\n\n---\n\n`;
        });
      }

      if (agentChunks.length > 0) {
        contextFormatted += '## Agent-Specific Documents\n\n';
        agentChunks.forEach((chunk: any, i: number) => {
          contextFormatted += `### ${chunk.file_name || 'Document'}\n${chunk.content}\n\n---\n\n`;
        });
      }

      if (playbookChunks.length > 0) {
        contextFormatted += '## Playbooks\n\n';
        playbookChunks.forEach((chunk: any, i: number) => {
          contextFormatted += `### ${chunk.file_name || 'Playbook'}\n${chunk.content}\n\n---\n\n`;
        });
      }
    }

    // Get recent conversation history
    console.log('📚 Fetching conversation history...');
    const { data: recentMessages } = await supabase
      .from('chat_messages')
      .select('content, user_id, agent_id, created_at')
      .eq('channel_id', channel_id)
      .order('created_at', { ascending: false })
      .limit(10);

    const conversationHistory =
      recentMessages
        ?.reverse()
        .map((msg: any) => {
          const role = msg.agent_id ? 'assistant' : 'user';
          return { role, content: msg.content };
        }) || [];

    console.log(`✅ Retrieved ${conversationHistory.length} previous messages`);

    // Build messages for AI
    const systemPrompt = agent.system_prompt + (contextFormatted ? contextFormatted : '\n\nNo additional context available.');

    const aiMessages = [
      { role: 'system', content: systemPrompt },
      ...conversationHistory.slice(-5), // Last 5 messages for context
      { role: 'user', content: message },
    ];

    console.log(`🤖 Calling ${agent.model}...`);

    // Call AI provider
    let aiResponse: { content: string; tokens: number };

    if (agent.model.startsWith('gpt-')) {
      aiResponse = await callOpenAI(
        aiMessages,
        agent.model,
        agent.temperature,
        agent.max_tokens
      );
    } else if (agent.model.includes('gemini')) {
      // Call Gemini API
      aiResponse = await callGemini(
        aiMessages,
        agent.model,
        agent.temperature,
        agent.max_tokens
      );
    } else if (agent.model.includes('claude')) {
      // Call Anthropic API
      aiResponse = await callClaude(
        aiMessages,
        agent.model,
        agent.temperature,
        agent.max_tokens
      );
    } else {
      throw new AppError(`Unsupported model: ${agent.model}`, 400);
    }

    console.log(`✅ AI response received (${aiResponse.tokens} tokens)`);

    // Store AI response
    const { data: aiMessage, error: aiMsgError } = await supabase
      .from('chat_messages')
      .insert({
        channel_id,
        agent_id,
        content: aiResponse.content,
        parent_message_id: parent_message_id || userMessage.id,
        ai_model: agent.model,
        tokens_used: aiResponse.tokens,
        context_used: {
          chunks_count: contextChunks.length,
          company_os_chunks: contextChunks.filter((c: any) => c.document_type === 'company_os').length,
          agent_doc_chunks: contextChunks.filter((c: any) => c.document_type === 'agent_specific').length,
          playbook_chunks: contextChunks.filter((c: any) => c.document_type === 'playbook').length,
        },
      })
      .select('id')
      .single();

    if (aiMsgError) {
      console.error('Error storing AI message:', aiMsgError);
      throw new Error(`Failed to store AI response: ${aiMsgError.message}`);
    }

    console.log(`✅ AI message stored: ${aiMessage.id}`);

    // Update usage tracking
    const now = new Date();
    const periodStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const periodEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0);

    await supabase
      .from('usage_tracking')
      .upsert(
        {
          company_id: channel.company_id,
          period_start: periodStart.toISOString(),
          period_end: periodEnd.toISOString(),
          total_tokens_used: aiResponse.tokens,
          total_messages_sent: 1,
        },
        {
          onConflict: 'company_id,period_start',
          ignoreDuplicates: false,
        }
      );

    const response: ChatResponse = {
      message_id: aiMessage.id,
      content: aiResponse.content,
      tokens_used: aiResponse.tokens,
      context_chunks: contextChunks.length,
      model_used: agent.model,
    };

    console.log('🎉 Chat handler complete!');

    return createJsonResponse(response, 200, origin);
  })
);

// Helper functions for other AI providers

async function callGemini(
  messages: Array<{ role: string; content: string }>,
  model: string,
  temperature: number,
  maxTokens: number
): Promise<{ content: string; tokens: number }> {
  const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');
  if (!GEMINI_API_KEY) {
    throw new AppError('Gemini API key not configured', 500);
  }

  // Convert messages to Gemini format
  const systemMessage = messages.find((m) => m.role === 'system');
  const conversationMessages = messages.filter((m) => m.role !== 'system');

  const contents = conversationMessages.map((m) => ({
    role: m.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: m.content }],
  }));

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents,
        systemInstruction: systemMessage
          ? { parts: [{ text: systemMessage.content }] }
          : undefined,
        generationConfig: {
          temperature,
          maxOutputTokens: maxTokens,
        },
      }),
    }
  );

  if (!response.ok) {
    const error = await response.json();
    throw new AppError(`Gemini API error: ${JSON.stringify(error)}`, response.status);
  }

  const data = await response.json();
  const content = data.candidates[0]?.content?.parts[0]?.text || '';
  const tokens = data.usageMetadata?.totalTokenCount || 0;

  return { content, tokens };
}

async function callClaude(
  messages: Array<{ role: string; content: string }>,
  model: string,
  temperature: number,
  maxTokens: number
): Promise<{ content: string; tokens: number }> {
  const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY');
  if (!ANTHROPIC_API_KEY) {
    throw new AppError('Anthropic API key not configured', 500);
  }

  // Extract system message
  const systemMessage = messages.find((m) => m.role === 'system')?.content || '';
  const conversationMessages = messages.filter((m) => m.role !== 'system');

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      max_tokens: maxTokens,
      temperature,
      system: systemMessage,
      messages: conversationMessages,
    }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new AppError(`Claude API error: ${JSON.stringify(error)}`, response.status);
  }

  const data = await response.json();
  const content = data.content[0]?.text || '';
  const tokens = data.usage?.input_tokens + data.usage?.output_tokens || 0;

  return { content, tokens };
}
