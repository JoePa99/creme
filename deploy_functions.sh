#!/bin/bash
# Deploy the 4 clean edge functions to Supabase
# Usage: ./deploy_functions.sh

# Check if SUPABASE_ACCESS_TOKEN is set
if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
  echo "❌ ERROR: SUPABASE_ACCESS_TOKEN is not set"
  echo "Get your token from: https://supabase.com/dashboard/account/tokens"
  echo "Then run: export SUPABASE_ACCESS_TOKEN=your_token_here"
  exit 1
fi

PROJECT_REF="znpbeicliyymvyoaojzz"

echo "🚀 Deploying 4 clean edge functions..."
echo ""

# Deploy test-deploy
echo "📦 Deploying test-deploy..."
npx supabase functions deploy test-deploy --project-ref $PROJECT_REF
if [ $? -eq 0 ]; then
  echo "✅ test-deploy deployed successfully"
else
  echo "❌ test-deploy deployment failed"
fi
echo ""

# Deploy document-processor
echo "📦 Deploying document-processor..."
npx supabase functions deploy document-processor --project-ref $PROJECT_REF
if [ $? -eq 0 ]; then
  echo "✅ document-processor deployed successfully"
else
  echo "❌ document-processor deployment failed"
fi
echo ""

# Deploy context-retriever
echo "📦 Deploying context-retriever..."
npx supabase functions deploy context-retriever --project-ref $PROJECT_REF
if [ $? -eq 0 ]; then
  echo "✅ context-retriever deployed successfully"
else
  echo "❌ context-retriever deployment failed"
fi
echo ""

# Deploy chat-handler
echo "📦 Deploying chat-handler..."
npx supabase functions deploy chat-handler --project-ref $PROJECT_REF
if [ $? -eq 0 ]; then
  echo "✅ chat-handler deployed successfully"
else
  echo "❌ chat-handler deployment failed"
fi
echo ""

echo "🎉 Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Go to https://supabase.com/dashboard/project/znpbeicliyymvyoaojzz/functions"
echo "2. Verify all 4 functions are listed"
echo "3. Add API keys at https://supabase.com/dashboard/project/znpbeicliyymvyoaojzz/settings/functions"
echo "   - OPENAI_API_KEY"
echo "   - ANTHROPIC_API_KEY"
echo "   - PERPLEXITY_API_KEY"
