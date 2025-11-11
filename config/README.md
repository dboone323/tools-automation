# Configuration Files

Centralized configuration for tools-automation agent system and workflows.

## Overview

This directory contains shared configuration files used by agents, workflows, and MCP servers across all projects.

## Configuration Files

### Agent System

- **agent_status.json**: Tracks current status of all running agents (running, idle, busy, crashed)
- **task_queue.json**: Queue of tasks for agents to process
- **agent_assignments.json**: Mapping of TODO items to agents (66,972 assignments)

### Automation

- **automation_config.yaml**: General automation settings
- **deployment_config.json**: Deployment pipeline configuration
- **monitoring_config.json**: Monitoring and alerting settings
- **audit_config.json**: Audit logging configuration

### Security

- **security.yaml**: Security policies and settings
- **security_monitoring.json**: Security monitoring rules
- **encryption_config.json**: Encryption settings

### Reliability

- **alerting.yaml**: Alert definitions and thresholds
- **error_recovery.yaml**: Error recovery strategies
- **integration_testing.yaml**: Integration test configuration

### Cloud

- **cloud_fallback_config.json**: Cloud backup and fallback settings

### Code Quality

- **UNIFIED_EDITORCONFIG_ROOT**: EditorConfig settings for all projects
- **UNIFIED_SWIFTFORMAT_ROOT**: Swift formatting rules
- **UNIFIED_SWIFTLINT_ROOT.yml**: Swift linting configuration

### Projects

- **projects/**: Project-specific configurations

## Usage

### From Agents

Agents access config via `agent_config.sh`:

```bash
source agents/agent_config.sh
# STATUS_FILE points to config/agent_status.json
# TASK_QUEUE points to config/task_queue.json
```

### From Workflows

Workflows reference configs:

```bash
CONFIG_DIR="/path/to/tools-automation/config"
source "$CONFIG_DIR/automation_config.yaml"
```

### From Submodules

```bash
export TOOLS_AUTOMATION_ROOT="/path/to/tools-automation"
CONFIG_PATH="$TOOLS_AUTOMATION_ROOT/config/automation_config.yaml"
```

## Key Files

### agent_status.json

Tracks agent state:

```json
{
  "agent_build": {
    "status": "running",
    "pid": 12345,
    "last_update": "2025-11-11T07:30:00Z"
  }
}
```

### task_queue.json

Manages task queue:

```json
{
  "tasks": [
    {
      "id": "task_001",
      "type": "build",
      "status": "pending",
      "assigned_to": "agent_build.sh"
    }
  ]
}
```

### agent_assignments.json

Maps TODOs to agents (66,972 entries):

```json
{
  "todo_001": {
    "agent": "agent_codegen.sh",
    "priority": "high",
    "file": "src/main.swift"
  }
}
```

## Path Resolution

Configuration files are accessed relative to the agents directory:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_FILE="${SCRIPT_DIR}/../config/agent_status.json"
TASK_QUEUE="${SCRIPT_DIR}/../config/task_queue.json"
```

## Configuration Priority

1. **Environment variables** (highest priority)
2. **Agent-specific overrides** in `agent_config.sh`
3. **Global defaults** in this directory
4. **Hardcoded fallbacks** (lowest priority)

## Maintenance

### Backing Up Configurations

```bash
cp -r config/ config.backup.$(date +%Y%m%d)
```

### Validating Configs

```bash
# Validate JSON
jq . config/agent_status.json
jq . config/task_queue.json

# Validate YAML
yamllint config/automation_config.yaml
```

### Cleaning Up

```bash
# Remove old task queue entries
jq '.tasks |= map(select(.status != "completed"))' task_queue.json > task_queue.tmp.json
mv task_queue.tmp.json task_queue.json
```

## Security

### Sensitive Data

- Do NOT commit secrets or tokens to this directory
- Use environment variables for sensitive values
- Keep `.env` files out of git
- Use encrypted config files when needed

### Permissions

```bash
# Protect sensitive configs
chmod 600 config/encryption_config.json
chmod 600 config/security_monitoring.json
```

## Monitoring

Check configuration health:

```bash
# Verify files exist
ls -la config/*.json config/*.yaml

# Check file sizes (detect corruption)
du -sh config/*

# Monitor changes
watch -n 5 'ls -lt config/*.json | head'
```

## Related Directories

- `../agents/` - Agent scripts that use these configs
- `../workflows/` - Workflow scripts that reference configs
- `../mcp/` - MCP servers with config integration
- `../docs/` - Documentation

## Migration Notes

Configuration files were moved here on 2025-11-11 from the root directory to create a centralized config location. All agent and workflow scripts have been updated to use the new paths.

**Benefits:**

- Centralized configuration management
- Easier to backup and restore
- Clear separation from code
- Consistent access patterns
