#!/bin/bash

# 🚀 Next Steps Implementation Script
# This script implements Phase 4 & 5 enhancements

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    cat > jest.config.js << 'EOF'
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
    cat > playwright.config.js << 'EOF'
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
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
  ],
});
EOF

    # Create test directories
    mkdir -p tests/unit tests/e2e

    # Create sample unit test
    cat > tests/unit/agentMatcher.test.js << 'EOF'
const { matchAgent } = require('../../agentMatcher');

describe('Agent Matcher', () => {
  test('matches codegen tasks correctly', () => {
    const task = { type: 'code_improvement', priority: 'high' };
    expect(matchAgent(task)).toBe('agent_codegen');
  });

  test('matches monitoring tasks correctly', () => {
    const task = { type: 'system_monitoring', priority: 'medium' };
    expect(matchAgent(task)).toBe('agent_monitoring');
  });

  test('returns default agent for unknown tasks', () => {
    const task = { type: 'unknown_task', priority: 'low' };
    expect(matchAgent(task)).toBe('agent_default');
  });
});
EOF

    # Create sample E2E test
    cat > tests/e2e/dashboard.spec.js << 'EOF'
import { test, expect } from '@playwright/test';

test.describe('Agent Dashboard', () => {
  test('loads main dashboard', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('text=Agent Status Dashboard')).toBeVisible();
  });

  test('displays agent status', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('[data-testid="agent-status"]')).toBeVisible();
  });

  test('shows metrics data', async ({ page }) => {
    await page.goto('/metrics');
    await expect(page.locator('text=Active Agents')).toBeVisible();
  });

  test('Grafana integration works', async ({ page }) => {
    await page.goto('/grafana');
    // Check if Grafana iframe loads or redirects properly
    await expect(page.locator('iframe, [data-testid="grafana-content"]')).toBeVisible();
  });
});
EOF

    # Create test runner script
    cat > run_tests.sh << 'EOF'
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

# Run E2E tests (only if services are running)
echo "🌐 Checking if services are running for E2E tests..."
if curl -s http://localhost:3000 > /dev/null 2>&1; then
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
        else
            log_warning "Please install ngrok manually from https://ngrok.com/download"
        fi
    fi

    # Create ngrok management script
    cat > ngrok_manager.sh << 'EOF'
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
    echo "  $0 sonarqube 9000"
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
    echo "📋 Share this URL for external access to $SERVICE"
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

    cat > .github/workflows/ci-cd.yml << 'EOF'
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

    - name: Install Python dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt

    - name: Install Node.js dependencies
      run: npm ci

    - name: Run pre-commit hooks
      run: |
        pip install pre-commit
        pre-commit run --all-files

    - name: Run unit tests
      run: npm test

    - name: Security scan with Trivy
      run: |
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
        trivy fs --exit-code 1 --no-progress .

    - name: Build Docker images
      run: |
        docker build -t agent-system:latest .
        docker build -t metrics-exporter:latest -f Dockerfile.metrics .

    - name: Run integration tests
      run: |
        docker-compose -f docker-compose.test.yml up -d
        sleep 30
        npm run test:e2e
        docker-compose -f docker-compose.test.yml down

    - name: Deploy to staging
      if: github.ref == 'refs/heads/develop'
      run: |
        echo "🚀 Deploying to staging environment..."
        # Add your staging deployment commands here

    - name: Deploy to production
      if: github.ref == 'refs/heads/main'
      run: |
        echo "🎯 Deploying to production..."
        # Add your production deployment commands here

  docs:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
    - uses: actions/checkout@v4

    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'

    - name: Install MkDocs
      run: pip install mkdocs mkdocs-material

    - name: Build documentation
      run: mkdocs build

    - name: Deploy to GitHub Pages
      uses: peaceiris/actions-gh-pages@v3
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./site
EOF

    # Create advanced monitoring configuration
    cat > prometheus/advanced_rules.yml << 'EOF'
groups:
  - name: agent_alerts
    rules:
      - alert: AgentDown
        expr: up{job="agent_metrics"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Agent {{ $labels.instance }} is down"
          description: "Agent {{ $labels.instance }} has been down for more than 5 minutes."

      - alert: HighTaskQueue
        expr: agent_tasks_queued > 100
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High task queue on {{ $labels.agent_name }}"
          description: "Task queue for {{ $labels.agent_name }} is above 100 tasks."

      - alert: LowAgentPerformance
        expr: rate(agent_tasks_completed_total[5m]) < 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Low performance on {{ $labels.agent_name }}"
          description: "Agent {{ $labels.agent_name }} completed less than 1 task per minute over 10 minutes."
EOF

    # Create alerting configuration for Prometheus
    cat > prometheus/alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@agent-system.local'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email'

receivers:
- name: 'email'
  email_configs:
  - to: 'admin@agent-system.local'
    send_resolved: true
EOF

    log_success "Advanced features setup complete!"
    log_info "New capabilities available:"
    log_info "  🌐 ngrok: ./ngrok_manager.sh <service> <port>"
    log_info "  🔄 CI/CD: GitHub Actions workflow created"
    log_info "  🚨 Alerts: Prometheus alerting rules configured"
}

# Integration Testing Setup
setup_integration_testing() {
    log_info "🔗 Setting up Integration Testing..."

    # Create docker-compose.test.yml for integration tests
    cat > docker-compose.test.yml << 'EOF'
version: '3.8'

services:
  test-prometheus:
    image: prom/prometheus:latest
    ports:
      - "9091:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - test-network

  test-grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    depends_on:
      - test-prometheus
    networks:
      - test-network

  test-metrics-exporter:
    build:
      context: .
      dockerfile: Dockerfile.metrics
    ports:
      - "8081:8080"
    networks:
      - test-network

networks:
  test-network:
    driver: bridge
EOF

    # Create integration test script
    cat > tests/integration/test_services.py << 'EOF'
#!/usr/bin/env python3

"""
Integration Tests for Agent System Services
"""

import requests
import time
import sys
from typing import Dict, List

class ServiceTester:
    def __init__(self):
        self.services = {
            'prometheus': 'http://localhost:9091',
            'grafana': 'http://localhost:3001',
            'metrics_exporter': 'http://localhost:8081'
        }
        self.timeout = 30

    def wait_for_service(self, name: str, url: str) -> bool:
        """Wait for a service to become available"""
        print(f"⏳ Waiting for {name} at {url}...")
        start_time = time.time()

        while time.time() - start_time < self.timeout:
            try:
                response = requests.get(url, timeout=5)
                if response.status_code == 200:
                    print(f"✅ {name} is ready!")
                    return True
            except requests.RequestException:
                pass

            time.sleep(2)

        print(f"❌ {name} failed to start within {self.timeout} seconds")
        return False

    def test_prometheus(self) -> bool:
        """Test Prometheus metrics endpoint"""
        try:
            response = requests.get(f"{self.services['prometheus']}/api/v1/status/buildinfo")
            if response.status_code == 200:
                data = response.json()
                if 'data' in data:
                    print("✅ Prometheus API responding correctly")
                    return True
        except Exception as e:
            print(f"❌ Prometheus test failed: {e}")

        return False

    def test_metrics_exporter(self) -> bool:
        """Test custom metrics exporter"""
        try:
            # Test health endpoint
            health_response = requests.get(f"{self.services['metrics_exporter']}/health")
            if health_response.status_code != 200:
                return False

            # Test metrics endpoint
            metrics_response = requests.get(f"{self.services['metrics_exporter']}/metrics")
            if metrics_response.status_code == 200:
                content = metrics_response.text
                if 'agent_status' in content and 'prometheus' in content.lower():
                    print("✅ Metrics exporter working correctly")
                    return True
        except Exception as e:
            print(f"❌ Metrics exporter test failed: {e}")

        return False

    def test_grafana(self) -> bool:
        """Test Grafana accessibility"""
        try:
            response = requests.get(f"{self.services['grafana']}/api/health")
            if response.status_code == 200:
                print("✅ Grafana API responding correctly")
                return True
        except Exception as e:
            print(f"❌ Grafana test failed: {e}")

        return False

    def run_all_tests(self) -> bool:
        """Run all integration tests"""
        print("🧪 Starting Integration Tests...\n")

        all_passed = True

        # Wait for all services
        for name, url in self.services.items():
            if not self.wait_for_service(name, url):
                all_passed = False

        if not all_passed:
            print("\n❌ Some services failed to start. Aborting tests.")
            return False

        print("\n🔍 Running service tests...\n")

        # Test each service
        tests = [
            ('Prometheus', self.test_prometheus),
            ('Metrics Exporter', self.test_metrics_exporter),
            ('Grafana', self.test_grafana)
        ]

        for test_name, test_func in tests:
            print(f"Testing {test_name}...")
            if not test_func():
                all_passed = False

        print("\n" + "="*50)
        if all_passed:
            print("🎉 All integration tests passed!")
        else:
            print("❌ Some integration tests failed!")

        return all_passed

if __name__ == '__main__':
    tester = ServiceTester()
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)
EOF

    chmod +x tests/integration/test_services.py

    log_success "Integration testing setup complete!"
}

# Documentation Enhancement
enhance_documentation() {
    log_info "📚 Enhancing Documentation..."

    # Create advanced MkDocs configuration
    cat > mkdocs.yml << 'EOF'
site_name: Agent Automation System
site_description: Comprehensive automation platform with AI agents
site_author: dboone323

# Repository
repo_name: dboone323/tools-automation
repo_url: https://github.com/dboone323/tools-automation

# Theme
theme:
  name: material
  palette:
    primary: blue
    accent: light blue
  font:
    text: Roboto
    code: Roboto Mono
  features:
    - navigation.tabs
    - navigation.sections
    - toc.integrate
    - search.suggest
    - search.highlight
    - content.tabs.link
    - content.code.annotation
    - content.code.copy

# Plugins
plugins:
  - search
  - minify:
      minify_html: true
  - git-revision-date-localized:
      enable_creation_date: true
  - mkdocstrings:
      handlers:
        python:
          options:
            show_source: true

# Extensions
markdown_extensions:
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.inlinehilite
  - pymdownx.snippets
  - pymdownx.superfences
  - pymdownx.tabbed:
      alternate_style: true
  - pymdownx.emoji:
      emoji_index: !!python/name:materialx.emoji.twemoji
      emoji_generator: !!python/name:materialx.emoji.to_svg
  - admonition
  - pymdownx.details
  - pymdownx.superfences
  - footnotes
  - meta
  - toc:
      permalink: true

# Navigation
nav:
  - Home: index.md
  - Getting Started:
      - Installation: getting-started/installation.md
      - Quick Start: getting-started/quick-start.md
      - Configuration: getting-started/configuration.md
  - User Guide:
      - Agents: user-guide/agents.md
      - Tasks: user-guide/tasks.md
      - Monitoring: user-guide/monitoring.md
      - Quality Assurance: user-guide/quality.md
  - API Reference:
      - REST API: api/rest.md
      - Metrics: api/metrics.md
      - Webhooks: api/webhooks.md
  - Development:
      - Contributing: development/contributing.md
      - Testing: development/testing.md
      - CI/CD: development/ci-cd.md
  - Tools & Integrations:
      - Free Tools Stack: tools/free-tools.md
      - Docker Setup: tools/docker.md
      - Monitoring: tools/monitoring.md
      - Security: tools/security.md
  - Troubleshooting: troubleshooting.md
  - Changelog: changelog.md

# Additional CSS/JS
extra_css:
  - stylesheets/extra.css

extra_javascript:
  - javascripts/extra.js
EOF

    # Create documentation structure
    mkdir -p docs/{getting-started,user-guide,api,development,tools}

    # Create main index
    cat > docs/index.md << 'EOF'
# Agent Automation System

Welcome to the comprehensive automation platform powered by AI agents. This system provides enterprise-grade monitoring, quality assurance, and development tools all running locally.

## 🚀 Quick Start

Get started in minutes with our automated setup:

```bash
# Clone the repository
git clone https://github.com/dboone323/tools-automation.git
cd tools-automation

# Run automated setup
./setup_tools.sh --all

# Start all services
./monitoring.sh start
./quality.sh start
mkdocs serve
```

## 📊 System Overview

Our platform includes:

- **🤖 AI Agents**: Intelligent task processing and automation
- **📈 Monitoring**: Prometheus + Grafana for comprehensive observability
- **🧪 Quality Assurance**: SonarQube for code quality analysis
- **🔒 Security**: Trivy and Snyk for vulnerability scanning
- **📚 Documentation**: MkDocs with Material theme
- **🧪 Testing**: Jest and Playwright for comprehensive testing

## 🎯 Key Features

### Agent Management
- Dynamic agent assignment based on task types
- Real-time performance monitoring
- Automated scaling and load balancing

### Quality Assurance
- Automated code analysis with SonarQube
- Security vulnerability scanning
- Test coverage reporting

### Monitoring & Alerting
- System metrics collection with Prometheus
- Interactive dashboards with Grafana
- Custom alerting rules and notifications

## 📖 Documentation Sections

- [Getting Started](getting-started/) - Installation and setup guides
- [User Guide](user-guide/) - How to use the system
- [API Reference](api/) - REST API documentation
- [Development](development/) - Contributing and development info
- [Tools](tools/) - Available tools and integrations

## 🤝 Contributing

We welcome contributions! Please see our [contributing guide](development/contributing.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.
EOF

    log_success "Documentation enhanced with advanced MkDocs configuration!"
}

# Main execution
main() {
    local phase="$1"

    case "${phase}" in
        "testing")
            setup_testing_frameworks
            ;;
        "advanced")
            setup_advanced_features
            ;;
        "integration")
            setup_integration_testing
            ;;
        "docs")
            enhance_documentation
            ;;
        "all")
            log_info "🚀 Running complete next steps implementation..."
            setup_testing_frameworks
            setup_advanced_features
            setup_integration_testing
            enhance_documentation
            log_success "🎉 All next steps implemented successfully!"
            ;;
        *)
            echo "Usage: $0 {testing|advanced|integration|docs|all}"
            echo ""
            echo "Phases:"
            echo "  testing     - Set up Jest and Playwright testing frameworks"
            echo "  advanced    - Add ngrok, CI/CD, and advanced monitoring"
            echo "  integration - Create integration testing infrastructure"
            echo "  docs        - Enhance documentation with MkDocs"
            echo "  all         - Run all phases"
            exit 1
            ;;
    esac
}

main "$@"</content>
<parameter name="filePath">/Users/danielstevens/Desktop/github-projects/tools-automation/next_steps.sh