#!/bin/bash

# List all edge functions in the project

echo "📦 Edge Functions in this project:"
echo "==================================="
echo ""

cd supabase/functions

for dir in */; do
    dir=${dir%/}  # Remove trailing slash
    if [ -f "$dir/index.ts" ]; then
        echo "✓ $dir"
    fi
done

echo ""
echo "Total: $(find . -maxdepth 2 -name "index.ts" | wc -l) functions"
