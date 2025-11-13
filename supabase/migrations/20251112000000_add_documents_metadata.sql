-- Add metadata and document_type columns to documents table for better organization

-- Add metadata column to store additional document information
ALTER TABLE public.documents
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Add document_type column to categorize documents (e.g., 'company_os', 'uploaded', 'embedded')
ALTER TABLE public.documents
ADD COLUMN IF NOT EXISTS document_type TEXT DEFAULT 'uploaded';

-- Create index on document_type for efficient filtering
CREATE INDEX IF NOT EXISTS idx_documents_document_type ON public.documents(document_type);

-- Create index on metadata for JSONB queries
CREATE INDEX IF NOT EXISTS idx_documents_metadata ON public.documents USING gin(metadata);

-- Add comment to explain usage
COMMENT ON COLUMN public.documents.document_type IS 'Type of document: company_os (CompanyOS document chunks), uploaded (user-uploaded documents), or custom types';
COMMENT ON COLUMN public.documents.metadata IS 'Additional metadata about the document chunk (chunk_index, source, file_name, etc.)';
