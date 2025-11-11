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

### Phase 2: Security & Quality Tools

1. **SonarQube** for code quality analysis
2. **Trivy** for container vulnerability scanning
3. **Snyk** for dependency vulnerability management

### Phase 3: Documentation & Testing

1. **MkDocs** for project documentation
2. **Jest/Playwright** for testing frameworks

### Phase 4: Advanced Features

1. **ngrok** for external integrations
2. **HTTPie + jq** for API testing

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
_Tools Version: 1.0.0_
