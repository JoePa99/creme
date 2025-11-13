// Minimal test function to verify GitHub integration works

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

serve(async (req: Request) => {
  return new Response(
    JSON.stringify({
      message: 'Test function deployed successfully!',
      timestamp: new Date().toISOString()
    }),
    {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
      },
    }
  );
});
