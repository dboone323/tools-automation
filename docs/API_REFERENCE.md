# MCP Server API Reference

## Overview

The MCP (Model Context Protocol) Server provides a comprehensive HTTP API for coordinating AI agents, managing tasks, and monitoring system health. This document provides detailed reference information for all available endpoints.

## Base URL

```
http://localhost:5005
```

## Authentication

- **Rate Limiting**: 50 requests per minute per IP (configurable)
- **CORS**: Enabled for cross-origin requests
- **Security Headers**: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, CSP

## Response Format

All responses follow this structure:

```json
{
  "ok": boolean,
  "data": object,
  "error": "string (only present on errors)",
  "timestamp": number
}
```

---

## Health & Status Endpoints

### GET /health

Get detailed system health information.

**Response:**

```json
{
  "ok": true,
  "status": "healthy|degraded|error",
  "timestamp": 1640995200.123,
  "uptime": true,
  "agents": {
    "registered": 5,
    "controllers": 3
  },
  "tasks": {
    "total": 42,
    "queued": 8,
    "running": 2
  },
  "dependencies": {
    "ollama": {
      "available": true,
      "endpoint": "http://localhost:11434"
    }
  },
  "system": {
    "disk_free_gb": 245.8,
    "disk_total_gb": 500.0,
    "disk_percent": 48.8,
    "cpu_percent": 12.5,
    "memory_percent": 65.2,
    "memory_available_gb": 8.7
  },
  "issues": ["string"] // Only present if issues exist
}
```

### GET /status

Get basic system status.

**Response:**

```json
{
  "ok": true,
  "agents": ["agent1", "agent2"],
  "tasks": [{ "id": "task1", "status": "queued" }],
  "controllers": [{ "agent": "controller1", "last_heartbeat": 1640995200 }]
}
```

### GET /controllers

Get registered controller agents.

**Response:**

```json
{
  "ok": true,
  "controllers": [
    {
      "agent": "controller1",
      "project": "HabitQuest",
      "last_heartbeat": 1640995200.123
    }
  ]
}
```

---

## Agent Management Endpoints

### GET /api/agents/status

Get comprehensive agent status information.

**Response:**

```json
{
  "ok": true,
  "agents": {
    "total_agents": 5,
    "registered_agents": ["agent1", "agent2", "agent3"],
    "active_controllers": 3,
    "controller_details": [
      {
        "agent": "controller1",
        "project": "HabitQuest",
        "last_heartbeat": 1640995200.123
      }
    ],
    "timestamp": 1640995200.456
  }
}
```

### POST /register

Register a new agent.

**Request Body:**

```json
{
  "agent": "agent_name",
  "capabilities": ["analyze", "fix", "optimize"]
}
```

**Response:**

```json
{
  "ok": true,
  "registered": "agent_name"
}
```

### POST /heartbeat

Send heartbeat from controller agent.

**Request Body:**

```json
{
  "agent": "controller_name",
  "project": "project_name"
}
```

**Response:**

```json
{
  "ok": true,
  "heartbeat": true,
  "agent": "controller_name"
}
```

---

## Task Management Endpoints

### POST /run

Submit a task for execution.

**Request Body:**

```json
{
  "agent": "agent_name",
  "command": "analyze",
  "project": "HabitQuest",
  "execute": false
}
```

**Allowed Commands:**

- `analyze` - Run AI enhancement analysis
- `analyze-all` - Analyze all projects
- `auto-apply` - Auto-apply enhancements
- `ci-check` - Run CI checks
- `fix` - Apply fixes
- `fix-all` - Fix all issues
- `status` - Get MCP server status
- `validate` - Validate fixes
- `optimize-performance` - Performance optimization
- `enhance-review-engine` - Enhance review engine
- `implement-feature` - Implement features
- `integrate-api` - API integration
- `enhance-ui` - UI enhancement
- `implement-todo` - TODO implementation
- `quantum_orchestrate` - Quantum orchestration
- `quantum_analyze` - Quantum analysis
- `quantum_finance` - Quantum finance optimization
- `quantum_learning` - Quantum learning
- `multiverse_navigate` - Multiverse navigation
- `consciousness_expand` - Consciousness expansion
- `dimensional_compute` - Dimensional computing

**Response:**

```json
{
  "ok": true,
  "task_id": "uuid-string",
  "queued": true
}
```

### POST /execute_task

Execute a queued task.

**Request Body:**

```json
{
  "task_id": "uuid-string"
}
```

**Response:**

```json
{
  "ok": true,
  "executing": true,
  "task_id": "uuid-string"
}
```

### GET /api/tasks/analytics

Get comprehensive task analytics.

**Response:**

```json
{
  "ok": true,
  "analytics": {
    "total_tasks": 42,
    "queued_tasks": 8,
    "running_tasks": 2,
    "completed_tasks": 30,
    "failed_tasks": 2,
    "success_rate": 71.43,
    "recent_tasks": [
      {
        "id": "task-id",
        "agent": "agent1",
        "command": "analyze",
        "status": "completed",
        "project": "HabitQuest"
      }
    ],
    "timestamp": 1640995200.123
  }
}
```

---

## Monitoring & Metrics Endpoints

### GET /metrics

Get Prometheus-format metrics.

**Response (text/plain):**

```
# HELP tasks_queued Simple MCP counter for tasks_queued
# TYPE tasks_queued counter
tasks_queued 42

# HELP tasks_executed Simple MCP counter for tasks_executed
# TYPE tasks_executed counter
tasks_executed 38

# HELP tasks_failed Simple MCP counter for tasks_failed
# TYPE tasks_failed counter
tasks_failed 2
```

### GET /api/metrics/system

Get system-level performance metrics.

**Response:**

```json
{
  "ok": true,
  "system_metrics": {
    "server_uptime": 3600.5,
    "total_requests": 1250,
    "active_connections": 3,
    "cpu_percent": 12.5,
    "memory_percent": 65.2,
    "disk_usage_percent": 48.8,
    "timestamp": 1640995200.123
  }
}
```

### GET /api/dashboard/refresh

Refresh dashboard data and clear caches.

**Response:**

```json
{
  "ok": true,
  "refresh": {
    "dashboard_refreshed": true,
    "data_updated": true,
    "cache_cleared": false,
    "last_refresh": 1640995200.123,
    "next_refresh_scheduled": 1640995500.123
  }
}
```

---

## Analytics Endpoints

### GET /api/ml/analytics

Get machine learning analytics (future feature).

**Response:**

```json
{
  "ok": true,
  "ml_analytics": {
    "ml_models_active": 0,
    "predictions_made": 0,
    "accuracy_metrics": {},
    "training_sessions": 0,
    "feature_importance": {},
    "model_performance": {},
    "timestamp": 1640995200.123
  }
}
```

### GET /api/umami/stats

Get user analytics data (future feature).

**Response:**

```json
{
  "ok": true,
  "umami_stats": {
    "total_visitors": 0,
    "page_views": 0,
    "unique_sessions": 0,
    "bounce_rate": 0.0,
    "avg_session_duration": 0,
    "top_pages": [],
    "referrers": [],
    "timestamp": 1640995200.123
  }
}
```

---

## Workflow Integration Endpoints

### POST /workflow_alert

Receive workflow alerts from CI/CD systems.

**Request Body:**

```json
{
  "workflow": "CI Pipeline",
  "conclusion": "failure",
  "url": "https://github.com/...",
  "head_branch": "feature-branch",
  "run_id": "12345",
  "action": "rerun-workflow"
}
```

**Response:**

```json
{
  "ok": true,
  "enqueued": true,
  "task_id": "uuid-string"
}
```

### POST /github_webhook

Receive GitHub webhook events.

**Headers:**

- `X-GitHub-Event`: Event type
- `X-Hub-Signature-256`: Webhook signature

**Supported Events:**

- `repository_dispatch` - Manual workflow triggers
- `workflow_run` - Workflow completion notifications

**Response:**

```json
{
  "ok": true,
  "enqueued": true,
  "task_id": "uuid-string"
}
```

---

## Quantum-Enhanced Endpoints

### GET /quantum_status

Get quantum system status.

**Response:**

```json
{
  "ok": true,
  "quantum_status": {
    "entanglement_network": {
      "active": true,
      "entangled_agents": 3,
      "network_health": 0.95
    },
    "multiverse_navigation": {
      "active": true,
      "parallel_universes": 5,
      "current_universe": "alpha",
      "multiverse_stability": 0.92
    },
    "consciousness_frameworks": {
      "active": true,
      "active_frameworks": 2,
      "consciousness_level": 0.6
    },
    "dimensional_computing": {
      "active": true,
      "supported_dimensions": [3, 4, 5],
      "dimensional_stability": 0.88
    },
    "quantum_orchestrator": {
      "active": true,
      "queued_jobs": 12,
      "orchestration_cycles": 45
    }
  }
}
```

### POST /quantum_entangle

Create quantum entanglement between agents.

**Request Body:**

```json
{
  "agent1": "agent_a",
  "agent2": "agent_b"
}
```

**Response:**

```json
{
  "ok": true,
  "entanglement_created": true,
  "entanglement_id": "uuid-string"
}
```

### POST /multiverse_navigate

Navigate to parallel universe.

**Request Body:**

```json
{
  "universe_id": "parallel_1",
  "workflow_type": "computation"
}
```

**Response:**

```json
{
  "ok": true,
  "navigation_completed": true,
  "universe": "parallel_1",
  "workflow_type": "computation"
}
```

### POST /consciousness_expand

Expand consciousness frameworks.

**Request Body:**

```json
{
  "expansion_type": "intelligence",
  "target_agent": "agent1"
}
```

**Response:**

```json
{
  "ok": true,
  "consciousness_expanded": true,
  "expansion_details": {...}
}
```

### POST /dimensional_compute

Execute dimensional computing task.

**Request Body:**

```json
{
  "dimensions": [3, 4, 5],
  "computation_type": "optimization"
}
```

**Response:**

```json
{
  "ok": true,
  "computation_completed": true,
  "results": {...}
}
```

### POST /quantum_orchestrate

Advanced quantum orchestration.

**Request Body:**

```json
{
  "workflow_name": "quantum_optimization",
  "execution_mode": "parallel"
}
```

**Response:**

```json
{
  "ok": true,
  "orchestration_started": true,
  "task_id": "uuid-string",
  "workflow": "quantum_optimization"
}
```

### POST /reality_simulate

Reality simulation.

**Request Body:**

```json
{
  "universe_config": {},
  "duration": 1000
}
```

**Response:**

```json
{
  "ok": true,
  "simulation_completed": true,
  "results": {...}
}
```

---

## Error Responses

### Rate Limited (429)

```json
{
  "error": "rate_limited"
}
```

### Not Found (404)

```json
{
  "error": "not_found"
}
```

### Bad Request (400)

```json
{
  "error": "invalid_json"
}
```

### Forbidden (403)

```json
{
  "error": "command_not_allowed",
  "allowed": ["analyze", "fix", "status"]
}
```

### Server Error (500)

```json
{
  "error": "internal_server_error"
}
```

---

## Configuration

### Environment Variables

- `MCP_HOST`: Server host (default: 127.0.0.1)
- `MCP_PORT`: Server port (default: 5005)
- `RATE_LIMIT_MAX_REQS`: Max requests per window (default: 50)
- `RATE_LIMIT_WINDOW_SEC`: Rate limit window (default: 60)
- `TASK_TTL_DAYS`: Task cleanup age (default: 7)
- `GITHUB_WEBHOOK_SECRET`: Webhook signature verification

### Circuit Breaker Settings

- `CIRCUIT_BREAKER_THRESHOLD`: Failure threshold (default: 3)
- `CIRCUIT_BREAKER_TIMEOUT`: Open timeout seconds (default: 300)
- `CIRCUIT_BREAKER_HALF_OPEN_TIMEOUT`: Half-open timeout (default: 60)

---

## Rate Limiting

- **Default**: 50 requests per minute per IP
- **Whitelisted Clients**: Bypass rate limiting via `X-Client-Id` header
- **Rate Limit Headers**: Not currently exposed (future enhancement)

---

## Monitoring

### Metrics Available

- `tasks_queued`: Total tasks queued
- `tasks_executed`: Total tasks executed
- `tasks_failed`: Total tasks failed
- `tasks_assigned`: Total tasks assigned
- `tasks_dlq`: Tasks moved to dead letter queue

### Health Checks

- `/health`: Detailed health with system metrics
- Circuit breaker status for external services
- Dependency availability (Ollama, etc.)

---

## Security Considerations

1. **Input Validation**: All inputs validated and sanitized
2. **Rate Limiting**: Prevents abuse and DoS attacks
3. **CORS**: Configured for legitimate cross-origin requests
4. **Security Headers**: Standard security headers applied
5. **Command Allowlist**: Only pre-approved commands executable
6. **Webhook Verification**: GitHub webhooks signature-verified
7. **File Permissions**: Sensitive files protected
8. **Audit Logging**: All operations logged for security review

---

## Examples

### Register an Agent

```bash
curl -X POST http://localhost:5005/register \
  -H "Content-Type: application/json" \
  -d '{"agent": "my-agent", "capabilities": ["analyze", "fix"]}'
```

### Submit a Task

```bash
curl -X POST http://localhost:5005/run \
  -H "Content-Type: application/json" \
  -d '{"agent": "my-agent", "command": "analyze", "project": "MyProject"}'
```

### Check Health

```bash
curl http://localhost:5005/health
```

### Get Task Analytics

```bash
curl http://localhost:5005/api/tasks/analytics
```

---

_Last Updated: November 12, 2025_
_Version: 1.0.0_
