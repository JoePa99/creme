-- BATCH 1: Core Tables and Extensions
-- Run this first in Supabase SQL Editor

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS http;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Note: After enabling extensions, proceed to run the individual migration files
-- from supabase/migrations/ in chronological order.
-- This file just ensures extensions are ready.

SELECT 'Extensions enabled successfully' as status;
