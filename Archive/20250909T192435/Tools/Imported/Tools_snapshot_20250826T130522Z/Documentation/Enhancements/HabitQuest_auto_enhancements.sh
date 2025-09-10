#!/bin/bash
# Auto-applicable enhancements for safe improvements

set -euo pipefail

PROJECT_PATH="$1"
cd "$PROJECT_PATH"

echo "🤖 Applying safe enhancements..."

# Optimize array operations
echo "🔧 Optimizing array operations..."
find . -name "*.swift" -type f -exec sed -i.bak '
    /for.*in.*{/{
        N
        s/for \([^{]*\) {\n[[:space:]]*\([^.]*\)\.append(\([^)]*\))/\2 += \1.map { \3 }/
    }
' {} \;
find . -name "*.swift.bak" -delete
echo "✅ Array operations optimized"

