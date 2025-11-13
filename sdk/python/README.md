# MCP Python SDK

A comprehensive Python SDK for interacting with the MCP (Model Context Protocol) server.

## Features

- **Full API Coverage**: Complete access to all MCP server endpoints
- **Async/Await Support**: Non-blocking operations with asyncio
- **Automatic Retry Logic**: Built-in error handling and retries
- **Type Hints**: Full type annotations for better IDE support
- **Connection Pooling**: Efficient session management
- **CLI Interface**: Command-line tools for quick operations

## Installation

```bash
pip install mcp-sdk
# or
pip install -e .
```

## Quick Start

### Async Usage

```python
import asyncio
from mcp_sdk import MCPClient

async def main():
    async with MCPClient(base_url="http://localhost:5005") as client:
        # Get server status
        status = await client.get_status()
        print(f"Server status: {status.data}")

        # List available agents
        agents = await client.list_controllers()
        print(f"Available agents: {agents.data}")

        # Submit a task
        task = await client.submit_task({
            "type": "code_analysis",
            "target": "my_script.py"
        })
        print(f"Task submitted: {task.data}")

asyncio.run(main())
```

### Synchronous Usage

```python
from mcp_sdk import quick_status_check_sync

# Quick status check
status = quick_status_check_sync()
print(f"Server is {'healthy' if status.get('healthy') else 'unhealthy'}")
```

## API Reference

### Core Client

#### `MCPClient(base_url="http://localhost:5005", timeout=30.0, max_retries=3)`

Main client class for MCP server interaction.

**Methods:**

- `get_status()` - Get server status
- `get_health()` - Get server health
- `list_controllers()` - List available agents/controllers
- `get_agent_status(agent_name)` - Get specific agent status
- `register_agent(name, capabilities)` - Register new agent
- `submit_task(task_data)` - Submit task for processing
- `get_task_status(task_id)` - Get task status
- `list_tasks(status=None, limit=50)` - List tasks with filtering
- `cancel_task(task_id)` - Cancel running task

### AI Features

- `analyze_code(code, language="python")` - AI-powered code analysis
- `predict_performance(metrics)` - Performance prediction
- `generate_code(description, language="python")` - Code generation

### Webhook Management

- `register_webhook(url, events)` - Register webhook
- `list_webhooks()` - List registered webhooks
- `delete_webhook(webhook_id)` - Delete webhook

### Plugin Management

- `list_plugins()` - List available plugins
- `get_plugin_info(plugin_name)` - Get plugin details
- `install_plugin(plugin_name, config=None)` - Install plugin

## CLI Usage

```bash
# Check server status
mcp-cli --status

# List available agents
mcp-cli --agents

# List recent tasks
mcp-cli --tasks

# Specify custom server URL
mcp-cli --base-url http://my-mcp-server:5005 --status
```

## Error Handling

The SDK provides comprehensive error handling:

```python
from mcp_sdk import MCPClient, MCPError, MCPConnectionError, MCPTimeoutError

async def safe_operation():
    try:
        async with MCPClient() as client:
            result = await client.get_status()
            return result.data
    except MCPConnectionError:
        print("Connection failed - check server URL")
    except MCPTimeoutError:
        print("Request timed out - try again later")
    except MCPError as e:
        print(f"MCP error: {e}")
```

## Configuration

### Environment Variables

- `MCP_BASE_URL` - Default server URL (default: http://localhost:5005)
- `MCP_TIMEOUT` - Request timeout in seconds (default: 30.0)
- `MCP_MAX_RETRIES` - Maximum retry attempts (default: 3)

### Client Configuration

```python
client = MCPClient(
    base_url="http://custom-server:5005",
    timeout=60.0,
    max_retries=5,
    retry_delay=2.0
)
```

## Development

### Setup Development Environment

```bash
git clone https://github.com/dboone323/tools-automation.git
cd tools-automation/sdk/python
pip install -e ".[dev]"
```

### Run Tests

```bash
pytest
```

### Code Quality

```bash
black mcp_sdk/
isort mcp_sdk/
mypy mcp_sdk/
flake8 mcp_sdk/
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/dboone323/tools-automation/issues)
- **Documentation**: [Full API Docs](https://github.com/dboone323/tools-automation/docs)
- **Discussions**: [GitHub Discussions](https://github.com/dboone323/tools-automation/discussions)
