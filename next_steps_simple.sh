#!/bin/bash

# 🚀 Next Steps Implementation Script (Simplified)
# This script implements Phase 4 & 5 enhancements

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Phase 4: Testing Frameworks Setup
setup_testing_frameworks() {
    log_info "🔧 Setting up Testing Frameworks (Phase 4)..."

    # Check if Node.js is installed
    if ! command_exists node; then
        log_error "Node.js is required for testing frameworks. Please install Node.js first."
        return 1
    fi

    # Initialize package.json if it doesn't exist
    if [[ ! -f "package.json" ]]; then
        log_info "Creating package.json..."
        npm init -y
    fi

    # Install Jest for unit testing
    log_info "Installing Jest for unit testing..."
    npm install --save-dev jest

    # Install Playwright for E2E testing
    log_info "Installing Playwright for E2E testing..."
    npm install --save-dev @playwright/test
    npx playwright install

    # Create Jest configuration
    cat >jest.config.js <<'EOF'
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.js', '**/?(*.)+(spec|test).js'],
  collectCoverage: true,
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html'],
  verbose: true,
};
EOF

    # Create Playwright configuration
    cat >playwright.config.js <<'EOF'
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
EOF

    # Create test directories
    mkdir -p tests/unit tests/e2e

    # Create sample unit test
    cat >tests/unit/agentMatcher.test.js <<'EOF'
const { matchAgent } = require('../../agentMatcher');

describe('Agent Matcher', () => {
  test('matches codegen tasks correctly', () => {
    const task = { type: 'code_improvement', priority: 'high' };
    expect(matchAgent(task)).toBe('agent_codegen');
  });
});
EOF

    # Create sample E2E test
    cat >tests/e2e/dashboard.spec.js <<'EOF'
import { test, expect } from '@playwright/test';

test.describe('Agent Dashboard', () => {
  test('loads main dashboard', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('text=Agent Status Dashboard')).toBeVisible();
  });
});
EOF

    # Create test runner script
    cat >run_tests.sh <<'EOF'
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
EOF

    chmod +x run_tests.sh

    log_success "Testing frameworks setup complete!"
    log_info "Run './run_tests.sh' to execute the test suite"
}

# Phase 5: Advanced Features Setup
setup_advanced_features() {
    log_info "🚀 Setting up Advanced Features (Phase 5)..."

    # Install ngrok for external integrations
    if ! command_exists ngrok; then
        log_info "Installing ngrok..."
        if command_exists brew; then
            brew install ngrok
        fi
    fi

    # Create ngrok management script
    cat >ngrok_manager.sh <<'EOF'
#!/bin/bash

# ngrok Management Script
set -e

SERVICE=$1
PORT=$2

if [[ -z "$SERVICE" || -z "$PORT" ]]; then
    echo "Usage: $0 <service> <port>"
    echo "Examples:"
    echo "  $0 grafana 3000"
    echo "  $0 prometheus 9090"
    exit 1
fi

echo "🌐 Starting ngrok tunnel for $SERVICE on port $PORT..."

# Start ngrok in background
ngrok http $PORT > /tmp/ngrok_$SERVICE.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to start
sleep 3

# Get the public URL
PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')

if [[ -n "$PUBLIC_URL" && "$PUBLIC_URL" != "null" ]]; then
    echo "✅ ngrok tunnel established!"
    echo "🌍 Public URL: $PUBLIC_URL"
    echo "🔗 Local service: http://localhost:$PORT"
    echo ""
    echo "💡 Press Ctrl+C to stop the tunnel"
    echo ""
    echo "📊 Tunnel status: http://localhost:4040"
    echo ""
    # Keep the script running to maintain the tunnel
    wait $NGROK_PID
else
    echo "❌ Failed to establish ngrok tunnel"
    kill $NGROK_PID 2>/dev/null || true
    exit 1
fi
EOF

    chmod +x ngrok_manager.sh

    # Create CI/CD pipeline configuration
    mkdir -p .github/workflows

    cat >.github/workflows/ci-cd.yml <<'EOF'
name: Agent System CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'

    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
        npm ci

    - name: Run tests
      run: npm test

    - name: Security scan
      run: |
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
        trivy fs --exit-code 1 --no-progress .
EOF

    log_success "Advanced features setup complete!"
    log_info "New capabilities available:"
    log_info "  🌐 ngrok: ./ngrok_manager.sh <service> <port>"
    log_info "  🔄 CI/CD: GitHub Actions workflow created"
}

# Main execution
main() {
    local command="$1"

    case "${command}" in
    "testing")
        setup_testing_frameworks
        ;;
    "advanced")
        setup_advanced_features
        ;;
    "all")
        log_info "🚀 Running complete next steps implementation..."
        setup_testing_frameworks
        setup_advanced_features
        log_success "🎉 All next steps implemented successfully!"
        ;;
    *)
        echo "Usage: $0 {testing|advanced|all}"
        echo ""
        echo "Commands:"
        echo "  testing     - Set up Jest and Playwright testing frameworks"
        echo "  advanced    - Add ngrok, CI/CD, and advanced monitoring"
        echo "  all         - Run all phases"
        exit 1
        ;;
    esac
}

main "$@"
