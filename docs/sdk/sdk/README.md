# Tools Automation SDKs

Welcome to the Tools Automation SDK documentation! This page provides an overview of our SDK ecosystem and guides for getting started with each SDK.

## Available SDKs

### Python SDK (`mcp-sdk`)

A comprehensive Python SDK for interacting with the MCP (Model Context Protocol) server.

**Installation:**
```bash
pip install mcp-sdk
```

**Features:**
- Synchronous and asynchronous API clients
- Comprehensive error handling
- Type hints and IDE support
- Extensive test coverage

[📖 Python SDK Documentation](./python/) | [📦 PyPI](https://pypi.org/project/mcp-sdk/)

### TypeScript SDK (`@tools-automation/mcp-sdk`)

A full-featured TypeScript SDK for MCP server integration with modern JavaScript/TypeScript applications.

**Installation:**
```bash
npm install @tools-automation/mcp-sdk
```

**Features:**
- Full TypeScript support with type definitions
- Promise-based API
- Browser and Node.js compatibility
- Comprehensive error handling

[📖 TypeScript SDK Documentation](./typescript/) | [📦 npm](https://www.npmjs.com/package/@tools-automation/mcp-sdk)

### Go SDK (`github.com/dboone323/tools-automation/sdk/go`)

A high-performance Go SDK for MCP server communication.

**Installation:**
```bash
go get github.com/dboone323/tools-automation/sdk/go
```

**Features:**
- Idiomatic Go API design
- High performance and low memory footprint
- Context support for cancellation
- Comprehensive error handling

[📖 Go SDK Documentation](./go/) | [📦 Go Modules](https://pkg.go.dev/github.com/dboone323/tools-automation/sdk/go)

## Quick Start

### Python Example

```python
from mcp_sdk import MCPClient

# Initialize client
client = MCPClient(base_url="https://api.tools-automation.com")

# Make a request
response = client.get("/api/v1/tools")
print(response.json())
```

### TypeScript Example

```typescript
import { MCPClient } from '@tools-automation/mcp-sdk';

// Initialize client
const client = new MCPClient({
  baseURL: 'https://api.tools-automation.com'
});

// Make a request
const response = await client.get('/api/v1/tools');
console.log(response.data);
```

### Go Example

```go
package main

import (
    "fmt"
    mcp "github.com/dboone323/tools-automation/sdk/go"
)

func main() {
    client := mcp.NewClient("https://api.tools-automation.com")

    response, err := client.Get("/api/v1/tools")
    if err != nil {
        panic(err)
    }

    fmt.Println(response)
}
```

## Authentication

All SDKs support multiple authentication methods:

- **API Key Authentication**: Pass your API key directly
- **OAuth 2.0**: Use OAuth flows for secure authentication
- **JWT Tokens**: Use JSON Web Tokens for stateless authentication

## Error Handling

All SDKs provide comprehensive error handling:

- **Network Errors**: Automatic retry with exponential backoff
- **API Errors**: Structured error responses with error codes
- **Validation Errors**: Input validation with detailed error messages

## Contributing

We welcome contributions to our SDKs! Please see our [contribution guidelines](../CONTRIBUTING.md) for more information.

## Support

- [GitHub Issues](https://github.com/dboone323/tools-automation/issues)
- [Community Discussions](https://github.com/dboone323/tools-automation/discussions)
- [Documentation](https://docs.tools-automation.com)

## License

All SDKs are licensed under the MIT License. See individual SDK LICENSE files for details.
