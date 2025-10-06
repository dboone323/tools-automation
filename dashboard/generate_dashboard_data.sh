#!/bin/bash
#
# Dashboard Data Generator v2.1
# Aggregates metrics from multiple sources into unified dashboard JSON
#

set -euo pipefail

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
OUTPUT_FILE="${ROOT_DIR}/Tools/dashboard_data.json"

# Configuration thresholds
readonly DISK_WARNING_THRESHOLD="${DISK_WARNING_THRESHOLD:-85}"
readonly DISK_CRITICAL_THRESHOLD="${DISK_CRITICAL_THRESHOLD:-95}"

# Get agent status with enhanced fields
get_agent_status() {
    local agent_file="${ROOT_DIR}/Tools/agents/agent_status.json"
    
    if [[ ! -f "$agent_file" ]]; then
        echo '{}'
        return
    fi
    
    # Add human-readable last_seen timestamps
    cat "$agent_file" | jq -c '.agents | to_entries | map({
        key: .key,
        value: (.value + {
            last_seen_human: (
                if .value.last_seen then
                    ((now - .value.last_seen) |
                    if . < 60 then "\(. | floor)s ago"
                    elif . < 3600 then "\((. / 60) | floor)m ago"
                    elif . < 86400 then "\((. / 3600) | floor)h ago"
                    else "\((. / 86400) | floor)d ago"
                    end)
                else "never"
                end
            ),
            tasks_completed: (.value.tasks_completed // 0)
        })
    }) | from_entries'
}

# Get GitHub workflow status
get_workflow_status() {
    if ! command -v gh >/dev/null 2>&1; then
        echo '[]'
        return
    fi
    
    local workflow_data
    workflow_data=$(gh run list --limit 10 --json status,name,conclusion,updatedAt 2>/dev/null || echo "[]")
    
    if [[ -z "$workflow_data" ]] || ! echo "$workflow_data" | jq -e . &>/dev/null; then
        echo '[]'
        return
    fi
    
    echo "$workflow_data" | jq -c 'group_by(.name) | map({
        name: .[0].name,
        status: .[0].status,
        conclusion: (.[0].conclusion // "unknown"),
        last_run: .[0].updatedAt,
        total_runs: length,
        recent_failures: (map(select(.conclusion == "failure")) | length)
    })'
}

# Get MCP alert summary
get_mcp_summary() {
    local alert_dir="${SCRIPT_DIR}/../alerts"
    local mcp_available=false
    
    # Check if MCP server is running (simple check)
    if pgrep -f "mcp" > /dev/null 2>&1; then
        mcp_available=true
    fi
    
    local critical=0 error=0 warning=0 info=0
    local last_alert=""
    
    if [[ -d "$alert_dir" ]]; then
        # Count alerts from last 24 hours by level
        while IFS= read -r alert_file; do
            local level
            level=$(jq -r '.level // "info"' "$alert_file" 2>/dev/null || echo "info")
            case "$level" in
                critical) ((critical++)) ;;
                error) ((error++)) ;;
                warning) ((warning++)) ;;
                *) ((info++)) ;;
            esac
        done < <(find "$alert_dir" -name "*.json" -mtime -1 2>/dev/null)
        
        # Get most recent alert timestamp
        last_alert=$(find "$alert_dir" -name "*.json" -type f -print0 2>/dev/null | xargs -0 ls -t | head -1 | xargs jq -r '.timestamp // "never"' 2>/dev/null || echo "never")
    fi
    
    local total=$((critical + error + warning + info))
    
    echo "{\"available\": $mcp_available, \"alerts_24h\": {\"critical\": $critical, \"error\": $error, \"warning\": $warning, \"info\": $info, \"total\": $total}, \"last_alert_time\": \"$last_alert\"}"
}

# Get Ollama status
get_ollama_status() {
    local ollama_data
    ollama_data=$(curl -s http://localhost:11434/api/tags 2>/dev/null)
    
    if [[ -n "$ollama_data" ]] && echo "$ollama_data" | jq -e . &>/dev/null; then
        echo "$ollama_data" | jq -c '{
            available: true,
            models_count: (.models | length),
            models: [.models[].name]
        }'
    else
        echo '{"available": false, "models_count": 0, "models": []}'
    fi
}

# Get disk usage
get_disk_usage() {
    local percent
    percent=$(df . | awk 'NR==2 {gsub("%","",$5); print $5}')
    
    local status="healthy"
    if (( percent >= DISK_CRITICAL_THRESHOLD )); then
        status="critical"
    elif (( percent >= DISK_WARNING_THRESHOLD )); then
        status="warning"
    fi
    
    echo "{\"percent\": ${percent:-0}, \"status\": \"$status\"}"
}

# Get latest metrics snapshot
get_latest_metrics() {
    local today
    today=$(date +%Y-%m-%d)
    local metrics_file="${SCRIPT_DIR}/../metrics/snapshots/${today}.json"
    
    if [[ -f "$metrics_file" ]] && jq -e . "$metrics_file" &>/dev/null; then
        cat "$metrics_file"
    else
        echo '{}'
    fi
}

# Get task queue information
get_task_queue() {
    local validation_dir="${SCRIPT_DIR}/../validation_reports"
    local ai_review_dir="${SCRIPT_DIR}/../ai_reviews"
    
    local pending_validations=0
    if [[ -d "$validation_dir" ]]; then
        pending_validations=$(find "$validation_dir" -name "*.json" -mtime -1 2>/dev/null | wc -l | xargs)
    fi
    
    local active_reviews=0
    if [[ -d "$ai_review_dir" ]]; then
        active_reviews=$(find "$ai_review_dir" -name "*.md" -mtime -1 2>/dev/null | wc -l | xargs)
    fi
    
    echo "{\"total_pending\": ${pending_validations:-0}, \"total_active\": ${active_reviews:-0}, \"by_agent\": {}}"
}

# Generate complete dashboard data
generate_dashboard_data() {
    local current_time
    current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Collect all data (compact JSON)
    local agent_status
    agent_status=$(get_agent_status)
    
    local workflow_status
    workflow_status=$(get_workflow_status)
    
    local mcp_summary
    mcp_summary=$(get_mcp_summary)
    
    local ollama_status
    ollama_status=$(get_ollama_status)
    
    local disk_usage
    disk_usage=$(get_disk_usage)
    
    local latest_metrics
    latest_metrics=$(get_latest_metrics | jq -c .)
    
    local task_queue
    task_queue=$(get_task_queue)
    
    # Calculate agent summary from agent_status
    local total_agents
    total_agents=$(echo "$agent_status" | jq 'length')
    
    local running_agents
    running_agents=$(echo "$agent_status" | jq '[.[] | select(.status == "running")] | length')
    
    local idle_agents
    idle_agents=$(echo "$agent_status" | jq '[.[] | select(.status == "idle")] | length')
    
    local stopped_agents
    stopped_agents=$(echo "$agent_status" | jq '[.[] | select(.status == "stopped")] | length')
    
    local unresponsive_agents
    unresponsive_agents=$(echo "$agent_status" | jq '[.[] | select(.status == "unresponsive")] | length')
    
    local health_percent
    health_percent=$(awk "BEGIN {if(${total_agents}>0) printf \"%.0f\", (${running_agents}+${idle_agents})/${total_agents}*100; else print 0}")
    
    local uptime_value
    uptime_value=$(uptime | awk '{print $3,$4}' | sed 's/,//')
    
    local load_value
    load_value=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    
    # Build complete JSON using jq
    jq -n \
        --arg generated_at "$current_time" \
        --argjson agents "$agent_status" \
        --argjson total "$total_agents" \
        --argjson running "$running_agents" \
        --argjson idle "$idle_agents" \
        --argjson stopped "$stopped_agents" \
        --argjson unresponsive "$unresponsive_agents" \
        --argjson health "$health_percent" \
        --argjson workflows "$workflow_status" \
        --argjson mcp "$mcp_summary" \
        --argjson ollama "$ollama_status" \
        --argjson disk "$disk_usage" \
        --arg uptime "$uptime_value" \
        --arg load "$load_value" \
        --argjson metrics "$latest_metrics" \
        --argjson tasks "$task_queue" \
        '{
            generated_at: $generated_at,
            version: "2.1.0",
            agents: $agents,
            agent_summary: {
                total: $total,
                running: $running,
                idle: $idle,
                stopped: $stopped,
                unresponsive: $unresponsive,
                health_percent: $health
            },
            workflows: $workflows,
            mcp: $mcp,
            ollama: $ollama,
            system: {
                disk_usage: $disk,
                uptime: $uptime,
                load_average: $load
            },
            metrics: $metrics,
            tasks: $tasks
        }'
}

# Main function
main() {
    echo "[INFO] Generating dashboard data..."
    
    # Create output directory if needed
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    
    # Generate and save dashboard data
    generate_dashboard_data > "$OUTPUT_FILE"
    
    echo "[INFO] Dashboard data written to: ${OUTPUT_FILE}"
    echo "[INFO] File size: $(du -h "$OUTPUT_FILE" | cut -f1)"
    
    # Pretty print summary
    echo ""
    echo "=== Dashboard Data Summary ==="
    jq -r '
        "Generated: \(.generated_at)",
        "Agents: \(.agent_summary.total) total (\(.agent_summary.running) running, \(.agent_summary.unresponsive) unresponsive)",
        "Workflows: \(.workflows | length) tracked",
        "MCP: \(if .mcp.available then "Available" else "Unavailable" end) - \(.mcp.alerts_24h.total) alerts (24h)",
        "Ollama: \(if .ollama.available then "Available" else "Unavailable" end) - \(.ollama.models_count) models",
        "Disk: \(.system.disk_usage.percent)% used (\(.system.disk_usage.status))",
        "Tasks: \(.tasks.total_pending) pending, \(.tasks.total_active) active"
    ' "$OUTPUT_FILE"
    echo "=============================="
}

# Run main
main "$@"
