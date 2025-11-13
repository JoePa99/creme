-- Clean Architecture Migration - Vector Search Functions
-- Phase 1: Hybrid search with semantic + keyword matching
-- Created: 2025-11-12

-- ============================================================================
-- VECTOR SEARCH FUNCTION
-- Pure vector similarity search using cosine distance
-- ============================================================================

CREATE OR REPLACE FUNCTION public.search_documents_by_embedding(
  query_embedding vector(1536),
  match_company_id UUID,
  match_agent_id UUID DEFAULT NULL,
  match_threshold FLOAT DEFAULT 0.7,
  match_count INT DEFAULT 10,
  include_company_os BOOLEAN DEFAULT true,
  include_playbooks BOOLEAN DEFAULT true
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  document_type TEXT,
  file_name TEXT,
  metadata JSONB,
  similarity FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.content,
    d.document_type,
    d.file_name,
    d.metadata,
    1 - (d.embedding <=> query_embedding) AS similarity
  FROM public.documents d
  WHERE d.company_id = match_company_id
    -- Include Company OS documents if enabled
    AND (
      (include_company_os AND d.document_type = 'company_os')
      OR
      -- Include agent-specific documents (either global or assigned to this agent)
      (d.document_type = 'agent_specific' AND (d.agent_id IS NULL OR d.agent_id = match_agent_id))
      OR
      -- Include playbook documents if enabled
      (include_playbooks AND d.document_type = 'playbook')
    )
    -- Similarity threshold filter
    AND (1 - (d.embedding <=> query_embedding)) > match_threshold
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- HYBRID SEARCH FUNCTION
-- Combines vector similarity with full-text keyword search
-- ============================================================================

-- First, add tsvector column for full-text search
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS content_tsv tsvector;

-- Create index for full-text search
CREATE INDEX IF NOT EXISTS idx_documents_content_tsv ON public.documents USING gin(content_tsv);

-- Create trigger to auto-update tsvector when content changes
CREATE OR REPLACE FUNCTION documents_content_tsv_trigger()
RETURNS TRIGGER AS $$
BEGIN
  NEW.content_tsv = to_tsvector('english', COALESCE(NEW.content, ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER documents_content_tsv_update
  BEFORE INSERT OR UPDATE ON public.documents
  FOR EACH ROW
  EXECUTE FUNCTION documents_content_tsv_trigger();

-- Backfill existing documents
UPDATE public.documents
SET content_tsv = to_tsvector('english', COALESCE(content, ''))
WHERE content_tsv IS NULL;

-- Hybrid search function
CREATE OR REPLACE FUNCTION public.hybrid_search_documents(
  query_text TEXT,
  query_embedding vector(1536),
  match_company_id UUID,
  match_agent_id UUID DEFAULT NULL,
  semantic_weight FLOAT DEFAULT 0.7, -- How much to weight vector similarity vs keyword match
  match_threshold FLOAT DEFAULT 0.6,
  match_count INT DEFAULT 10,
  include_company_os BOOLEAN DEFAULT true,
  include_playbooks BOOLEAN DEFAULT true
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  document_type TEXT,
  file_name TEXT,
  metadata JSONB,
  semantic_score FLOAT,
  keyword_score FLOAT,
  combined_score FLOAT
) AS $$
DECLARE
  query_tsquery tsquery := websearch_to_tsquery('english', query_text);
BEGIN
  RETURN QUERY
  WITH semantic_results AS (
    -- Get semantic similarity scores
    SELECT
      d.id,
      d.content,
      d.document_type,
      d.file_name,
      d.metadata,
      (1 - (d.embedding <=> query_embedding)) AS similarity
    FROM public.documents d
    WHERE d.company_id = match_company_id
      AND (
        (include_company_os AND d.document_type = 'company_os')
        OR (d.document_type = 'agent_specific' AND (d.agent_id IS NULL OR d.agent_id = match_agent_id))
        OR (include_playbooks AND d.document_type = 'playbook')
      )
      AND (1 - (d.embedding <=> query_embedding)) > match_threshold
  ),
  keyword_results AS (
    -- Get keyword match scores
    SELECT
      d.id,
      ts_rank_cd(d.content_tsv, query_tsquery) AS rank
    FROM public.documents d
    WHERE d.company_id = match_company_id
      AND d.content_tsv @@ query_tsquery
      AND (
        (include_company_os AND d.document_type = 'company_os')
        OR (d.document_type = 'agent_specific' AND (d.agent_id IS NULL OR d.agent_id = match_agent_id))
        OR (include_playbooks AND d.document_type = 'playbook')
      )
  ),
  combined_results AS (
    -- Combine both searches
    SELECT
      COALESCE(s.id, k.id) AS id,
      s.content,
      s.document_type,
      s.file_name,
      s.metadata,
      COALESCE(s.similarity, 0) AS semantic_score,
      COALESCE(k.rank, 0) AS keyword_score,
      -- Weighted combination (normalize keyword score to 0-1 range)
      (COALESCE(s.similarity, 0) * semantic_weight) +
      (LEAST(COALESCE(k.rank, 0) * 10, 1.0) * (1 - semantic_weight)) AS combined_score
    FROM semantic_results s
    FULL OUTER JOIN keyword_results k ON s.id = k.id
  )
  SELECT
    cr.id,
    cr.content,
    cr.document_type,
    cr.file_name,
    cr.metadata,
    cr.semantic_score,
    cr.keyword_score,
    cr.combined_score
  FROM combined_results cr
  ORDER BY cr.combined_score DESC
  LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CONTEXT RETRIEVAL FOR CHAT
-- High-level function that agents use to get relevant context
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_chat_context(
  user_message TEXT,
  message_embedding vector(1536),
  for_company_id UUID,
  for_agent_id UUID,
  max_chunks INT DEFAULT 10
)
RETURNS TABLE (
  source TEXT,
  content TEXT,
  document_type TEXT,
  file_name TEXT,
  relevance_score FLOAT,
  metadata JSONB
) AS $$
DECLARE
  agent_config RECORD;
BEGIN
  -- Get agent configuration
  SELECT
    use_company_os,
    use_playbooks,
    max_context_chunks
  INTO agent_config
  FROM public.agents
  WHERE id = for_agent_id
    AND company_id = for_company_id;

  -- If agent not found, use defaults
  IF NOT FOUND THEN
    agent_config.use_company_os := true;
    agent_config.use_playbooks := true;
    agent_config.max_context_chunks := max_chunks;
  END IF;

  -- Return hybrid search results formatted for chat context
  RETURN QUERY
  SELECT
    CASE
      WHEN h.document_type = 'company_os' THEN 'Company OS'
      WHEN h.document_type = 'agent_specific' THEN 'Agent Document'
      WHEN h.document_type = 'playbook' THEN 'Playbook'
      ELSE 'Document'
    END AS source,
    h.content,
    h.document_type,
    h.file_name,
    h.combined_score AS relevance_score,
    h.metadata
  FROM public.hybrid_search_documents(
    user_message,
    message_embedding,
    for_company_id,
    for_agent_id,
    0.7, -- semantic_weight
    0.6, -- match_threshold
    COALESCE(agent_config.max_context_chunks, max_chunks),
    COALESCE(agent_config.use_company_os, true),
    COALESCE(agent_config.use_playbooks, true)
  ) h;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SEMANTIC CHUNKING HELPER
-- Smart text chunking that respects paragraph boundaries
-- ============================================================================

CREATE OR REPLACE FUNCTION public.semantic_chunk_text(
  input_text TEXT,
  target_chunk_size INT DEFAULT 1000,
  overlap INT DEFAULT 100
)
RETURNS TEXT[] AS $$
DECLARE
  chunks TEXT[] := '{}';
  paragraphs TEXT[];
  current_chunk TEXT := '';
  para TEXT;
BEGIN
  -- Split by double newlines (paragraphs)
  paragraphs := regexp_split_to_array(input_text, E'\\n\\n+');

  FOREACH para IN ARRAY paragraphs
  LOOP
    -- If adding this paragraph would exceed target size and we have content
    IF LENGTH(current_chunk) + LENGTH(para) > target_chunk_size AND LENGTH(current_chunk) > 0 THEN
      -- Store current chunk
      chunks := array_append(chunks, TRIM(current_chunk));

      -- Start new chunk with overlap (last few characters of previous chunk)
      IF LENGTH(current_chunk) > overlap THEN
        current_chunk := SUBSTRING(current_chunk, LENGTH(current_chunk) - overlap);
      ELSE
        current_chunk := '';
      END IF;
    END IF;

    -- Add paragraph to current chunk
    current_chunk := current_chunk || E'\\n\\n' || para;
  END LOOP;

  -- Add final chunk if it has content
  IF LENGTH(TRIM(current_chunk)) > 0 THEN
    chunks := array_append(chunks, TRIM(current_chunk));
  END IF;

  RETURN chunks;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- DOCUMENT STATS FUNCTION
-- Get statistics about documents for a company
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_document_stats(
  for_company_id UUID
)
RETURNS TABLE (
  document_type TEXT,
  chunk_count BIGINT,
  total_characters BIGINT,
  average_chunk_size NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.document_type,
    COUNT(*)::BIGINT AS chunk_count,
    SUM(LENGTH(d.content))::BIGINT AS total_characters,
    ROUND(AVG(LENGTH(d.content)), 2) AS average_chunk_size
  FROM public.documents d
  WHERE d.company_id = for_company_id
  GROUP BY d.document_type
  ORDER BY d.document_type;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST SEARCH QUALITY FUNCTION
-- Test function to debug search results
-- ============================================================================

CREATE OR REPLACE FUNCTION public.test_search_quality(
  test_query TEXT,
  test_embedding vector(1536),
  for_company_id UUID,
  for_agent_id UUID DEFAULT NULL
)
RETURNS TABLE (
  search_type TEXT,
  result_count BIGINT,
  avg_score NUMERIC,
  top_3_scores TEXT
) AS $$
BEGIN
  RETURN QUERY
  WITH vector_results AS (
    SELECT
      'Vector Only' AS search_type,
      COUNT(*)::BIGINT AS result_count,
      ROUND(AVG(similarity), 3) AS avg_score,
      STRING_AGG(ROUND(similarity::numeric, 3)::text, ', ' ORDER BY similarity DESC) AS scores
    FROM public.search_documents_by_embedding(
      test_embedding,
      for_company_id,
      for_agent_id,
      0.6,
      3
    )
  ),
  hybrid_results AS (
    SELECT
      'Hybrid Search' AS search_type,
      COUNT(*)::BIGINT AS result_count,
      ROUND(AVG(combined_score), 3) AS avg_score,
      STRING_AGG(ROUND(combined_score::numeric, 3)::text, ', ' ORDER BY combined_score DESC) AS scores
    FROM public.hybrid_search_documents(
      test_query,
      test_embedding,
      for_company_id,
      for_agent_id,
      0.7,
      0.6,
      3
    )
  )
  SELECT * FROM vector_results
  UNION ALL
  SELECT * FROM hybrid_results;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION public.search_documents_by_embedding IS 'Pure vector similarity search using cosine distance';
COMMENT ON FUNCTION public.hybrid_search_documents IS 'Combines vector similarity with full-text keyword search for better results';
COMMENT ON FUNCTION public.get_chat_context IS 'High-level function to retrieve relevant context for chat based on agent config';
COMMENT ON FUNCTION public.semantic_chunk_text IS 'Intelligently chunks text at paragraph boundaries with overlap';
COMMENT ON FUNCTION public.get_document_stats IS 'Get statistics about documents for a company';
COMMENT ON FUNCTION public.test_search_quality IS 'Debug function to compare search quality between methods';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Allow authenticated users to call search functions
GRANT EXECUTE ON FUNCTION public.search_documents_by_embedding TO authenticated;
GRANT EXECUTE ON FUNCTION public.hybrid_search_documents TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_context TO authenticated;
GRANT EXECUTE ON FUNCTION public.semantic_chunk_text TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_document_stats TO authenticated;
GRANT EXECUTE ON FUNCTION public.test_search_quality TO authenticated;
