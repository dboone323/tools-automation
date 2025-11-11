---
title: Quick Start Guide
description: Get up and running with Tools Automation in minutes
author: Tools Automation Team
date: 2025-11-11
---

# 🚀 Quick Start Guide

Get the Tools Automation project up and running in your development environment.

## Prerequisites

- **Operating System**: macOS 10.15+ or Ubuntu 18.04+
- **Hardware**: 4GB RAM minimum, 8GB recommended
- **Network**: Internet connection for downloading tools

## ⚡ One-Command Setup

The fastest way to get started:

```bash
# Clone and setup everything
git clone https://github.com/dboone323/tools-automation.git
cd tools-automation

# Install all tools automatically
./setup_tools.sh --all

# Start the monitoring stack
./monitoring.sh start

# Start the metrics exporter (in another terminal)
python3 metrics_exporter.py
```

That's it! Access your monitoring dashboard at [http://localhost:3000](http://localhost:3000).

## 📋 Manual Setup Steps

If automated setup fails, follow these steps:

### 1. Install Docker

=== "macOS"
```bash # Install Homebrew if not installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Install Docker Desktop
    brew install --cask docker

    # Start Docker Desktop from Applications
    ```

=== "Ubuntu"
```bash # Update system
sudo apt-get update

    # Install Docker
    sudo apt-get install ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Add user to docker group
    sudo usermod -aG docker $USER
    ```

### 2. Install Python Dependencies

```bash
# Install required packages
pip3 install flask prometheus_client

# Optional: Install in virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install flask prometheus_client
```

### 3. Install Development Tools

```bash
# Install MkDocs for documentation
pip3 install mkdocs mkdocs-material

# Install pre-commit for code quality
pip3 install pre-commit

# Install additional tools
pip3 install linkchecker  # For documentation validation
```

### 4. Setup Pre-commit Hooks

```bash
# Install git hooks
pre-commit install

# Run on all existing files
pre-commit run --all-files
```

## 🖥️ Starting Services

### Monitoring Stack

```bash
# Start Prometheus, Grafana, and Uptime Kuma
./monitoring.sh start

# Check status
./monitoring.sh status

# View logs
./monitoring.sh logs grafana
```

### Quality Tools (Optional)

```bash
# Start SonarQube for code analysis
./quality.sh start

# Run code analysis
./quality.sh analyze
```

### Documentation (Optional)

```bash
# Start documentation development server
./docs.sh serve

# Build documentation site
./docs.sh build
```

## 🔍 Verification

### Check Monitoring Setup

```bash
# Run comprehensive test
./test_monitoring.sh

# Should show:
# ✅ Configuration files exist
# ✅ Python dependencies installed
# (Docker tests will fail until Docker is installed)
```

### Access Points

Once everything is running:

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Uptime Kuma**: http://localhost:3001
- **SonarQube**: http://localhost:9000 (admin/admin)
- **Documentation**: http://localhost:8000 (if running)

### Test Metrics

```bash
# Check metrics endpoint
curl http://localhost:8080/metrics

# Should return Prometheus-formatted metrics
```

## 🛠️ Development Workflow

### Daily Development

1. **Start your environment**:

   ```bash
   ./monitoring.sh start
   python3 metrics_exporter.py &
   ```

2. **Make code changes** with pre-commit checks:

   ```bash
   git add .
   git commit -m "Your changes"
   # Pre-commit hooks run automatically
   ```

3. **Monitor your work** in Grafana dashboards

### Code Quality Checks

```bash
# Run security scan
./security_scan.sh audit

# Check dependencies
./dependency_scan.sh test

# Run code analysis (if SonarQube is running)
./quality.sh analyze
```

## 🐛 Troubleshooting

### Common Issues

#### Docker Not Starting

```bash
# Check Docker is installed
docker --version

# Check Docker daemon
docker info

# Restart Docker service
# macOS: Restart Docker Desktop
# Linux: sudo systemctl restart docker
```

#### Port Conflicts

```bash
# Check what's using ports
lsof -i :3000,9090,3001,8080

# Change ports in docker-compose files if needed
```

#### Python Import Errors

```bash
# Check Python path
python3 -c "import flask; print('Flask OK')"
python3 -c "import prometheus_client; print('Prometheus OK')"

# Reinstall packages
pip3 uninstall flask prometheus_client
pip3 install flask prometheus_client
```

#### Pre-commit Issues

```bash
# Update hooks
pre-commit autoupdate

# Clean cache
pre-commit clean

# Run manually
pre-commit run --all-files
```

## 📞 Getting Help

- **Documentation**: [Full Documentation](../reference/troubleshooting.md)
- **Issues**: [GitHub Issues](https://github.com/dboone323/tools-automation/issues)
- **Discussions**: [GitHub Discussions](https://github.com/dboone323/tools-automation/discussions)

## 🎯 Next Steps

Now that you have the basics running:

1. **Explore Grafana**: Create custom dashboards for your metrics
2. **Configure Monitoring**: Add your own services to monitor
3. **Set up CI/CD**: Integrate with GitHub Actions
4. **Add Documentation**: Use MkDocs to document your processes
5. **Security Scanning**: Regular vulnerability assessments

Happy automating! 🤖

---

_Last updated: November 11, 2025_
