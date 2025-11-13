#!/bin/bash
# Minimal batch processor test

set -euo pipefail

echo "Starting minimal batch processor..."

# Test jq
if command -v jq >/dev/null 2>&1; then
    echo "jq is available"
else
    echo "jq is not available"
    exit 1
fi

# Test JSON creation
json=$(
    cat <<'EOF'
{
  "test": "value"
}
EOF
)

echo "JSON created: $json"

# Test jq update
updated=$(echo "$json" | jq '.test = "updated"')
echo "JSON updated: $updated"

echo "Minimal test completed successfully"
