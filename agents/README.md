# Agents Directory

This directory contains all automation agents for the `tools-automation` project.

## Directory Structure

```
agents/
├── logs/           # Agent runtime logs (.log, .out, .pid files)
├── status/         # Agent status JSON files (*_status.json)
├── tests/          # Test scripts and temporary test data
├── bin/            # (Reserved for compiled binaries if needed)
├── communication/  # Agent-to-agent communication files
├── backups/        # Agent backup configurations
└── *.sh            # Agent scripts (executable)
```

## Available Agents

### Core Agents
- **agent_codegen.sh**: Code generation and scaffolding
- **agent_build.sh**: Build automation and validation
- **agent_testing.sh**: Test execution and reporting
- **agent_deployment.sh**: Deployment orchestration
- **agent_monitoring.sh**: System health monitoring

### Quality Agents
- **agent_security.sh**: Security scanning and audits
- **code_review_agent.sh**: Automated code review
- **quality_agent.sh**: Code quality enforcement

### Documentation Agents
- **agent_documentation.sh**: Documentation generation
- **knowledge_base_agent.sh**: Knowledge base maintenance

### Orchestration
- **task_orchestrator.sh**: Task scheduling and coordination
- **agent_supervisor.sh**: Agent health management

## Running Agents

### Start an Agent
```bash
cd agents
./agent_codegen.sh
```

### Check Agent Status
```bash
cat agents/status/codegen_status.json
```

### View Agent Logs
```bash
tail -f agents/logs/agent_codegen.log
```

## Agent Development

### Creating a New Agent

1. Create your script in `agents/`
2. Follow naming convention: `agent_<name>.sh` or `<name>_agent.sh`
3. Ensure executable: `chmod +x agents/agent_<name>.sh`
4. Log to `logs/`, status to `status/`
5. Add documentation to this README

### Best Practices

- Use `${REPO_ROOT}` for absolute paths
- Write status to `status/<name>_status.json`
- Write logs to `logs/<name>.log`
- Handle signals (SIGTERM, SIGINT) gracefully
- Implement health checks

## Troubleshooting

### Agent Won't Start
1. Check executable permissions: `ls -l agents/agent_<name>.sh`
2. View recent logs: `tail -n 50 agents/logs/agent_<name>.log`
3. Verify dependencies: `./scripts/verify_agents.sh`

### Status Files Not Updating
1. Check write permissions on `agents/status/`
2. Ensure agent is running: `ps aux | grep agent`
3. Check for lock files: `ls agents/*.lock`

## Maintenance

### Cleanup Old Logs
Use the cleanup script:
```bash
./scripts/cleanup.sh --retention 30 --confirm
```

### Health Check
```bash
./scripts/verify_agents.sh
```

## Related Documentation
- [MCP Integration](../mcp/README.md)
- [Cleanup Policy](../CLEANUP.md)
- [Main README](../README.md)
