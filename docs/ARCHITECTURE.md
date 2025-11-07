# Tools-Automation Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    macOS Local Environment                       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                Launchd Services Layer                       │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │ │
│  │  │ Agent Monitoring │ Task Orchestrator │ Dependency Graph │ │ │
│  │  │ Dashboard        │ Auto Rollback     │ CI Orchestrator   │ │ │
│  │  └─────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                MCP Server (127.0.0.1:5005)                 │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │ │
│  │  │ /v1/health    │ /v1/register │ /v1/run     │ /v1/status │ │ │
│  │  │ Auth Required │ Controllers   │ Commands    │ Metrics    │ │ │
│  │  └─────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                   AI Layer (Local-First)                    │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │ │
│  │  │ Ollama (11434) │ Cloud Fallback │ Circuit Breaker       │ │ │
│  │  │ Models: llama2 │ Priority Queue │ Quota Management      │ │ │
│  │  └─────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                 Git Flow & Safety                           │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │ │
│  │  │ Pre-commit │ Pre-push │ Post-merge │ Error Budget       │ │ │
│  │  │ Linting    │ Tests     │ Rollback   │ Circuit Breaker    │ │ │
│  │  └─────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Component Interactions

### Data Flow

```
User Request → MCP Server → Task Orchestrator → Agent Execution
       ↓              ↓              ↓              ↓
   Dashboard ← Metrics Collection ← Agent Monitoring ← Results
```

### AI Request Flow

```
Code Generation Request
        ↓
Policy Check (Priority + Quota)
        ↓
Local Ollama API Call
        ↓
Success? → Yes: Return Result
        ↓
No: Circuit Breaker Check
        ↓
Cloud Fallback (if allowed)
        ↓
Log Escalation + Return
```

### Git Flow

```
Commit → Pre-commit Hook → Lint + Fast Tests
        ↓
Push → Pre-push Hook → Full Test Suite
        ↓
Merge → Post-merge Hook → Integration Tests
        ↓
Failure? → Error Budget Check
        ↓
Budget OK? → Auto Rollback
        ↓
No: Manual Intervention
```

## Submodule Integration

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ CodingReviewer  │    │ PlannerApp      │    │ HabitQuest      │
│ ├───────────────┤    ├───────────────┤    ├───────────────┤
│ │ .tools-auto   │    │ .tools-auto   │    │ .tools-auto   │
│ │ mcp_client.sh │◄──►│ mcp_client.sh │◄──►│ mcp_client.sh │
│ │ config.json   │    │ config.json   │    │ config.json   │
│ └───────────────┘    └───────────────┘    └───────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ MCP Server      │
                    │ 127.0.0.1:5005 │
                    └─────────────────┘
```

## Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ External Access Prevention                                  │
│                                                             │
│ • MCP Server: 127.0.0.1 only                                │
│ • Auth: X-Auth-Token header required                        │
│ • Tokens: macOS Keychain storage                            │
│ • Fallback: .env file (logged as insecure)                  │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Keychain Secrets                                         │ │
│ │ • MCP Auth Token                                          │ │
│ │ • Cloud API Keys (if configured)                          │ │
│ │ • Service Credentials                                     │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ .env Fallback (Audit Logged)                              │ │
│ │ • MCP_AUTH_TOKEN                                          │ │
│ │ • OLLAMA_ENDPOINT                                         │ │
│ │ • Cloud Provider Keys                                     │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Observability Stack

```
┌─────────────────────────────────────────────────────────────┐
│ Metrics Collection                                          │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Agent Monitoring                                         │ │
│ │ • Throughput (tasks/min)                                  │ │
│ │ • Uptime (seconds)                                        │ │
│ │ • Error Budget Status                                     │ │
│ │ • AI Fallback Rate                                        │ │
│ │ • Submodule Coverage                                      │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Trend Analysis                                           │ │
│ │ • Error Rate Trends                                       │ │
│ │ • Fallback Rate Trends                                    │ │
│ │ • Coverage Drop Alerts                                    │ │
│ │ • Deduplication                                           │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Dashboard                                                │ │
│ │ • Real-time Metrics                                       │ │
│ │ • Historical Trends                                       │ │
│ │ • Alert Summary                                           │ │
│ │ • Submodule Status                                        │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Dependency Graph

```
┌─────────────────┐
│ MomentumFinance │
│                 │
│ Depends on:     │
│ • Shared Kit    │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐    ┌─────────────────┐
│ Shared Kit      │    │ Other Modules   │
│                 │    │                 │
│ No Dependencies │    │ Independent     │
└─────────────────┘    └─────────────────┘
```

## Circuit Breaker States

```
Circuit Breaker State Machine
        ┌─────────────────────────────────┐
        │           CLOSED                │
        │   Normal operation              │
        │   Requests flow through         │
        └─────────────┬───────────────────┘
                      │
                      │ 3 consecutive failures
                      ▼
        ┌─────────────────────────────────┐
        │            OPEN                 │
        │   Requests fail fast            │
        │   No operations attempted       │
        └─────────────┬───────────────────┘
                      │
                      │ After 10 minutes
                      ▼
        ┌─────────────────────────────────┐
        │          HALF-OPEN              │
        │   Test request allowed          │
        │   Success → CLOSED              │
        │   Failure → OPEN                │
        └─────────────────────────────────┘
```

## Error Budget Management

```
Error Budget Tracking
┌─────────────────────────────────────────────────────────────┐
│ Service: post_merge_tests                                   │
│ Budget: 5% error rate                                       │
│                                                             │
│ Current Period:                                             │
│ • Total Runs: 100                                           │
│ • Failures: 3                                               │
│ • Error Rate: 3%                                            │
│ • Budget Remaining: 2%                                      │
│                                                             │
│ Decision Logic:                                             │
│ IF error_rate > budget THEN                                 │
│   Prevent auto-rollback                                     │
│   Require manual intervention                               │
│ ELSE                                                        │
│   Allow auto-rollback                                       │
│ END                                                         │
└─────────────────────────────────────────────────────────────┘
```

## AI Policy Enforcement

```
AI Request Processing
┌─────────────────────────────────────────────────────────────┐
│ 1. Task Priority Assessment                                 │
│    • codeGen: medium                                        │
│    • archAnalysis: high                                     │
│    • dashboardSummary: low                                  │
│                                                             │
│ 2. Quota Check                                              │
│    • Critical: 50/day, 10/hour                              │
│    • High: 20/day, 5/hour                                   │
│                                                             │
│ 3. Local AI Call                                            │
│    • Ollama API: http://localhost:11434                     │
│    • Timeout: 60s                                           │
│                                                             │
│ 4. Fallback Decision                                        │
│    IF local_timeout OR consecutive_failures >= 2 THEN       │
│      IF priority >= high AND quota_available THEN           │
│        Cloud API call                                       │
│        Log escalation                                       │
│      END                                                    │
│    END                                                      │
│                                                             │
│ 5. Circuit Breaker                                          │
│    • Failure threshold: 3                                   │
│    • Window: 10 minutes                                     │
│    • Reset: 30 minutes                                      │
└─────────────────────────────────────────────────────────────┘
```

## Launchd Service Configuration

```
Service Configuration Template
┌─────────────────────────────────────────────────────────────┐
│ Label: com.tools.{service_name}                             │
│ ProgramArguments:                                           │
│   /bin/zsh                                                  │
│   -lc                                                      │
│   /path/to/script.sh                                        │
│ RunAtLoad: true                                             │
│ KeepAlive: true                                             │
│ StandardOutPath: ~/Library/Logs/tools-automation/*.log     │
│ StandardErrorPath: ~/Library/Logs/tools-automation/*.log   │
│ EnvironmentVariables:                                       │
│   PATH: /opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin      │
│ ThrottleInterval: 60                                        │
└─────────────────────────────────────────────────────────────┘
```

This architecture ensures local-first operation with bounded cloud fallback, comprehensive safety mechanisms, and full observability for autonomous agent coordination.
