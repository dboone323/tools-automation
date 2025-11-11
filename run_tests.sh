#!/bin/bash

# Test Runner Script
set -e

echo "🧪 Running Test Suite..."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Run unit tests
echo "📝 Running Unit Tests (Jest)..."
if npm test; then
    echo -e "${GREEN}✅ Unit tests passed${NC}"
else
    echo -e "${RED}❌ Unit tests failed${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Test suite completed!${NC}"
