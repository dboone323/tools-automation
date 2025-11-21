        #!/usr/bin/env bash

# Dynamic configuration discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./agent_config_discovery.sh
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh"
    WORKSPACE_ROOT=$(get_workspace_root)
    AGENTS_DIR=$(get_agents_dir)
    MCP_URL=$(get_mcp_url)
else
    echo "ERROR: agent_config_discovery.sh not found"
    exit 1
fi
        # Auto-injected health & reliability shim

        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer shared helpers when available
if [[ -f "$DIR/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="agent_test_quality.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  issues=()
  if [[ ! -w "/tmp" ]]; then
    issues+=("tmp_not_writable")
  fi
  if [[ ! -d "$DIR" ]]; then
    issues+=("cwd_missing")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
    exit 2
  fi
  printf '{"ok":true}\n'
  exit 0
fi

# Original agent script continues below
#!/bin/bash
# Agent: Test Quality Manager
# Purpose: Code coverage tracking and flaky test detection
# Author: Quantum Workspace AI Agent System
# Created: 2025-10-06

# Exit early if in test mode
if [[ "${TEST_MODE:-}" == "true" ]]; then
    return 0 2>/dev/null || exit 0
fi

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
LOG_FILE="${SCRIPT_DIR}/agent_test_quality.log"

# Global array for check results
check_results=()

# Enterprise reliability features
run_with_timeout() {
    local timeout_seconds="$1"
    local command="$2"
    local timeout_message="$3"

    log "Running command with ${timeout_seconds}s timeout: ${command}"

    # Use timeout command if available, otherwise run without timeout
    if command -v timeout >/dev/null 2>&1; then
        if timeout "${timeout_seconds}s" bash -c "${command}"; then
            log "Command completed successfully within timeout"
            return 0
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                log "ERROR: Command timed out after ${timeout_seconds} seconds: ${timeout_message}"
                return 1
            else
                log "Command failed with exit code ${exit_code}"
                return $exit_code
            fi
        fi
    else
        log "WARNING: timeout command not available, running without timeout protection"
        if bash -c "${command}"; then
            log "Command completed successfully"
            return 0
        else
            local exit_code=$?
            log "Command failed with exit code ${exit_code}"
            return $exit_code
        fi
    fi
}

check_resource_limits() {
    local operation_name="$1"
    log "Checking resource limits for: ${operation_name}"

    # Check available disk space (minimum 1GB)
    local available_space
    available_space=$(df -BG "${WORKSPACE_ROOT}" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [[ ${available_space} -lt 1 ]]; then
        log "ERROR: Insufficient disk space (${available_space}GB available, need 1GB minimum)"
        return 1
    fi

    # Check memory usage (maximum 90%)
    local memory_usage
    memory_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.' | xargs -I {} echo "scale=2; {}/1024/1024" | bc 2>/dev/null || echo "0")
    if [[ -n "${memory_usage}" ]] && (($(echo "${memory_usage} > 90" | bc -l 2>/dev/null || echo 0))); then
        log "ERROR: Memory usage too high (${memory_usage}%)"
        return 1
    fi

    # Check file count in workspace (maximum 50,000 files)
    local file_count
    file_count=$(find "${WORKSPACE_ROOT}" -type f 2>/dev/null | wc -l)
    if [[ ${file_count} -gt 50000 ]]; then
        log "ERROR: Too many files in workspace (${file_count}, maximum 50,000)"
        return 1
    fi

    log "Resource limits check passed"
    return 0
}

# Source enhancement modules
# Temporarily simplified - enhancement files causing issues
# source "${ENHANCEMENTS_DIR}/testing_coverage.sh"
# source "${ENHANCEMENTS_DIR}/testing_flaky_detection.sh"

# Stub functions for now
generate_coverage_report() {
    echo "Coverage analysis temporarily disabled"
}

detect_flaky_tests() {
    echo "Flaky test detection temporarily disabled"
}

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [agent_test_quality] $*" | tee -a "${LOG_FILE}"
}

run_quality_checks() {
    log "🧪 Starting test quality checks"

    # Check resource limits before starting quality checks
    if ! check_resource_limits "test quality analysis"; then
        log "ERROR: Resource limits check failed, aborting quality checks"
        return 1
    fi

    # Create backup before quality analysis operations
    log "Creating backup before quality analysis..."
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup "test_quality" "quality_analysis_$(date +%Y%m%d_%H%M%S)" >>"${LOG_FILE}" 2>&1 || log "WARNING: Backup creation failed, continuing anyway"

    # Find all projects
    local projects=(
        "Projects/AvoidObstaclesGame"
        "Projects/HabitQuest"
        "Projects/MomentumFinance"
        "Projects/PlannerApp"
        "Projects/CodingReviewer"
    )

    check_results=()

    for project in "${projects[@]}"; do
        local project_path="${WORKSPACE_ROOT}/${project}"

        if [[ -d ${project_path} ]]; then
            log "Analyzing ${project}..."

            # Run coverage analysis (once per week to save time)
            if [[ $(date +%u) -eq 7 ]]; then # Sunday
                log "Running coverage analysis (weekly)..."
                local coverage_result
                if run_with_timeout 300 "generate_coverage_report '${project_path}'" "Coverage analysis timed out"; then
                    coverage_result=$(generate_coverage_report "${project_path}" 2>&1 || echo "skipped")
                else
                    coverage_result="timeout"
                fi
                check_results+=("${project}: Coverage=${coverage_result}")
            fi

            # Flaky test detection (once per month to save time)
            if [[ $(date +%d) -eq 01 ]]; then # First of month
                log "Running flaky test detection (monthly)..."
                local flaky_result
                if run_with_timeout 600 "detect_flaky_tests '${project_path}' 3" "Flaky test detection timed out"; then
                    flaky_result=$(detect_flaky_tests "${project_path}" 3 2>&1 || echo "skipped") # 3 iterations
                else
                    flaky_result="timeout"
                fi
                check_results+=("${project}: Flaky=${flaky_result}")
            fi
        fi
    done

    log "✅ Test quality checks complete"

    # Summary
    for result in "${check_results[@]}"; do
        log "  ${result}"
    done
}

daemon_mode() {
    log "Starting agent_test_quality daemon (daily checks)"
    update_agent_status "agent_test_quality.sh" "active" $$ ""

    while true; do
        update_agent_status "agent_test_quality.sh" "running" $$ ""
        run_quality_checks
        update_agent_status "agent_test_quality.sh" "available" $$ ""

        # Sleep for 24 hours
        log "Next check in 24 hours"
        sleep 86400
    done
}

# Main execution
if [[ $# -eq 0 ]]; then
    run_quality_checks
elif [[ $1 == "daemon" ]]; then
    daemon_mode
else
    echo "Usage: $0 [daemon]"
    exit 1
fi
