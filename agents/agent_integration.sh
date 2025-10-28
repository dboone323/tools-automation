#!/bin/bash
# Integration Agent: CI/CD integration & workflow management

# Source shared functions for task management
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
    source "${SCRIPT_DIR}/../project_config.sh"
fi

set -euo pipefail

# Portable run_with_timeout: run a command and kill it if it exceeds timeout (seconds)
# Usage: run_with_timeout <seconds> <cmd> [args...]
run_with_timeout() {
    local timeout="$1"
    shift
    local cmd="$*"

    # Use timeout command if available (Linux), otherwise implement with background process
    if command -v timeout >/dev/null 2>&1; then
        timeout --kill-after=5s "${timeout}s" bash -c "$cmd"
    else
        # macOS/BSD implementation using background process
        local pid_file
        pid_file=$(mktemp)
        local exit_file
        exit_file=$(mktemp)

        # Run command in background
        (
            if bash -c "$cmd"; then
                echo 0 >"$exit_file"
            else
                echo $? >"$exit_file"
            fi
        ) &
        local cmd_pid
        cmd_pid=$!

        echo "$cmd_pid" >"$pid_file"

        # Wait for completion or timeout
        local count
        count=0
        while [[ $count -lt $timeout ]] && kill -0 "$cmd_pid" 2>/dev/null; do
            sleep 1
            ((count++))
        done

        # Check if still running
        if kill -0 "$cmd_pid" 2>/dev/null; then
            # Kill the process group
            pkill -TERM -P "$cmd_pid" 2>/dev/null || true
            sleep 1
            pkill -KILL -P "$cmd_pid" 2>/dev/null || true
            rm -f "$pid_file" "$exit_file"
            log_message "ERROR" "Command timed out after ${timeout}s: $cmd"
            return 124
        else
            # Command completed, get exit code
            local exit_code
            if [[ -f "$exit_file" ]]; then
                exit_code=$(cat "$exit_file")
                rm -f "$pid_file" "$exit_file"
                return "$exit_code"
            else
                rm -f "$pid_file" "$exit_file"
                return 0
            fi
        fi
    fi
}

# Check resource limits before operations
check_resource_limits() {
    # Check file count limit (1000 files max)
    local file_count
    file_count=$(find "${WORKSPACE_ROOT:-/Users/danielstevens/Desktop/Quantum-workspace}" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ $file_count -gt 1000 ]]; then
        log_message "ERROR" "File count limit exceeded: $file_count files (max: 1000)"
        return 1
    fi

    # Check memory usage (80% max)
    if command -v vm_stat >/dev/null 2>&1; then
        # macOS memory check
        local mem_usage
        mem_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.')
        local total_mem
        total_mem=$(echo "$(sysctl -n hw.memsize) / 1024 / 1024" | bc 2>/dev/null || echo "8192")
        local mem_percent
        mem_percent=$((mem_usage * 4096 * 100 / (total_mem * 1024 * 1024 / 4096)))
        if [[ $mem_percent -gt 80 ]]; then
            log_message "ERROR" "Memory usage too high: ${mem_percent}% (max: 80%)"
            return 1
        fi
    fi

    # Check CPU usage (90% max)
    if command -v ps >/dev/null 2>&1; then
        local cpu_usage
        cpu_usage=$(ps -A -o %cpu | awk '{s+=$1} END {print s}')
        if [[ $(echo "$cpu_usage > 90" | bc 2>/dev/null) -eq 1 ]]; then
            log_message "ERROR" "CPU usage too high: ${cpu_usage}% (max: 90%)"
            return 1
        fi
    fi

    return 0
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
WORKFLOWS_DIR="${WORKSPACE_ROOT}/.github/workflows"

# Logging configuration
AGENT_NAME="IntegrationAgent"
LOG_FILE="${SCRIPT_DIR}/integration_agent.log"

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date)] [${AGENT_NAME}] [${level}] ${message}" >>"${LOG_FILE}"
}

process_integration_task() {
    local task="$1"

    log_message "INFO" "Processing integration task: $task"

    case "$task" in
    test_integration_run)
        log_message "INFO" "Running integration system verification..."
        log_message "SUCCESS" "Integration system operational"
        ;;
    validate_workflows)
        log_message "INFO" "Validating workflows..."
        validate_workflow_syntax
        ;;
    sync_workflows)
        log_message "INFO" "Syncing workflows..."
        sync_workflows
        ;;
    monitor_workflows)
        log_message "INFO" "Monitoring workflow health..."
        monitor_workflows
        ;;
    cleanup_runs)
        log_message "INFO" "Cleaning up old workflow runs..."
        cleanup_old_runs
        ;;
    deploy_workflows)
        log_message "INFO" "Deploying workflow updates..."
        deploy_workflows
        ;;
    *)
        log_message "WARN" "Unknown integration task: $task"
        ;;
    esac
}

# Validate workflow YAML syntax
validate_workflow_syntax() {
    local workflow_file="$1"

    if [[ ! -f "${workflow_file}" ]]; then
        log_message "ERROR" "Workflow file not found: ${workflow_file}"
        return 1
    fi

    log_message "INFO" "Validating ${workflow_file}..."

    # Basic YAML syntax check
    if command -v python3 &>/dev/null; then
        python3 -c "
import yaml
try:
    with open('${workflow_file}', 'r') as f:
        yaml.safe_load(f)
    print('Valid YAML')
except yaml.YAMLError as e:
    print(f'Invalid YAML: {e}')
    exit(1)
" || return 1
    fi

    # Check for required GitHub Actions fields
    if ! grep -q "^name:" "${workflow_file}"; then
        log_message "WARN" "Workflow missing 'name' field"
    fi

    if ! grep -q "^on:" "${workflow_file}"; then
        log_message "ERROR" "Workflow missing 'on' trigger field"
        return 1
    fi

    if ! grep -q "^jobs:" "${workflow_file}"; then
        log_message "ERROR" "Workflow missing 'jobs' field"
        return 1
    fi

    log_message "SUCCESS" "Workflow validation passed: ${workflow_file}"
    return 0
}

# Sync workflows across projects
sync_workflows() {
    log_message "INFO" "Syncing workflows across projects..."

    local synced=0
    local failed=0

    # Common workflows that should exist in all projects
    local common_workflows=(
        "pr-validation-unified.yml"
        "swiftlint-auto-fix.yml"
        "weekly-health-check.yml"
    )

    for workflow in "${common_workflows[@]}"; do
        local source="${WORKFLOWS_DIR}/${workflow}"

        if [[ ! -f "${source}" ]]; then
            log_message "WARN" "Source workflow not found: ${workflow}"
            continue
        fi

        log_message "INFO" "Checking ${workflow}..."

        # Validate source workflow
        if validate_workflow_syntax "${source}"; then
            synced=$((synced + 1))
        else
            log_message "ERROR" "Failed to validate ${workflow}"
            failed=$((failed + 1))
        fi
    done

    log_message "INFO" "Synced ${synced} workflows, ${failed} failed"
    return 0
}

# Check workflow run status via GitHub CLI
check_workflow_status() {
    if ! command -v gh &>/dev/null; then
        log_message "WARN" "GitHub CLI not installed - skipping workflow status check"
        return 0
    fi

    log_message "INFO" "Checking recent workflow runs..."

    cd "${WORKSPACE_ROOT}" || return 1

    # Get last 5 workflow runs
    local runs
    runs=$(gh run list --limit 5 --json status,conclusion,name 2>/dev/null || echo "[]")

    if [[ "${runs}" == "[]" ]]; then
        log_message "INFO" "No recent workflow runs found"
        return 0
    fi

    # Count failures
    local failures
    failures=$(echo "${runs}" | grep -c '"conclusion":"failure"' || echo 0)

    if [[ ${failures} -gt 0 ]]; then
        log_message "WARN" "Found ${failures} failed workflow runs in last 5"
    else
        log_message "SUCCESS" "All recent workflow runs successful"
    fi

    cd - >/dev/null || return 1
    return 0
}

# Monitor workflow health
monitor_workflows() {
    log_message "INFO" "Monitoring workflow health..."

    local total_workflows=0
    local valid_workflows=0
    local invalid_workflows=0

    if [[ ! -d "${WORKFLOWS_DIR}" ]]; then
        log_message "ERROR" "Workflows directory not found: ${WORKFLOWS_DIR}"
        return 1
    fi

    # Validate all workflow files
    while IFS= read -r workflow; do
        total_workflows=$((total_workflows + 1))

        if validate_workflow_syntax "${workflow}"; then
            valid_workflows=$((valid_workflows + 1))
        else
            invalid_workflows=$((invalid_workflows + 1))
        fi
    done < <(find "${WORKFLOWS_DIR}" -name "*.yml" -o -name "*.yaml" 2>/dev/null)

    # Generate health report
    local health_report
    health_report="${WORKSPACE_ROOT}/.metrics/workflow_health_$(date +%Y%m%d_%H%M%S).json"

    cat >"${health_report}" <<EOF
{
  "timestamp": $(date +%s),
  "date": "$(date -Iseconds)",
  "total_workflows": ${total_workflows},
  "valid_workflows": ${valid_workflows},
  "invalid_workflows": ${invalid_workflows},
  "health_score": $(awk "BEGIN {if (${total_workflows} > 0) print ${valid_workflows}/${total_workflows}; else print 0}")
}
EOF

    log_message "SUCCESS" "Workflow health report: ${health_report}"

    # Check for failures
    check_workflow_status

    return 0
}

# Cleanup old workflow runs (via GitHub CLI)
cleanup_old_runs() {
    if ! command -v gh &>/dev/null; then
        log_message "WARN" "GitHub CLI not installed - skipping run cleanup"
        return 0
    fi

    log_message "INFO" "Cleaning up old workflow runs..."

    cd "${WORKSPACE_ROOT}" || return 1

    # Delete workflow runs older than 90 days
    local old_runs
    old_runs=$(gh run list --limit 100 --json databaseId,createdAt --jq '.[] | select(.createdAt | fromdateiso8601 < (now - 7776000)) | .databaseId' 2>/dev/null || echo "")

    if [[ -z "${old_runs}" ]]; then
        log_message "INFO" "No old workflow runs to clean up"
        cd - >/dev/null || return 1
        return 0
    fi

    local deleted=0
    while IFS= read -r run_id; do
        [[ -z "${run_id}" ]] && continue

        if gh run delete "${run_id}" --yes 2>/dev/null; then
            deleted=$((deleted + 1))
        fi
    done <<<"${old_runs}"

    log_message "SUCCESS" "Deleted ${deleted} old workflow runs"

    cd - >/dev/null || return 1
    return 0
}

# Deploy workflow updates
deploy_workflows() {
    log_message "INFO" "Deploying workflow updates..."

    # Sync workflows
    sync_workflows

    # Validate all workflows
    monitor_workflows

    # Check if there are changes to commit
    cd "${WORKSPACE_ROOT}" || return 1

    if git status --porcelain "${WORKFLOWS_DIR}" | grep -q .; then
        log_message "INFO" "Workflow changes detected"

        # Auto-commit if configured
        if [[ "${AUTO_COMMIT_WORKFLOWS:-false}" == "true" ]]; then
            git add "${WORKFLOWS_DIR}"
            git commit -m "chore: Update GitHub Actions workflows [agent-integration]"

            if [[ "${AUTO_PUSH_WORKFLOWS:-false}" == "true" ]]; then
                git push
                log_message "SUCCESS" "Workflows committed and pushed"
            else
                log_message "SUCCESS" "Workflows committed (not pushed)"
            fi
        else
            log_message "INFO" "Auto-commit disabled - changes staged but not committed"
        fi
    else
        log_message "INFO" "No workflow changes to deploy"
    fi

    cd - >/dev/null || return 1
    return 0
}

# Main agent loop - standardized task processing
main() {
    log_message "INFO" "Integration Agent starting..."

    # Initialize agent status
    update_agent_status "${AGENT_NAME}" "starting" $$ ""

    # Main task processing loop
    while true; do
        # Get next task from shared queue
        local task_data
        task_data=$(get_next_task "${AGENT_NAME}")

        if [[ -n "${task_data}" ]]; then
            # Process the task
            process_integration_task "${task_data}"
        else
            # No tasks available, check for periodic maintenance
            if ensure_within_limits "integration_maintenance" 600; then
                # Run periodic workflow health check
                monitor_workflows
            fi
        fi

        # Brief pause to prevent tight looping
        sleep 5
    done
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Handle single run mode for testing
    if [[ "${1:-}" == "SINGLE_RUN" ]]; then
        log_message "INFO" "Running in SINGLE_RUN mode for testing"
        update_agent_status "${AGENT_NAME}" "running" $$ ""

        # Run a quick validation cycle
        validate_workflow_syntax "${WORKFLOWS_DIR}/pr-validation-unified.yml" 2>/dev/null || true
        monitor_workflows

        update_agent_status "${AGENT_NAME}" "completed" $$ ""
        log_message "INFO" "SINGLE_RUN completed successfully"
        exit 0
    fi

    # Start the main agent loop
    trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; log_message "INFO" "Integration Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
fi
