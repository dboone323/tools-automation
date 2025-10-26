#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../.. && pwd)"
AGENTS_DIR="$ROOT_DIR/Tools/Automation/agents"
KNOWLEDGE_DIR="$AGENTS_DIR/knowledge"

pass() { echo "[PASS] $1"; }
fail() {
    echo "[FAIL] $1"
    exit 1
}

# 1) Run integration
"$AGENTS_DIR/integrate_phase4.sh"

# 2) Validate analytics.json
[[ -s "$KNOWLEDGE_DIR/analytics.json" ]] || fail "analytics.json missing"

if command -v jq >/dev/null 2>&1; then
    OVERALL=$(jq -r '.overall_success_rate // empty' "$KNOWLEDGE_DIR/analytics.json" || true)
    [[ -n "$OVERALL" ]] || fail "overall_success_rate missing"
fi
pass "analytics.json generated"

# 3) Dashboard works
"$AGENTS_DIR/metrics_dashboard.py" show --refresh 1>/dev/null || fail "dashboard show failed"
pass "dashboard show"

# 4) Orchestrator assign
ASSIGN_OUT=$("$AGENTS_DIR/orchestrator_v2.py" assign --task '{"id":"t-123","type":"test","priority":2}')
[[ -n "$ASSIGN_OUT" ]] || fail "orchestrator assign output empty"
pass "orchestrator assign"

# 5) AI Integration
AI_OUT=$("$AGENTS_DIR/ai_integration.py" analyze --text "Null reference crash in viewDidLoad")
[[ -n "$AI_OUT" ]] || fail "ai integration analyze output empty"
pass "ai integration analyze"

echo "[OK] Phase 4 integration tests completed successfully"
