# Clean Architecture - Phase 1 Complete ✅

This document describes the **clean rebuild** of the Creme AI platform with a focus on **perfect context retrieval** and **maintainable architecture**.

## 🎯 What We Fixed

The original problem: **90-page Company OS documents weren't being properly chunked and embedded for vector search.**

The solution: **Complete architectural rebuild with proper 3-tier knowledge system.**

---

## 📊 Architecture Overview

### Database Schema (3 Clean Migrations)

**Migration 00001: Core Schema**
- Companies (multi-tenant)
- Users (auth profiles)
- Company Members (role-based access)
- Company OS (Tier 1: Global context)
- Agents (AI employees)
- Documents (Tier 2: Vector store with 1536-dim embeddings)
- Playbooks (Tier 3: General knowledge base)
- Channels (Slack-like interface)
- Channel Members (humans + AI)
- Chat Messages (with @mentions)
- Usage Tracking

**Migration 00002: RLS Policies**
- Row Level Security for multi-tenant isolation
- Helper functions for access control
- Storage bucket policies

**Migration 00003: Vector Functions**
- `search_documents_by_embedding()` - Pure vector similarity
- `hybrid_search_documents()` - Vector + keyword search
- `get_chat_context()` - Context retrieval for chat
- `semantic_chunk_text()` - Smart text chunking
- Full-text search with tsvector

---

## 🔧 Edge Functions (3 Core Functions)

### 1. **document-processor**
**Purpose:** Process uploaded documents into searchable chunks

**Flow:**
1. Download file from storage (company-os, agent-documents buckets)
2. Extract text (PDF, DOCX, TXT, MD)
3. Clean and normalize text
4. Chunk semantically (1000 chars, 100 char overlap)
5. Generate embeddings (OpenAI text-embedding-ada-002)
6. Store chunks in `documents` table with metadata

**API:**
```typescript
POST /document-processor
{
  "file_path": "company-id/file.pdf",
  "company_id": "uuid",
  "document_type": "company_os" | "agent_specific" | "playbook",
  "agent_id": "uuid" // optional, for agent-specific docs
}
```

**Key Features:**
- Automatic file type detection
- Semantic chunking at paragraph boundaries
- Metadata tracking (chunk index, total chunks, source)
- Replaces old documents (no duplicates)

---

### 2. **context-retriever**
**Purpose:** Retrieve relevant context for a user query

**Flow:**
1. Verify user access to company
2. Get agent configuration (use_company_os, use_playbooks, max_context_chunks)
3. Generate query embedding
4. Call `get_chat_context()` database function
5. Format results by document type
6. Return structured context

**API:**
```typescript
POST /context-retriever
{
  "query": "What are our brand values?",
  "company_id": "uuid",
  "agent_id": "uuid",
  "max_chunks": 10
}
```

**Returns:**
```typescript
{
  "chunks": [
    {
      "source": "Company OS",
      "content": "...",
      "document_type": "company_os",
      "relevance_score": 0.87
    }
  ],
  "total_found": 5,
  "context_formatted": "# Relevant Context\n\n## Company OS\n..."
}
```

---

### 3. **chat-handler**
**Purpose:** Main chat orchestration with AI providers

**Flow:**
1. Verify channel access
2. Store user message
3. Get agent configuration
4. Generate message embedding
5. Retrieve context via `get_chat_context()`
6. Fetch recent conversation history
7. Build AI prompt with system prompt + context + history
8. Call AI provider (OpenAI, Gemini, or Claude)
9. Store AI response
10. Update usage tracking

**API:**
```typescript
POST /chat-handler
{
  "message": "What is our mission statement?",
  "channel_id": "uuid",
  "agent_id": "uuid", // optional
  "parent_message_id": "uuid" // optional, for threading
}
```

**Returns:**
```typescript
{
  "message_id": "uuid",
  "content": "Our mission is...",
  "tokens_used": 1250,
  "context_chunks": 5,
  "model_used": "gpt-4o"
}
```

**Supported AI Providers:**
- OpenAI (gpt-4o, gpt-4-turbo, gpt-3.5-turbo)
- Google Gemini (gemini-2.0-flash-exp, gemini-pro)
- Anthropic Claude (claude-3-5-sonnet, claude-3-opus)

---

## 🧠 3-Tier Knowledge Architecture

### Tier 1: Company OS (Global Context)
- **Scope:** Accessible by ALL agents in the company
- **Use Case:** Brand guide, mission, values, company policies
- **Storage:** `documents` table with `document_type='company_os'` and `agent_id=NULL`
- **Example:** 90-page brand guide uploaded → chunked into 90+ searchable pieces

### Tier 2: Agent-Specific Documents
- **Scope:** Only accessible by assigned agent(s)
- **Use Case:** Sales agent gets sales docs, support agent gets support docs
- **Storage:** `documents` table with `document_type='agent_specific'` and `agent_id='specific-uuid'`
- **Example:** Sales playbook assigned to Sales Agent only

### Tier 3: Playbooks (General RAG)
- **Scope:** Configurable per agent (use_playbooks flag)
- **Use Case:** General knowledge base, processes, templates
- **Storage:** `playbooks` table + `documents` table with `document_type='playbook'`
- **Example:** Marketing templates, HR processes

---

## 🔍 Hybrid Search Explained

Our search combines **two methods** for better results:

### 1. Vector Similarity (Semantic Search)
- Converts query to 1536-dimensional embedding
- Finds documents with similar meaning (cosine similarity)
- Great for: Conceptual questions ("What are our values?")

### 2. Keyword Search (Full-Text)
- Uses PostgreSQL tsvector for fast keyword matching
- Great for: Specific terms, names, dates

### 3. Combined Scoring
```typescript
final_score = (semantic_score × 0.7) + (keyword_score × 0.3)
```

You can adjust the `semantic_weight` parameter (default: 0.7).

---

## 📁 File Structure

```
supabase/
├── migrations_clean/           # NEW clean migrations
│   ├── 00001_core_schema.sql
│   ├── 00002_rls_policies.sql
│   └── 00003_vector_functions.sql
│
└── functions/                  # NEW edge functions
    ├── _shared/                # Shared utilities
    │   ├── types.ts           # TypeScript types
    │   ├── supabase.ts        # Supabase client
    │   ├── openai.ts          # OpenAI & embeddings
    │   ├── cors.ts            # CORS headers
    │   ├── errors.ts          # Error handling
    │   └── text-extraction.ts # PDF/DOCX parsing
    │
    ├── document-processor/
    │   └── index.ts
    ├── context-retriever/
    │   └── index.ts
    └── chat-handler/
        └── index.ts
```

---

## 🚀 Deployment Instructions

### Step 1: Apply Migrations

Go to Supabase SQL Editor:
https://supabase.com/dashboard/project/znpbeicliyymvyoaojzz/sql/new

Run migrations in order:
1. Copy contents of `migrations_clean/00001_core_schema.sql` → Run
2. Copy contents of `migrations_clean/00002_rls_policies.sql` → Run
3. Copy contents of `migrations_clean/00003_vector_functions.sql` → Run

### Step 2: Deploy Edge Functions

**Option A: Via GitHub Integration** (Recommended)
1. Go to Supabase Dashboard → Edge Functions
2. Connect GitHub repository
3. Select branch: `rebuild/clean-architecture`
4. Auto-deploy enabled

**Option B: Via CLI**
```bash
supabase link --project-ref znpbeicliyymvyoaojzz
supabase functions deploy document-processor
supabase functions deploy context-retriever
supabase functions deploy chat-handler
```

### Step 3: Set Environment Variables

In Supabase Dashboard → Project Settings → Edge Functions → Secrets:

```
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
ANTHROPIC_API_KEY=sk-ant-...  (optional)
```

### Step 4: Test!

Upload a Company OS document and watch it get chunked and embedded automatically!

---

## 🧪 Testing Phase 1

### Test 1: Upload Company OS Document

```typescript
// 1. Upload file to storage
const { data, error } = await supabase.storage
  .from('company-os')
  .upload(`${companyId}/brand-guide.pdf`, file);

// 2. Trigger processing
const response = await fetch('https://your-project.supabase.co/functions/v1/document-processor', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${anonKey}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    file_path: `${companyId}/brand-guide.pdf`,
    company_id: companyId,
    document_type: 'company_os'
  })
});
```

**Expected Result:**
- File extracted
- Text chunked into ~90 pieces (for 90-page doc)
- Embeddings generated
- Chunks stored in `documents` table
- `company_os.status` = 'ready'

### Test 2: Query Context

```typescript
const response = await fetch('https://your-project.supabase.co/functions/v1/context-retriever', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${anonKey}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    query: 'What are our brand values?',
    company_id: companyId,
    agent_id: agentId
  })
});
```

**Expected Result:**
- Query embedded
- Relevant chunks retrieved (hybrid search)
- Context formatted with sources
- High relevance scores for brand values sections

### Test 3: Full Chat Flow

```typescript
const response = await fetch('https://your-project.supabase.co/functions/v1/chat-handler', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${anonKey}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    message: 'Explain our brand positioning',
    channel_id: channelId,
    agent_id: agentId
  })
});
```

**Expected Result:**
- Message stored
- Context retrieved from Company OS
- AI generates response using full context
- Response references specific sections from 90-page doc
- Usage tracked

---

## 📈 What's Next?

### Phase 2: Multi-Tier Knowledge (Week 2)
- [ ] Agent document assignment UI
- [ ] Playbook creation and management
- [ ] Scoped search testing
- [ ] Document versioning

### Phase 3: Slack-like Collaboration (Week 3)
- [ ] Channel management UI
- [ ] @mention parsing (humans + AI)
- [ ] Real-time updates (Supabase Realtime)
- [ ] Notification system

### Phase 4: Polish & Scale (Week 4)
- [ ] Stripe billing integration
- [ ] Usage limits and quotas
- [ ] Admin dashboard
- [ ] Performance optimization
- [ ] Deploy to Vercel

---

## 🎉 Key Improvements Over Old Architecture

| Aspect | Old (105 migrations, 73 functions) | New (3 migrations, 3 functions) |
|--------|-------------------------------------|----------------------------------|
| **Complexity** | High, unclear dependencies | Low, clear purpose |
| **Context Quality** | Poor, Company OS not embedded | Excellent, hybrid search |
| **Maintainability** | Difficult to trace logic | Easy to understand |
| **Performance** | Multiple redundant queries | Optimized single queries |
| **Security** | Inconsistent RLS | Comprehensive RLS |
| **Documentation** | Scattered, outdated | Clear, comprehensive |

---

## 🐛 Troubleshooting

### Documents not being found in search

**Check:**
1. Are embeddings generated? `SELECT COUNT(*) FROM documents WHERE embedding IS NOT NULL;`
2. Is agent configured correctly? `SELECT use_company_os, use_playbooks FROM agents WHERE id='...';`
3. Is similarity threshold too high? Lower it in search functions.

### Edge function timing out

**Check:**
1. File size - very large PDFs may timeout (increase timeout or chunk processing)
2. OpenAI API rate limits - add retry logic
3. Database connection - ensure service role key is set

### RLS blocking queries

**Check:**
1. User is member of company: `SELECT * FROM company_members WHERE user_id='...' AND company_id='...';`
2. User is member of channel: `SELECT * FROM channel_members WHERE user_id='...' AND channel_id='...';`
3. For system operations, use service role client (bypasses RLS)

---

## 📚 Additional Resources

- [Supabase Vector Documentation](https://supabase.com/docs/guides/ai/vector-columns)
- [OpenAI Embeddings Guide](https://platform.openai.com/docs/guides/embeddings)
- [pgvector GitHub](https://github.com/pgvector/pgvector)

---

**Built with ❤️ for perfect context retrieval**

Phase 1 Status: ✅ **COMPLETE**

Ready to deploy and test!
