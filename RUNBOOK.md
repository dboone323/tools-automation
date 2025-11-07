# 🚀 Autonomous Agent System - Operations Runbook

## System Overview

The Autonomous Agent System is a comprehensive AI-powered development and deployment platform that provides 100% autonomous operation with full safety mechanisms, monitoring, and self-healing capabilities.

**Version:** 1.0.0
**Status:** Production Ready
**Coverage:** 95%+ Swift, 77 Python Tests, Safety Mechanisms Operational

---

## 🏗️ Architecture

### Core Components

1. **MCP Server** (`mcp_server.py`)

   - HTTP-based coordination server
   - Authentication via X-Auth-Token
   - Health endpoints and task queuing
   - Port: 5005 (configurable)

2. **Agent Orchestrator** (`agents/orchestrator_v2.py`)

   - Coordinates 203+ agent scripts
   - Task queue management
   - Failure prediction and recovery
   - Status tracking via `agent_status.json`

3. **Launchd Services** (`com.quantum.mcp.plist`)

   - User-level service orchestration
   - Automatic startup and monitoring
   - Resource limits and error handling

4. **Git Flow Safety** (`git_hooks/post-merge`)

   - Post-merge validation with smoke tests
   - Automatic rollback on test failures
   - Error budget tracking

5. **Test Infrastructure**
   - Swift: XCTest with 95%+ coverage
   - Python: pytest with 77 test files
   - Coverage analysis: `analyze_coverage.sh`

### Safety Mechanisms

- **Circuit Breaker**: Prevents runaway cloud usage (3-failure threshold)
- **Error Budget**: Tracks failure rates with configurable rollback
- **Authentication**: MCP endpoints require X-Auth-Token headers
- **Resource Limits**: CPU/RAM constraints prevent system overload
- **Dependency Coordination**: Graph-based submodule relationship tracking

---

## 🚀 Quick Start

### Prerequisites

```bash
# Required software
- Python 3.8+
- Swift 5.5+
- Ollama (for AI operations)
- Git with hooks enabled

# Required Python packages
pip install flask pytest requests pyyaml

# Required system services
- launchd (macOS service manager)
```

### Installation

```bash
# Clone and setup
git clone <repository>
cd tools-automation
pip install -r requirements.txt

# Start MCP server
python3 mcp_server.py &

# Load launchd services
launchctl load com.quantum.mcp.plist

# Run initial tests
python3 -m pytest tests/ -v
```

### Basic Operation

```bash
# Check system status
curl -H "X-Auth-Token: your-token" http://localhost:5005/health

# Run coverage analysis
./analyze_coverage.sh

# Start agent monitoring
./dashboard_unified.sh

# Execute agent task
python3 agents/run_agent.py --task build --project HabitQuest
```

---

## 📊 Monitoring & Health Checks

### System Health Endpoints

```bash
# Overall health
curl http://localhost:5005/health

# Agent status
curl http://localhost:5005/agents/status

# Task queue
curl http://localhost:5005/tasks/queue

# Coverage report
curl http://localhost:5005/coverage/status
```

### Dashboard Monitoring

```bash
# Unified dashboard (includes all metrics)
./dashboard_unified.sh

# Agent-specific monitoring
./agent_monitoring.sh

# CI/CD monitoring
./ci_cd_monitoring.sh

# Code health dashboard
python3 code_health_dashboard.py
```

### Log Locations

- **Agent Logs**: `logs/agent_*.log`
- **System Logs**: `logs/system.log`
- **Test Results**: `metrics/coverage/`
- **Error Reports**: `logs/errors/`

---

## 🔧 Maintenance Procedures

### Daily Operations

1. **Morning Check**

   ```bash
   # Verify all services running
   launchctl list | grep quantum

   # Check agent status
   cat agent_status.json

   # Run smoke tests
   python3 -m pytest tests/ -k smoke --tb=short
   ```

2. **Coverage Analysis**

   ```bash
   ./analyze_coverage.sh
   # Review coverage_report_*.md
   ```

3. **Log Rotation**
   ```bash
   ./cleanup_all_projects.sh
   ./backup_rotation.sh
   ```

### Weekly Maintenance

1. **Full Test Suite**

   ```bash
   python3 -m pytest tests/ --tb=short -q
   ```

2. **Dependency Updates**

   ```bash
   # Update Python packages
   pip install --upgrade -r requirements.txt

   # Update Swift packages
   cd Projects/* && swift package update
   ```

3. **Performance Optimization**
   ```bash
   ./build_performance_optimizer.sh
   ```

### Monthly Maintenance

1. **Archive Old Logs**

   ```bash
   ./cleanup_ai_analysis.sh
   ./audit_large_files.sh
   ```

2. **Security Audit**

   ```bash
   ./check_secret_scanning.sh
   ./security/audit_security.sh
   ```

3. **System Validation**
   ```bash
   ./comprehensive_test_generator.sh
   ./validate_system_integrity.sh
   ```

---

## 🚨 Troubleshooting

### Common Issues

#### MCP Server Not Starting

```bash
# Check port availability
lsof -i :5005

# Kill conflicting processes
pkill -f mcp_server

# Start with debug logging
python3 mcp_server.py --debug
```

#### Agent Failures

```bash
# Check agent status
cat agent_status.json

# View agent logs
tail -f logs/agent_*.log

# Restart failed agents
python3 agents/agent_recovery.py --agent <failed_agent>
```

#### Test Failures

```bash
# Run specific failing test
python3 -m pytest tests/test_<failing_test>.py -v

# Check syntax errors
python3 -m py_compile <failing_file>.py

# Regenerate test stubs
python3 generate_missing_tests.py
```

#### Git Hook Issues

```bash
# Verify hooks are executable
ls -la .git/hooks/post-merge

# Test hook manually
.git/hooks/post-merge

# Reinstall hooks
./install_git_hooks.sh
```

### Emergency Procedures

#### System Lockup

```bash
# Emergency stop all agents
pkill -f "agent_.*\.sh"

# Reset agent status
echo '{}' > agent_status.json

# Clear task queue
echo '[]' > task_queue.json

# Restart MCP server
python3 mcp_server.py &
```

#### Data Corruption

```bash
# Restore from backup
./backup_rotation.sh --restore latest

# Validate system integrity
./check_architecture.py

# Rebuild dependency graph
python3 agents/dependency_graph_agent.py
```

#### Security Breach

```bash
# Immediate isolation
pkill -f quantum
launchctl unload com.quantum.mcp.plist

# Security audit
./check_secret_scanning.sh --full

# Log analysis
./agents/ai_log_analyzer.py --security

# System rebuild if compromised
./bootstrap_meta_repo.sh
```

---

## 📈 Performance Tuning

### Resource Optimization

```bash
# CPU/Memory monitoring
./performance_monitor.sh

# Build optimization
./build_performance_optimizer.sh

# Cache management
./cleanup_duplicate_references.py
```

### Scaling Configuration

```yaml
# config/agent_config.json
{
  "max_concurrent_agents": 10,
  "cpu_limit": 80,
  "memory_limit": "2GB",
  "timeout_seconds": 300,
}
```

### Network Optimization

```bash
# Connection pooling
export MCP_CONNECTION_POOL=5

# Timeout configuration
export HTTP_TIMEOUT=30

# Retry logic
export MAX_RETRIES=3
```

---

## 🔒 Security

### Authentication

- MCP endpoints require `X-Auth-Token` header
- Tokens stored securely via Keychain
- Automatic token rotation every 24 hours

### Access Control

```bash
# View current permissions
security find-generic-password -l quantum-auth

# Rotate authentication token
./security/rotate_tokens.sh

# Audit access logs
./security/audit_access.sh
```

### Encryption

- All sensitive data encrypted at rest
- TLS 1.3 for network communications
- AES-256 for file encryption

---

## 📚 API Reference

### MCP Server Endpoints

| Endpoint             | Method   | Description           |
| -------------------- | -------- | --------------------- |
| `/health`            | GET      | System health check   |
| `/agents/status`     | GET      | Agent status overview |
| `/tasks/queue`       | GET/POST | Task queue management |
| `/coverage/status`   | GET      | Test coverage report  |
| `/metrics/dashboard` | GET      | Performance metrics   |

### Agent Commands

```bash
# List available agents
python3 agents/list_agents.py

# Run specific agent
python3 agents/run_agent.py --agent <name> --params <json>

# Monitor agent execution
python3 agents/monitor_agent.py --agent <name> --follow
```

### Configuration Files

- `agent_config.json` - Agent behavior settings
- `alert_config.json` - Monitoring alerts
- `com.quantum.mcp.plist` - Service configuration
- `task_queue.json` - Active tasks
- `agent_status.json` - Agent health status

---

## 🎯 Best Practices

### Development

1. **Always run tests before committing**

   ```bash
   python3 -m pytest tests/ --tb=short
   ```

2. **Check coverage after changes**

   ```bash
   ./analyze_coverage.sh
   ```

3. **Use agent orchestrator for complex tasks**
   ```bash
   python3 agents/orchestrator_v2.py --task <complex_task>
   ```

### Operations

1. **Monitor system health continuously**
2. **Review logs daily for anomalies**
3. **Keep dependencies updated**
4. **Test backups regularly**
5. **Document all changes**

### Security

1. **Rotate authentication tokens regularly**
2. **Audit access logs weekly**
3. **Keep security patches current**
4. **Monitor for unusual activity**
5. **Use principle of least privilege**

---

## 📞 Support

### Emergency Contacts

- **System Admin**: [Contact Information]
- **Security Team**: [Contact Information]
- **Development Team**: [Contact Information]

### Escalation Procedures

1. **Level 1**: Check runbook and logs
2. **Level 2**: Contact on-call engineer
3. **Level 3**: Escalate to development team
4. **Level 4**: Emergency shutdown and investigation

### Documentation Updates

This runbook is maintained in the repository at `RUNBOOK.md`. Updates should be:

1. Reviewed by development team
2. Tested in staging environment
3. Approved by security team
4. Deployed with change documentation

---

**Last Updated:** November 6, 2025
**Version:** 1.0.0
**Status:** Production Ready
