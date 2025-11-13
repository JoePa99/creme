// Error handling utilities for edge functions

import {
  AppError,
  AuthenticationError,
  AuthorizationError,
  NotFoundError,
  RateLimitError,
  ValidationError,
} from './types.ts';
import { createErrorResponse } from './cors.ts';

/**
 * Handle errors and return appropriate response
 */
export function handleError(error: unknown, origin?: string | null): Response {
  console.error('Error:', error);

  // Handle known error types
  if (error instanceof ValidationError) {
    return createErrorResponse(
      error.message,
      error.statusCode,
      error.code,
      origin
    );
  }

  if (error instanceof AuthenticationError) {
    return createErrorResponse(
      error.message,
      error.statusCode,
      error.code,
      origin
    );
  }

  if (error instanceof AuthorizationError) {
    return createErrorResponse(
      error.message,
      error.statusCode,
      error.code,
      origin
    );
  }

  if (error instanceof NotFoundError) {
    return createErrorResponse(
      error.message,
      error.statusCode,
      error.code,
      origin
    );
  }

  if (error instanceof RateLimitError) {
    return createErrorResponse(
      error.message,
      error.statusCode,
      error.code,
      origin
    );
  }

  if (error instanceof AppError) {
    return createErrorResponse(
      error.message,
      error.statusCode,
      error.code,
      origin
    );
  }

  // Handle Deno/fetch errors
  if (error instanceof TypeError) {
    return createErrorResponse(
      'Invalid request or network error',
      400,
      'INVALID_REQUEST',
      origin
    );
  }

  // Generic error
  const errorMessage = error instanceof Error ? error.message : 'Unknown error';
  return createErrorResponse(
    `Internal server error: ${errorMessage}`,
    500,
    'INTERNAL_ERROR',
    origin
  );
}

/**
 * Wrap an async handler with error handling
 */
export function withErrorHandling(
  handler: (req: Request) => Promise<Response>
): (req: Request) => Promise<Response> {
  return async (req: Request) => {
    try {
      return await handler(req);
    } catch (error) {
      const origin = req.headers.get('Origin');
      return handleError(error, origin);
    }
  };
}

/**
 * Validate required fields in an object
 */
export function validateRequired<T extends Record<string, unknown>>(
  obj: T,
  fields: (keyof T)[]
): void {
  const missing = fields.filter((field) => !obj[field]);

  if (missing.length > 0) {
    throw new ValidationError(
      `Missing required fields: ${missing.join(', ')}`
    );
  }
}

/**
 * Validate email format
 */
export function validateEmail(email: string): void {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    throw new ValidationError('Invalid email format');
  }
}

/**
 * Validate UUID format
 */
export function validateUUID(uuid: string, fieldName: string = 'ID'): void {
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(uuid)) {
    throw new ValidationError(`Invalid ${fieldName} format`);
  }
}

/**
 * Parse and validate JSON request body
 */
export async function parseRequestBody<T>(req: Request): Promise<T> {
  try {
    const body = await req.json();
    return body as T;
  } catch (error) {
    throw new ValidationError('Invalid JSON in request body');
  }
}

/**
 * Validate string length
 */
export function validateLength(
  value: string,
  fieldName: string,
  min?: number,
  max?: number
): void {
  if (min !== undefined && value.length < min) {
    throw new ValidationError(
      `${fieldName} must be at least ${min} characters`
    );
  }

  if (max !== undefined && value.length > max) {
    throw new ValidationError(
      `${fieldName} must be at most ${max} characters`
    );
  }
}

/**
 * Validate number range
 */
export function validateRange(
  value: number,
  fieldName: string,
  min?: number,
  max?: number
): void {
  if (min !== undefined && value < min) {
    throw new ValidationError(`${fieldName} must be at least ${min}`);
  }

  if (max !== undefined && value > max) {
    throw new ValidationError(`${fieldName} must be at most ${max}`);
  }
}

/**
 * Validate enum value
 */
export function validateEnum<T>(
  value: T,
  fieldName: string,
  allowedValues: T[]
): void {
  if (!allowedValues.includes(value)) {
    throw new ValidationError(
      `${fieldName} must be one of: ${allowedValues.join(', ')}`
    );
  }
}
