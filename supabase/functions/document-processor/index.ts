// Document Processor Edge Function
// Handles: Company OS, Agent Documents, Playbooks
// Process: Download → Extract Text → Chunk → Embed → Store

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import {
  createJsonResponse,
  createErrorResponse,
  handleCorsPreFlight,
} from '../_shared/cors.ts';
import {
  createServiceClient,
  getAuthenticatedUser,
  verifyAdminAccess,
  downloadStorageFile,
} from '../_shared/supabase.ts';
import {
  generateEmbeddings,
  smartChunk,
  estimateTokens,
} from '../_shared/openai.ts';
import { extractText, cleanText, getTextStats } from '../_shared/text-extraction.ts';
import {
  withErrorHandling,
  parseRequestBody,
  validateRequired,
  validateUUID,
  validateEnum,
} from '../_shared/errors.ts';
import {
  DocumentProcessRequest,
  DocumentProcessResponse,
  ValidationError,
  AuthorizationError,
  NotFoundError,
} from '../_shared/types.ts';

serve(
  withErrorHandling(async (req: Request) => {
    const origin = req.headers.get('Origin');

    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
      return handleCorsPreFlight(req);
    }

    // Only POST allowed
    if (req.method !== 'POST') {
      return createErrorResponse('Method not allowed', 405, undefined, origin);
    }

    // Get authenticated user
    const user = await getAuthenticatedUser(req);

    // Parse and validate request
    const body = await parseRequestBody<DocumentProcessRequest>(req);
    validateRequired(body, ['file_path', 'company_id', 'document_type']);
    validateUUID(body.company_id, 'company_id');
    validateEnum(body.document_type, 'document_type', [
      'company_os',
      'agent_specific',
      'playbook',
    ]);

    if (body.agent_id) {
      validateUUID(body.agent_id, 'agent_id');
    }

    const { file_path, company_id, document_type, agent_id, metadata } = body;

    console.log(`📄 Processing document: ${file_path}`);
    console.log(`   Type: ${document_type}`);
    console.log(`   Company: ${company_id}`);
    if (agent_id) console.log(`   Agent: ${agent_id}`);

    // Verify user is admin in company
    const isAdmin = await verifyAdminAccess(user.id, company_id);
    if (!isAdmin) {
      throw new AuthorizationError('Only admins can upload documents');
    }

    // Determine storage bucket based on document type
    let bucket: string;
    switch (document_type) {
      case 'company_os':
        bucket = 'company-os';
        break;
      case 'agent_specific':
        bucket = 'agent-documents';
        break;
      case 'playbook':
        bucket = 'agent-documents'; // Playbooks can use same bucket
        break;
      default:
        throw new ValidationError(`Invalid document type: ${document_type}`);
    }

    // Download file from storage
    console.log(`📥 Downloading from bucket: ${bucket}/${file_path}`);
    const fileBlob = await downloadStorageFile(bucket, file_path);
    const fileBuffer = await fileBlob.arrayBuffer();
    const fileName = file_path.split('/').pop() || 'document';

    console.log(`✅ Downloaded ${fileBuffer.byteLength} bytes`);

    // Extract text from file
    console.log('🔍 Extracting text...');
    const extractedText = await extractText(fileBuffer, fileName);
    const cleanedText = cleanText(extractedText);

    if (cleanedText.length < 10) {
      throw new ValidationError('Document contains no readable text');
    }

    const stats = getTextStats(cleanedText);
    console.log(`📊 Text stats:`, stats);

    // Chunk text semantically
    console.log('✂️  Chunking text...');
    const chunks = smartChunk(cleanedText, 1000, 100);
    console.log(`✅ Created ${chunks.length} chunks`);

    if (chunks.length === 0) {
      throw new ValidationError('Failed to chunk document text');
    }

    // Generate embeddings for all chunks
    console.log('🧠 Generating embeddings...');
    const embeddings = await generateEmbeddings(chunks);
    console.log(`✅ Generated ${embeddings.length} embeddings`);

    if (embeddings.length !== chunks.length) {
      throw new Error(
        `Embedding count mismatch: ${embeddings.length} embeddings for ${chunks.length} chunks`
      );
    }

    // Store chunks in database
    const supabase = createServiceClient();

    console.log('💾 Storing chunks in database...');

    // Delete existing documents of this type for this company/agent
    if (document_type === 'company_os') {
      // Delete all Company OS chunks for this company
      const { error: deleteError } = await supabase
        .from('documents')
        .delete()
        .eq('company_id', company_id)
        .eq('document_type', 'company_os');

      if (deleteError) {
        console.error('Error deleting old Company OS documents:', deleteError);
        throw new Error(`Failed to delete old documents: ${deleteError.message}`);
      }

      console.log('🗑️  Deleted old Company OS documents');
    } else if (document_type === 'agent_specific' && agent_id) {
      // Delete old agent-specific documents for this agent
      const { error: deleteError } = await supabase
        .from('documents')
        .delete()
        .eq('company_id', company_id)
        .eq('document_type', 'agent_specific')
        .eq('agent_id', agent_id);

      if (deleteError) {
        console.error('Error deleting old agent documents:', deleteError);
        throw new Error(`Failed to delete old documents: ${deleteError.message}`);
      }

      console.log('🗑️  Deleted old agent-specific documents');
    }

    // Insert all chunks
    const documentsToInsert = chunks.map((chunk, index) => ({
      company_id,
      document_type,
      file_name: fileName,
      agent_id: agent_id || null,
      content: chunk,
      embedding: embeddings[index],
      metadata: {
        ...metadata,
        chunk_index: index,
        total_chunks: chunks.length,
        source: document_type,
        file_path,
        characters: chunk.length,
        estimated_tokens: estimateTokens(chunk),
        created_at: new Date().toISOString(),
      },
    }));

    const { data: insertedDocs, error: insertError } = await supabase
      .from('documents')
      .insert(documentsToInsert)
      .select('id');

    if (insertError) {
      console.error('Error inserting documents:', insertError);
      throw new Error(`Failed to store documents: ${insertError.message}`);
    }

    console.log(`✅ Stored ${insertedDocs.length} document chunks`);

    // Update Company OS status if applicable
    if (document_type === 'company_os') {
      const { error: updateError } = await supabase
        .from('company_os')
        .update({
          raw_text: cleanedText,
          status: 'ready',
          updated_at: new Date().toISOString(),
        })
        .eq('company_id', company_id);

      if (updateError) {
        console.error('Error updating Company OS:', updateError);
        // Non-fatal, continue
      } else {
        console.log('✅ Updated Company OS status to ready');
      }
    }

    const response: DocumentProcessResponse = {
      success: true,
      document_id: insertedDocs[0]?.id,
      chunks_created: insertedDocs.length,
    };

    console.log('🎉 Document processing complete!');

    return createJsonResponse(response, 200, origin);
  })
);
