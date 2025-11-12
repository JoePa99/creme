# Easy Setup - No Terminal Required! 🚀

Since you're working in a browser, here's the easiest way to set up your new Supabase instance.

## Your Instance Details

- **URL:** https://znpbeicliyymvyoaojzz.supabase.co
- **Project Ref:** znpbeicliyymvyoaojzz
- **Anon Key:** (in your `.env` file)
- **Service Role:** (in your `.env` file)

## Option 1: Fastest Setup (Recommended) ⚡

### Step 1: Enable Vector Extension
1. Go to https://supabase.com/dashboard/project/znpbeicliyymvyoaojzz/sql/new
2. Paste this:
```sql
CREATE EXTENSION IF NOT EXISTS vector;
```
3. Click **Run**

### Step 2: Apply All Migrations at Once
The migrations are already in your repo! Supabase can auto-apply them via GitHub:

1. Go to https://supabase.com/dashboard/project/znpbeicliyymvyoaojzz/settings/general
2. Scroll to **GitHub Connection**
3. Click **Connect to GitHub**
4. Select your repository: `JoePa99/creme`
5. Select branch: `claude/debug-unexpected-behavior-011CV4k31Kr4nJffoG8r4ZkN`
6. Click **Enable** - Supabase will auto-apply all migrations!

### Step 3: Deploy All Functions via GitHub

1. Go to https://supabase.com/dashboard/project/znpbeicliyymvyoaojzz/functions
2. Click **Deploy with GitHub** (if not already connected from Step 2)
3. Select the branch: `claude/debug-unexpected-behavior-011CV4k31Kr4nJffoG8r4ZkN`
4. Supabase will automatically deploy all 73 functions!

### Step 4: Set Environment Variables

1. Go to https://supabase.com/dashboard/project/znpbeicliyymvyoaojzz/settings/functions
2. Scroll to **Secrets**
3. Add these secrets:

```
OPENAI_API_KEY = your_openai_key
GEMINI_API_KEY = your_gemini_key
PERPLEXITY_API_KEY = your_perplexity_key
ANTHROPIC_API_KEY = your_claude_key (optional)
```

### Step 5: Create Storage Buckets

Go to SQL Editor and run:
```sql
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('documents', 'documents', false),
  ('chat-attachments', 'chat-attachments', true),
  ('chat-files', 'chat-files', false)
ON CONFLICT (id) DO NOTHING;
```

**Done! You're ready to go! 🎉**

---

## Option 2: Manual SQL Approach (if GitHub doesn't work)

If you can't connect GitHub, you can run migrations manually:

### Apply Migrations Manually

1. Go to https://supabase.com/dashboard/project/znpbeicliyymvyoaojzz/sql/new
2. Open each file in `supabase/migrations/` (in alphabetical order)
3. Copy the SQL content
4. Paste into SQL Editor
5. Click **Run**
6. Repeat for all 100+ migration files

**This is tedious! Use Option 1 (GitHub) instead if possible.**

---

## Verify Everything Worked

Run this in SQL Editor to check:

```sql
-- Check tables exist
SELECT COUNT(*) as table_count
FROM information_schema.tables
WHERE table_schema = 'public';
-- Should show 20+ tables

-- Check vector extension
SELECT * FROM pg_extension WHERE extname = 'vector';
-- Should show 1 row

-- Check storage buckets
SELECT * FROM storage.buckets;
-- Should show 3 buckets

-- Check documents table has new columns
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'documents' AND column_name IN ('metadata', 'document_type');
-- Should show both columns
```

---

## Test Your App

Your `.env` file is already configured! Just run:

```bash
npm install
npm run dev
```

Then:
1. Sign up for an account
2. Create a company
3. Upload your 90-page Company OS document
4. Create an AI agent
5. Chat and ask specific questions from the document

The AI will now have access to ALL 90 pages, not just a summary! 🎯

---

## Troubleshooting

**GitHub connection not working?**
- Make sure your GitHub repo is public or you've granted Supabase access
- Try disconnecting and reconnecting

**Migrations fail?**
- Check if vector extension is enabled first
- Some migrations may already be applied - that's OK

**Functions not deploying?**
- Make sure environment variables (secrets) are set first
- Check the function logs for errors

**Need help?**
See `MANUAL_SETUP.md` for more detailed manual setup instructions.
