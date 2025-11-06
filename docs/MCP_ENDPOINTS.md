# MCP Endpoints Documentation

**API Version:** v1  
**Base URL:** `http://127.0.0.1:5005`  
**Authentication:** `X-Auth-Token` header (local only)  
**Updated:** November 6, 2025

---

## Overview

The Model Context Protocol (MCP) server provides a centralized API for AI task execution, agent registration, and health monitoring. The server is bound to `127.0.0.1` (localhost only) for security and requires authentication via the `X-Auth-Token` header.

---

## Authentication

All requests must include the `X-Auth-Token` header with a valid token:

```bash
X-Auth-Token: <your-token-here>
```

To get your auth token:

```bash
# From Keychain
security find-generic-password -a $USER -s 'tools-automation-mcp' -w

# Or using helper script
./security/keychain_secrets.sh get mcp
```

---

## Endpoints

### GET `/v1/status`

**Description:** Check server health and status

**Authentication:** Required

**Response:**

```json
{
  "status": "healthy",
  "version": "1.0",
  "uptime_seconds": 3600,
  "timestamp": "2025-11-06T15:00:00Z"
}
```

**Example:**

```bash
curl -H "X-Auth-Token: $TOKEN" http://127.0.0.1:5005/v1/status
```

---

### POST `/v1/run`

**Description:** Execute an AI task

**Authentication:** Required

**Request Body:**

```json
{
  "task": "codeGen",
  "prompt": "Create a function to calculate fibonacci",
  "context": {
    "file": "main.swift",
    "language": "swift"
  },
  "options": {
    "temperature": 0.1,
    "max_tokens": 512
  }
}
```

**Response:**

```json
{
  "success": true,
  "task_id": "task_20251106_150030",
  "result": "func fibonacci(n: Int) -> Int { ... }",
  "model_used": "codellama:7b",
  "tokens_used": 128,
  "duration_ms": 1500
}
```

**Example:**

```bash
curl -X POST \
  -H "X-Auth-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"task":"codeGen","prompt":"Create a Swift function"}' \
  http://127.0.0.1:5005/v1/run
```

---

### POST `/v1/heartbeat`

**Description:** Agent heartbeat to indicate liveness

**Authentication:** Required

**Request Body:**

```json
{
  "agent_name": "code_analysis_agent",
  "pid": 12345,
  "status": "active",
  "tasks_completed": 42,
  "uptime_seconds": 3600
}
```

**Response:**

```json
{
  "acknowledged": true,
  "timestamp": "2025-11-06T15:00:00Z"
}
```

**Example:**

```bash
curl -X POST \
  -H "X-Auth-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"agent_name":"test_agent","pid":$$,"status":"active"}' \
  http://127.0.0.1:5005/v1/heartbeat
```

---

### POST `/v1/register`

**Description:** Register a new agent

**Authentication:** Required

**Request Body:**

```json
{
  "agent_name": "new_agent",
  "version": "1.0.0",
  "capabilities": ["codeGen", "testGen"],
  "contact": "agent@localhost"
}
```

**Response:**

```json
{
  "registered": true,
  "agent_id": "agent_20251106_150030",
  "timestamp": "2025-11-06T15:00:00Z"
}
```

**Example:**

```bash
curl -X POST \
  -H "X-Auth-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"agent_name":"my_agent","version":"1.0.0","capabilities":["codeGen"]}' \
  http://127.0.0.1:5005/v1/register
```

---

## Legacy Endpoints (Deprecated)

These endpoints are deprecated and will be removed in v2. Use v1 endpoints instead.

- `/status` → Use `/v1/status`
- `/run` → Use `/v1/run`
- `/heartbeat` → Use `/v1/heartbeat`
- `/register` → Use `/v1/register`

Legacy endpoints return a deprecation warning header:

```
X-Deprecation-Warning: This endpoint is deprecated. Use /v1/* endpoints instead.
```

---

## Error Responses

### 401 Unauthorized

Missing or invalid auth token:

```json
{
  "error": "unauthorized",
  "message": "Missing or invalid X-Auth-Token header"
}
```

### 400 Bad Request

Invalid request format:

```json
{
  "error": "bad_request",
  "message": "Invalid JSON or missing required fields"
}
```

### 500 Internal Server Error

Server-side error:

```json
{
  "error": "internal_error",
  "message": "An error occurred processing your request"
}
```

---

## Security

- **Local-only binding:** Server binds to `127.0.0.1` and is not accessible from external networks
- **Token authentication:** All requests require valid auth token stored in macOS Keychain
- **HTTPS not required:** Since the server is localhost-only, HTTPS is not necessary
- **Token rotation:** Regenerate tokens periodically using `./security/mcp_auth_token.sh`

---

## Rate Limits

Currently no rate limits are enforced for local requests. Cloud fallback requests are governed by `config/cloud_fallback_config.json`.

---

## Client Libraries

### Bash

```bash
./mcp_client.sh --task codeGen --prompt "Create function"
```

### Python

```python
import ollama_client
result = ollama_client.generate(task="codeGen", prompt="Create function")
```

### Swift

```swift
let client = OllamaClient()
let result = try await client.generate(task: "codeGen", prompt: "Create function")
```

---

## Submodule Integration

Each submodule has an MCP kit in `.tools-automation/`:

- `mcp_client.sh` - Shim to root MCP client
- `mcp_config.json` - Submodule-specific configuration
- `env.sh` - Environment variables
- `simple_mcp_check.sh` - Health check script

**Example from submodule:**

```bash
cd CodingReviewer
./.tools-automation/mcp_client.sh --help
```

---

## Monitoring

Monitor MCP server health:

```bash
# Check if server is running
curl -H "X-Auth-Token: $TOKEN" http://127.0.0.1:5005/v1/status

# View recent logs
tail -f ~/Library/Logs/tools-automation/mcp-server.log

# Check via launchd
launchctl list | grep com.quantum.mcp
```

---

## Troubleshooting

### Connection Refused

- Verify server is running: `launchctl list | grep com.quantum.mcp`
- Check logs: `tail ~/Library/Logs/tools-automation/mcp-server-error.log`
- Restart server: `launchctl unload ~/Library/LaunchAgents/com.quantum.mcp.plist && launchctl load ~/Library/LaunchAgents/com.quantum.mcp.plist`

### Authentication Failed

- Regenerate token: `./security/mcp_auth_token.sh`
- Update environment: `export MCP_AUTH_TOKEN=$(security find-generic-password -a $USER -s 'tools-automation-mcp' -w)`
- Restart MCP server after token change

### Slow Responses

- Check Ollama status: `ollama list`
- Monitor resource usage: `top -pid $(pgrep -f mcp_server)`
- Review cloud escalation log: `tail logs/cloud_escalation_log.jsonl`

---

**For more information, see:**

- [Runbook](RUNBOOK.md) - Operational procedures
- [Architecture](ARCHITECTURE.md) - System design
- [Master Plan](../AGENT_ENHANCEMENT_MASTER_PLAN.md) - Overall strategy
