#!/bin/bash

# Deploy to Supabase using npx (no installation required!)
# Run this script from your project root

echo "🚀 Deploying to Supabase (znpbeicliyymvyoaojzz)"
echo "================================================"
echo ""

# Step 1: Link to project
echo "📡 Step 1: Linking to Supabase project..."
npx supabase link --project-ref znpbeicliyymvyoaojzz

# Step 2: Push migrations
echo ""
echo "📊 Step 2: Pushing database migrations..."
npx supabase db push

# Step 3: Deploy functions
echo ""
echo "⚡ Step 3: Deploying edge functions..."
npx supabase functions deploy

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Set environment variables in Supabase Dashboard"
echo "2. Run 'npm run dev' to start your app"
