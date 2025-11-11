# MCP (Model Context Protocol) Servers

Centralized MCP server infrastructure for tools-automation and all submodules.

## Overview

This directory contains all MCP servers, configurations, and related infrastructure for integrating with AI assistants and language models across the entire project ecosystem.

## Structure

```
mcp/
├── mcp_config.json           # Primary MCP configuration
├── mcp_workflow.sh           # MCP workflow orchestration
├── mcp_controller.py         # Python MCP controller
├── mcp_dashboard_flask.py    # Web dashboard for monitoring
├── mcp_dashboard.sh          # Dashboard launcher
├── mcp_server_venv.sh        # Virtual environment setup
├── mcp_client.sh             # MCP client utilities
├── simple_mcp_check.sh       # Health check script
├── mcp_github_get_job_logs.sh # GitHub integration
└── servers/                  # MCP server implementations
    ├── start_mcp_server.sh
    ├── mcp_client.sh
    └── run_mcp_server.sh
```

## Configuration

### Primary Config
The main configuration file is `mcp_config.json` which defines:
- Server endpoints
- Authentication settings
- Model configurations
- Integration points

### Submodule Overrides
Each submodule can provide project-specific overrides in:
```
<submodule>/.tools-automation/mcp_config.json
```

Priority order:
1. Submodule-specific config (if exists)
2. Global config (this directory)

## Usage

### Starting MCP Server
```bash
cd /path/to/tools-automation/mcp
./servers/start_mcp_server.sh
```

### Running Workflows
```bash
./mcp_workflow.sh --check-config
./mcp_workflow.sh --run
```

### Monitoring
```bash
# Launch dashboard
./mcp_dashboard.sh

# Check health
./simple_mcp_check.sh

# View status via Python controller
python3 mcp_controller.py --status
```

## MCP Servers

### Available Servers
- **start_mcp_server.sh**: Main server launcher
- **run_mcp_server.sh**: Server runtime handler
- **mcp_client.sh**: Client connection utilities

### Server Features
- Context management for AI assistants
- Code analysis integration
- Project knowledge base
- Task automation hooks
- Real-time monitoring

## Integration with Agents

Agents can interact with MCP servers for:
- **Code Generation**: `agent_codegen.sh` uses MCP for AI-assisted code generation
- **Debugging**: `agent_debug.sh` leverages MCP for intelligent debugging suggestions
- **Documentation**: `agent_documentation.sh` generates docs with MCP assistance
- **Analysis**: Various agents use MCP for code quality and security analysis

## Dashboard

The Flask-based dashboard provides:
- Server status monitoring
- Request/response logs
- Performance metrics
- Configuration management

Access dashboard at: `http://localhost:5000` (default)

## Environment Setup

### Python Dependencies
```bash
# Setup virtual environment
./mcp_server_venv.sh

# Activate venv
source venv/bin/activate

# Run controller
python3 mcp_controller.py
```

### Configuration
Set environment variables:
```bash
export MCP_CONFIG_PATH="/path/to/mcp_config.json"
export MCP_SERVER_PORT=8080
export MCP_LOG_LEVEL=INFO
```

## Submodule Usage

From any submodule:
```bash
# Use shared MCP config
export TOOLS_AUTOMATION_ROOT="/path/to/tools-automation"
MCP_CONFIG="$TOOLS_AUTOMATION_ROOT/mcp/mcp_config.json"

# Override with project-specific config if needed
if [ -f ".tools-automation/mcp_config.json" ]; then
    MCP_CONFIG=".tools-automation/mcp_config.json"
fi

# Start MCP workflow
"$TOOLS_AUTOMATION_ROOT/mcp/mcp_workflow.sh"
```

## Workflows

### Check Configuration
```bash
./mcp_workflow.sh --check-config
```

### Run Standard Workflow
```bash
./mcp_workflow.sh --run
```

### GitHub Integration
```bash
./mcp_github_get_job_logs.sh <job-id>
```

## Troubleshooting

### Server Won't Start
1. Check Python dependencies: `pip list | grep flask`
2. Verify port availability: `lsof -i :8080`
3. Check logs: `tail -f /tmp/mcp_server.log`

### Connection Issues
1. Verify `mcp_config.json` syntax: `python3 -m json.tool mcp_config.json`
2. Check network connectivity
3. Ensure firewall allows port

### Configuration Not Loading
1. Check file permissions: `ls -la mcp_config.json`
2. Validate JSON: `jq . mcp_config.json`
3. Check override priority (submodule vs global)

## Security

### Best Practices
- Keep `mcp_config.json` out of version control if it contains secrets
- Use environment variables for sensitive data
- Limit server access to localhost in production
- Enable authentication for remote access

### Authentication
Configure in `mcp_config.json`:
```json
{
  "auth": {
    "enabled": true,
    "method": "token",
    "token_file": "/path/to/secure/token"
  }
}
```

## Performance

### Optimization Tips
- Use connection pooling for multiple requests
- Enable caching for repeated queries
- Monitor resource usage via dashboard
- Scale horizontally for high load

### Monitoring
```bash
# Check resource usage
ps aux | grep mcp
top -pid $(pgrep -f mcp_controller)

# View logs
tail -f /tmp/mcp_server.log
```

## Related Directories

- `../agents/` - Agent scripts that use MCP
- `../workflows/` - CI/CD workflows with MCP integration
- `../config/` - Shared configuration files
- `../docs/` - Documentation

## Migration Notes

This centralized MCP structure was created on 2025-11-11. Previously, MCP files were scattered across the repository root and submodules. All files are now consolidated here for easier maintenance and consistent configuration.

## Further Reading

- Model Context Protocol specification: https://modelcontextprotocol.io/
- Flask documentation: https://flask.palletsprojects.com/
- See `../docs/REPOSITORY_REORGANIZATION_PLAN.md` for details
