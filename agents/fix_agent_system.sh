#!/bin/bash
# Agent System Fixer - Resolves jq errors and agent persistence issues

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/fixer.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Fix 1: Replace problematic jq usage with shared functions
fix_agent_jq_usage() {
    log "Fixing jq usage in agents..."

    # Find agents using jq directly for status updates
    for agent_file in "${SCRIPT_DIR}"/*.sh; do
        if [[ -f "$agent_file" && "$agent_file" != *"shared_functions.sh" ]]; then
            agent_name=$(basename "$agent_file" .sh)

            # Check if agent uses jq for status updates
            if grep -q "jq.*agents.*status" "$agent_file"; then
                log "Fixing $agent_name - replacing jq status updates with shared functions"

                # Create backup
                cp "$agent_file" "${agent_file}.backup"

                # Replace jq status updates with shared function calls
                sed -i '' 's/update_agent_status "$AGENT_NAME" "available" "$$"" "$$"/g' "$agent_file"
                sed -i '' 's/update_agent_status "$AGENT_NAME" "running" "$$"" "$$"/g' "$agent_file"
                sed -i '' 's/update_agent_status "$AGENT_NAME" "busy" "$$"" "$$"/g' "$agent_file"
                sed -i '' 's/update_agent_status "$AGENT_NAME" "failed" "$$"" "$$"/g' "$agent_file"

                log "Fixed status updates in $agent_name"
            fi
        fi
    done
}

# Fix 2: Ensure shared functions are sourced properly
fix_shared_functions_sourcing() {
    log "Ensuring shared functions are sourced..."

    for agent_file in "${SCRIPT_DIR}"/*.sh; do
        if [[ -f "$agent_file" && "$agent_file" != *"shared_functions.sh" ]]; then
            agent_name=$(basename "$agent_file" .sh)

            # Check if shared functions are sourced
            if ! grep -q "source.*shared_functions.sh" "$agent_file"; then
                log "Adding shared functions source to $agent_name"

                # Add source line after shebang
                sed -i '' '2a\
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\
source "${SCRIPT_DIR}/shared_functions.sh"
' "$agent_file"
            fi
        fi
    done
}

# Fix 3: Fix jq parsing errors in system monitoring
fix_system_monitoring() {
    log "Fixing system monitoring jq errors..."

    # Find agents doing system monitoring
    for agent_file in "${SCRIPT_DIR}"/*.sh; do
        if grep -q "ps aux\|top\|free\|df" "$agent_file"; then
            log "Fixing system monitoring in $(basename "$agent_file")"

            # Replace problematic jq parsing with safer alternatives
            # This is a common pattern that causes the "cannot be parsed as a number" error
            sed -i '' 's/jq.*ps aux.*number/sed "s/^[[:space:]]*//" | cut -d" " -f4 | grep -E "^[0-9]+$" | head -1/g' "$agent_file"
            sed -i '' 's/jq.*free.*number/sed "s/^[[:space:]]*//" | grep "Mem:" | tr -s " " | cut -d" " -f2/g' "$agent_file"
        fi
    done
}

# Fix 4: Ensure proper temporary file handling
fix_temp_file_handling() {
    log "Fixing temporary file handling..."

    for agent_file in "${SCRIPT_DIR}"/*.sh; do
        if grep -q "jq.*\.tmp" "$agent_file"; then
            log "Fixing temp file handling in $(basename "$agent_file")"

            # Replace problematic jq temp file patterns
            sed -i '' 's/jq -r ".tasks[] | select(.id == \"${task_id}\") | .description" "${TASK_QUEUE_FILE}" 2>/dev/null || echo "Task not found"/jq -r ".tasks[] | select(.id == \\"${task_id}\\") | .description" "${TASK_QUEUE_FILE}" 2>\/dev\/null || echo "Task not found"/g' "$agent_file"
        fi
    done
}

# Fix 5: Restart agents with fixes
restart_agents_cleanly() {
    log "Restarting agents cleanly..."

    # Kill existing agents
    pkill -f "agent_.*\.sh" 2>/dev/null || true
    pkill -f "quality_agent.sh" 2>/dev/null || true
    sleep 2

    # Start agents one by one
    agents=(
        "agent_analytics.sh"
        "agent_build.sh"
        "agent_cleanup.sh"
        "agent_codegen.sh"
        "code_review_agent.sh"
        "deployment_agent.sh"
        "documentation_agent.sh"
        "learning_agent.sh"
        "monitoring_agent.sh"
        "performance_agent.sh"
        "quality_agent.sh"
        "search_agent.sh"
        "security_agent.sh"
        "testing_agent.sh"
    )

    for agent in "${agents[@]}"; do
        if [[ -f "$agent" ]]; then
            log "Starting $agent..."
            chmod +x "$agent"
            ./"$agent" start &
            sleep 0.5
        fi
    done

    log "All agents restarted"
}

# Fix 6: Validate JSON files
validate_json_files() {
    log "Validating JSON files..."

    # Check agent status file
    if [[ -f "agent_status.json" ]]; then
        if ! python3 -c "import json; json.load(open('agent_status.json'))" 2>/dev/null; then
            log "Fixing corrupted agent_status.json"
            echo '{"agents":{},"last_update":0}' > agent_status.json
        fi
    else
        log "Creating missing agent_status.json"
        echo '{"agents":{},"last_update":0}' > agent_status.json
    fi

    # Check task queue file
    if [[ -f "task_queue.json" ]]; then
        if ! python3 -c "import json; json.load(open('task_queue.json'))" 2>/dev/null; then
            log "Fixing corrupted task_queue.json"
            echo '{"tasks":[],"completed":[]}' > task_queue.json
        fi
    else
        log "Creating missing task_queue.json"
        echo '{"tasks":[],"completed":[]}' > task_queue.json
    fi
}

# Main fix execution
main() {
    log "=== AGENT SYSTEM FIXER STARTED ==="

    validate_json_files
    fix_shared_functions_sourcing
    fix_agent_jq_usage
    fix_system_monitoring
    fix_temp_file_handling
    restart_agents_cleanly

    log "=== AGENT SYSTEM FIXER COMPLETED ==="
    log "Monitor the dashboard at http://127.0.0.1:8080 for progress"
}

# Run main if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi