// OpenAI client and utilities for embeddings and chat

import { AppError } from './types.ts';

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');

if (!OPENAI_API_KEY) {
  console.warn('OPENAI_API_KEY not set - embedding features will not work');
}

export const EMBEDDING_MODEL = 'text-embedding-ada-002';
export const EMBEDDING_DIMENSIONS = 1536;
export const MAX_TOKENS_PER_REQUEST = 8191;

/**
 * Generate embeddings for an array of texts using OpenAI
 */
export async function generateEmbeddings(
  texts: string[],
  model: string = EMBEDDING_MODEL
): Promise<number[][]> {
  if (!OPENAI_API_KEY) {
    throw new AppError('OpenAI API key not configured', 500);
  }

  if (texts.length === 0) {
    return [];
  }

  // Filter out empty texts
  const validTexts = texts.filter((t) => t && t.trim().length > 0);
  if (validTexts.length === 0) {
    return [];
  }

  try {
    console.log(`Generating embeddings for ${validTexts.length} texts`);

    const response = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        input: validTexts,
      }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new AppError(
        `OpenAI API error: ${error.error?.message || response.statusText}`,
        response.status
      );
    }

    const data = await response.json();

    // Extract embeddings in order
    const embeddings = data.data
      .sort((a: any, b: any) => a.index - b.index)
      .map((item: any) => item.embedding);

    console.log(`✅ Generated ${embeddings.length} embeddings`);
    console.log(`📊 Tokens used: ${data.usage.total_tokens}`);

    return embeddings;
  } catch (error) {
    console.error('Error generating embeddings:', error);
    throw error instanceof AppError
      ? error
      : new AppError(`Failed to generate embeddings: ${error.message}`, 500);
  }
}

/**
 * Generate a single embedding for text
 */
export async function generateEmbedding(
  text: string,
  model: string = EMBEDDING_MODEL
): Promise<number[]> {
  const embeddings = await generateEmbeddings([text], model);
  return embeddings[0];
}

/**
 * Chunk text semantically (at paragraph boundaries)
 */
export function semanticChunk(
  text: string,
  targetChunkSize: number = 1000,
  overlap: number = 100
): string[] {
  if (!text || text.trim().length === 0) {
    return [];
  }

  const chunks: string[] = [];

  // Split by double newlines (paragraphs)
  const paragraphs = text.split(/\n\n+/).filter((p) => p.trim().length > 0);

  let currentChunk = '';

  for (const para of paragraphs) {
    // If adding this paragraph would exceed target size and we have content
    if (
      currentChunk.length + para.length > targetChunkSize &&
      currentChunk.length > 0
    ) {
      // Store current chunk
      chunks.push(currentChunk.trim());

      // Start new chunk with overlap (last few characters of previous chunk)
      if (currentChunk.length > overlap) {
        currentChunk = currentChunk.slice(-overlap);
      } else {
        currentChunk = '';
      }
    }

    // Add paragraph to current chunk
    currentChunk += (currentChunk.length > 0 ? '\n\n' : '') + para;
  }

  // Add final chunk if it has content
  if (currentChunk.trim().length > 0) {
    chunks.push(currentChunk.trim());
  }

  return chunks;
}

/**
 * Fixed-size chunking (fallback for non-paragraph text)
 */
export function fixedChunk(
  text: string,
  chunkSize: number = 1000,
  overlap: number = 100
): string[] {
  if (!text || text.trim().length === 0) {
    return [];
  }

  const chunks: string[] = [];
  let start = 0;

  while (start < text.length) {
    const end = Math.min(start + chunkSize, text.length);
    const chunk = text.slice(start, end);

    if (chunk.trim().length > 0) {
      chunks.push(chunk.trim());
    }

    start = end - overlap;

    // Prevent infinite loop
    if (start >= text.length) break;
  }

  return chunks;
}

/**
 * Smart chunking: tries semantic first, falls back to fixed
 */
export function smartChunk(
  text: string,
  targetChunkSize: number = 1000,
  overlap: number = 100
): string[] {
  // Try semantic chunking first
  const semanticChunks = semanticChunk(text, targetChunkSize, overlap);

  // If semantic chunking produced good results, use it
  if (semanticChunks.length > 0) {
    const avgChunkSize =
      semanticChunks.reduce((sum, c) => sum + c.length, 0) /
      semanticChunks.length;

    // If average chunk size is reasonable, use semantic chunks
    if (avgChunkSize >= targetChunkSize * 0.5 && avgChunkSize <= targetChunkSize * 2) {
      console.log(`✅ Using semantic chunking: ${semanticChunks.length} chunks, avg size ${Math.round(avgChunkSize)}`);
      return semanticChunks;
    }
  }

  // Fall back to fixed chunking
  console.log('⚠️ Falling back to fixed-size chunking');
  return fixedChunk(text, targetChunkSize, overlap);
}

/**
 * Estimate token count (rough approximation)
 */
export function estimateTokens(text: string): number {
  // Rough estimate: 1 token ≈ 4 characters
  return Math.ceil(text.length / 4);
}

/**
 * Truncate text to fit within token limit
 */
export function truncateToTokens(text: string, maxTokens: number): string {
  const estimatedTokens = estimateTokens(text);

  if (estimatedTokens <= maxTokens) {
    return text;
  }

  // Calculate character limit based on token limit
  const charLimit = maxTokens * 4;
  return text.slice(0, charLimit) + '...';
}

/**
 * Call OpenAI Chat Completions API
 */
export async function callOpenAI(
  messages: Array<{ role: string; content: string }>,
  model: string = 'gpt-4o',
  temperature: number = 0.7,
  maxTokens: number = 4000
): Promise<{ content: string; tokens: number }> {
  if (!OPENAI_API_KEY) {
    throw new AppError('OpenAI API key not configured', 500);
  }

  try {
    console.log(`Calling OpenAI ${model} with ${messages.length} messages`);

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages,
        temperature,
        max_tokens: maxTokens,
      }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new AppError(
        `OpenAI API error: ${error.error?.message || response.statusText}`,
        response.status
      );
    }

    const data = await response.json();

    const content = data.choices[0]?.message?.content || '';
    const tokens = data.usage?.total_tokens || 0;

    console.log(`✅ OpenAI response: ${tokens} tokens used`);

    return { content, tokens };
  } catch (error) {
    console.error('Error calling OpenAI:', error);
    throw error instanceof AppError
      ? error
      : new AppError(`Failed to call OpenAI: ${error.message}`, 500);
  }
}
