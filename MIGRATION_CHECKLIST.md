# Migration Checklist - Run in Supabase SQL Editor

**Go to:** https://supabase.com/dashboard/project/znpbeicliyymvyoaojzz/sql/new

## Before You Start

For each migration below:
1. Open the file in your code editor
2. Copy the ENTIRE contents
3. Paste into Supabase SQL Editor
4. Click **RUN**
5. Check the box below once complete

If a migration fails with "already exists", that's OK - just check the box and move on!

---

## ☑️ STEP 1: Enable Extensions
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS http;
CREATE EXTENSION IF NOT EXISTS pg_net;
```
- [ ] Extensions enabled

---

## ☑️ STEP 2: Run Migrations in Order

### Early 2025 (January)
- [ ] 1. `20250106150000_provision_openai_for_company_agents.sql`
- [ ] 2. `20250106160000_backfill_existing_agents.sql`
- [ ] 3. `20250107000000_fix_company_creation_rls.sql`
- [ ] 4. `20250107000002_create_company_bypass_rls.sql`
- [ ] 5. `20250107000003_fix_company_creation_with_rpc.sql`
- [ ] 6. `20250110150000_add_stripe_and_usage_tracking.sql`
- [ ] 7. `20250110150001_usage_tracking_triggers.sql`
- [ ] 8. `20250110150002_add_seat_tracking.sql`
- [ ] 9. `20250110160000_add_playbook_unique_constraint.sql`
- [ ] 10. `20250114000000_create_company_os_table.sql` ⭐ **IMPORTANT**
- [ ] 11. `20250120000000_add_agent_chain_support.sql`
- [ ] 12. `20250120000000_add_google_drive_folder_to_companies.sql`
- [ ] 13. `20250120000000_add_openai_file_tracking.sql`
- [ ] 14. `20250120000000_cleanup_duplicate_agents.sql`
- [ ] 15. `20250120000001_company_scoped_agents.sql`
- [ ] 16. `20250121000000_fix_channel_delete_notification.sql`
- [ ] 17. `20250125000000_add_consultation_communication.sql`
- [ ] 18. `20250125000001_add_agent_id_to_chat_messages.sql`
- [ ] 19. `20250125000001_add_agent_message_notifications.sql`
- [ ] 20. `20250125000001_create_documents_table.sql` ⭐⭐⭐ **CRITICAL**
- [ ] 21. `20250127000000_add_raw_scraped_text_to_company_os.sql`
- [ ] 22. `20250127000000_consultation_doc_request_trigger.sql`
- [ ] 23. `20250127000001_platform_admin_playbook_policies.sql`
- [ ] 24. `20250127000002_add_client_message_id_to_chat_messages.sql`
- [ ] 25. `20250127000003_unique_chat_conversation.sql`
- [ ] 26. `20250127000004_private_channel_visibility.sql`
- [ ] 27. `20250127000005_fix_channel_members_rls.sql`
- [ ] 28. `20250127000006_fix_channel_visibility_final.sql`
- [ ] 29. `20250127000007_fix_channel_rls_errors.sql`
- [ ] 30. `20250128000001_fix_web_research_tools.sql`
- [ ] 31. `20250128000002_add_quickbooks_tools.sql`
- [ ] 32. `20250128000003_add_hubspot_tools.sql`
- [ ] 33. `20250129000001_fix_agent_notification_urls.sql`
- [ ] 34. `20250130000000_hubspot_integration.sql`
- [ ] 35. `20250130000000_merge_duplicate_conversations.sql`
- [ ] 36. `20250130000001_fix_channel_members_visibility.sql`
- [ ] 37. `20250130000002_test_user_company_function.sql`
- [ ] 38. `20250130000003_comprehensive_channel_fix.sql`
- [ ] 39. `20250131120000_create_extracted_text_test_results.sql`

### Mid 2025 (August)
- [ ] 40. `20250815080118_c4579fdd-b0c5-4355-ab0e-2bfa41d50357.sql`
- [ ] 41. `20250818073455_324ef73c-394c-445a-8105-0e7058663b94.sql`
- [ ] 42. `20250818082226_5541363e-4950-448e-af64-e8cf600f7cce.sql`
- [ ] 43. `20250818084933_29c3d279-79ac-440f-b80f-c46c97e71d4d.sql`
- [ ] 44. `20250818092642_443d46de-022d-4707-aa17-508af6857073.sql`
- [ ] 45. `20250819170137_5413c05f-f0d7-4122-92fe-c47ebd2e94b5.sql`
- [ ] 46. `20250819174103_0a502b12-af54-488e-9fd4-c7712ec29b27.sql`
- [ ] 47. `20250819174236_de7b1fd9-37cb-4dd4-b6f3-fba63b33a2ba.sql`
- [ ] 48. `20250819174303_32baafdd-edb4-46d6-9652-5805d1c8bfe2.sql`
- [ ] 49. `20250819182114_755410ed-ee52-4b28-8eb3-976ca810c717.sql`
- [ ] 50. `20250820105848_857691e2-4db7-4299-91c3-3f5a6b3f0e43.sql`
- [ ] 51. `20250820111946_4ca7c90e-eed1-486f-b1f8-28913fe97125.sql`
- [ ] 52. `20250820123624_533ed3e5-c3aa-4e4c-8fad-7016c695f674.sql`
- [ ] 53. `20250820130435_0dc9f6c6-735b-48bc-963c-7c67f65395dd.sql`
- [ ] 54. `20250820135823_7aabee6a-ef93-4cf1-a75d-5f135ac49981.sql`
- [ ] 55. `20250820142006_61fe14e0-1fbe-45d2-a84f-29148b7b4398.sql`
- [ ] 56. `20250827175448_db8ac7a1-5d9c-4250-a39c-e3c365b315ca.sql`
- [ ] 57. `20250827183313_b969bdfb-fd70-4131-9591-fe37f48b414b.sql`
- [ ] 58. `20250827184034_1a58b3b4-0ad6-4715-bbe3-e940b2ac6540.sql`
- [ ] 59. `20250828071415_26a99c9c-2ba5-45bc-a870-2b7a51d03f38.sql`
- [ ] 60. `20250828071442_0319e61b-59af-4303-a617-93e015b4c606.sql`
- [ ] 61. `20250828072901_ec3c7fdf-e3e1-4010-8d16-28788841754d.sql`
- [ ] 62. `20250829054133_c919bf21-d0c0-40a7-b755-d2c2b825b8b8.sql`
- [ ] 63. `20250829054524_a07659e0-0217-4408-8d11-87c3844844f9.sql`
- [ ] 64. `20250901124447_4edfddc7-d4eb-4b55-b226-eab8563a8e96.sql`
- [ ] 65. `20250904110812_30791d1e-8fd9-4ba8-9f14-95a29df9c33b.sql`
- [ ] 66. `20250908154603_0a40fd94-bc18-416f-b2b5-663801c62c9d.sql`
- [ ] 67. `20250909112733_594032b8-8848-4a93-ba3d-31b9d3c7f347.sql`
- [ ] 68. `20250909114302_1c4b517f-0552-4cd5-9ebd-c81da00c476a.sql`
- [ ] 69. `20250910141057_d2229919-2010-4789-b774-38e1607f85da.sql`
- [ ] 70. `20250911085055_60001a6a-7eef-4257-b4bd-d854382a8ba9.sql`
- [ ] 71. `20250911133528_1773582b-58e6-453d-aedb-8a039cc74cc1.sql`

### Late 2025 (September-November)
- [ ] 72. `20250922000001_add_openai_tools.sql`
- [ ] 73. `20250922000002_add_chat_message_columns.sql`
- [ ] 74. `20251001132543_cc56ef53-fc40-41e4-95d3-5a183b8e7e76.sql`
- [ ] 75. `20251001133305_9259ee3a-05b6-4517-923a-d10c212ffd1a.sql`
- [ ] 76. `20251001160004_7ca92bf2-4914-4525-96f4-b91f7e232854.sql`
- [ ] 77. `20251002000000_add_document_analysis_support.sql`
- [ ] 78. `20251002100832_c59b8d18-f925-4dfe-800a-ee64865f9f5f.sql`
- [ ] 79. `20251002120000_create_team_invitations.sql`
- [ ] 80. `20251002120000_fix_storage_policies.sql`
- [ ] 81. `20251002121500_simple_storage_fix.sql`
- [ ] 82. `20251002122000_fix_document_archives_policy.sql`
- [ ] 83. `20251002122027_3396365c-bdba-46e8-a17b-b9fbb7bf0414.sql`
- [ ] 84. `20251002122500_simplify_document_archives_policy.sql`
- [ ] 85. `20251002155207_fix_storage_policies.sql`
- [ ] 86. `20251002160000_add_chat_messages_foreign_keys.sql`
- [ ] 87. `20251002160500_add_playbook_insert_policy.sql`
- [ ] 88. `20251002180000_notification_settings_system.sql`
- [ ] 89. `20251002190000_implement_role_based_access.sql`
- [ ] 90. `20251002200000_update_content_type_constraint.sql`
- [ ] 91. `20251005205803_48a3582c-f6d3-45fe-9290-e733e96f11cd.sql`
- [ ] 92. `20251005215831_d8ea524e-4309-4707-8b28-6267e188591e.sql`
- [ ] 93. `20251005221220_e85af2c1-4ea3-4f4b-be36-12b2dbb6d576.sql`
- [ ] 94. `20251005222139_6236cced-4a93-4955-83b0-e2883d8a0158.sql`
- [ ] 95. `20251005222845_792e4373-7cfc-4d9e-906b-31db96d6b26e.sql`
- [ ] 96. `20251006113533_fix_seed_default_agents_trigger.sql`
- [ ] 97. `20251006140000_use_agents_table_for_seeding.sql`
- [ ] 98. `20251006155343_52588c37-263c-43b9-9345-103afe0ec505.sql`
- [ ] 99. `20251008073722_5c1ef482-de5c-47d8-815e-e3aaa50cbbf3.sql`
- [ ] 100. `20251008074111_6d325edc-14de-4618-8ee8-56d5aa0e03ad.sql`
- [ ] 101. `20251015154854_25387385-b736-4bb6-a0a6-3c98c6701658.sql`
- [ ] 102. `20251016115427_033a7403-f0b6-45cc-bff6-6269316a835f.sql`
- [ ] 103. `20251029124054_add_status_to_company_os.sql`
- [ ] 104. `20251102000000_add_chain_mention_to_mention_type.sql`
- [ ] 105. `20251112000000_add_documents_metadata.sql` ⭐⭐⭐ **YOUR FIX!**

---

## ☑️ STEP 3: Create Storage Buckets
```sql
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('documents', 'documents', false),
  ('chat-attachments', 'chat-attachments', true),
  ('chat-files', 'chat-files', false)
ON CONFLICT (id) DO NOTHING;
```
- [ ] Storage buckets created

---

## ☑️ STEP 4: Verify Everything

```sql
-- Check tables
SELECT COUNT(*) as table_count
FROM information_schema.tables
WHERE table_schema = 'public';
-- Should show 20+ tables

-- Check vector extension
SELECT * FROM pg_extension WHERE extname = 'vector';
-- Should show 1 row

-- Check documents table has your fix
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'documents'
AND column_name IN ('metadata', 'document_type', 'embedding');
-- Should show all 3 columns
```
- [ ] Verification complete

---

## 🎉 Done!

Once all migrations are complete:
1. Set environment variables in Supabase Dashboard
2. Deploy edge functions (manually or via CLI)
3. Test the app!

**Pro tip:** If a migration fails with "already exists" errors, that's normal - just move on to the next one!
