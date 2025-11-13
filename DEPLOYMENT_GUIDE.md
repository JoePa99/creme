# Clean Architecture Deployment Guide

## Overview
This guide deploys the 3 new clean edge functions and updates the frontend to use them.

---

## Step 1: Add API Keys to Supabase

**Go to:** https://supabase.com/dashboard/project/znpbeicliyymvyoaojzz/settings/functions

Click **"Add new secret"** for each:

### Required Keys:
1. **OPENAI_API_KEY**
   - Get from: https://platform.openai.com/api-keys
   - Used for: Embeddings (text-embedding-ada-002) + GPT models

2. **ANTHROPIC_API_KEY**
   - Get from: https://console.anthropic.com/settings/keys
   - Used for: Claude models (claude-3-5-sonnet, etc.)

3. **PERPLEXITY_API_KEY**
   - Get from: https://www.perplexity.ai/settings/api
   - Used for: Web research features

### Optional Keys:
4. **GEMINI_API_KEY** (if using Gemini)
   - Get from: https://aistudio.google.com/app/apikey
   - Used for: Gemini models

---

## Step 2: Deploy Edge Functions

### Option A: Using Supabase CLI (Recommended)

```bash
# Install Supabase CLI globally
npm install -g supabase

# Link to your project
npx supabase link --project-ref znpbeicliyymvyoaojzz

# Deploy all functions
npx supabase functions deploy

# Or deploy individually:
npx supabase functions deploy document-processor
npx supabase functions deploy context-retriever
npx supabase functions deploy chat-handler
```

### Option B: Manual Deployment via Dashboard

If CLI doesn't work, we can deploy via the dashboard, but the `_shared` folder makes this tricky. CLI is strongly recommended.

---

## Step 3: Frontend Migration Strategy

We need to update the frontend to call the new clean functions. Here's the mapping:

### Old → New Function Mapping:

```typescript
// OLD: chat-with-agent & chat-with-agent-channel
// NEW: chat-handler

// OLD: extract-document-text, generate-company-os, generate-company-os-from-text
// NEW: document-processor
```

### Migration Approach:

Create adapter functions in the frontend that translate old API calls to new ones:

**File:** `src/lib/function-adapters.ts` (NEW FILE)

```typescript
import { supabase } from '@/integrations/supabase/client';

/**
 * Adapter: chat-with-agent → chat-handler
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
  // If conversation_id but no channel_id, we need to find/create a DM channel
  // For now, pass channel_id if provided, otherwise this won't work
  // TODO: Add logic to convert conversation_id to channel_id

  return supabase.functions.invoke('chat-handler', {
    body: {
      message: params.message,
      channel_id: params.channel_id || params.conversation_id, // Temp hack
      agent_id: params.agent_id,
      user_id: params.user_id,
    }
  });
}

/**
 * Adapter: chat-with-agent-channel → chat-handler
 */
export async function chatWithAgentChannel(params: {
  message: string;
  agent_id: string;
  channel_id: string;
  attachments?: any[];
}) {
  return supabase.functions.invoke('chat-handler', {
    body: {
      message: params.message,
      channel_id: params.channel_id,
      agent_id: params.agent_id,
    }
  });
}

/**
 * Adapter: generate-company-os-from-document → document-processor
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
```

---

## Step 4: Update Frontend Files

### File 1: `src/components/ui/unified-chat-area.tsx`

**Find line ~820:**
```typescript
const { data, error } = await supabase.functions.invoke('chat-with-agent', {
```

**Replace with:**
```typescript
const { data, error } = await chatWithAgent({
  message: userMessage,
  agent_id: agent.id,
  conversation_id: conversation.id,
  user_id: user.id,
  attachments,
  client_message_id: clientMessageId,
});
```

**Find line ~930:**
```typescript
const { data, error: agentError } = await supabase.functions.invoke('chat-with-agent-channel', {
```

**Replace with:**
```typescript
const { data, error: agentError } = await chatWithAgentChannel({
  message: userMessage,
  agent_id: firstAgent.agentId,
  channel_id: channelId,
  attachments,
});
```

**Add import at top:**
```typescript
import { chatWithAgent, chatWithAgentChannel } from '@/lib/function-adapters';
```

### File 2: `src/lib/company-os.ts`

Update to use document-processor for file uploads.

**Find the `extractDocumentText` function** and replace its implementation:

```typescript
export async function extractDocumentText(
  request: ExtractDocumentTextRequest
): Promise<ExtractDocumentTextResponse> {
  try {
    // NEW: Use document-processor
    const { data, error } = await supabase.functions.invoke('document-processor', {
      body: {
        file_path: request.filePath,
        company_id: request.companyId,
        document_type: 'company_os',
        metadata: {
          file_name: request.fileName,
        }
      }
    });

    if (error) {
      throw error;
    }

    if (!data.success) {
      throw new Error(data.error || 'Failed to process document');
    }

    return {
      success: true,
      text: data.chunks_created ? `Processed ${data.chunks_created} chunks` : 'Success',
    };
  } catch (error) {
    console.error('Error processing document:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
}
```

---

## Step 5: Test Phase 1

### Test 1: Upload Company OS Document

1. Go to your app
2. Upload a 90-page PDF as Company OS
3. Verify it processes successfully
4. Check Supabase `documents` table - you should see ~90+ rows with embeddings

### Test 2: Chat with Context

1. Create an agent
2. Ask it a question about something from page 50 of the doc
3. Verify it retrieves the correct context
4. Check the AI response references the right information

---

## Troubleshooting

### Functions not deploying?
- Check GitHub integration is connected
- Try CLI deployment
- Verify config.toml has correct project_id

### Functions deployed but failing?
- Check API keys are set in Supabase
- Check function logs in Supabase Dashboard → Edge Functions → Logs
- Look for errors about missing keys

### Frontend errors?
- Check browser console
- Verify adapter functions are imported
- Check that channel_id is being passed correctly

---

## Success Criteria

✅ All 3 functions deployed to Supabase
✅ All API keys configured
✅ Can upload 90-page Company OS document
✅ Document is chunked and embedded (~90+ chunks in database)
✅ Can chat with agent and get relevant context from all pages
✅ Context retrieval is better than before

---

## Next Steps (Phase 2)

Once Phase 1 works:
- Add agent-specific document assignments
- Build playbook system
- Add scoped search (agent only sees their docs + CompanyOS)
