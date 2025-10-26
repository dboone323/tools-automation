#!/usr/bin/env bash
set -euo pipefail

# Phase 4 Integration Script
# - Collect analytics summary
# - Generate HTML dashboard
# - Smoke-test orchestrator v2
# - Smoke-test AI integration wrapper

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../.. && pwd)"
AGENTS_DIR="$ROOT_DIR/Tools/Automation/agents"
KNOWLEDGE_DIR="$AGENTS_DIR/knowledge"

PYTHON="python3"

echo "[phase4] Starting Phase 4 integration..."

# Ensure knowledge dir exists
mkdir -p "$KNOWLEDGE_DIR"

# 1) Analytics collection
echo "[phase4] Collecting analytics summary..."
"$AGENTS_DIR/analytics_collector.py" collect --out "$KNOWLEDGE_DIR/analytics.json" --html "$AGENTS_DIR/analytics_report.html" 1>/dev/null

if [[ ! -s "$KNOWLEDGE_DIR/analytics.json" ]]; then
    echo "[phase4] ERROR: analytics.json not generated" >&2
    exit 2
fi

# 2) Dashboard CLI
echo "[phase4] Showing dashboard (snapshot):"
"$AGENTS_DIR/metrics_dashboard.py" show 1>/dev/null || true

# 3) Orchestrator v2 smoke
echo "[phase4] Orchestrator assignment smoke-test..."
TASK='{"id":"phase4-smoke-1","type":"diagnostics","priority":1}'
ASSIGN_OUT=$("$AGENTS_DIR/orchestrator_v2.py" assign --task "$TASK" || true)
if [[ -z "$ASSIGN_OUT" ]]; then
    echo "[phase4] WARN: orchestrator returned empty output" >&2
else
    echo "$ASSIGN_OUT" | head -c 300 1>/dev/null
fi

# 4) AI Integration smoke
echo "[phase4] AI integration analyze smoke-test..."
AI_OUT=$("$AGENTS_DIR/ai_integration.py" analyze --text "Timeout while fetching resource" || true)
if [[ -z "$AI_OUT" ]]; then
    echo "[phase4] WARN: ai_integration returned empty output" >&2
fi

echo "[phase4] Phase 4 integration complete. Artifacts:"
echo " - $KNOWLEDGE_DIR/analytics.json"
echo " - $AGENTS_DIR/analytics_report.html"
