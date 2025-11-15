#!/bin/bash
# Autonomy Pipeline Orchestrator
# Runs end-to-end autonomy cycle: log analysis -> predictive ML -> self-healing -> enrichment -> metrics -> dashboard snapshot

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$ROOT/.venv"
RUN_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DASHBOARD_OUT="$ROOT/reports/dashboard_snapshot_${RUN_TIMESTAMP}.txt"
PIPELINE_LOG="$ROOT/reports/pipeline_runs.jsonl"
MAX_SNAPSHOTS=100

log() { echo -e "[PIPELINE] $1"; }

activate_venv() {
    if [[ -f "$VENV/bin/activate" ]]; then
        # shellcheck source=/dev/null
        source "$VENV/bin/activate"
        log "Virtual environment activated"
    else
        log "Virtual environment not found; continuing with system Python"
    fi
}

run_step() {
    local desc;
    desc="$1"
    shift
    log "STEP: $desc"
    if "$@"; then
        log "SUCCESS: $desc"
    else
        log "FAILED: $desc" >&2
    fi
}

prune_old_snapshots() {
    log "Pruning old dashboard snapshots (keeping last $MAX_SNAPSHOTS)"
    local snapshots;
    snapshots=("$ROOT/reports/dashboard_snapshot_"*.txt)
    local count;
    count=${#snapshots[@]}
    if [[ $count -gt $MAX_SNAPSHOTS ]]; then
        local to_remove;
        to_remove=$((count - MAX_SNAPSHOTS))
        # Sort by modification time and remove oldest
        find "$ROOT/reports" -name "dashboard_snapshot_*.txt" -type f -print0 2>/dev/null |
            xargs -0 ls -t | tail -n "$to_remove" | xargs rm -f 2>/dev/null || true
        log "Pruned $to_remove old snapshots"
    fi
}

append_pipeline_run_log() {
    local start_time;
    start_time="$1"
    local end_time;
    end_time="$(date -u +%s)"
    local duration;
    duration=$((end_time - start_time))
    local autonomy_score;
    autonomy_score=$(python3 -c "
import json, os
score = 0
if os.path.exists('$ROOT/unified_todos.json'):
    todos = json.load(open('$ROOT/unified_todos.json')).get('todos', [])
    if todos:
        completed = len([t for t in todos if t.get('status') == 'completed'])
        assigned = len([t for t in todos if t.get('assignee')])
        score += int((completed*10/len(todos)) if todos else 0)
        score += int((assigned*10/len(todos)) if todos else 0)
print(score)
" 2>/dev/null || echo "0")

    local log_entry
    log_entry=$(
        cat <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","run_id":"$RUN_TIMESTAMP","duration_seconds":$duration,"autonomy_score":$autonomy_score}
EOF
    )
    echo "$log_entry" >>"$PIPELINE_LOG"
    log "Run logged to $PIPELINE_LOG"
}

activate_venv

START_TIME=$(date -u +%s)

# 1. Log analysis & todo generation
run_step "Enhanced log analysis" "$ROOT/enhanced_log_analysis.sh"

# 2. Predictive failure analysis (includes ML + self healing)
run_step "Predictive failure analysis" "$ROOT/predictive_failure_analysis.sh"

# 3. Process resolved todos for learning correlations
run_step "Process resolved todos" python3 "$ROOT/process_resolved_todos.py"

# 4. Generate success metrics
run_step "Generate success metrics" python3 "$ROOT/success_metrics_report.py"

# 5. Enrich root causes (if script exists)
if [[ -f "$ROOT/root_cause_enrichment.py" ]]; then
    run_step "Root cause enrichment" python3 "$ROOT/root_cause_enrichment.py"
fi

# 6. Auto-complete stale todos (if script exists)
if [[ -f "$ROOT/auto_complete_stale_todos.py" ]]; then
    run_step "Auto-complete stale todos" python3 "$ROOT/auto_complete_stale_todos.py"
fi

# 7. Dashboard snapshot
if [[ -f "$ROOT/autonomy_dashboard.sh" ]]; then
    "$ROOT/autonomy_dashboard.sh" >"$DASHBOARD_OUT" || log "Dashboard snapshot failed"
    log "Dashboard snapshot written to $DASHBOARD_OUT"
fi

# 8. Prune old snapshots
prune_old_snapshots

# 9. Alerting check
if [[ -f "$ROOT/alerting.py" ]]; then
    run_step "Alerting check" python3 "$ROOT/alerting.py"
fi

# 10. Log this pipeline run
append_pipeline_run_log "$START_TIME"

log "Pipeline run complete"
