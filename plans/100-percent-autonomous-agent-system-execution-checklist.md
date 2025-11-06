# 100% Autonomous Agent System: Step-by-Step Execution Checklist

**Version:** 1.0  
**Date:** November 6, 2025  
**Target:** Local-first, MCP-standardized, safe-merge operations with hybrid AI, dependency graph coordination, and comprehensive observability

---

## Prerequisites Verification

- [ ] Confirm macOS environment with Homebrew installed
- [ ] Verify Ollama installed and accessible at `/opt/homebrew/bin/ollama` or `/usr/local/bin/ollama`
- [ ] Confirm Python 3.8+ in `.venv` with dependencies installed
- [ ] Verify Git submodules initialized: `CodingReviewer`, `PlannerApp`, `HabitQuest`, `MomentumFinance`, `AvoidObstaclesGame`, `shared-kit`
- [ ] Confirm workspace path: `/Users/danielstevens/Desktop/github-projects/tools-automation`

---

## Phase 1: Adaptive AI Policy & Cloud Fallback Governance

### 1.1 Create Cloud Fallback Configuration

**Files to create:**

- `config/cloud_fallback_config.json`

**Content structure:**

```json
{
  "version": "1.0",
  "mode": "adaptive",
  "allowed_priority_levels": ["critical", "high"],
  "circuit_breaker": {
    "failure_threshold": 3,
    "window_minutes": 10,
    "reset_after_minutes": 30
  },
  "quotas": {
    "critical": {
      "daily_limit": 50,
      "hourly_limit": 10,
      "per_task_timeout_sec": 30
    },
    "high": {
      "daily_limit": 20,
      "hourly_limit": 5,
      "per_task_timeout_sec": 20
    }
  },
  "fallback_conditions": {
    "local_timeout_sec": 60,
    "local_consecutive_failures": 2,
    "model_not_available": true
  },
  "cloud_providers": {
    "ollama_cloud": {
      "enabled": false,
      "endpoint": "https://ollama.ai/api",
      "requires_auth": true
    }
  }
}
```

**Actions:**

- [ ] Create `config/` directory if it doesn't exist
- [ ] Add `cloud_fallback_config.json` with schema above
- [ ] Validate JSON syntax with `python3 -m json.tool config/cloud_fallback_config.json`

### 1.2 Create Cloud Escalation Log

**Files to create:**

- `logs/cloud_escalation_log.jsonl`

**Actions:**

- [ ] Create `logs/` directory if it doesn't exist
- [ ] Touch empty file: `touch logs/cloud_escalation_log.jsonl`
- [ ] Set permissions: `chmod 644 logs/cloud_escalation_log.jsonl`

### 1.3 Update Model Registry with Task Priorities

**Files to modify:**

- `model_registry.json`

**Changes:**
Add `"priority"` field to each task entry:

- `codeGen`: `"priority": "medium"`
- `testGen`: `"priority": "medium"`
- `archAnalysis`: `"priority": "high"`
- `dashboardSummary`: `"priority": "low"`
- `visionOcr`: `"priority": "medium"`
- `visionLayout`: `"priority": "medium"`
- `codeAnalysis`: `"priority": "high"`
- `projectHealth`: `"priority": "high"`
- `workflowOptimization`: `"priority": "medium"`

**Actions:**

- [ ] Backup current `model_registry.json`: `cp model_registry.json model_registry.json.backup`
- [ ] Add `"priority"` field to each task object
- [ ] Validate JSON syntax
- [ ] Confirm all `fallbacks` arrays contain only local models (no cloud endpoints)

### 1.4 Update Free AI Config with Bounded Cloud Fallback

**Files to modify:**

- `free_ai_config.json`

**Changes:**

```json
{
  "primary_service": "ollama",
  "services": {
    "ollama": {
      "endpoint": "http://localhost:11434",
      "models": {
        "general": "llama2",
        "code": "codellama"
      },
      "cost": "free",
      "priority": 1
    },
    "ollama_cloud": {
      "endpoint": "https://ollama.ai/api",
      "models": {
        "general": "llama2",
        "code": "codellama"
      },
      "cost": "bounded_fallback",
      "priority": 99,
      "enabled": false,
      "requires_config": "cloud_fallback_config.json"
    },
    "huggingface": {
      "endpoint": "https://api-inference.huggingface.co",
      "models": {
        "general": "microsoft/DialoGPT-medium",
        "code": "microsoft/codebert-base"
      },
      "cost": "free_tier",
      "priority": 98,
      "enabled": false
    }
  },
  "fallback_order": ["ollama", "ollama_cloud"],
  "fallback_policy": "adaptive_by_priority",
  "rate_limits": {
    "ollama": "unlimited",
    "ollama_cloud": "governed_by_config",
    "huggingface": "3000_requests/hour"
  }
}
```

**Actions:**

- [ ] Backup: `cp free_ai_config.json free_ai_config.json.backup`
- [ ] Update with cloud providers marked `"enabled": false` by default
- [ ] Add `"fallback_policy": "adaptive_by_priority"`
- [ ] Validate JSON syntax

### 1.5 Update Ollama Client (Bash) with Policy Enforcement

**Files to modify:**

- `ollama_client.sh`

**Changes to add:**

1. Load `cloud_fallback_config.json` at startup
2. Add policy enforcement function:
   - Check task priority
   - Track quota counters in `metrics/quota_tracker.json`
   - Implement circuit-breaker state tracking
   - Log justification when escalating to cloud
3. Append escalation record to `logs/cloud_escalation_log.jsonl`:
   ```json
   {"timestamp": "<ISO8601>", "task": "<task>", "priority": "<priority>", "reason": "<local_timeout|local_failure|model_missing>", "model_attempted": "<model>", "cloud_provider": "<provider>", "quota_remaining": <count>}
   ```
4. Update `dashboard_data.json` with escalation metrics

**Actions:**

- [ ] Backup: `cp ollama_client.sh ollama_client.sh.backup`
- [ ] Add policy loading near line 30 (after MODEL_REGISTRY load)
- [ ] Add quota tracking functions
- [ ] Add circuit-breaker state functions
- [ ] Add cloud escalation logging
- [ ] Test with dry-run: `echo '{"task":"codeGen","prompt":"test"}' | ./ollama_client.sh --dry-run`

### 1.6 Update Ollama Client (Python) with Policy Enforcement

**Files to modify:**

- `ollama_client.py`

**Changes:**
Mirror bash client changes:

1. Load `cloud_fallback_config.json`
2. Implement policy enforcement class
3. Add quota tracking
4. Add circuit-breaker logic
5. Log escalations

**Actions:**

- [ ] Backup: `cp ollama_client.py ollama_client.py.backup`
- [ ] Add `CloudFallbackPolicy` class
- [ ] Implement quota and circuit-breaker tracking
- [ ] Add escalation logging
- [ ] Test import: `python3 -c "import ollama_client; print('OK')"`

### 1.7 Update Ollama Client (Swift) with Policy Enforcement

**Files to modify:**

- `OllamaClient.swift`

**Changes:**

1. Add policy loading from `cloud_fallback_config.json`
2. Implement quota and circuit-breaker tracking
3. Add escalation logging

**Actions:**

- [ ] Backup: `cp OllamaClient.swift OllamaClient.swift.backup`
- [ ] Add `CloudFallbackPolicy` struct
- [ ] Implement tracking logic
- [ ] Compile check: `swiftc -parse OllamaClient.swift`

### 1.8 Route All Agent AI Calls via Policy-Aware Clients

**Files to audit and update:**

- `ai_enhanced_automation.sh`
- `ai_implementation_automation.sh`
- `ci_orchestrator.sh`
- `dashboard_unified.sh`
- `agents/testing_agent.sh`
- `agents/audit_agent.sh`
- `agents/ai_docs_agent.sh`
- `agents/ai_predictive_analytics_agent.sh`
- `agents/monitoring_agent.sh`
- `agents/security_agent.sh`
- `agents/predictive_analytics_agent.sh`
- `agents/ai_code_review_agent.sh`
- `agents/testing_agent_backup.sh`

**Changes:**
Replace direct `curl $OLLAMA_ENDPOINT` or `ollama run` calls with:

- Bash scripts: `./ollama_client.sh` or `./mcp_client.sh ai generate`
- Python scripts: `import ollama_client; ollama_client.generate(...)`

**Actions:**

- [ ] Create list of all files calling Ollama directly: `grep -r "ollama run\|curl.*11434" agents/ *.sh | cut -d: -f1 | sort -u > /tmp/ollama_callers.txt`
- [ ] For each file in list, replace direct calls with client adapter
- [ ] Test each modified script with `bash -n <script>` for syntax
- [ ] Mark complete when all direct calls routed through policy-aware clients

---

## Phase 2: Security Hardening & MCP Standardization

### 2.1 Create Keychain Secrets Helpers

**Files to verify/create:**

- `security/keychain_secrets.sh`
- `security/keychain.py`

**Actions:**

- [ ] Create `security/` directory
- [ ] Verify `keychain_secrets.sh` exists and is executable
- [ ] Verify `keychain.py` exists
- [ ] Test keychain access: `./security/keychain_secrets.sh get tools-automation-test || echo "OK if not found"`

### 2.2 Create .env Template

**Files to create:**

- `.env.example`

**Content:**

```bash
# Local-first Ollama Configuration
OLLAMA_ENDPOINT=http://localhost:11434
OLLAMA_CLOUD_ENDPOINT=https://ollama.ai/api
OLLAMA_CLOUD_API_KEY=your_api_key_here

# MCP Configuration
MCP_SERVER_URL=http://127.0.0.1:5005
MCP_AUTH_TOKEN=generate_with_mcp_auth_token_sh

# Dashboard
DASHBOARD_DATA=/Users/danielstevens/Desktop/github-projects/tools-automation/dashboard_data.json

# Secrets Mode (keychain|env)
SECRETS_MODE=keychain
```

**Actions:**

- [ ] Create `.env.example` with template above
- [ ] Verify `.env` is in `.gitignore`
- [ ] Add comment to `.env.example`: "Copy to .env and fill in values; prefer Keychain over .env"

### 2.3 Create MCP Auth Token Generator

**Files to create:**

- `security/mcp_auth_token.sh`

**Content:**

```bash
#!/bin/bash
# Generate and store MCP auth token in Keychain

SERVICE="tools-automation-mcp"
TOKEN=$(openssl rand -hex 32)

# Store in Keychain
security add-generic-password -a "$USER" -s "$SERVICE" -w "$TOKEN" -U 2>/dev/null || \
security delete-generic-password -a "$USER" -s "$SERVICE" 2>/dev/null && \
security add-generic-password -a "$USER" -s "$SERVICE" -w "$TOKEN" -U

echo "MCP auth token generated and stored in Keychain (service: $SERVICE)"
echo "Token: $TOKEN"
```

**Actions:**

- [ ] Create `security/mcp_auth_token.sh`
- [ ] Make executable: `chmod +x security/mcp_auth_token.sh`
- [ ] Run to generate token: `./security/mcp_auth_token.sh`
- [ ] Note token for MCP server configuration

### 2.4 Version MCP Endpoints and Add Local Auth

**Files to modify:**

- `mcp_server.py`

**Changes:**

1. Add endpoint versioning: `/v1/status`, `/v1/run`, `/v1/heartbeat`, `/v1/register`
2. Keep legacy endpoints with deprecation warnings
3. Add auth token verification in `do_POST` and `do_GET`:
   ```python
   def verify_auth(self):
       auth_header = self.headers.get('X-Auth-Token')
       expected_token = os.environ.get('MCP_AUTH_TOKEN') or get_keychain_token()
       return auth_header == expected_token
   ```
4. Bind to `127.0.0.1` only (confirm `HOST = '127.0.0.1'`)

**Actions:**

- [ ] Backup: `cp mcp_server.py mcp_server.py.backup`
- [ ] Add versioned endpoints with routing
- [ ] Add `verify_auth()` method
- [ ] Confirm `HOST = '127.0.0.1'` and no `0.0.0.0` binding
- [ ] Test syntax: `python3 -m py_compile mcp_server.py`

### 2.5 Update MCP Client with Versioned Endpoints and Auth

**Files to modify:**

- `mcp_client.sh`

**Changes:**

1. Update endpoints to `/v1/*`
2. Add `X-Auth-Token` header from Keychain or env
3. Update error handling for auth failures

**Actions:**

- [ ] Backup: `cp mcp_client.sh mcp_client.sh.backup`
- [ ] Update endpoint URLs to `/v1/status`, `/v1/run`, etc.
- [ ] Add auth token loading and header injection
- [ ] Test: `./mcp_client.sh --help`

### 2.6 Document MCP Endpoints

**Files to create:**

- `docs/MCP_ENDPOINTS.md`

**Content outline:**

- API version: v1
- Base URL: `http://127.0.0.1:5005`
- Authentication: `X-Auth-Token` header (local only)
- Endpoints:
  - `GET /v1/status` - Server health
  - `POST /v1/run` - Execute task
  - `POST /v1/heartbeat` - Agent heartbeat
  - `POST /v1/register` - Register agent
- Deprecations: `/status` → `/v1/status` (remove in v2)

**Actions:**

- [ ] Create `docs/` directory
- [ ] Create `docs/MCP_ENDPOINTS.md` with full API documentation
- [ ] Include auth requirements and local-only binding notice

### 2.7 Drop MCP Kit into Each Submodule

**Submodules to configure:**

- `CodingReviewer`
- `PlannerApp`
- `HabitQuest`
- `MomentumFinance`
- `AvoidObstaclesGame`
- `shared-kit`

**Files to create per submodule:**

1. `<submodule>/.tools-automation/mcp_client.sh` (shim to root)
2. `<submodule>/.tools-automation/mcp_config.json`
3. `<submodule>/.tools-automation/env.sh`
4. `<submodule>/.tools-automation/simple_mcp_check.sh`
5. `<submodule>/.tools-automation/README.md`

**Template content for `mcp_client.sh` shim:**

```bash
#!/bin/bash
# MCP client shim - forwards to root tools-automation
TOOLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec "${TOOLS_ROOT}/mcp_client.sh" "$@"
```

**Template for `mcp_config.json`:**

```json
{
  "mcp_server": {
    "url": "http://127.0.0.1:5005",
    "version": "v1"
  },
  "default_provider": "ollama",
  "providers": {
    "ollama": {
      "endpoint": "http://localhost:11434"
    }
  }
}
```

**Template for `env.sh`:**

```bash
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export MCP_URL="http://127.0.0.1:5005"
export OLLAMA_ENDPOINT="http://localhost:11434"
export DASHBOARD_DATA="${TOOLS_ROOT}/dashboard_data.json"
```

**Actions:**

- [ ] For each submodule, create `.tools-automation/` directory
- [ ] Add all 5 files per submodule with templates above
- [ ] Make scripts executable: `chmod +x .tools-automation/*.sh`
- [ ] Test shim: `<submodule>/.tools-automation/mcp_client.sh --help`
- [ ] Commit submodule changes

---

## Phase 3: Change Safety & Git Flow

### 3.1 Install Git Hooks

**Files to verify/create:**

- `git_hooks/pre-commit`
- `git_hooks/pre-push`
- `git_hooks/post-merge` (new)
- `install_hooks.sh`

**Actions:**

- [ ] Verify `git_hooks/pre-commit` exists
- [ ] Verify `git_hooks/pre-push` exists
- [ ] Create `git_hooks/post-merge` with test runner and rollback logic

**Content for `git_hooks/post-merge`:**

```bash
#!/bin/bash
# Post-merge hook: run tests and rollback on failure

set -e

echo "Running post-merge validation..."

# Run fast test suite
if ! ./ci_orchestrator.sh smoke; then
    echo "ERROR: Post-merge tests failed!"

    # Check error budget before rollback
    if ./scripts/check_error_budget.sh --can-rollback; then
        echo "Rolling back merge..."
        git reset --hard HEAD~1
        ./agents/auto_rollback.sh log-incident "post-merge-test-failure"
        exit 1
    else
        echo "ERROR: Tests failed but error budget exhausted - manual intervention required"
        exit 1
    fi
fi

echo "Post-merge validation passed"
```

**Actions:**

- [ ] Create `git_hooks/post-merge` with content above
- [ ] Make executable: `chmod +x git_hooks/post-merge`
- [ ] Update `install_hooks.sh` to install all three hooks
- [ ] Run: `./install_hooks.sh`

### 3.2 Create Error Budget Tracker

**Files to create:**

- `metrics/error_budget_tracker.json`
- `scripts/check_error_budget.sh`

**Content for `metrics/error_budget_tracker.json`:**

```json
{
  "version": "1.0",
  "services": {
    "post_merge_tests": {
      "budget_percent": 5.0,
      "window_hours": 24,
      "current_failures": 0,
      "total_runs": 0,
      "last_reset": "2025-11-06T00:00:00Z"
    },
    "agent_health": {
      "budget_percent": 2.0,
      "window_hours": 24,
      "current_failures": 0,
      "total_runs": 0,
      "last_reset": "2025-11-06T00:00:00Z"
    }
  }
}
```

**Content for `scripts/check_error_budget.sh`:**

```bash
#!/bin/bash
# Check if service error budget allows rollback

SERVICE="${1:-post_merge_tests}"
TRACKER="metrics/error_budget_tracker.json"

if [[ "$2" == "--can-rollback" ]]; then
    # Read current failure rate
    FAILURES=$(jq -r ".services.${SERVICE}.current_failures" "$TRACKER")
    TOTAL=$(jq -r ".services.${SERVICE}.total_runs" "$TRACKER")
    BUDGET=$(jq -r ".services.${SERVICE}.budget_percent" "$TRACKER")

    if (( TOTAL == 0 )); then
        echo "true"
        exit 0
    fi

    RATE=$(awk "BEGIN {print ($FAILURES / $TOTAL) * 100}")

    if (( $(echo "$RATE < $BUDGET" | bc -l) )); then
        echo "true"
        exit 0
    else
        echo "false - error budget exhausted ($RATE% >= $BUDGET%)"
        exit 1
    fi
fi
```

**Actions:**

- [ ] Create `metrics/` directory
- [ ] Create `metrics/error_budget_tracker.json`
- [ ] Create `scripts/check_error_budget.sh`
- [ ] Make executable: `chmod +x scripts/check_error_budget.sh`
- [ ] Test: `./scripts/check_error_budget.sh post_merge_tests --can-rollback`

### 3.3 Add Retry Window to Test Runners

**Files to modify:**

- `ci_orchestrator.sh`
- `comprehensive_test_generator.sh`
- `automated_deployment_pipeline.sh`

**Changes to add:**
Add retry logic with configurable policy:

```bash
RETRY_POLICY="${RETRY_POLICY:-ci}"  # ci|local|none
RETRY_COUNT=2
RETRY_DELAY=5

run_with_retry() {
    local cmd="$1"
    local attempt=1

    if [[ "$RETRY_POLICY" == "local" || "$RETRY_POLICY" == "none" ]]; then
        eval "$cmd"
        return $?
    fi

    while (( attempt <= RETRY_COUNT + 1 )); do
        if eval "$cmd"; then
            return 0
        fi

        if (( attempt <= RETRY_COUNT )); then
            echo "Attempt $attempt failed, retrying in ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        fi

        ((attempt++))
    done

    return 1
}
```

**Actions:**

- [ ] Add retry function to each test runner script
- [ ] Wrap test invocations with `run_with_retry`
- [ ] Test with `RETRY_POLICY=ci`: `RETRY_POLICY=ci ./ci_orchestrator.sh smoke`
- [ ] Test with `RETRY_POLICY=local`: `RETRY_POLICY=local ./ci_orchestrator.sh smoke`

### 3.4 Create Auto-Rollback Agent

**Files to create:**

- `agents/auto_rollback.sh`

**Content outline:**

```bash
#!/bin/bash
# Auto-rollback agent for handling failures

AGENT_NAME="auto_rollback.sh"
LOG_FILE="agents/auto_rollback.log"

log_incident() {
    local reason="$1"
    local incident_id="$(date +%Y%m%d_%H%M%S)_${reason}"
    local incident_dir="incidents/${incident_id}"

    mkdir -p "$incident_dir"

    # Capture state
    git log -1 > "${incident_dir}/last_commit.txt"
    cp dashboard_data.json "${incident_dir}/"
    cp logs/cloud_escalation_log.jsonl "${incident_dir}/" 2>/dev/null || true

    echo "Incident logged: ${incident_dir}"
}

# Main logic
case "$1" in
    log-incident)
        log_incident "$2"
        ;;
    *)
        echo "Usage: $0 {log-incident} <reason>"
        exit 1
        ;;
esac
```

**Actions:**

- [ ] Create `agents/auto_rollback.sh`
- [ ] Make executable
- [ ] Test: `./agents/auto_rollback.sh log-incident test-incident`
- [ ] Verify `incidents/` directory created with logs

### 3.5 Update Merge Guard

**Files to verify:**

- `merge_guard.sh`

**Actions:**

- [ ] Verify `merge_guard.sh` exists and runs tests
- [ ] Ensure it's called before any merge operations
- [ ] Test: `./merge_guard.sh`

---

## Phase 4: Dependency Graph Agent

### 4.1 Create Dependency Graph Agent

**Files to create:**

- `agents/dependency_graph_agent.sh`

**Content outline:**

```bash
#!/bin/bash
# Dependency Graph Agent: Monitor submodule relationships and impact

AGENT_NAME="dependency_graph_agent.sh"
LOG_FILE="agents/dependency_graph_agent.log"
WORKSPACE_ROOT="/Users/danielstevens/Desktop/github-projects/tools-automation"
GRAPH_FILE="${WORKSPACE_ROOT}/dependency_graph.json"
SCAN_INTERVAL="${SCAN_INTERVAL:-600}"  # 10 minutes

log_message() {
    echo "[$(date)] [${AGENT_NAME}] $*" | tee -a "${LOG_FILE}"
}

# Scan Package.swift files for dependencies
scan_swift_dependencies() {
    local project="$1"
    local package_file="${project}/Package.swift"

    if [[ -f "$package_file" ]]; then
        # Extract dependencies
        grep -A 5 'dependencies:' "$package_file" | \
        grep '.package' | \
        sed 's/.*name: "\([^"]*\)".*/\1/' || echo "[]"
    fi
}

# Build dependency graph
build_graph() {
    log_message "Building dependency graph..."

    local graph='{"version":"1.0","updated":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","nodes":[],"edges":[]}'

    # Scan submodules
    for submodule in CodingReviewer PlannerApp HabitQuest MomentumFinance AvoidObstaclesGame shared-kit; do
        if [[ -d "$submodule" ]]; then
            log_message "Scanning $submodule..."

            # Add node
            graph=$(echo "$graph" | jq ".nodes += [{\"name\":\"$submodule\",\"type\":\"submodule\"}]")

            # Scan dependencies
            deps=$(scan_swift_dependencies "$submodule")

            # Add edges
            for dep in $deps; do
                if [[ -n "$dep" && "$dep" != "[]" ]]; then
                    graph=$(echo "$graph" | jq ".edges += [{\"from\":\"$submodule\",\"to\":\"$dep\"}]")
                fi
            done
        fi
    done

    echo "$graph" > "$GRAPH_FILE"
    log_message "Dependency graph updated: $GRAPH_FILE"
}

# Main loop
log_message "Starting Dependency Graph Agent..."

while true; do
    build_graph
    sleep "$SCAN_INTERVAL"
done
```

**Actions:**

- [ ] Create `agents/dependency_graph_agent.sh`
- [ ] Make executable: `chmod +x agents/dependency_graph_agent.sh`
- [ ] Test run: `timeout 10 bash agents/dependency_graph_agent.sh`
- [ ] Verify `dependency_graph.json` created
- [ ] Review graph structure with: `jq . dependency_graph.json`

### 4.2 Integrate Dependency Graph with Task Orchestrator

**Files to modify:**

- `agents/task_orchestrator.sh`

**Changes:**
Add dependency graph awareness:

1. Load `dependency_graph.json` on startup
2. Order tasks by dependency priority (e.g., `shared-kit` first)
3. Gate cross-project changes with impact analysis

**Actions:**

- [ ] Backup: `cp agents/task_orchestrator.sh agents/task_orchestrator.sh.backup`
- [ ] Add graph loading function
- [ ] Add task ordering by dependencies
- [ ] Test with sample tasks

---

## Phase 5: Launchd Scheduling

### 5.1 Fix Existing Launchd Plists

**Files to audit and fix:**

- `com.quantum.mcp.plist`
- `~/Library/LaunchAgents/com.tools.ollama.serve.plist`

**Changes needed:**

1. Fix paths to absolute workspace path
2. Add `EnvironmentVariables` with proper PATH
3. Fix log paths to `~/Library/Logs/tools-automation/`
4. Add `RunAtLoad`, `KeepAlive`, `ThrottleInterval`

**Template for fixed plist:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tools.ollama.serve</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/ollama</string>
        <string>serve</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>60</integer>
    <key>StandardOutPath</key>
    <string>/Users/danielstevens/Library/Logs/tools-automation/ollama-serve.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/danielstevens/Library/Logs/tools-automation/ollama-serve-error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
```

**Actions:**

- [ ] Create log directory: `mkdir -p ~/Library/Logs/tools-automation/`
- [ ] Fix `com.quantum.mcp.plist` with correct paths
- [ ] Move to LaunchAgents: `cp com.quantum.mcp.plist ~/Library/LaunchAgents/`
- [ ] Verify Ollama plist exists and is correct
- [ ] Create validation script (see next step)

### 5.2 Create Launchd Validation Script

**Files to create:**

- `scripts/validate_launchd.sh`

**Content:**

```bash
#!/bin/bash
# Validate and manage launchd plists

PLIST_DIR="$HOME/Library/LaunchAgents"
PLISTS=(
    "com.tools.ollama.serve"
    "com.quantum.mcp"
)

validate_plist() {
    local name="$1"
    local plist="${PLIST_DIR}/${name}.plist"

    echo "Validating $name..."

    if [[ ! -f "$plist" ]]; then
        echo "  ERROR: Plist not found: $plist"
        return 1
    fi

    if ! plutil -lint "$plist" >/dev/null 2>&1; then
        echo "  ERROR: Invalid plist syntax"
        return 1
    fi

    echo "  OK"
    return 0
}

load_plist() {
    local name="$1"
    local plist="${PLIST_DIR}/${name}.plist"

    echo "Loading $name..."
    launchctl unload "$plist" 2>/dev/null || true
    launchctl load "$plist"
}

# Main
for plist in "${PLISTS[@]}"; do
    if validate_plist "$plist"; then
        if [[ "$1" == "--load" ]]; then
            load_plist "$plist"
        fi
    fi
done
```

**Actions:**

- [ ] Create `scripts/validate_launchd.sh`
- [ ] Make executable
- [ ] Run validation: `./scripts/validate_launchd.sh`
- [ ] Load services: `./scripts/validate_launchd.sh --load`
- [ ] Verify services running: `launchctl list | grep com.tools`

### 5.3 Create LaunchAgent Plists for Key Agents

**Agents to schedule:**

- `agent_monitoring.sh`
- `task_orchestrator.sh`
- `dependency_graph_agent.sh`
- `dashboard_unified.sh`

**Actions:**

- [ ] Create plist for each agent in `monitoring/launchd/`
- [ ] Follow template from step 5.1
- [ ] Set appropriate `StartInterval` or `StartCalendarInterval`
- [ ] Copy to `~/Library/LaunchAgents/`
- [ ] Load with validation script

### 5.4 Deconflict Cron Jobs

**Files to check:**

- Crontab: `crontab -l`
- `setup_cron_cleanup.sh`

**Actions:**

- [ ] List current cron jobs: `crontab -l > /tmp/crontab_backup.txt`
- [ ] Identify duplicates with launchd schedules
- [ ] Remove cron entries that are now in launchd
- [ ] Document decision in `docs/SCHEDULING.md`

---

## Phase 6: Observability & Monitoring

### 6.1 Extend Agent Monitoring with Submodule Support

**Files to modify:**

- `agent_monitoring.sh`

**Changes:**

1. Add submodule scanning
2. Tag metrics with `project` and `submodule` fields
3. Scrape MCP health endpoints per submodule
4. Collect per-submodule coverage data

**Actions:**

- [ ] Backup: `cp agent_monitoring.sh agent_monitoring.sh.backup`
- [ ] Add submodule iteration loop
- [ ] Add project/submodule tagging to metrics
- [ ] Test: `./agent_monitoring.sh --once`

### 6.2 Extend Dashboard with New Metrics

**Files to modify:**

- `dashboard_unified.sh`
- `dashboard_data.json` (structure)

**New metrics to add:**

- Task throughput (tasks/minute)
- Agent uptime (seconds)
- Error budget status per service
- AI fallback rate (cloud escalations / total requests)
- Per-submodule coverage percentage

**Dashboard data structure update:**

```json
{
  "timestamp": "2025-11-06T...",
  "throughput": {
    "tasks_per_minute": 0.5,
    "total_tasks_24h": 720
  },
  "uptime": {
    "agent_monitoring": 86400,
    "task_orchestrator": 86400,
    "dependency_graph": 86400
  },
  "error_budgets": {
    "post_merge_tests": {
      "current_rate": 0.5,
      "budget": 5.0,
      "status": "healthy"
    }
  },
  "ai_metrics": {
    "fallback_rate": 0.02,
    "escalation_count": 5,
    "quota_remaining": {
      "critical": 45,
      "high": 18
    }
  },
  "coverage": {
    "tools-automation": 75,
    "CodingReviewer": 60,
    "PlannerApp": 55,
    "HabitQuest": 50,
    "MomentumFinance": 45,
    "AvoidObstaclesGame": 40,
    "shared-kit": 80
  }
}
```

**Actions:**

- [ ] Backup dashboard scripts
- [ ] Update `dashboard_data.json` structure
- [ ] Modify `dashboard_unified.sh` to populate new fields
- [ ] Test dashboard generation: `./dashboard_unified.sh`
- [ ] View in browser: `open http://localhost:8080`

### 6.3 Configure Trend-Based Alerts

**Files to modify:**

- `alert_config.json`

**Changes:**
Add trend detection and deduplication:

```json
{
  "alert_channels": {
    "email": {
      "enabled": true,
      "smtp_host": "smtp.gmail.com",
      "smtp_port": 587,
      "from": "dboon323@gmail.com",
      "to": ["dboon323@gmail.com"]
    }
  },
  "alert_levels": {
    "CRITICAL": {
      "immediate": true,
      "max_per_hour": 10,
      "cooldown_minutes": 5
    },
    "HIGH": {
      "immediate": true,
      "max_per_hour": 20,
      "cooldown_minutes": 10
    },
    "MEDIUM": {
      "immediate": false,
      "digest": "daily"
    },
    "LOW": {
      "immediate": false,
      "digest": "weekly"
    }
  },
  "trend_detection": {
    "enabled": true,
    "window_hours": 24,
    "thresholds": {
      "error_rate_increase": 50,
      "fallback_rate_increase": 100,
      "coverage_decrease": 10
    }
  },
  "deduplication": {
    "enabled": true,
    "window_minutes": 60,
    "max_duplicates": 3
  }
}
```

**Actions:**

- [ ] Backup: `cp alert_config.json alert_config.json.backup`
- [ ] Add trend detection configuration
- [ ] Add deduplication rules
- [ ] Test alert system: `./email_alert_system.sh test`

---

## Phase 7: Testing & Validation

### 7.1 Generate Missing Tests for All Projects

**Actions:**

- [ ] Run for root: `./comprehensive_test_generator.sh`
- [ ] Run for each submodule:
  ```bash
  for submodule in CodingReviewer PlannerApp HabitQuest MomentumFinance AvoidObstaclesGame shared-kit; do
    cd "$submodule"
    ../comprehensive_test_generator.sh
    cd ..
  done
  ```
- [ ] Generate Swift tests: `./ai_generate_swift_tests.sh`
- [ ] Review generated tests for quality

### 7.2 Run Coverage Analysis

**Actions:**

- [ ] Run coverage for root: `./analyze_coverage.sh`
- [ ] Run for each submodule recursively
- [ ] Aggregate results into `metrics/coverage/`
- [ ] Set coverage targets per project

### 7.3 Setup Pre-commit Hooks for Fast Tests

**Actions:**

- [ ] Ensure `git_hooks/pre-commit` runs fast test suite
- [ ] Set timeout to <2 minutes
- [ ] Test: make a dummy commit and verify hook runs

### 7.4 Create Nightly Full Test Suite via Launchd

**Files to create:**

- `~/Library/LaunchAgents/com.tools.automation.nightly-tests.plist`

**Content:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tools.automation.nightly-tests</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/danielstevens/Desktop/github-projects/tools-automation/run_integration_tests.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/danielstevens/Library/Logs/tools-automation/nightly-tests.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/danielstevens/Library/Logs/tools-automation/nightly-tests-error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
```

**Actions:**

- [ ] Create plist for nightly tests
- [ ] Load: `launchctl load ~/Library/LaunchAgents/com.tools.automation.nightly-tests.plist`
- [ ] Verify: `launchctl list | grep nightly-tests`

---

## Phase 8: End-to-End Validation

### 8.1 Test Cloud Escalation Policy

**Actions:**

- [ ] Temporarily set a high-priority task to fail locally
- [ ] Verify cloud escalation triggers
- [ ] Check `logs/cloud_escalation_log.jsonl` for entry
- [ ] Verify quota decremented
- [ ] Check circuit-breaker state
- [ ] Verify metrics in `dashboard_data.json`

### 8.2 Test MCP Endpoints

**Actions:**

- [ ] Test health: `curl -H "X-Auth-Token: $TOKEN" http://127.0.0.1:5005/v1/status`
- [ ] Test from submodule: `cd CodingReviewer && ./.tools-automation/simple_mcp_check.sh`
- [ ] Verify auth rejection: `curl http://127.0.0.1:5005/v1/status` (should fail)

### 8.3 Test Git Flow with Rollback

**Actions:**

- [ ] Create test branch: `git checkout -b test-rollback`
- [ ] Make breaking change
- [ ] Commit and merge to main
- [ ] Verify post-merge hook triggers
- [ ] Verify rollback occurs if tests fail
- [ ] Check incident logged in `incidents/`

### 8.4 Test Dependency Graph Agent

**Actions:**

- [ ] Verify `dependency_graph_agent.sh` running: `ps aux | grep dependency_graph`
- [ ] Check graph file: `cat dependency_graph.json | jq .`
- [ ] Verify nodes for all submodules
- [ ] Verify edges showing dependencies

### 8.5 Validate All Services Running

**Actions:**

- [ ] Check launchd services: `launchctl list | grep com.tools`
- [ ] Check agent processes: `ps aux | grep -E "agent|monitor|orchestrator"`
- [ ] Check logs for errors: `tail -n 50 ~/Library/Logs/tools-automation/*.log`
- [ ] Verify dashboard accessible: `open http://localhost:8080`

---

## Phase 9: Documentation & Finalization

### 9.1 Update Master Plan

**Files to modify:**

- `AGENT_ENHANCEMENT_MASTER_PLAN.md`

**Sections to add:**

- Cloud fallback governance
- MCP standardization
- Local Git flow with auto-rollback
- Dependency graph coordination
- Observability and trend alerts

**Actions:**

- [ ] Backup: `cp AGENT_ENHANCEMENT_MASTER_PLAN.md AGENT_ENHANCEMENT_MASTER_PLAN.md.backup`
- [ ] Add new sections documenting all phases
- [ ] Update architecture diagrams (if any)
- [ ] Add troubleshooting guide

### 9.2 Create Runbook

**Files to create:**

- `docs/RUNBOOK.md`

**Content sections:**

- Starting/stopping services
- Checking agent health
- Viewing metrics and alerts
- Common troubleshooting scenarios
- Emergency rollback procedures
- Quota management

**Actions:**

- [ ] Create comprehensive runbook
- [ ] Include all `launchctl` commands
- [ ] Add monitoring commands
- [ ] Include incident response procedures

### 9.3 Create Architecture Diagram

**Files to create:**

- `docs/ARCHITECTURE.md`

**Content:**

- System overview
- Component interactions
- Data flow diagrams
- MCP endpoint mapping
- Dependency graph visualization

**Actions:**

- [ ] Document architecture
- [ ] Create ASCII art diagrams or link to external tool
- [ ] Explain each component's role

---

## Success Criteria Checklist

### Core Requirements

- [ ] All agents route AI calls through policy-aware clients
- [ ] Cloud fallback only triggers for high-priority tasks within quotas
- [ ] Circuit-breaker prevents runaway cloud usage
- [ ] All escalations logged with justification
- [ ] MCP endpoints versioned and auth-protected
- [ ] Local-only binding confirmed (no external exposure)
- [ ] Secrets in Keychain with .env fallback
- [ ] All 6 submodules have MCP kit installed
- [ ] Dependency graph agent running and producing graph
- [ ] Git hooks installed: pre-commit, pre-push, post-merge
- [ ] Merge-on-green enforced via merge_guard.sh
- [ ] Auto-rollback triggers on test failures respecting error budget
- [ ] Retry windows implemented in test runners
- [ ] LaunchAgents configured and running for key services
- [ ] No duplicate cron/launchd schedules
- [ ] Monitoring extended with submodule metrics
- [ ] Dashboard shows all new metrics (throughput, uptime, fallback rate, coverage)
- [ ] Trend-based alerts configured
- [ ] Test coverage >80% target set
- [ ] Nightly test suite scheduled
- [ ] Documentation complete (runbook, architecture, endpoints)

### Validation Tests

- [ ] Cloud escalation test passed
- [ ] MCP auth test passed
- [ ] Rollback test passed
- [ ] Dependency graph test passed
- [ ] All launchd services healthy
- [ ] Dashboard accessible and showing data
- [ ] Alerts sending correctly

---

## Best Practices Summary

### 1. Adaptive AI Policy

- **Circuit-breaker tuning**: Default 3 failures/10 minutes per task; per-task overrides in `config/cloud_fallback_config.json`
- **Implementation**: Tracks failure rate per task; trips breaker when threshold exceeded; resets after cooldown period
- **Monitoring**: All breaker trips logged and visible in dashboard

### 2. Secrets Management

- **Secrets fallback**: If Keychain unavailable, `.env` fallback continues with warning and metrics tag `secrets_mode=env` for audits
- **Implementation**: Try Keychain first via `security` CLI; if fails, read from `.env`; log mode in all metrics
- **Audit trail**: Every secret access logged with source (keychain/env) for compliance

### 3. Retry Policy Modes

- **Retry modes**: Enable retries in CI by default; allow `RETRY_POLICY=local` to skip retries for developer workflows
- **Implementation**: Check `RETRY_POLICY` env var; `ci` mode does 2 retries with 5s backoff; `local` mode skips retries
- **Usage**: Export `RETRY_POLICY=local` in local shell for fast iteration; CI always uses default `ci` mode

### 4. Error Budget Respect

- **Flaky test protection**: Don't rollback on first failure; check error budget first
- **Implementation**: Track failure rate per service; only rollback if rate exceeds budget
- **Grace period**: Allows transient failures without disrupting workflow

### 5. Observability First

- **Log everything**: Every decision, escalation, failure logged with context
- **Trend detection**: Alert on trends (increasing errors) not just spikes
- **Deduplication**: Prevent alert fatigue with smart grouping

---

## Quick Start Commands

After completing all phases, use these commands for daily operations:

```bash
# Check all services
launchctl list | grep com.tools

# View dashboard
open http://localhost:8080

# Check agent health
./agent_monitoring.sh --once

# View recent escalations
tail -20 logs/cloud_escalation_log.jsonl | jq .

# Check error budgets
./scripts/check_error_budget.sh post_merge_tests

# View dependency graph
jq . dependency_graph.json

# Manual test run
RETRY_POLICY=local ./ci_orchestrator.sh smoke

# View logs
tail -f ~/Library/Logs/tools-automation/*.log
```

---

## Troubleshooting

### Services Not Starting

```bash
# Validate plists
./scripts/validate_launchd.sh

# Check logs
tail -50 ~/Library/Logs/tools-automation/*.log

# Restart service
launchctl unload ~/Library/LaunchAgents/com.tools.*.plist
launchctl load ~/Library/LaunchAgents/com.tools.*.plist
```

### Cloud Escalations Too Frequent

```bash
# Check quota status
jq .ai_metrics.quota_remaining dashboard_data.json

# Review escalation log
tail -50 logs/cloud_escalation_log.jsonl | jq .

# Adjust quotas
vi config/cloud_fallback_config.json
```

### Agents Not Creating Tasks

```bash
# Check agent logs
ls -lt agents/*.log | head -5

# Check task queue
jq . agents/task_queue.json

# Check agent status
jq . agent_status.json
```

---

**End of Checklist**

This comprehensive execution plan achieves 100% autonomy with local-first operations, bounded cloud fallback, cross-project coordination, and robust safety mechanisms. Follow phases sequentially for best results.
