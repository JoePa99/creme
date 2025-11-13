// Supabase client initialization for edge functions

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import { AuthenticationError } from './types.ts';

// Get Supabase credentials from environment
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('Missing Supabase environment variables');
}

/**
 * Create a Supabase client with user context (respects RLS)
 * Use this when you want to perform operations as the authenticated user
 */
export function createUserClient(authHeader?: string) {
  if (!authHeader) {
    throw new AuthenticationError('Missing authorization header');
  }

  return createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: {
      headers: {
        Authorization: authHeader,
      },
    },
    auth: {
      persistSession: false,
    },
  });
}

/**
 * Create a Supabase client with service role (bypasses RLS)
 * Use this sparingly and only for system operations
 */
export function createServiceClient() {
  return createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

/**
 * Get authenticated user from request
 */
export async function getAuthenticatedUser(req: Request) {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    throw new AuthenticationError('Missing authorization header');
  }

  const client = createUserClient(authHeader);
  const {
    data: { user },
    error,
  } = await client.auth.getUser();

  if (error || !user) {
    throw new AuthenticationError('Invalid or expired token');
  }

  return user;
}

/**
 * Verify user has access to a company
 */
export async function verifyCompanyAccess(
  userId: string,
  companyId: string
): Promise<boolean> {
  const client = createServiceClient();

  const { data, error } = await client.rpc('user_has_company_access', {
    user_uuid: userId,
    check_company_id: companyId,
  });

  if (error) {
    console.error('Error verifying company access:', error);
    return false;
  }

  return data === true;
}

/**
 * Verify user is admin in a company
 */
export async function verifyAdminAccess(
  userId: string,
  companyId: string
): Promise<boolean> {
  const client = createServiceClient();

  const { data, error } = await client.rpc('user_is_admin', {
    user_uuid: userId,
    check_company_id: companyId,
  });

  if (error) {
    console.error('Error verifying admin access:', error);
    return false;
  }

  return data === true;
}

/**
 * Get user's companies
 */
export async function getUserCompanies(userId: string) {
  const client = createServiceClient();

  const { data, error } = await client
    .from('company_members')
    .select('company_id, companies(*)')
    .eq('user_id', userId)
    .eq('status', 'active');

  if (error) {
    console.error('Error fetching user companies:', error);
    return [];
  }

  return data.map((cm: any) => cm.companies);
}

/**
 * Create a new company with owner
 */
export async function createCompanyWithOwner(
  companyName: string,
  companySlug: string,
  userId: string
) {
  const client = createServiceClient();

  const { data, error } = await client.rpc('create_company_with_owner', {
    company_name: companyName,
    company_slug: companySlug,
    user_uuid: userId,
  });

  if (error) {
    throw new Error(`Failed to create company: ${error.message}`);
  }

  return data as string; // Returns company ID
}

/**
 * Get storage bucket URL for a file
 */
export function getStorageUrl(bucket: string, path: string): string {
  return `${SUPABASE_URL}/storage/v1/object/public/${bucket}/${path}`;
}

/**
 * Get signed URL for private storage
 */
export async function getSignedUrl(
  bucket: string,
  path: string,
  expiresIn: number = 3600
): Promise<string> {
  const client = createServiceClient();

  const { data, error } = await client.storage
    .from(bucket)
    .createSignedUrl(path, expiresIn);

  if (error) {
    throw new Error(`Failed to create signed URL: ${error.message}`);
  }

  return data.signedUrl;
}

/**
 * Download file from storage
 */
export async function downloadStorageFile(
  bucket: string,
  path: string
): Promise<Blob> {
  const client = createServiceClient();

  const { data, error } = await client.storage.from(bucket).download(path);

  if (error) {
    throw new Error(`Failed to download file: ${error.message}`);
  }

  return data;
}

/**
 * Upload file to storage
 */
export async function uploadStorageFile(
  bucket: string,
  path: string,
  file: File | Blob,
  contentType?: string
): Promise<string> {
  const client = createServiceClient();

  const { data, error } = await client.storage.from(bucket).upload(path, file, {
    contentType,
    upsert: true,
  });

  if (error) {
    throw new Error(`Failed to upload file: ${error.message}`);
  }

  return data.path;
}
