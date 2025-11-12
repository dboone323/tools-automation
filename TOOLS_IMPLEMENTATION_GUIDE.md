# 🚀 Tools Automation - Free Tools Implementation Guide

## Overview

This guide walks you through implementing and using the free tools stack for comprehensive monitoring, development workflow, and quality assurance in your automation project.

## 📋 Prerequisites

- macOS or Linux operating system
- Internet connection for downloading tools
- Basic command line knowledge

## 🛠️ Quick Setup

### Option 1: Automated Setup (Recommended)

Run the automated setup script:

```bash
# Install everything (Docker, monitoring, dev tools)
./setup_tools.sh --all

# Or install components individually:
./setup_tools.sh --docker        # Docker for containers
./setup_tools.sh --monitoring    # Python monitoring dependencies
./setup_tools.sh --devtools      # Node.js, pre-commit, etc.
```

### Option 2: Manual Setup

If automated setup fails, follow the manual installation steps below.

## 🐳 Docker Installation

### macOS

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Docker Desktop
brew install --cask docker

# Start Docker Desktop from Applications folder
```

### Ubuntu/Debian

```bash
# Update package index
sudo apt-get update

# Install required packages
sudo apt-get install ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
```

## 📊 Monitoring Stack Setup

### 1. Install Python Dependencies

```bash
# Install required Python packages
pip3 install flask prometheus_client
```

### 2. Start Monitoring Stack

```bash
# Start all monitoring services
./monitoring.sh start
```

This will start:

- **Prometheus** (http://localhost:9090) - Metrics collection
- **Grafana** (http://localhost:3000) - Dashboards (admin/admin)
- **Uptime Kuma** (http://localhost:3001) - Uptime monitoring
- **Node Exporter** (http://localhost:9100) - System metrics

### 3. Start Metrics Exporter

```bash
# Start the agent metrics exporter
python3 metrics_exporter.py
```

Metrics will be available at: http://localhost:8080/metrics

## 📈 Analytics Setup (Umami)

### 1. Install Umami Analytics

Umami is a privacy-focused, self-hosted web analytics platform that integrates with your agent dashboard.

```bash
# Start Umami with PostgreSQL
python3 umami_analytics.py
```

This will:

- Start PostgreSQL database container
- Initialize Umami database schema
- Launch Umami web interface on http://localhost:3002

### 2. Configure Analytics Tracking

```python
# In your agent_dashboard_api.py or tracking script
from umami_analytics import track_event

# Track agent actions
track_event('agent_action', {
    'agent_name': 'agent_codegen',
    'action': 'code_review',
    'status': 'completed'
})

# Track user interactions
track_event('dashboard_view', {
    'page': 'agent_status',
    'user_agent': 'dashboard_user'
})
```

### 3. Access Analytics Dashboard

1. Open http://localhost:3002
2. Create admin account on first visit
3. Add your website (use localhost URLs for development)
4. View real-time analytics and user behavior

## 🔧 Development Tools Setup

### 1. Install Node.js (for various tools)

#### macOS

```bash
brew install node
```

#### Ubuntu

```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. Install Development Utilities

#### macOS

```bash
brew install jq httpie
```

#### Ubuntu

```bash
sudo apt-get update
sudo apt-get install jq httpie
```

### 3. Setup Pre-commit

```bash
# Install pre-commit
pip3 install pre-commit

# Install git hooks
pre-commit install

# Run on all files initially
pre-commit run --all-files
```

## 🚀 CI/CD with GitHub Actions

### 1. Create GitHub Actions Workflow

Create `.github/workflows/ci-cd.yml`:

```yaml
name: Agent System CI/CD
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.9"
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Run tests
        run: python3 -m pytest tests/ -v
      - name: Security scan
        run: |
          pip install safety
          safety check
      - name: Deploy to staging
        if: github.ref == 'refs/heads/develop'
        run: ./deploy_staging.sh
      - name: Deploy to production
        if: github.ref == 'refs/heads/main'
        run: ./deploy_production.sh
```

### 2. Add Required Files

Create `requirements.txt` with your dependencies:

```
flask==2.3.3
prometheus-client==0.17.1
requests==2.31.0
pytest==7.4.0
```

Create basic test structure:

```python
# tests/test_agent_api.py
import pytest
from agent_dashboard_api import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_endpoint(client):
    response = client.get('/health')
    assert response.status_code == 200
    assert b'healthy' in response.data
```

## 🔒 Security & Quality Tools

### 1. SonarQube Code Quality Analysis

```bash
# Start SonarQube container
docker run -d -p 9000:9000 sonarqube:community

# Install sonar-scanner
# macOS
brew install sonar-scanner

# Ubuntu
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-linux.zip
unzip sonar-scanner-cli-4.8.0.2856-linux.zip
export PATH=$PATH:$(pwd)/sonar-scanner-4.8.0.2856-linux/bin
```

Create `sonar-project.properties`:

```properties
sonar.projectKey=tools-automation
sonar.projectName=Tools Automation
sonar.projectVersion=1.0
sonar.sources=.
sonar.language=py
sonar.sourceEncoding=UTF-8
sonar.python.coverage.reportPaths=coverage.xml
```

Run analysis:

```bash
sonar-scanner
```

### 2. Trivy Container Vulnerability Scanning

```bash
# Install Trivy
# macOS
brew install trivy

# Ubuntu
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

# Scan container images
trivy image your-docker-image

# Scan filesystem
trivy fs /path/to/project

# CI/CD integration
trivy fs --exit-code 1 --no-progress .
```

### 3. Snyk Dependency Vulnerability Management

```bash
# Install Snyk CLI
npm install -g snyk

# Authenticate (get API token from snyk.io)
snyk auth

# Test for vulnerabilities
snyk test

# Monitor dependencies
snyk monitor

# Fix vulnerabilities
snyk wizard
```

## 📚 Documentation with MkDocs

### 1. Install and Setup MkDocs

```bash
# Install MkDocs and Material theme
pip3 install mkdocs mkdocs-material

# Create documentation site
mkdocs new docs

# Start development server
cd docs
mkdocs serve
```

### 2. Configure Documentation

Edit `mkdocs.yml`:

```yaml
site_name: Tools Automation System
nav:
  - Home: index.md
  - API Reference: api.md
  - Agent Guide: agents.md
  - Deployment: deployment.md
  - Monitoring: monitoring.md
theme:
  name: material
  features:
    - navigation.tabs
    - navigation.sections
    - toc.integrate
    - search.suggest
    - search.highlight
plugins:
  - search
```

### 3. Deploy Documentation

```bash
# Build static site
mkdocs build

# Deploy to GitHub Pages
mkdocs gh-deploy
```

## 🧪 Testing Frameworks

### 1. Jest for JavaScript Testing

```bash
# Install Jest
npm install --save-dev jest

# Add to package.json
{
  "scripts": {
    "test": "jest"
  }
}

# Create test file
// __tests__/agentMatcher.test.js
const { matchAgent } = require('../agentMatcher');

describe('Agent Matcher', () => {
  test('matches codegen tasks correctly', () => {
    const task = { type: 'code_improvement' };
    expect(matchAgent(task)).toBe('agent_codegen');
  });
});
```

### 2. Playwright for End-to-End Testing

```bash
# Install Playwright
npm install --save-dev @playwright/test
npx playwright install

# Create test
// tests/dashboard.spec.js
const { test, expect } = require('@playwright/test');

test('agent dashboard loads', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await expect(page.locator('text=Agent Status')).toBeVisible();
});
```

## 🤖 AI/ML Tools Integration

### 1. Ollama Local LLM Inference

```bash
# Install Ollama
# macOS
brew install ollama

# Ubuntu
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
ollama serve

# Pull models
ollama pull llama2
ollama pull codellama

# Use in Python scripts
from langchain.llms import Ollama

llm = Ollama(model="llama2")
response = llm("Generate a summary of this code")
```

### 2. Hugging Face Transformers

```bash
# Install transformers
pip3 install transformers torch

# Use for code analysis
from transformers import pipeline

# Sentiment analysis for code review
classifier = pipeline("sentiment-analysis")
result = classifier("This code looks good!")

# Text generation for documentation
generator = pipeline("text-generation", model="gpt2")
doc = generator("Write a function to", max_length=50)
```

### 3. LangChain for LLM Applications

```bash
# Install LangChain
pip3 install langchain

# Create agent workflow
from langchain.llms import Ollama
from langchain.chains import LLMChain
from langchain.prompts import PromptTemplate

llm = Ollama(model="llama2")
prompt = PromptTemplate(
    input_variables=["code"],
    template="Review this code for bugs: {code}"
)
chain = LLMChain(llm=llm, prompt=prompt)
result = chain.run(code="def hello(): print('world')")
```

### 4. scikit-learn for Machine Learning

```bash
# Install scikit-learn
pip3 install scikit-learn pandas numpy

# Train model on agent performance
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split

# Load agent performance data
# X = features, y = performance scores
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
clf = RandomForestClassifier()
clf.fit(X_train, y_train)
predictions = clf.predict(X_test)
```

## 🌐 External Integrations with ngrok

### 1. Install and Setup ngrok

```bash
# Install ngrok
# macOS
brew install ngrok

# Ubuntu
snap install ngrok

# Authenticate
ngrok config add-authtoken YOUR_AUTH_TOKEN

# Expose local services
# Expose dashboard
ngrok http 3000

# Expose API
ngrok http 5001

# Custom subdomain
ngrok http 3000 --subdomain=my-agent-dashboard
```

### 2. Webhook Integration

```python
# Example webhook handler
from flask import Flask, request
import json

app = Flask(__name__)

@app.route('/webhook/github', methods=['POST'])
def github_webhook():
    data = request.json
    if data['action'] == 'push':
        # Trigger agent tasks
        trigger_agent_task('code_review', data['head_commit'])
    return {'status': 'ok'}

if __name__ == '__main__':
    app.run(port=5002)
```

## 📈 Using the Monitoring Tools

### Grafana Dashboard Access

1. Open http://localhost:3000
2. Login with: `admin` / `admin`
3. Navigate to "System Overview" dashboard
4. Explore metrics for:
   - System CPU/Memory usage
   - Agent status
   - Task completion rates

### Prometheus Metrics

1. Open http://localhost:9090
2. Go to "Graph" tab
3. Query metrics like:
   - `agent_status{agent_name="agent_dashboard"}`
   - `system_agents_total`
   - `agent_tasks_completed_total`

### Uptime Kuma Monitoring

1. Open http://localhost:3001
2. Set up monitoring for:
   - Agent APIs
   - Web dashboards
   - External services

## 🧪 Testing the Implementation

### 1. Check Service Status

```bash
# Check all monitoring services
./monitoring.sh status

# View logs if issues occur
./monitoring.sh logs grafana
```

### 2. Test Metrics Endpoint

```bash
# Check metrics are being exported
curl http://localhost:8080/metrics

# Should see Prometheus-formatted metrics
```

### 3. Test API Endpoints

```bash
# Health check
curl http://localhost:8080/health

# Basic info
curl http://localhost:8080/
```

### 4. Test Development Tools

```bash
# Test jq JSON processing
echo '{"test": "data"}' | jq .

# Test HTTPie API calls
http GET http://localhost:8080/health

# Test pre-commit
pre-commit run --all-files
```

## 🔍 Troubleshooting

### Docker Issues

```bash
# Check Docker is running
docker info

# Check container status
./monitoring.sh status

# Restart monitoring stack
./monitoring.sh restart
```

### Metrics Not Appearing

```bash
# Check metrics exporter is running
ps aux | grep metrics_exporter

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Validate JSON format
python3 -m json.tool agent_status.json
```

### Pre-commit Issues

```bash
# Update pre-commit hooks
pre-commit autoupdate

# Clean pre-commit cache
pre-commit clean

# Run specific hook
pre-commit run black --all-files
```

### Port Conflicts

```bash
# Check what's using ports
lsof -i :3000,9090,3001,8080

# Change ports in docker-compose.monitoring.yml if needed
```

## 📚 Advanced Configuration

### Adding Custom Metrics

Edit `metrics_exporter.py` to add new metrics:

```python
from prometheus_client import Counter

CUSTOM_COUNTER = Counter('custom_operations_total', 'Custom operations performed')

# In your update_metrics() function:
CUSTOM_COUNTER.inc()  # Increment counter
```

### Custom Grafana Dashboards

1. In Grafana, go to "Create" → "Dashboard"
2. Add panels with queries like:
   ```
   rate(agent_tasks_completed_total[5m])
   ```
3. Save the dashboard

### Pre-commit Configuration

Edit `.pre-commit-config.yaml` to add more hooks:

```yaml
repos:
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.0.0
    hooks:
      - id: mypy
```

## 🎯 Next Steps

### Phase 2: Advanced Security & Quality (Implemented)

✅ **SonarQube** - Code quality analysis setup above  
✅ **Trivy** - Container vulnerability scanning setup above  
✅ **Snyk** - Dependency vulnerability management setup above

### Phase 3: Documentation & Testing (Implemented)

✅ **MkDocs** - Project documentation setup above  
✅ **Jest/Playwright** - Testing frameworks setup above

### Phase 4: AI/ML Integration (Implemented)

✅ **Ollama** - Local LLM inference setup above  
✅ **Hugging Face Transformers** - ML models for code analysis  
✅ **LangChain** - LLM application framework  
✅ **scikit-learn** - Machine learning for analytics

### Phase 5: Deployment & External Tools

1. **Railway/Vercel/Netlify** - Cloud deployment platforms
2. **GitHub Actions** - CI/CD automation (setup above)
3. **ngrok** - External integrations (setup above)

### Phase 6: Advanced Monitoring

1. **Plausible Analytics** - Alternative privacy-focused analytics
2. **Custom Grafana Dashboards** - Advanced visualization
3. **Alert Manager** - Automated alerting system

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review logs: `./monitoring.sh logs`
3. Validate configuration files
4. Check GitHub issues for similar problems

## 🤝 Contributing

When adding new tools:

1. Update this guide with setup instructions
2. Add configuration examples
3. Include troubleshooting steps
4. Test on both macOS and Linux

---

_Implementation Date: November 11, 2025_
_Tools Version: 1.1.0_
