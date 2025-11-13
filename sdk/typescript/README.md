# MCP TypeScript SDK

A comprehensive TypeScript SDK for interacting with the MCP (Model Context Protocol) server.

## Features

- **Full TypeScript Support**: Complete type definitions and IntelliSense
- **Promise-Based API**: Modern async/await operations
- **Automatic Retry Logic**: Built-in error handling and exponential backoff
- **Axios Integration**: Robust HTTP client with interceptors
- **Comprehensive Error Handling**: Custom error types for different failure modes
- **Full API Coverage**: Access to all MCP server endpoints

## Installation

```bash
npm install @tools-automation/mcp-sdk
# or
yarn add @tools-automation/mcp-sdk
```

## Quick Start

### Basic Usage

```typescript
import { MCPClient } from '@tools-automation/mcp-sdk';

const client = new MCPClient('http://localhost:5005');

// Get server status
const status = await client.getStatus();
console.log('Server status:', status.data);

// List available agents
const agents = await client.listControllers();
console.log('Available agents:', agents.data);
```

### Advanced Usage with Error Handling

```typescript
import { MCPClient, MCPError, MCPConnectionError } from '@tools-automation/mcp-sdk';

async function safeOperation() {
  const client = new MCPClient('http://localhost:5005');

  try {
    // Submit a task
    const task = await client.submitTask({
      type: 'code_analysis',
      target: 'src/main.ts',
      priority: 'high'
    });

    console.log('Task submitted:', task.data);

    // Check task status
    const status = await client.getTaskStatus(task.data.id);
    console.log('Task status:', status.data);

  } catch (error) {
    if (error instanceof MCPConnectionError) {
      console.error('Connection failed - check server URL');
    } else if (error instanceof MCPError) {
      console.error(`MCP error (${error.statusCode}):`, error.message);
    } else {
      console.error('Unexpected error:', error);
    }
  }
}
```

## API Reference

### Core Client

#### `new MCPClient(baseURL?, options?)`

Main client class for MCP server interaction.

**Parameters:**
- `baseURL` (string): Server base URL (default: 'http://localhost:5005')
- `options` (object): Client configuration
  - `timeout` (number): Request timeout in ms (default: 30000)
  - `maxRetries` (number): Maximum retry attempts (default: 3)
  - `retryDelay` (number): Base retry delay in ms (default: 1000)
  - `headers` (object): Additional headers

### Status & Health

- `getStatus()` - Get server status
- `getHealth()` - Get server health check

### Agent Management

- `listControllers()` - List all available agents
- `getAgentStatus(agentName)` - Get specific agent status
- `registerAgent(name, capabilities)` - Register new agent

### Task Management

- `submitTask(task)` - Submit task for processing
- `getTaskStatus(taskId)` - Get task status
- `listTasks(options?)` - List tasks with filtering
- `cancelTask(taskId)` - Cancel running task

### AI Features

- `analyzeCode(request)` - AI-powered code analysis
- `predictPerformance(metrics)` - Performance prediction
- `generateCode(request)` - Code generation from description

### Webhook Management

- `registerWebhook(registration)` - Register webhook for events
- `listWebhooks()` - List registered webhooks
- `deleteWebhook(webhookId)` - Delete webhook

### Plugin Management

- `listPlugins()` - List available plugins
- `getPluginInfo(pluginName)` - Get plugin details
- `installPlugin(pluginName, config?)` - Install plugin
- `uninstallPlugin(pluginName)` - Uninstall plugin

## Type Definitions

### Core Types

```typescript
interface MCPResponse<T = any> {
  success: boolean;
  data: T;
  error?: string;
  statusCode: number;
  responseTime: number;
}

interface AgentStatus {
  name: string;
  status: string;
  lastSeen: string;
  healthScore: number;
  capabilities: string[];
}

interface TaskInfo {
  id: string;
  status: string;
  agent: string;
  createdAt: string;
  completedAt?: string;
  result?: any;
}
```

### Task Submission

```typescript
interface TaskSubmission {
  type: string;
  target?: string;
  parameters?: Record<string, any>;
  priority?: 'low' | 'normal' | 'high' | 'critical';
}
```

### AI Requests

```typescript
interface CodeAnalysisRequest {
  code: string;
  language?: string;
  options?: {
    includeSuggestions?: boolean;
    includeMetrics?: boolean;
  };
}

interface CodeGenerationRequest {
  description: string;
  language?: string;
  context?: string;
  constraints?: string[];
}
```

## Error Handling

The SDK provides specific error types:

- `MCPError` - Base MCP error with status code
- `MCPConnectionError` - Connection/network errors
- `MCPTimeoutError` - Request timeout errors

```typescript
try {
  const result = await client.getStatus();
} catch (error) {
  if (error instanceof MCPConnectionError) {
    // Handle connection issues
  } else if (error instanceof MCPTimeoutError) {
    // Handle timeout issues
  } else if (error instanceof MCPError) {
    // Handle API errors
    console.log('Status code:', error.statusCode);
  }
}
```

## Configuration

### Environment Variables

```bash
export MCP_BASE_URL=http://my-server:5005
export MCP_TIMEOUT=60000
```

### Client Configuration

```typescript
const client = new MCPClient('http://custom-server:5005', {
  timeout: 60000,      // 60 second timeout
  maxRetries: 5,       // Retry up to 5 times
  retryDelay: 2000,    // Start with 2 second delay
  headers: {
    'Authorization': 'Bearer token123'
  }
});
```

## Development

### Setup

```bash
npm install
npm run build
```

### Testing

```bash
npm test
```

### Code Quality

```bash
npm run lint
npm run format
```

## Examples

### Task Management

```typescript
// Submit a code analysis task
const task = await client.submitTask({
  type: 'code_analysis',
  target: 'src/app.ts',
  priority: 'high',
  parameters: {
    includeMetrics: true,
    outputFormat: 'json'
  }
});

// Monitor task progress
let status = await client.getTaskStatus(task.data.id);
while (status.data.status === 'running') {
  await new Promise(resolve => setTimeout(resolve, 1000));
  status = await client.getTaskStatus(task.data.id);
}

console.log('Task completed:', status.data.result);
```

### AI Integration

```typescript
// Analyze code
const analysis = await client.analyzeCode({
  code: 'function add(a, b) { return a + b; }',
  language: 'javascript',
  options: {
    includeSuggestions: true,
    includeMetrics: true
  }
});

// Generate code
const generation = await client.generateCode({
  description: 'Create a React component for user authentication',
  language: 'typescript',
  context: 'React application with TypeScript',
  constraints: ['Use functional components', 'Include error handling']
});
```

### Webhook Management

```typescript
// Register webhook for task completion events
const webhook = await client.registerWebhook({
  url: 'https://my-app.com/webhooks/mcp',
  events: ['task.completed', 'task.failed'],
  secret: 'webhook-secret-key'
});

// List active webhooks
const webhooks = await client.listWebhooks();
console.log('Active webhooks:', webhooks.data);
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run the test suite: `npm test`
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/dboone323/tools-automation/issues)
- **Documentation**: [API Docs](https://github.com/dboone323/tools-automation/docs)
- **Discussions**: [GitHub Discussions](https://github.com/dboone323/tools-automation/discussions)