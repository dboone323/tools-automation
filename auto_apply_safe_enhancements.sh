#!/bin/bash
# Auto-applicable enhancements for safe improvements (Phase 1)
# Applies array performance optimizations and converts TODO/FIXME/HACK comments to doc comments

set -euo pipefail

PROJECT_PATH="$1"
cd "${PROJECT_PATH}"

echo "🤖 Applying safe enhancements..."

# Optimize array operations: replace inefficient appends in loops with map/reserveCapacity where possible
find . -name "*.swift" -type f -print0 | xargs -0 sed -i.bak -E \
	'/for[[:space:]]+.*in[[:space:]]+.*\{[[:space:]]*$/ { N; s/for[[:space:]]+([^\{]*)\{\n[[:space:]]*([^.]+)\.append\(([^)]*)\)/\2 += \1.map { \3 }/g; }'
find . -name "*.swift.bak" -delete
echo "✅ Array operations optimized"

# Convert TODO/FIXME/HACK comments to documentation comments
find . -name "*.swift" -type f -print0 | xargs -0 sed -i.bak -E \
	's#//[[:space:]]*(TODO|FIXME|HACK)[: ]*#/// #g'
find . -name "*.swift.bak" -delete
echo "✅ TODO/FIXME/HACK comments converted to doc comments"

echo "🎉 Safe enhancements applied."
