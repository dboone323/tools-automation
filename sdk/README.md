# Tools Automation SDK Ecosystem

A comprehensive multi-language SDK ecosystem for the Tools Automation MCP (Model Context Protocol) server, providing developers with powerful APIs to interact with automated agents, manage tasks, and leverage AI capabilities.

## 🚀 Quick Start

Choose your preferred language:

### Python

```bash
pip install mcp-sdk
```

```python
import asyncio
from mcp_sdk import MCPClient

async def main():
    async with MCPClient() as client:
        status = await client.get_status()
        print(f"Server status: {status.data}")

asyncio.run(main())
```

### TypeScript

```bash
npm install @tools-automation/mcp-sdk
```

```typescript
import { MCPClient } from "@tools-automation/mcp-sdk";

const client = new MCPClient();

async function main() {
  const status = await client.getStatus();
  console.log("Server status:", status.data);
}

main();
```

### Go

```bash
go get github.com/dboone323/tools-automation/sdk/go
```

```go
package main

import (
    "context"
    "fmt"
    "github.com/dboone323/tools-automation/sdk/go/mcp"
)

func main() {
    client := mcp.NewClient("http://localhost:5005", nil)
    status, err := client.GetStatus(context.Background())
    if err != nil {
        panic(err)
    }
    fmt.Printf("Server status: %+v\n", status)
}
```

## 📚 SDK Overview

### Core Features

- **Full API Coverage**: Complete access to all MCP server endpoints
- **Multi-Language Support**: Python, TypeScript, and Go implementations
- **Async/Await Support**: Non-blocking operations where applicable
- **Automatic Retry Logic**: Built-in error handling and connection recovery
- **Type Safety**: Strong typing with language-specific type systems
- **Comprehensive Testing**: Full test coverage for all SDKs

### Supported Operations

#### Server Management

- Server status and health checks
- Configuration management
- System monitoring

#### Agent Management

- List available agents/controllers
- Get agent status and capabilities
- Register new agents
- Monitor agent health

#### Task Management

- Submit tasks for processing
- Track task status and progress
- Cancel running tasks
- Task history and analytics

#### AI Features

- Code analysis and suggestions
- Performance prediction
- Code generation from descriptions
- AI-powered automation

#### Plugin System

- List available plugins
- Install/uninstall plugins
- Plugin configuration
- Plugin status monitoring

#### Webhook Integration

- Register webhooks for events
- Manage webhook subscriptions
- Event-driven automation

## 🏗️ Architecture

```
Tools Automation Ecosystem
├── MCP Server (Python/Flask)
├── SDK Ecosystem
│   ├── Python SDK (asyncio + aiohttp)
│   ├── TypeScript SDK (axios + promises)
│   └── Go SDK (resty + goroutines)
├── Agent System
├── Plugin Framework
└── Monitoring & Analytics
```

## 📖 Language-Specific Documentation

### [Python SDK](./python/README.md)

- Async/await support with asyncio
- Comprehensive type hints
- CLI interface included
- Extensive testing with pytest

### [TypeScript SDK](./typescript/README.md)

- Promise-based async operations
- Full TypeScript type definitions
- Axios-based HTTP client
- Jest testing framework

### [Go SDK](./go/README.md)

- Context-aware operations
- Go-native error handling
- Comprehensive struct definitions
- Go testing framework

## 🛠️ Development

### Building All SDKs

```bash
# Python
cd sdk/python
pip install -e ".[dev]"
pytest

# TypeScript
cd sdk/typescript
npm install
npm run build
npm test

# Go
cd sdk/go
go mod tidy
go test ./...
```

### Contributing

1. Choose your preferred language SDK
2. Follow the language-specific contribution guidelines
3. Ensure all tests pass
4. Submit a pull request

## 📋 API Compatibility

All SDKs maintain API compatibility across languages:

| Feature          | Python | TypeScript | Go   |
| ---------------- | ------ | ---------- | ---- |
| Server Status    | ✅     | ✅         | ✅   |
| Agent Management | ✅     | ✅         | ✅   |
| Task Operations  | ✅     | ✅         | ✅   |
| AI Features      | ✅     | ✅         | ✅   |
| Plugin System    | ✅     | ✅         | ✅   |
| Webhooks         | ✅     | ✅         | ✅   |
| Async Support    | ✅     | ✅         | ❌\* |

\*Go uses goroutines and channels for concurrency

## 🔧 Configuration

### Environment Variables

```bash
# Common across all SDKs
MCP_BASE_URL=http://localhost:5005
MCP_TIMEOUT=30
MCP_MAX_RETRIES=3
```

### Client Configuration

Each SDK provides flexible configuration options for timeouts, retries, and custom headers.

## 📊 Performance

- **Python SDK**: Optimized for high-throughput async operations
- **TypeScript SDK**: Browser and Node.js compatible
- **Go SDK**: High-performance concurrent operations

## 🧪 Testing

All SDKs include comprehensive test suites:

- Unit tests for all methods
- Integration tests with mock servers
- Error handling and edge case coverage
- Performance benchmarks

## 📄 License

MIT License - see individual SDK LICENSE files for details.

## 🤝 Support

- **Documentation**: [SDK Documentation](./docs/)
- **Issues**: [GitHub Issues](https://github.com/dboone323/tools-automation/issues)
- **Discussions**: [GitHub Discussions](https://github.com/dboone323/tools-automation/discussions)

---

_Built for the Tools Automation ecosystem - empowering developers with intelligent automation tools._</content>
<parameter name="filePath">/Users/danielstevens/Desktop/github-projects/tools-automation/sdk/README.md
