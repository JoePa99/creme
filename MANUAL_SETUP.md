# Manual Setup via Supabase Dashboard (No CLI Required!)

Since you're working in a browser environment, here's how to set everything up directly through the Supabase Dashboard.

## Your New Instance Details

**URL:** https://znpbeicliyymvyoaojzz.supabase.co
**Project Ref:** znpbeicliyymvyoaojzz

## Step 1: Apply All Database Migrations

Go to **Supabase Dashboard → SQL Editor → New Query**

Copy and paste the contents of each migration file in order:

### Quick Method: Run the master migration script

I've created a consolidated script for you. Run this single SQL file:

**File:** `setup-scripts/00_run_all_migrations.sql`

This applies all 20+ migrations in the correct order.

### Alternative: Run migrations individually

Navigate to `supabase/migrations/` and run each `.sql` file in alphabetical/date order in the SQL Editor.

## Step 2: Enable Vector Extension

In **SQL Editor**, run:

```sql
-- Enable vector extension for embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- Verify it's enabled
SELECT * FROM pg_extension WHERE extname = 'vector';
```

## Step 3: Create Storage Buckets

In **SQL Editor**, run:

```sql
-- Create storage buckets
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('documents', 'documents', false),
  ('chat-attachments', 'chat-attachments', true),
  ('chat-files', 'chat-files', false)
ON CONFLICT (id) DO NOTHING;

-- Verify buckets created
SELECT * FROM storage.buckets;
```

## Step 4: Set Environment Variables (Secrets)

Go to **Supabase Dashboard → Project Settings → Edge Functions**

Scroll down to **Environment Variables** section.

Click **Add new variable** for each:

```
Name: OPENAI_API_KEY
Value: sk-your-openai-key-here

Name: GEMINI_API_KEY
Value: your-gemini-api-key-here

Name: PERPLEXITY_API_KEY
Value: pplx-your-perplexity-key

Name: ANTHROPIC_API_KEY (Optional)
Value: sk-ant-your-claude-key
```

## Step 5: Deploy Edge Functions

You have 2 options:

### Option A: GitHub Integration (Recommended)

1. Go to **Supabase Dashboard → Edge Functions**
2. Click **Deploy with GitHub**
3. Connect your GitHub repository
4. Select branch: `claude/debug-unexpected-behavior-011CV4k31Kr4nJffoG8r4ZkN`
5. Supabase will automatically deploy all functions from `supabase/functions/`

### Option B: Manual Deployment (if you have CLI locally)

If you have a local terminal with Supabase CLI installed:

```bash
# In your project directory
supabase link --project-ref znpbeicliyymvyoaojzz
supabase functions deploy
```

### Option C: Deploy Individual Functions via Dashboard

You can deploy functions one-by-one:

1. Go to **Edge Functions → Create Function**
2. Copy the code from each function's `index.ts` file
3. Paste and deploy

(This is tedious for 73 functions - use Option A or B instead!)

## Step 6: Verify Setup

Run these queries in **SQL Editor** to verify everything is set up:

```sql
-- Check tables exist
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- Check vector extension
SELECT * FROM pg_extension WHERE extname = 'vector';

-- Check storage buckets
SELECT * FROM storage.buckets;

-- Check if documents table has required columns
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'documents';
```

Expected results:
- ✅ 20+ tables (companies, agents, documents, chat_messages, etc.)
- ✅ Vector extension enabled
- ✅ 3 storage buckets
- ✅ documents table has: metadata (jsonb), document_type (text), embedding (vector)

## Step 7: Test Your Frontend

Update your local `.env` file (already done for you!):

```bash
VITE_SUPABASE_URL=https://znpbeicliyymvyoaojzz.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGci...
```

Then run:

```bash
npm install
npm run dev
```

## Troubleshooting

### Migrations fail?

Run migrations one at a time in SQL Editor to see which one fails. Common issues:
- Extension not enabled (run `CREATE EXTENSION IF NOT EXISTS vector;` first)
- Tables already exist (that's OK, just continue)

### Functions not deploying?

- Make sure environment variables are set first
- Try GitHub integration method
- Check function logs for errors

### Can't sign up?

- Check Authentication settings: Dashboard → Authentication → URL Configuration
- Add your frontend URL to "Site URL"

## You're Ready! 🎉

Once all migrations are applied and functions deployed:

1. Sign up for an account in your app
2. Create a company
3. Upload your 90-page Company OS document
4. Create an AI agent
5. Start chatting - the full document will be searchable!

The context fix is live and your AI will have access to all 90 pages, not just a summary!
