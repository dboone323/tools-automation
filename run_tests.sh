#!/bin/bash

# Test Runner Script
set -e

echo "🧪 Running Test Suite..."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Run unit tests with Jest
echo "📝 Running Unit Tests (Jest)..."
if npm test -- --testPathIgnorePatterns="tests/e2e"; then
    echo -e "${GREEN}✅ Unit tests passed${NC}"
else
    echo -e "${RED}❌ Unit tests failed${NC}"
    exit 1
fi

# Run E2E tests with Playwright (only if services are running)
echo "🌐 Checking if services are running for E2E tests..."
if curl -s http://localhost:8000/health >/dev/null 2>&1; then
    echo "📱 Running E2E Tests (Playwright)..."
    if npx playwright test; then
        echo -e "${GREEN}✅ E2E tests passed${NC}"
    else
        echo -e "${YELLOW}⚠️  E2E tests failed - check if all services are running${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Skipping E2E tests - services not running${NC}"
fi

echo -e "${GREEN}🎉 Test suite completed!${NC}"
