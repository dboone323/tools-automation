#!/bin/bash

# Lightweight portable audit and compliance tool for Phase 17

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_CONFIG_DIR="$WORKSPACE_ROOT/audit_config"
AUDIT_LOG="$WORKSPACE_ROOT/logs/audit.log"
AUDIT_EVENTS_DB="$AUDIT_CONFIG_DIR/audit_events.jsonl"
COMPLIANCE_REPORTS_DIR="$WORKSPACE_ROOT/compliance_reports"

mkdir -p "$AUDIT_CONFIG_DIR" "$COMPLIANCE_REPORTS_DIR" "$WORKSPACE_ROOT/logs"

log() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $*" >>"$AUDIT_LOG"
    echo "[$ts] $*" >&2
}

init_audit_system() {
    [[ -f "$AUDIT_EVENTS_DB" ]] || touch "$AUDIT_EVENTS_DB"
    cat >"$AUDIT_CONFIG_DIR/audit_config.json" <<'EOF'
{
    "audit_settings": { "enabled": true, "retention_days": 365 },
    "compliance_requirements": {
        "SOX": {
            "retention_period_days": 2555,
            "required_events": ["authentication", "authorization", "system_config", "code_changes"],
            "alert_thresholds": { "failed_auth_attempts": 5 }
        },
        "GDPR": {
            "retention_period_days": 2555,
            "required_events": ["data_access", "user_management", "authentication"]
        },
        "HIPAA": {
            "retention_period_days": 2555,
            "required_events": ["data_access", "authentication", "security_events"]
        },
        "PCI-DSS": {
            "retention_period_days": 365,
            "required_events": ["authentication", "data_access", "security_events"]
        }
    }
}
EOF
    log "Initialized audit system"
}

# Append a JSONL audit event
log_audit_event() {
    local event_type="$1" username="$2" action="$3" resource="$4" result="${5:-success}" details="${6:-}"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq -n --arg id "audit_$(date +%s)_$RANDOM" --arg timestamp "$ts" --arg event_type "$event_type" --arg username "$username" --arg action "$action" --arg resource "$resource" --arg result "$result" --arg details "$details" '{event_id: $id, timestamp: $timestamp, event_type: $event_type, username: $username, action: $action, resource: $resource, result: $result, details: $details, compliance_flags: []}' >>"$AUDIT_EVENTS_DB"
    log "Audit event: $event_type $action by $username on $resource ($result)"
}

# Simple compliance report (framework, optional start/end YYYY-MM-DD)
generate_compliance_report() {
    local framework="$1" start_date="${2:-}" end_date="${3:-}"
    if [[ -z "$start_date" ]]; then
        start_date=$(
            python3 <<PY
from datetime import datetime, timedelta, timezone
import sys
sys.stdout.write((datetime.now(timezone.utc)-timedelta(days=30)).strftime('%Y-%m-%d') + "\n")
PY
        )
    fi
    if [[ -z "$end_date" ]]; then
        end_date=$(date -u +%Y-%m-%d)
    fi
    log "Generating $framework report $start_date..$end_date"
    # select events
    local events
    events=$(jq -c "select(.timestamp[:10] >= \"$start_date\" and .timestamp[:10] <= \"$end_date\")" "$AUDIT_EVENTS_DB" 2>/dev/null || echo "[]")
    local total
    total=$(echo "$events" | jq -s 'length')
    # basic required events check — iterate required_events directly via jq for robustness
    local score=100
    local violations=()
    local reqs
    reqs=$(jq -r ".compliance_requirements.\"$framework\".required_events[]?" "$AUDIT_CONFIG_DIR/audit_config.json" 2>/dev/null || true)
    if [[ -n "$reqs" ]]; then
        while IFS= read -r r; do
            [[ -z "$r" ]] && continue
            cnt=$(echo "$events" | jq -s "[.[] | select(.event_type == \"$r\")] | length")
            if ((cnt == 0)); then
                violations+=("Missing required event: $r")
                ((score -= 20))
            fi
        done <<<"$reqs"
    fi
    local violations_json
    local violations_count
    violations_count=${#violations[@]}
    if [[ $violations_count -eq 0 ]]; then
        violations_json='[]'
    else
        violations_json=$(printf '%s\n' "${violations[@]}" | jq -R -s -c 'split("\n")[:-1]')
    fi
    jq -n --arg framework "$framework" --arg start_date "$start_date" --arg end_date "$end_date" --argjson total "$total" --argjson score "$score" --argjson violations "$violations_json" '{framework: $framework, period: {start: $start_date, end: $end_date}, summary: {total_events: $total, compliance_score: $score}, violations: $violations}'
}

query_audit_events() {
    local filters="$1"
    if [[ -z "$filters" ]]; then
        jq '.' "$AUDIT_EVENTS_DB"
    else
        local fjq='.'
        IFS=',' read -ra fa <<<"$filters"
        for kv in "${fa[@]}"; do
            IFS='=' read -ra p <<<"$kv"
            # Use bracket/key access in jq and properly quote variables to avoid word-splitting
            fjq="$fjq | select(.\"${p[0]}\" == \"${p[1]}\")"
        done
        jq "$fjq" "$AUDIT_EVENTS_DB"
    fi
}

cleanup_audit_logs() {
    local days="${1:-365}"
    local cutoff
    # Use environment variable to pass days into the python helper (avoids heredoc argv issues)
    cutoff=$(
        DAYS="$days" python3 - <<PY
from datetime import datetime, timedelta, timezone
import os, sys
d = int(os.environ.get('DAYS', '365'))
sys.stdout.write((datetime.now(timezone.utc)-timedelta(days=d)).strftime('%Y-%m-%dT%H:%M:%SZ') + "\n")
PY
    )
    jq "select(.timestamp >= \"$cutoff\")" "$AUDIT_EVENTS_DB" >"${AUDIT_EVENTS_DB}.tmp" 2>/dev/null || true
    mv "${AUDIT_EVENTS_DB}.tmp" "$AUDIT_EVENTS_DB" || true
    log "Cleaned up audit logs older than $days days"
}

case "${1:-help}" in
init)
    init_audit_system
    ;;
log)
    log_audit_event "$2" "$3" "$4" "$5" "${6:-success}" "${7:-}"
    ;;
report)
    generate_compliance_report "$2" "${3:-}" "${4:-}"
    ;;
query)
    query_audit_events "${2:-}"
    ;;
cleanup)
    cleanup_audit_logs "${2:-365}"
    ;;
*)
    echo "Usage: $0 <init|log|report|query|cleanup>"
    ;;
esac
