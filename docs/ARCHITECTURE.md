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

## MCP↔Agent↔Workflow Integration Flows

### Agent Registration & Task Execution Sequence

```
sequenceDiagram
    participant User
    participant MCP as MCP Server
    participant Agent as Agent Orchestrator
    participant TaskQ as Task Queue
    participant Worker as Agent Worker
    participant Workflow as Workflow Orchestrator

    User->>MCP: POST /v1/register
    MCP->>Agent: Register Agent
    Agent->>MCP: Agent Capabilities
    MCP->>User: Registration Success

    User->>MCP: POST /v1/run
    MCP->>Agent: Match Agent to Task
    Agent->>TaskQ: Queue Task
    TaskQ->>Worker: Assign Task
    Worker->>Workflow: Execute Task
    Workflow->>Worker: Task Result
    Worker->>TaskQ: Complete Task
    TaskQ->>Agent: Task Status
    Agent->>MCP: Update Status
    MCP->>User: Task Result
```

### Submodule MCP Client Integration Sequence

```
sequenceDiagram
    participant Submodule as Submodule (.tools-automation/)
    participant MCPClient as MCP Client Shim
    participant MCP as Root MCP Server
    participant Agent as Agent Orchestrator
    participant Worker as Agent Worker

    Submodule->>MCPClient: Local Task Request
    MCPClient->>MCP: Forward Request (HTTP)
    MCP->>Agent: Route to Agent
    Agent->>Worker: Execute Task
    Worker->>Agent: Task Result
    Agent->>MCP: Return Result
    MCP->>MCPClient: Response
    MCPClient->>Submodule: Local Result
```

### Health Monitoring & Auto-Restart Sequence

```
sequenceDiagram
    participant Monitor as Agent Monitor
    participant MCP as MCP Server
    participant Agent as Agent Orchestrator
    participant Launchd as Launchd Service
    participant Dashboard as Dashboard API

    loop Every 30s
        Monitor->>MCP: GET /v1/health
        MCP->>Monitor: Health Status
        Monitor->>Agent: Check Agent Status
        Agent->>Monitor: Agent Metrics

        alt Agent Unhealthy
            Monitor->>Launchd: Restart Agent Service
            Launchd->>Agent: Service Restart
            Agent->>Monitor: Ready Status
        end

        Monitor->>Dashboard: Update Metrics
        Dashboard->>Monitor: Metrics Stored
    end
```

### Git Hook Integration Sequence

```
sequenceDiagram
    participant Git as Git Client
    participant Hook as Pre-commit Hook
    participant MCP as MCP Server
    participant Agent as Agent Orchestrator
    participant Linter as Code Linter Agent
    participant Tester as Test Runner Agent

    Git->>Hook: Pre-commit Trigger
    Hook->>MCP: POST /v1/execute_task
    Note over MCP,Agent: Task: code_quality_check
    MCP->>Agent: Route Task
    Agent->>Linter: Run Linting
    Linter->>Agent: Lint Results
    Agent->>Tester: Run Fast Tests
    Tester->>Agent: Test Results
    Agent->>MCP: Combined Results
    MCP->>Hook: Quality Status

    alt Quality Check Failed
        Hook->>Git: Block Commit
        Git->>User: Commit Rejected
    else Quality Check Passed
        Hook->>Git: Allow Commit
        Git->>User: Commit Allowed
    end
```

### Error Handling & Circuit Breaker Sequence

```
sequenceDiagram
    participant Client
    participant MCP as MCP Server
    participant Circuit as Circuit Breaker
    participant Agent as Agent Orchestrator
    participant Fallback as Cloud Fallback
    participant Logger as Error Logger

    Client->>MCP: API Request
    MCP->>Circuit: Check State

    alt Circuit CLOSED
        Circuit->>Agent: Forward Request
        Agent-->>Circuit: Success
        Circuit->>MCP: Allow Response
        MCP->>Client: Success Response

    else Circuit OPEN
        Circuit->>MCP: Fail Fast
        MCP->>Client: Circuit Open Error

    else Circuit HALF-OPEN
        Circuit->>Agent: Test Request
        alt Test Success
            Circuit->>Circuit: Reset to CLOSED
            Circuit->>MCP: Allow Response
            MCP->>Client: Success Response
        else Test Failure
            Circuit->>Circuit: Back to OPEN
            Circuit->>Logger: Log Failure
            MCP->>Client: Circuit Open Error
        end
    end

    alt Local Failure
        Agent->>Circuit: Report Failure
        Circuit->>Fallback: Check Cloud Available
        alt Cloud Allowed
            Fallback->>Circuit: Cloud Response
            Circuit->>MCP: Cloud Result
            MCP->>Client: Response
        else Cloud Not Allowed
            Circuit->>Logger: Log Escalation
            MCP->>Client: Local Failure
        end
    end
```

### Workflow Orchestrator Integration Sequence

```
sequenceDiagram
    participant CI as CI/CD Pipeline
    participant Workflow as Workflow Orchestrator
    participant MCP as MCP Server
    participant Agent as Agent Orchestrator
    participant TaskQ as Task Queue
    participant Workers as Agent Workers

    CI->>Workflow: Trigger Build
    Workflow->>MCP: POST /v1/controllers
    Note over MCP,Agent: Request: build_orchestration
    MCP->>Agent: Route Controller Task
    Agent->>TaskQ: Queue Build Tasks
    TaskQ->>Workers: Distribute Tasks
    Workers->>TaskQ: Task Completion
    TaskQ->>Agent: Build Status
    Agent->>MCP: Controller Result
    MCP->>Workflow: Build Complete
    Workflow->>CI: Pipeline Status

    alt Build Success
        Workflow->>CI: Deploy
    else Build Failure
        Workflow->>CI: Rollback
        CI->>Workflow: Rollback Complete
    end
```

### Quantum-Enhanced Processing Sequence

```
sequenceDiagram
    participant Client
    participant MCP as MCP Server
    participant Quantum as Quantum Processor
    participant Agent as Agent Orchestrator
    participant AI as AI Layer
    participant Cache as Result Cache

    Client->>MCP: POST /v1/quantum/analyze
    MCP->>Cache: Check Cached Result
    alt Cache Hit
        Cache->>MCP: Return Cached
        MCP->>Client: Cached Result
    else Cache Miss
        MCP->>Quantum: Initialize Quantum State
        Quantum->>Agent: Request AI Enhancement
        Agent->>AI: Process with AI
        AI->>Agent: Enhanced Result
        Agent->>Quantum: Apply Quantum Processing
        Quantum->>Cache: Store Result
        Cache->>MCP: Processing Complete
        MCP->>Client: Quantum Result
    end
```

### API Contract Testing Flow

```
sequenceDiagram
    participant Test as Integration Test
    participant MCP as MCP Server
    participant Contract as Contract Validator
    participant Schema as Response Schema
    participant Logger as Test Logger

    Test->>MCP: API Request
    MCP->>Test: Response
    Test->>Contract: Validate Contract
    Contract->>Schema: Check Schema Compliance
    Schema->>Contract: Schema Valid

    alt Contract Valid
        Contract->>Test: Pass
        Test->>Logger: Log Success
    else Contract Invalid
        Contract->>Test: Fail Details
        Test->>Logger: Log Failure
        Logger->>Test: Alert Developer
    end
```

## Integration Testing Coverage

### End-to-End Test Scenarios

```
┌─────────────────────────────────────────────────────────────┐
│ Integration Test Matrix                                     │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ MCP Server Health                                        │ │
│ │ • Health endpoint response                                │ │
│ │ • Service availability                                    │ │
│ │ • Error handling                                          │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Agent Registration                                       │ │
│ │ • Agent capability matching                               │ │
│ │ • Registration persistence                                │ │
│ │ • Duplicate handling                                      │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Task Execution Flows                                      │ │
│ │ • Task submission to completion                           │ │
│ │ • Concurrent task handling                                │ │
│ │ • Task timeout handling                                   │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Orchestrator Integration                                 │ │
│ │ • Command routing                                         │ │
│ │ • Status synchronization                                  │ │
│ │ • Error propagation                                       │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Workflow Integration                                      │ │
│ │ • CI/CD pipeline triggers                                 │ │
│ │ • Build orchestration                                      │ │
│ │ • Deployment coordination                                 │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Submodule MCP Clients                                     │ │
│ │ • Request forwarding                                       │ │
│ │ • Response handling                                       │ │
│ │ • Error isolation                                         │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Error Scenarios                                          │ │
│ │ • Network failures                                        │ │
│ │ • Service unavailability                                  │ │
│ │ • Data corruption                                         │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Performance & Load                                       │ │
│ │ • Concurrent request handling                             │ │
│ │ • Resource utilization                                    │ │
│ │ • Scalability testing                                     │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Contract Testing Validation

```
Contract Test Coverage
┌─────────────────────────────────────────────────────────────┐
│ Endpoint Contracts                                          │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ /v1/health                                               │ │
│ │ • Response schema validation                             │ │
│ │ • Status code contracts                                   │ │
│ │ • Response time SLAs                                      │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ /v1/register                                             │ │
│ │ • Request schema validation                              │ │
│ │ • Response contracts                                      │ │
│ │ • Error response formats                                 │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ /v1/run                                                  │ │
│ │ • Task submission contracts                              │ │
│ │ • Async response handling                                │ │
│ │ • Status update schemas                                  │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ /v1/status                                               │ │
│ │ • Status response schemas                                │ │
│ │ • Historical data contracts                              │ │
│ │ • Metrics format validation                              │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ /v1/controllers                                          │ │
│ │ • Controller routing contracts                           │ │
│ │ • Command validation                                      │ │
│ │ • Result format standards                                │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ /v1/execute_task                                         │ │
│ │ • Task execution contracts                               │ │
│ │ • Workflow integration                                    │ │
│ │ • Error handling standards                               │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
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
