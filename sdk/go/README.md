# MCP Go SDK

A comprehensive Go SDK for interacting with the MCP (Model Context Protocol) server.

## Features

- **Full Go Support**: Complete type safety and idiomatic Go patterns
- **Context Support**: Proper context handling for cancellation and timeouts
- **Automatic Retry Logic**: Built-in error handling and exponential backoff
- **Resty Integration**: Robust HTTP client with interceptors
- **Comprehensive Error Handling**: Custom error types for different failure modes
- **Full API Coverage**: Access to all MCP server endpoints

## Installation

```bash
go get github.com/dboone323/tools-automation/sdk/go
```

## Quick Start

### Basic Usage

```go
package main

import (
    "context"
    "fmt"
    "log"

    mcp "github.com/dboone323/tools-automation/sdk/go"
)

func main() {
    client := mcp.NewClient("http://localhost:5005", nil)

    // Get server status
    status, err := client.GetStatus(context.Background())
    if err != nil {
        log.Fatal(err)
    }
    fmt.Printf("Server status: %s\n", status.Data.Status)

    // List available agents
    agents, err := client.ListControllers(context.Background())
    if err != nil {
        log.Fatal(err)
    }
    fmt.Printf("Available agents: %+v\n", agents.Data)
}
```

### Advanced Usage with Error Handling

```go
package main

import (
    "context"
    "fmt"
    "log"

    mcp "github.com/dboone323/tools-automation/sdk/go"
)

func safeOperation() {
    client := mcp.NewClient("http://localhost:5005", &mcp.ClientOptions{
        Timeout:    60 * time.Second,
        MaxRetries: 5,
        RetryDelay: 2 * time.Second,
    })

    // Submit a task
    task, err := client.SubmitTask(context.Background(), mcp.TaskSubmission{
        Type:     "code_analysis",
        Target:   "src/main.go",
        Priority: "high",
        Parameters: map[string]interface{}{
            "includeMetrics": true,
            "outputFormat":   "json",
        },
    })
    if err != nil {
        if mcpErr, ok := err.(mcp.MCPError); ok {
            log.Printf("MCP error (%d): %s", mcpErr.StatusCode, mcpErr.Message)
        } else if connErr, ok := err.(mcp.ConnectionError); ok {
            log.Printf("Connection failed: %v", connErr.Err)
        } else {
            log.Printf("Unexpected error: %v", err)
        }
        return
    }

    fmt.Printf("Task submitted: %s\n", task.Data.ID)

    // Check task status
    status, err := client.GetTaskStatus(context.Background(), task.Data.ID)
    if err != nil {
        log.Fatal(err)
    }
    fmt.Printf("Task status: %s\n", status.Data.Status)
}
```

## API Reference

### Core Client

#### `NewClient(baseURL, opts)`

Creates a new MCP client.

**Parameters:**

- `baseURL` (string): Server base URL
- `opts` (\*ClientOptions): Client configuration (optional)

**Returns:** `*Client`

#### `DefaultClientOptions()`

Returns default client options.

**Returns:** `*ClientOptions`

### ClientOptions

Configuration options for the MCP client:

```go
type ClientOptions struct {
    Timeout    time.Duration      // Request timeout (default: 30s)
    MaxRetries int               // Maximum retry attempts (default: 3)
    RetryDelay time.Duration     // Base retry delay (default: 1s)
    Headers    map[string]string // Additional headers
}
```

### Status & Health

- `GetStatus(ctx)` - Get server status
- `GetHealth(ctx)` - Get server health check

### Agent Management

- `ListControllers(ctx)` - List all available agents
- `GetAgentStatus(ctx, agentName)` - Get specific agent status
- `RegisterAgent(ctx, name, capabilities)` - Register new agent

### Task Management

- `SubmitTask(ctx, task)` - Submit task for processing
- `GetTaskStatus(ctx, taskId)` - Get task status
- `ListTasks(ctx, status, agent)` - List tasks with filtering
- `CancelTask(ctx, taskId)` - Cancel running task

### AI Features

- `AnalyzeCode(ctx, req)` - AI-powered code analysis
- `PredictPerformance(ctx, metrics)` - Performance prediction
- `GenerateCode(ctx, req)` - Code generation from description

### Webhook Management

- `RegisterWebhook(ctx, registration)` - Register webhook for events
- `ListWebhooks(ctx)` - List registered webhooks
- `DeleteWebhook(ctx, webhookId)` - Delete webhook

### Plugin Management

- `ListPlugins(ctx)` - List available plugins
- `GetPluginInfo(ctx, pluginName)` - Get plugin details
- `InstallPlugin(ctx, pluginName, config)` - Install plugin
- `UninstallPlugin(ctx, pluginName)` - Uninstall plugin

## Type Definitions

### Core Types

```go
type Response[T any] struct {
    Success      bool   `json:"success"`
    Data         T      `json:"data,omitempty"`
    Error        string `json:"error,omitempty"`
    StatusCode   int    `json:"statusCode"`
    ResponseTime int64  `json:"responseTime"`
}

type ServerStatus struct {
    Status      string    `json:"status"`
    Version     string    `json:"version,omitempty"`
    Uptime      int64     `json:"uptime,omitempty"`
    LastChecked time.Time `json:"lastChecked,omitempty"`
}

type AgentStatus struct {
    Name          string   `json:"name"`
    Status        string   `json:"status"`
    LastSeen      string   `json:"lastSeen"`
    HealthScore   float64  `json:"healthScore"`
    Capabilities  []string `json:"capabilities"`
    ActiveTasks   int      `json:"activeTasks,omitempty"`
    TotalTasks    int      `json:"totalTasks,omitempty"`
}

type TaskInfo struct {
    ID          string                 `json:"id"`
    Status      string                 `json:"status"`
    Type        string                 `json:"type"`
    Agent       string                 `json:"agent"`
    CreatedAt   string                 `json:"createdAt"`
    CompletedAt string                 `json:"completedAt,omitempty"`
    Result      map[string]interface{} `json:"result,omitempty"`
    Error       string                 `json:"error,omitempty"`
    Priority    string                 `json:"priority,omitempty"`
    Progress    float64                `json:"progress,omitempty"`
}
```

### Task Submission

```go
type TaskSubmission struct {
    Type       string                 `json:"type"`
    Target     string                 `json:"target,omitempty"`
    Parameters map[string]interface{} `json:"parameters,omitempty"`
    Priority   string                 `json:"priority,omitempty"`
    Agent      string                 `json:"agent,omitempty"`
}
```

### AI Requests

```go
type CodeAnalysisRequest struct {
    Code     string            `json:"code"`
    Language string            `json:"language,omitempty"`
    Options  map[string]bool   `json:"options,omitempty"`
    Context  map[string]string `json:"context,omitempty"`
}

type CodeGenerationRequest struct {
    Description string   `json:"description"`
    Language    string   `json:"language,omitempty"`
    Context     string   `json:"context,omitempty"`
    Constraints []string `json:"constraints,omitempty"`
}
```

## Error Handling

The SDK provides specific error types:

- `MCPError` - MCP API error with status code
- `ConnectionError` - Connection/network error

```go
task, err := client.SubmitTask(ctx, taskSubmission)
if err != nil {
    switch e := err.(type) {
    case mcp.MCPError:
        // Handle API errors
        fmt.Printf("MCP error (%d): %s\n", e.StatusCode, e.Message)
    case mcp.ConnectionError:
        // Handle connection issues
        fmt.Printf("Connection failed: %v\n", e.Err)
    default:
        // Handle other errors
        fmt.Printf("Unexpected error: %v\n", err)
    }
}
```

## Configuration

### Environment Variables

```bash
export MCP_BASE_URL=http://my-server:5005
export MCP_TIMEOUT=60s
```

### Client Configuration

```go
client := mcp.NewClient("http://localhost:5005", &mcp.ClientOptions{
    Timeout:    60 * time.Second,      // 60 second timeout
    MaxRetries: 5,                     // Retry up to 5 times
    RetryDelay: 2 * time.Second,       // Start with 2 second delay
    Headers: map[string]string{
        "Authorization": "Bearer token123",
    },
})
```

## Examples

### Task Management

```go
// Submit a code analysis task
task, err := client.SubmitTask(context.Background(), mcp.TaskSubmission{
    Type:     "code_analysis",
    Target:   "src/app.go",
    Priority: "high",
    Parameters: map[string]interface{}{
        "includeMetrics": true,
        "outputFormat":   "json",
    },
})
if err != nil {
    log.Fatal(err)
}

// Monitor task progress
for {
    status, err := client.GetTaskStatus(context.Background(), task.Data.ID)
    if err != nil {
        log.Fatal(err)
    }

    fmt.Printf("Task status: %s (%.1f%%)\n", status.Data.Status, status.Data.Progress)

    if status.Data.Status == "completed" || status.Data.Status == "failed" {
        break
    }

    time.Sleep(1 * time.Second)
}

fmt.Printf("Task completed: %+v\n", status.Data.Result)
```

### AI Integration

```go
// Analyze code
analysis, err := client.AnalyzeCode(context.Background(), mcp.CodeAnalysisRequest{
    Code:     "func add(a, b int) int { return a + b }",
    Language: "go",
    Options: map[string]bool{
        "includeSuggestions": true,
        "includeMetrics":    true,
    },
})
if err != nil {
    log.Fatal(err)
}

// Generate code
generation, err := client.GenerateCode(context.Background(), mcp.CodeGenerationRequest{
    Description: "Create a REST API handler for user authentication",
    Language:    "go",
    Context:     "Gin web framework application",
    Constraints: []string{
        "Use proper error handling",
        "Include input validation",
        "Return JSON responses",
    },
})
if err != nil {
    log.Fatal(err)
}
```

### Webhook Management

```go
// Register webhook for task completion events
webhook, err := client.RegisterWebhook(context.Background(), mcp.WebhookRegistration{
    URL:    "https://my-app.com/webhooks/mcp",
    Events: []string{"task.completed", "task.failed"},
    Secret: "webhook-secret-key",
})
if err != nil {
    log.Fatal(err)
}

// List active webhooks
webhooks, err := client.ListWebhooks(context.Background())
if err != nil {
    log.Fatal(err)
}
fmt.Printf("Active webhooks: %+v\n", webhooks.Data)
```

## Development

### Setup

```bash
go mod download
go build ./...
```

### Testing

```bash
go test ./...
```

### Code Quality

```bash
go fmt ./...
go vet ./...
golint ./...
```

## Examples Directory

See the `examples/` directory for complete usage examples:

- `basic_usage.go` - Basic client usage
- `task_management.go` - Task submission and monitoring
- `ai_integration.go` - AI-powered features
- `webhook_management.go` - Webhook registration and management

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run the test suite: `go test ./...`
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/dboone323/tools-automation/issues)
- **Documentation**: [API Docs](https://github.com/dboone323/tools-automation/docs)
- **Discussions**: [GitHub Discussions](https://github.com/dboone323/tools-automation/discussions)
