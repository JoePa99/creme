#!/bin/bash

# Automated Supabase Setup Script
# This script sets up a fresh Supabase instance with all schema and functions

set -e  # Exit on any error

echo "🚀 Supabase Fresh Instance Setup"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}❌ Supabase CLI not found${NC}"
    echo "Install it with: npm install -g supabase"
    exit 1
fi

echo -e "${GREEN}✅ Supabase CLI found${NC}"
echo ""

# Prompt for project details
read -p "Enter your Supabase Project Reference ID: " PROJECT_REF
read -sp "Enter your Supabase Database Password: " DB_PASSWORD
echo ""

if [ -z "$PROJECT_REF" ] || [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}❌ Project ref and password are required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 1/5: Linking to Supabase project...${NC}"
supabase link --project-ref "$PROJECT_REF" --password "$DB_PASSWORD"
echo -e "${GREEN}✅ Linked to project${NC}"
echo ""

echo -e "${YELLOW}Step 2/5: Pushing database migrations...${NC}"
supabase db push
echo -e "${GREEN}✅ All migrations applied${NC}"
echo ""

echo -e "${YELLOW}Step 3/5: Creating storage buckets...${NC}"
supabase storage create documents --public=false
supabase storage create chat-attachments --public=true
supabase storage create chat-files --public=false
echo -e "${GREEN}✅ Storage buckets created${NC}"
echo ""

echo -e "${YELLOW}Step 4/5: Deploying all edge functions...${NC}"
echo "This may take several minutes..."
supabase functions deploy
echo -e "${GREEN}✅ All functions deployed${NC}"
echo ""

echo -e "${YELLOW}Step 5/5: Verifying setup...${NC}"
echo "Checking migrations:"
supabase migration list
echo ""
echo "Checking functions:"
supabase functions list
echo ""

echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Set environment variables in Supabase Dashboard:"
echo "   - OPENAI_API_KEY"
echo "   - ANTHROPIC_API_KEY (optional)"
echo "   - PERPLEXITY_API_KEY"
echo ""
echo "2. Update your frontend .env file with new credentials"
echo ""
echo "3. Deploy your frontend to Vercel/Netlify"
echo ""
echo "See SUPABASE_SETUP_GUIDE.md for detailed instructions"
