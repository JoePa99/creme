# Supabase Setup Guide - Fresh Instance

This guide will help you set up a brand new Supabase instance with all schema, functions, and configuration from this repository.

## Prerequisites

1. Supabase CLI installed: `npm install -g supabase`
2. A new Supabase project created at [supabase.com](https://supabase.com)
3. Your Supabase project credentials ready

## Step 1: Link to Your New Supabase Project

```bash
# Navigate to project root
cd /home/user/creme

# Link to your Supabase project (you'll be prompted for credentials)
supabase link --project-ref YOUR_PROJECT_REF

# Or provide database password directly
supabase link --project-ref YOUR_PROJECT_REF --password YOUR_DB_PASSWORD
```

**Where to find your project ref:**
- Supabase Dashboard → Project Settings → General → Reference ID

## Step 2: Push All Database Migrations

This will apply ALL migrations in order and set up your complete schema:

```bash
# Push all migrations to your new Supabase instance
supabase db push

# Verify migrations were applied
supabase migration list
```

**What this creates:**
- ✅ All tables (companies, agents, documents, chat_messages, etc.)
- ✅ All indexes (including vector search indexes)
- ✅ All RLS policies
- ✅ All functions (match_documents, etc.)
- ✅ All triggers
- ✅ All constraints

## Step 3: Deploy All Edge Functions

Deploy all 30+ edge functions to your new instance:

```bash
# Deploy all functions at once
supabase functions deploy

# Or deploy specific functions individually
supabase functions deploy chat-with-agent
supabase functions deploy generate-company-os
supabase functions deploy generate-company-os-from-document
# ... etc
```

**Deployed functions include:**
- chat-with-agent (main chat handler)
- chat-with-agent-channel (channel chat)
- generate-company-os (web research-based)
- generate-company-os-from-document (document upload)
- process-documents-embeddings (vector embeddings)
- All tool executors (Google Drive, HubSpot, etc.)

## Step 4: Set Environment Variables

### In Supabase Dashboard:

Go to: **Project Settings → Edge Functions → Environment Variables**

Add these required variables:

```bash
# OpenAI (Required)
OPENAI_API_KEY=sk-...

# Anthropic Claude (Optional)
ANTHROPIC_API_KEY=sk-ant-...

# Google Gemini (Optional)
GEMINI_API_KEY=...

# Perplexity (For web research)
PERPLEXITY_API_KEY=pplx-...

# Supabase (Auto-populated, verify these exist)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

### For Local Development:

Create `.env` file in root:

```bash
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...
```

## Step 5: Enable Required Extensions

Run these in Supabase Dashboard → SQL Editor:

```sql
-- Enable vector extension for embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Verify extensions
SELECT * FROM pg_extension;
```

## Step 6: Configure Storage Buckets

In Supabase Dashboard → Storage, create these buckets:

1. **documents** (for Company OS and uploaded files)
   - Public: No
   - File size limit: 50 MB
   - Allowed MIME types: PDF, DOCX, TXT, etc.

2. **chat-attachments** (for chat files and generated images)
   - Public: Yes
   - File size limit: 10 MB

3. **chat-files** (for temporary chat uploads)
   - Public: No
   - File size limit: 10 MB

**Or run this SQL to create buckets:**

```sql
-- Insert storage buckets
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('documents', 'documents', false),
  ('chat-attachments', 'chat-attachments', true),
  ('chat-files', 'chat-files', false)
ON CONFLICT (id) DO NOTHING;
```

## Step 7: Configure Authentication

In Supabase Dashboard → Authentication → URL Configuration:

- **Site URL**: Your frontend URL (e.g., https://your-app.vercel.app)
- **Redirect URLs**: Add your frontend URL(s)

Enable auth providers you need:
- Email (enabled by default)
- Google OAuth (optional)
- GitHub OAuth (optional)

## Step 8: Verify Setup

Run these checks to ensure everything is working:

```bash
# 1. Check database connection
supabase db remote --linked

# 2. List all functions
supabase functions list

# 3. Test a function locally
supabase functions serve chat-with-agent

# 4. Check migration status
supabase migration list
```

## Step 9: Seed Initial Data (Optional)

If you want to create a test company/user:

```sql
-- Create a test company
INSERT INTO companies (id, name, domain, status)
VALUES (gen_random_uuid(), 'Test Company', 'test.com', 'active')
RETURNING id;

-- Use the returned ID to create a test user profile
-- (After signing up a user via your app's auth flow)
```

## Troubleshooting

### Migrations fail?
```bash
# Reset and reapply (WARNING: Destructive)
supabase db reset

# Or apply specific migration
supabase db push --file supabase/migrations/MIGRATION_FILE.sql
```

### Function deployment fails?
```bash
# Check function logs
supabase functions logs FUNCTION_NAME

# Redeploy specific function
supabase functions deploy FUNCTION_NAME --no-verify-jwt
```

### Vector search not working?
```sql
-- Verify vector extension is enabled
SELECT * FROM pg_extension WHERE extname = 'vector';

-- Check if documents table has embeddings
SELECT COUNT(*) FROM documents WHERE embedding IS NOT NULL;
```

## Complete Setup Script

See `scripts/setup-supabase.sh` for an automated setup script.

## Your New Instance is Ready! 🎉

You now have:
- ✅ Complete database schema
- ✅ All 30+ edge functions deployed
- ✅ Vector search configured
- ✅ Storage buckets created
- ✅ Authentication configured

## Next Steps

1. Update your frontend `.env` with new Supabase URL/keys
2. Deploy your frontend (Vercel, Netlify, etc.)
3. Create your first user account
4. Upload a Company OS document
5. Create AI agents and start chatting!

## Need Help?

- Check function logs: `supabase functions logs FUNCTION_NAME --tail`
- Check database logs: Supabase Dashboard → Database → Logs
- Migration issues: `supabase migration repair`
