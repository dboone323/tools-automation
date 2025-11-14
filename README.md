# tools-automation

**Centralized automation tools, agents, and infrastructure for all projects**

## 🆓 Free Tools Stack - System Observability

A comprehensive suite of free, open-source tools for monitoring, security, quality assurance, and documentation to provide detailed visibility into your automation system's health and functionality.

### Quick Setup & Validation

```bash
# Install all free tools
./setup_tools.sh --all

# Validate installation
./test_tools.sh

# Start monitoring stack
./monitoring.sh start

# Start quality tools
./quality.sh start

# View documentation
./docs.sh serve
```

### Implemented Tools

| Category          | Tools                            | Status      |
| ----------------- | -------------------------------- | ----------- |
| **Monitoring**    | Prometheus, Grafana, Uptime Kuma | ✅ Complete |
| **Quality**       | SonarQube, PostgreSQL            | ✅ Complete |
| **Security**      | Trivy, Snyk                      | ✅ Complete |
| **Documentation** | MkDocs, Material Theme           | ✅ Complete |
| **Development**   | Pre-commit, HTTPie, jq           | ✅ Complete |

### Access Points

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Uptime Kuma**: http://localhost:3001
- **SonarQube**: http://localhost:9000 (admin/admin)
- **Documentation**: http://localhost:8000 (after `./docs.sh serve`)

### Key Features

- **Real-time Monitoring**: Track agent health, system metrics, and service status
- **Code Quality**: Automated analysis with technical debt tracking
- **Security Scanning**: Container and dependency vulnerability detection
- **Professional Documentation**: Auto-generated docs with search and versioning
- **Development Workflow**: Pre-commit hooks and API testing tools

---

## Overview

This repository serves as the superproject for all automation infrastructure, providing shared tools, agents, MCP servers, and workflows to all project submodules. Everything is organized for maximum reusability and minimal duplication.

## Structure

```
tools-automation/
├── agents/          # 111 shared agent scripts for automation
├── mcp/            # MCP servers and AI integration
├── workflows/      # CI/CD orchestration scripts
├── config/         # Shared configuration files
├── scripts/        # Utility scripts (TODO scanning, etc.)
├── docs/           # Documentation
└── [submodules]    # Project submodules (see below)
```

### Submodules

- **AvoidObstaclesGame** - Game project
- **CodingReviewer** - Code review tool
- **HabitQuest** - Habit tracking app
- **MomentumFinance** - Finance app
- **PlannerApp** - Planning tool
- **shared-kit** - Shared Swift utilities

All submodules access centralized tools via symlinks and environment variables.

## Quick Start

### MCP Server

Start the MCP server for AI integration:

```bash
cd mcp/
./servers/start_mcp_server.sh
```

View MCP dashboard:

```bash
./mcp_dashboard.sh
```

### Agents

Run an agent:

```bash
cd agents/
./agent_build.sh    # Build automation
./agent_codegen.sh  # Code generation
./agent_debug.sh    # Debugging assistance
```

Check agent status:

```bash
cat config/agent_status.json
```

### Workflows

Run CI orchestration:

```bash
cd workflows/
./ci_orchestrator.sh --project CodingReviewer
```

### Utilities

Scan for TODOs:

```bash
python3 scripts/regenerate_todo_json.py
```

## Configuration

Global agent configuration in `agents/agent_config.sh`:

- `MAX_CONCURRENCY=2` - Max concurrent agent instances
- `LOAD_THRESHOLD=4.0` - System load threshold
- `GLOBAL_AGENT_CAP=10` - Max total agents

Configuration files in `config/`:

- `agent_status.json` - Agent status tracking
- `task_queue.json` - Task queue
- `agent_assignments.json` - TODO assignments (66,972 entries)
- Plus deployment, monitoring, security configs

## Using from Submodules

Submodules access tools via environment variable:

```bash
export TOOLS_AUTOMATION_ROOT="/path/to/tools-automation"
source "$TOOLS_AUTOMATION_ROOT/agents/agent_config.sh"

# Run agents
"$TOOLS_AUTOMATION_ROOT/agents/agent_build.sh"
```

Agent symlink in CodingReviewer:

```bash
cd CodingReviewer/Tools/Automation/agents  # → symlink to ../../../agents
```

## Documentation

- `docs/AGENT_HEALTH_REPORT.md` - Agent diagnostics and health monitoring
- `docs/TODO_SYSTEM_ENHANCEMENT_PLAN.md` - TODO automation enhancement
- `docs/REPOSITORY_REORGANIZATION_PLAN.md` - Migration and structure details
- `docs/AGENT_ENHANCEMENT_MASTER_PLAN.md` - Agent improvement roadmap
- `docs/AI_MONITORING_GUIDE.md` - AI integration monitoring

Each directory has its own README:

- `agents/README.md`
- `mcp/README.md`
- `workflows/README.md`
- `config/README.md`
- `scripts/README.md`

## Artifacts

By default artifacts saved to `~/mcp_artifacts` (configurable via `ARTIFACT_DIR`).

For remote uploads, set `ARTIFACT_DEST`:

```bash
export ARTIFACT_DEST="s3://my-bucket/path"
```

Ensure AWS CLI is configured.

## Web Dashboard

Start a minimal web dashboard that proxies the MCP server and provides a simple UI:

```bash
python3 mcp_web_dashboard.py &
# then open http://127.0.0.1:8080
```

Daemon helper & log rotation

Use `run_mcp_daemon.sh` to start the MCP server and auto-rotate logs before start.
You can configure rotation via env vars:

````bash
export MAX_LOG_BYTES=2097152   # 2MB
export MAX_LOG_COUNT=10
./run_mcp_daemon.sh

Flask-based dashboard (optional)

If you prefer a richer UI, a Flask-based dashboard is included. Install dependencies and run:

```bash
python3 -m pip install -r requirements.txt
python3 mcp_dashboard_flask.py
# open http://127.0.0.1:8080
````

````


Notes

- `mcp_server.py` implements an allowlist of commands mapped to workspace scripts to reduce risk.
- `mcp_controller.py` prevents concurrent execution per project.
- For CI integration, run the server inside a background service or container.
# Master Automation

This folder contains the master automation controller and helper scripts used across the workspace.

Key scripts:


Notes:


Usage examples:

```bash
# List projects with quick status
./master_automation.sh list

# Run automation for a single project (e.g., PlannerApp)
./master_automation.sh run PlannerApp

# Run all project automations
./master_automation.sh all

# Validate workflows only
./deploy_workflows_all_projects.sh --validate
````

If you'd like I can also add a lightweight GitHub Actions workflow to run `master_automation.sh --validate` on PRs. Let me know if you want that added.

Note: retrigger marker — CI test edit.

## Local Agent CI

This repository is wired to run local, agent‑assisted validation with Ollama.

- Cloud first: set `OLLAMA_CLOUD_URL` to use a cloud endpoint.
- Local fallback: if no cloud is set, scripts start `ollama serve` automatically.

Quick start:

```bash
# Optional: install prerequisites
# brew install ollama swiftlint swiftformat
# ollama pull llama3.1:8b qwen2.5-coder:7b mistral:7b

# Prefer cloud (if available)
export OLLAMA_CLOUD_URL=https://your-cloud-endpoint
make validate

# Or run locally
unset OLLAMA_CLOUD_URL
make validate
```

Scripts:

- `.ci/agent_validate.sh`: sets AI env and runs validation
- `.ci/run_validation.sh`: performs lint/format, tests, and best‑effort remediation via Tools/Automation

## 🔒 Security Best Practices

This repository implements comprehensive security measures to protect your automation infrastructure.

### Automated Security Scanning

The repository includes automated security scanning that runs on every commit and in CI/CD pipelines:

```bash
# Run security audit (pre-commit hook)
./ci_security_gate.sh

# Run full security scan with reports
./ci_security_gate.sh --report-only

# Install security hooks
./setup_security_hooks.sh
```

### Security Features

- **Pre-commit Hooks**: Automatic secret detection and vulnerability scanning
- **CI/CD Security Gates**: Comprehensive security checks before deployment
- **Dependency Scanning**: Automated vulnerability detection in Python packages
- **File Permission Checks**: Ensures sensitive files have proper permissions
- **Backup Security**: Encrypted backups with no sensitive data exposure

### Security Configuration

- **MCP Server**: Bound to localhost only (127.0.0.1:5005)
- **API Keys**: Never stored in code; use environment variables or secure keychain
- **Secrets Management**: Use system keychain or secure environment variables
- **Network Security**: All services configured for local access only

### Best Practices for Contributors

1. **Never commit secrets**: Use `.env` files (gitignored) or secure keychain storage
2. **Run security scans**: Execute `./ci_security_gate.sh` before pushing changes
3. **Review dependencies**: Check for vulnerabilities before adding new packages
4. **Secure file permissions**: Sensitive files should be `chmod 600`
5. **Environment isolation**: Use virtual environments and avoid system-wide installations

### Security Monitoring

- **Automated Alerts**: Security issues trigger notifications via MCP
- **Regular Audits**: Weekly security scans and monthly comprehensive audits
- **Incident Response**: Automated rollback procedures for security incidents
- **Access Control**: Role-based access with audit logging

### Emergency Procedures

If a security issue is detected:

```bash
# Immediate response
./emergency_response.sh

# Rollback to secure state
./rollback.sh

# Security audit
./security_audit.sh
```

**Security is everyone's responsibility.** Report any security concerns immediately.
