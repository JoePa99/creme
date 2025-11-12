# Manual Migration Guide - Run in Supabase SQL Editor

Go to: https://supabase.com/dashboard/project/znpbeicliyymvyoaojzz/sql/new

## Step 1: Enable Extensions
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS http;
CREATE EXTENSION IF NOT EXISTS pg_net;
```

## Step 2: Run Each Migration File

Copy and paste the contents of each file below into the SQL Editor and click **Run**.

Run them in this exact order:

### Core Infrastructure Migrations

1. **20250106150000_provision_openai_for_company_agents.sql**
   - Sets up OpenAI provisioning system

2. **20250106160000_backfill_existing_agents.sql**
   - Backfills agent data

3. **20250107000000_fix_company_creation_rls.sql**
   - Fixes Row Level Security for company creation

4. **20250107000002_create_company_bypass_rls.sql**
   - Creates RLS bypass functions

5. **20250107000003_fix_company_creation_with_rpc.sql**
   - Adds RPC functions for company creation

6. **20250110150000_add_stripe_and_usage_tracking.sql**
   - Adds Stripe billing and usage tracking tables

7. **20250110150001_usage_tracking_triggers.sql**
   - Adds triggers for usage tracking

8. **20250110150002_add_seat_tracking.sql**
   - Adds seat/license tracking

9. **20250110160000_add_playbook_unique_constraint.sql**
   - Adds constraints to playbooks table

10. **20250114000000_create_company_os_table.sql** ⭐
    - **CRITICAL** - Creates company_os table

11. **20250120000000_add_agent_chain_support.sql**
    - Adds agent chaining functionality

12. **20250120000000_add_google_drive_folder_to_companies.sql**
    - Adds Google Drive integration

13. **20250120000000_add_openai_file_tracking.sql**
    - Adds OpenAI file tracking

14. **20250120000000_cleanup_duplicate_agents.sql**
    - Cleans up duplicate agent records

15. **20250120000001_company_scoped_agents.sql**
    - Adds company scoping for agents

16. **20250121000000_fix_channel_delete_notification.sql**
    - Fixes channel deletion notifications

17. **20250125000000_add_consultation_communication.sql**
    - Adds consultation features

18. **20250125000001_add_agent_id_to_chat_messages.sql**
    - Links chat messages to agents

19. **20250125000001_add_agent_message_notifications.sql**
    - Adds agent notifications

20. **20250125000001_create_documents_table.sql** ⭐⭐⭐
    - **VERY CRITICAL** - Creates documents table with vector embeddings

21. **20250127000000_add_raw_scraped_text_to_company_os.sql**
    - Adds raw text field to company_os

22. **20250127000000_consultation_doc_request_trigger.sql**
    - Adds consultation triggers

23. **20250127000001_platform_admin_playbook_policies.sql**
    - Adds admin policies

24. **20250127000002_add_client_message_id_to_chat_messages.sql**
    - Adds client message tracking

25. **20250127000003_unique_chat_conversation.sql**
    - Adds unique constraints for conversations

26. **20250127000004_private_channel_visibility.sql**
    - Adds private channel support

27. **20250127000005_fix_channel_members_rls.sql**
    - Fixes channel member RLS

28. **20250127000006_fix_channel_visibility_final.sql**
    - Final channel visibility fixes

29. **20250127000007_fix_channel_rls_errors.sql**
    - Channel RLS error fixes

30. **20250128000001_fix_web_research_tools.sql**
    - Fixes web research tools

31. **20250128000002_add_quickbooks_tools.sql**
    - Adds QuickBooks integration

32. **20250128000003_add_hubspot_tools.sql**
    - Adds HubSpot integration

33. **20250129000001_fix_agent_notification_urls.sql**
    - Fixes notification URLs

34. **20250130000000_hubspot_integration.sql**
    - HubSpot integration tables

35. **20250130000000_merge_duplicate_conversations.sql**
    - Merges duplicate conversations

36. **20250130000001_fix_channel_members_visibility.sql**
    - Channel member visibility fixes

37. **20250130000002_test_user_company_function.sql**
    - Test functions for user-company relationships

38. **20250130000003_comprehensive_channel_fix.sql**
    - Comprehensive channel fixes

39. **20250131120000_create_extracted_text_test_results.sql**
    - Test results table for document extraction

### August 2025 Migrations (Most of these appear to be auto-generated schema updates)

40-75. **20250815080118_* through 20250911133528_***
    - Various schema updates, RLS policies, and feature additions
    - Run these in order as they appear in the filesystem

### Recent Critical Migrations

76. **20250922000001_add_openai_tools.sql**
    - Adds OpenAI tools integration

77. **20250922000002_add_chat_message_columns.sql**
    - Adds columns to chat messages

78-100. **20251001132543_* through 20251029124054_***
    - Recent updates and fixes

101. **20251102000000_add_chain_mention_to_mention_type.sql**
    - Adds chain mentions

102. **20251112000000_add_documents_metadata.sql** ⭐⭐⭐
    - **YOUR FIX!** - Adds metadata and document_type to documents table

## Step 3: Verify Tables Were Created

After running all migrations, verify with:

```sql
-- Check all tables exist
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- Should return 20+ tables including:
-- companies, agents, documents, company_os, chat_messages, etc.
```

```sql
-- Verify vector extension and documents table structure
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'documents';

-- Should show: id, company_id, content, embedding (vector),
-- agent_id, document_archive_id, metadata (jsonb), document_type (text), etc.
```

## Step 4: Create Storage Buckets

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('documents', 'documents', false),
  ('chat-attachments', 'chat-attachments', true),
  ('chat-files', 'chat-files', false)
ON CONFLICT (id) DO NOTHING;
```

## Troubleshooting

**Migration fails with "relation already exists":**
- That's OK! It means the table was already created. Continue to the next migration.

**Migration fails with "extension does not exist":**
- Make sure you ran Step 1 (enable extensions) first

**Migration fails with "function does not exist":**
- Some migrations depend on previous ones. Make sure you're running them in order.

**Migration fails with syntax error:**
- Copy the entire file contents carefully (don't miss any characters)
- Make sure you're not including any file header comments that aren't SQL

## Quick Test After All Migrations

```sql
-- Test that everything is working
SELECT
  (SELECT COUNT(*) FROM companies) as companies_count,
  (SELECT COUNT(*) FROM agents) as agents_count,
  (SELECT COUNT(*) FROM documents) as documents_count,
  (SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector')) as vector_enabled;
```

You should see counts (even if 0) and vector_enabled = true.
