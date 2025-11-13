-- NUCLEAR OPTION: Drop EVERYTHING and start completely fresh
-- ⚠️ WARNING: This will delete ALL data in your database!
-- Only run this on the new empty instance (znpbeicliyymvyoaojzz)

-- ============================================================================
-- DROP ALL OLD TABLES
-- ============================================================================

-- Drop ALL tables from old architecture
DROP TABLE IF EXISTS public.activity_logs CASCADE;
DROP TABLE IF EXISTS public.agent_conversations CASCADE;
DROP TABLE IF EXISTS public.agent_metrics CASCADE;
DROP TABLE IF EXISTS public.agent_tag_assignments CASCADE;
DROP TABLE IF EXISTS public.agent_tags CASCADE;
DROP TABLE IF EXISTS public.agent_types CASCADE;
DROP TABLE IF EXISTS public.company_settings CASCADE;
DROP TABLE IF EXISTS public.document_access_logs CASCADE;
DROP TABLE IF EXISTS public.document_categories CASCADE;
DROP TABLE IF EXISTS public.document_versions CASCADE;
DROP TABLE IF EXISTS public.kpi_metrics CASCADE;
DROP TABLE IF EXISTS public.onboarding_sessions CASCADE;
DROP TABLE IF EXISTS public.onboarding_steps CASCADE;
DROP TABLE IF EXISTS public.playbook_activity CASCADE;
DROP TABLE IF EXISTS public.playbook_sections CASCADE;
DROP TABLE IF EXISTS public.subscription_plans CASCADE;
DROP TABLE IF EXISTS public.usage_analytics CASCADE;
DROP TABLE IF EXISTS public.usage_history CASCADE;
DROP TABLE IF EXISTS public.user_companies CASCADE;
DROP TABLE IF EXISTS public.user_roles CASCADE;
DROP TABLE IF EXISTS public.user_usage CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Drop new tables (in case they're partially created)
DROP TABLE IF EXISTS public.usage_tracking CASCADE;
DROP TABLE IF EXISTS public.chat_messages CASCADE;
DROP TABLE IF EXISTS public.channel_members CASCADE;
DROP TABLE IF EXISTS public.channels CASCADE;
DROP TABLE IF EXISTS public.playbooks CASCADE;
DROP TABLE IF EXISTS public.documents CASCADE;
DROP TABLE IF EXISTS public.agents CASCADE;
DROP TABLE IF EXISTS public.company_os CASCADE;
DROP TABLE IF EXISTS public.company_members CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;
DROP TABLE IF EXISTS public.companies CASCADE;

-- Drop any other leftover tables
DROP TABLE IF EXISTS public.agent_documents CASCADE;
DROP TABLE IF EXISTS public.document_archives CASCADE;
DROP TABLE IF EXISTS public.agent_indexes CASCADE;
DROP TABLE IF EXISTS public.company_openai_config CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.team_invitations CASCADE;
DROP TABLE IF EXISTS public.integrations CASCADE;
DROP TABLE IF EXISTS public.consultation_communications CASCADE;

-- Drop custom types/enums
DROP TYPE IF EXISTS public.onboarding_status CASCADE;
DROP TYPE IF EXISTS public.playbook_status CASCADE;
DROP TYPE IF EXISTS public.app_role CASCADE;

-- Drop old functions
DROP FUNCTION IF EXISTS public.update_updated_at_column CASCADE;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '🧹 All old tables dropped!';
  RAISE NOTICE 'Now run the clean schema creation script.';
END $$;
