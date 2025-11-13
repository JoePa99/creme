// Text extraction utilities for different file types

import { AppError } from './types.ts';

/**
 * Extract text from a PDF file using pdf-parse
 */
export async function extractTextFromPDF(buffer: ArrayBuffer): Promise<string> {
  try {
    // Use pdf-parse library
    const pdfParse = await import('https://esm.sh/pdf-parse@1.1.1');
    const data = await pdfParse.default(new Uint8Array(buffer));
    return data.text;
  } catch (error) {
    console.error('Error extracting text from PDF:', error);
    throw new AppError(`Failed to extract text from PDF: ${error.message}`, 400);
  }
}

/**
 * Extract text from a DOCX file
 */
export async function extractTextFromDOCX(buffer: ArrayBuffer): Promise<string> {
  try {
    // Use mammoth for DOCX extraction
    const mammoth = await import('https://esm.sh/mammoth@1.6.0');
    const result = await mammoth.extractRawText({ arrayBuffer: buffer });
    return result.value;
  } catch (error) {
    console.error('Error extracting text from DOCX:', error);
    throw new AppError(`Failed to extract text from DOCX: ${error.message}`, 400);
  }
}

/**
 * Extract text from a plain text file
 */
export async function extractTextFromTXT(buffer: ArrayBuffer): Promise<string> {
  const decoder = new TextDecoder('utf-8');
  return decoder.decode(buffer);
}

/**
 * Extract text from a Markdown file
 */
export async function extractTextFromMarkdown(buffer: ArrayBuffer): Promise<string> {
  const decoder = new TextDecoder('utf-8');
  const markdown = decoder.decode(buffer);

  // Remove markdown formatting (basic cleanup)
  let text = markdown
    .replace(/^#{1,6}\s+/gm, '') // Remove headers
    .replace(/\*\*(.+?)\*\*/g, '$1') // Remove bold
    .replace(/\*(.+?)\*/g, '$1') // Remove italic
    .replace(/\[(.+?)\]\(.+?\)/g, '$1') // Remove links but keep text
    .replace(/`(.+?)`/g, '$1') // Remove inline code
    .replace(/```[\s\S]*?```/g, '') // Remove code blocks
    .replace(/^\s*[-*+]\s+/gm, ''); // Remove list markers

  return text;
}

/**
 * Auto-detect file type and extract text
 */
export async function extractText(
  buffer: ArrayBuffer,
  fileName: string
): Promise<string> {
  const extension = fileName.split('.').pop()?.toLowerCase();

  console.log(`Extracting text from ${fileName} (${extension})`);

  switch (extension) {
    case 'pdf':
      return await extractTextFromPDF(buffer);

    case 'docx':
    case 'doc':
      return await extractTextFromDOCX(buffer);

    case 'txt':
      return await extractTextFromTXT(buffer);

    case 'md':
    case 'markdown':
      return await extractTextFromMarkdown(buffer);

    default:
      // Try as plain text
      try {
        return await extractTextFromTXT(buffer);
      } catch (error) {
        throw new AppError(
          `Unsupported file type: ${extension}. Supported types: PDF, DOCX, TXT, MD`,
          400
        );
      }
  }
}

/**
 * Clean and normalize extracted text
 */
export function cleanText(text: string): string {
  return text
    .replace(/\r\n/g, '\n') // Normalize line endings
    .replace(/\n{3,}/g, '\n\n') // Reduce multiple newlines to double
    .replace(/[ \t]+/g, ' ') // Reduce multiple spaces/tabs to single space
    .replace(/^\s+|\s+$/gm, '') // Trim lines
    .trim();
}

/**
 * Get text stats
 */
export function getTextStats(text: string): {
  characters: number;
  words: number;
  lines: number;
  paragraphs: number;
  estimatedTokens: number;
} {
  const lines = text.split('\n').length;
  const paragraphs = text.split(/\n\n+/).filter((p) => p.trim().length > 0).length;
  const words = text.split(/\s+/).filter((w) => w.length > 0).length;
  const characters = text.length;
  const estimatedTokens = Math.ceil(characters / 4); // Rough estimate

  return {
    characters,
    words,
    lines,
    paragraphs,
    estimatedTokens,
  };
}
