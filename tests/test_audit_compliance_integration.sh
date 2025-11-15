#!/bin/bash

# Simple integration test for audit_compliance.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Running audit_compliance integration test..."

# Ensure init
./audit_compliance.sh init

# Clean existing events
: >audit_config/audit_events.jsonl

# Log a couple of events
./audit_compliance.sh log authentication admin login / success "initial login"
./audit_compliance.sh log authorization admin permission_check system.config granted "test"

# Ensure events appended
cnt=$(jq -s 'length' audit_config/audit_events.jsonl)
if [[ "$cnt" -lt 2 ]]; then
    echo "FAIL: expected at least 2 events, got $cnt"
    exit 2
fi

echo "Events logged: $cnt"

# Run SOX report (should succeed and output JSON)
report=$(./audit_compliance.sh report SOX)
framework=$(echo "$report" | jq -r '.framework')
if [[ "$framework" != "SOX" ]]; then
    echo "FAIL: expected framework SOX, got $framework"
    echo "$report"
    exit 3
fi

# Run a query and assert we get at least one authentication event
auth_count=$(./audit_compliance.sh query "event_type=authentication" | jq -s 'length')
if [[ "$auth_count" -lt 1 ]]; then
    echo "FAIL: expected authentication events in query, got $auth_count"
    exit 4
fi

echo "OK: audit_compliance integration test passed — continuing extended checks"

# Additional tests: cleanup old events and missing-required-event detection
echo "Running cleanup and missing-event checks..."

# Append an old event that should be removed by cleanup
cat >>audit_config/audit_events.jsonl <<'EOF'
{"event_id":"old_evt","timestamp":"2000-01-01T00:00:00Z","event_type":"authentication","username":"legacy","action":"login","resource":"/","result":"success","details":"old"}
EOF

total_before=$(jq -s 'length' audit_config/audit_events.jsonl)
echo "Total events before cleanup: $total_before"

# Run cleanup to remove events older than 365 days
./audit_compliance.sh cleanup 365

total_after=$(jq -s 'length' audit_config/audit_events.jsonl)
if [[ "$total_after" -ge "$total_before" ]]; then
    echo "FAIL: cleanup did not remove old events (before=$total_before after=$total_after)"
    exit 5
fi
echo "Cleanup removed old events: before=$total_before after=$total_after"

# Test missing required event detection by injecting a test framework
cp audit_config/audit_config.json audit_config/audit_config.json.bak
jq '.compliance_requirements["TEST-MISSING"] = {retention_period_days:365, required_events:["code_changes"]}' audit_config/audit_config.json >audit_config/audit_config.json.tmp && mv audit_config/audit_config.json.tmp audit_config/audit_config.json

report2=$(./audit_compliance.sh report TEST-MISSING)
violations=$(echo "$report2" | jq -r '.violations[]?') || true
if echo "$violations" | grep -q "code_changes"; then
    echo "Detected missing required event: code_changes"
else
    echo "FAIL: expected missing required event code_changes in report"
    echo "$report2"
    # restore
    mv audit_config/audit_config.json.bak audit_config/audit_config.json
    exit 6
fi

# restore config
mv audit_config/audit_config.json.bak audit_config/audit_config.json

echo "All extended audit tests passed"
exit 0
