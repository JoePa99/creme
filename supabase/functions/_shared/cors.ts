// CORS headers for edge functions

const ALLOWED_ORIGINS = [
  'http://localhost:5173',
  'http://localhost:3000',
  'https://znpbeicliyymvyoaojzz.supabase.co',
  'https://creme-phi.vercel.app',
  'https://creme-bt13y0x8j-joepa99s-projects.vercel.app', // Preview deployments
];

/**
 * Get CORS headers for a request
 */
export function getCorsHeaders(origin?: string | null): HeadersInit {
  // Check if origin is allowed
  const allowedOrigin = origin && ALLOWED_ORIGINS.includes(origin)
    ? origin
    : ALLOWED_ORIGINS[0];

  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers':
      'Content-Type, Authorization, X-Client-Info, apikey, x-supabase-auth',
    'Access-Control-Max-Age': '86400',
  };
}

/**
 * Handle CORS preflight request
 */
export function handleCorsPreFlight(req: Request): Response {
  const origin = req.headers.get('Origin');
  return new Response(null, {
    status: 204,
    headers: getCorsHeaders(origin),
  });
}

/**
 * Create a JSON response with CORS headers
 */
export function createJsonResponse(
  data: unknown,
  status: number = 200,
  origin?: string | null
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...getCorsHeaders(origin),
    },
  });
}

/**
 * Create an error response with CORS headers
 */
export function createErrorResponse(
  message: string,
  status: number = 500,
  code?: string,
  origin?: string | null
): Response {
  return createJsonResponse(
    {
      error: message,
      code,
      status,
    },
    status,
    origin
  );
}
