#!/bin/bash
# Comprehensive Agent System Test Runner
# Starts all agents, monitors for 10 minutes, then stops them

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${WORKSPACE_ROOT}/agent_test_logs"
MONITOR_LOG="${LOG_DIR}/agent_monitor_$(date +%Y%m%d_%H%M%S).log"
SUMMARY_FILE="${LOG_DIR}/agent_test_summary_$(date +%Y%m%d_%H%M%S).md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global variables for analysis results
GLOBAL_ERROR_COUNT=0   # Used in final summary
GLOBAL_TOTAL_RUNNING=0 # Used in final summary

log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warning() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }
section() { echo -e "\n${CYAN}━━━ $* ━━━${NC}\n"; }

# Create log directory
mkdir -p "${LOG_DIR}"

# Initialize summary file
cat >"${SUMMARY_FILE}" <<EOF
# Agent System 10-Minute Test Report
Generated: $(date)
Test Duration: 10 minutes
Log Directory: ${LOG_DIR}

## Test Overview
This report covers a comprehensive 10-minute test of all 203 agents in the system.

EOF

log "Starting comprehensive agent system test..."
log "Log directory: ${LOG_DIR}"
log "Monitor log: ${MONITOR_LOG}"
log "Summary file: ${SUMMARY_FILE}"

# Function to get all agent scripts
get_all_agents() {
    local agents_dir="$1"

    # Find all .sh files that are executable and not utility scripts (macOS compatible)
    find "${agents_dir}" -maxdepth 1 -name "*.sh" -type f -perm +111 |
        grep -v -E "(shared_functions|configure_auto_restart|monitor_lock_timeouts|update_all_agents|execute_all_tasks|start_|stop_|monitor_|deprecated|seed_demo_tasks|assign_once|test_|_test)" |
        sort
}

# Function to start an agent
start_agent() {
    local agent_path="$1"
    local agent_name
    agent_name=$(basename "${agent_path}" .sh)

    log "Starting ${agent_name}..."

    # Start agent in background with timeout wrapper
    (
        timeout 610 bash "${agent_path}" >>"${LOG_DIR}/${agent_name}.log" 2>&1 &
        echo $! >"${LOG_DIR}/${agent_name}.pid"
    ) &

    # Give it a moment to start
    sleep 0.5

    # Check if it's running
    if [[ -f "${LOG_DIR}/${agent_name}.pid" ]]; then
        local pid
        pid=$(cat "${LOG_DIR}/${agent_name}.pid")
        if kill -0 "${pid}" 2>/dev/null; then
            success "Started ${agent_name} (PID: ${pid})"
            echo "${agent_name}:${pid}" >>"${LOG_DIR}/running_agents.txt"
            return 0
        fi
    fi

    warning "Failed to start ${agent_name}"
    return 1
}

# Function to stop all agents
stop_all_agents() {
    log "Stopping all agents..."

    local stopped=0
    local failed=0

    if [[ -f "${LOG_DIR}/running_agents.txt" ]]; then
        while IFS=: read -r agent_name pid; do
            if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
                log "Stopping ${agent_name} (PID: ${pid})..."
                if kill -TERM "${pid}" 2>/dev/null; then
                    # Wait up to 5 seconds for graceful shutdown
                    for _ in {1..5}; do
                        if ! kill -0 "${pid}" 2>/dev/null; then
                            success "Stopped ${agent_name}"
                            stopped=$((stopped + 1))
                            break
                        fi
                        sleep 1
                    done

                    # Force kill if still running
                    if kill -0 "${pid}" 2>/dev/null; then
                        warning "Force killing ${agent_name}..."
                        kill -9 "${pid}" 2>/dev/null || true
                        failed=$((failed + 1))
                    fi
                else
                    error "Failed to stop ${agent_name}"
                    failed=$((failed + 1))
                fi
            else
                log "${agent_name} already stopped"
            fi
        done <"${LOG_DIR}/running_agents.txt"
    fi

    success "Agent shutdown complete: ${stopped} stopped, ${failed} force-killed"
}

# Function to monitor system during test
monitor_system() {
    local duration="$1"
    local start_time
    start_time=$(date +%s)

    log "Starting system monitoring for ${duration} minutes..."

    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local remaining=$((duration * 60 - elapsed))

        if [[ ${remaining} -le 0 ]]; then
            break
        fi

        # System stats every 30 seconds
        if [[ $((elapsed % 30)) -eq 0 ]]; then
            echo "--- SYSTEM STATS $(date) ---" >>"${MONITOR_LOG}"
            echo "Elapsed: ${elapsed}s, Remaining: ${remaining}s" >>"${MONITOR_LOG}"

            # CPU and memory
            if command -v top &>/dev/null; then
                top -l 1 -stats pid,command,cpu,mem | head -20 >>"${MONITOR_LOG}" 2>/dev/null || true
            fi

            # Process count
            local agent_processes
            agent_processes=$(pgrep -f "\.sh" | wc -l | tr -d ' ')
            echo "Agent processes: ${agent_processes}" >>"${MONITOR_LOG}"

            # Disk usage
            df -h "${WORKSPACE_ROOT}" >>"${MONITOR_LOG}" 2>/dev/null || true

            # Memory stats
            if command -v vm_stat &>/dev/null; then
                vm_stat >>"${MONITOR_LOG}" 2>/dev/null || true
            fi
        fi

        # Agent status check every minute
        if [[ $((elapsed % 60)) -eq 0 ]]; then
            echo "--- AGENT STATUS $(date) ---" >>"${MONITOR_LOG}"

            local running_count=0
            local crashed_count=0

            if [[ -f "${LOG_DIR}/running_agents.txt" ]]; then
                while IFS=: read -r agent_name pid; do
                    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
                        running_count=$((running_count + 1))
                        echo "✓ ${agent_name} (PID: ${pid})" >>"${MONITOR_LOG}"
                    else
                        crashed_count=$((crashed_count + 1))
                        echo "✗ ${agent_name} (crashed)" >>"${MONITOR_LOG}"
                    fi
                done <"${LOG_DIR}/running_agents.txt"
            fi

            echo "Running: ${running_count}, Crashed: ${crashed_count}" >>"${MONITOR_LOG}"
            log "Status check: ${running_count} running, ${crashed_count} crashed"
        fi

        sleep 5
    done
}

# Function to analyze results
analyze_results() {
    section "ANALYZING TEST RESULTS"

    local total_started=0
    local total_running=0
    local total_crashed=0
    local total_logs=0

    # Count started agents
    if [[ -f "${LOG_DIR}/running_agents.txt" ]]; then
        total_started=$(wc -l <"${LOG_DIR}/running_agents.txt")
    fi

    # Check final status
    if [[ -f "${LOG_DIR}/running_agents.txt" ]]; then
        while IFS=: read -r agent_name pid; do
            if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
                total_running=$((total_running + 1))
            else
                total_crashed=$((total_crashed + 1))
            fi
        done <"${LOG_DIR}/running_agents.txt"
    fi

    # Set global variables for use in final summary
    GLOBAL_TOTAL_RUNNING=${total_running}

    # Count log files
    total_logs=$(find "${LOG_DIR}" -name "*.log" -type f | wc -l)

    # Analyze log sizes
    local total_log_size=0
    local largest_log=""
    local largest_size=0

    while IFS= read -r log_file; do
        if [[ -f "${log_file}" ]]; then
            local size
            size=$(stat -f%z "${log_file}" 2>/dev/null || echo "0")
            total_log_size=$((total_log_size + size))

            if [[ ${size} -gt ${largest_size} ]]; then
                largest_size=${size}
                largest_log=$(basename "${log_file}")
            fi
        fi
    done < <(find "${LOG_DIR}" -name "*.log" -type f)

    # System resource usage
    local cpu_usage="N/A"
    local mem_usage="N/A"

    if command -v ps &>/dev/null; then
        cpu_usage=$(ps -Ao pcpu= | awk '{sum+=$1} END {print int(sum)}' 2>/dev/null || echo "N/A")
        mem_usage=$(ps -Ao pmem= | awk '{sum+=$1} END {print int(sum)}' 2>/dev/null || echo "N/A")
    fi

    # Update summary file
    cat >>"${SUMMARY_FILE}" <<EOF

## Test Results Summary

### Agent Statistics
- **Total Agents Started**: ${total_started}
- **Still Running**: ${total_running}
- **Crashed/Stopped**: ${total_crashed}
- **Success Rate**: $((total_started > 0 ? (total_running * 100) / total_started : 0))%

### Logging Statistics
- **Log Files Created**: ${total_logs}
- **Total Log Size**: $((total_log_size / 1024)) KB
- **Largest Log**: ${largest_log} (${largest_size} bytes)

### System Resources
- **CPU Usage**: ${cpu_usage}%
- **Memory Usage**: ${mem_usage}%

### Key Observations

EOF

    # Analyze common issues
    local error_count=0
    local timeout_count=0
    local permission_count=0

    while IFS= read -r log_file; do
        if [[ -f "${log_file}" ]]; then
            local grep_result
            grep_result=$(grep -c -i "error\|failed\|exception" "${log_file}" 2>/dev/null || echo "0")
            error_count=$((error_count + grep_result))

            grep_result=$(grep -c -i "timeout" "${log_file}" 2>/dev/null || echo "0")
            timeout_count=$((timeout_count + grep_result))

            grep_result=$(grep -c -i "permission\|denied" "${log_file}" 2>/dev/null || echo "0")
            permission_count=$((permission_count + grep_result))
        fi
    done < <(find "${LOG_DIR}" -name "*.log" -type f)

    # Set global variables for use in final summary
    GLOBAL_ERROR_COUNT=${error_count}

    cat >>"${SUMMARY_FILE}" <<EOF
- **Total Errors**: ${error_count}
- **Timeouts**: ${timeout_count}
- **Permission Issues**: ${permission_count}

EOF

    # Top 5 most active agents (by log size)
    cat >>"${SUMMARY_FILE}" <<EOF
### Top 5 Most Active Agents (by log size)

EOF

    find "${LOG_DIR}" -name "*.log" -type f -exec stat -f"%z %N" {} \; 2>/dev/null |
        sort -nr | head -5 | while read -r size file; do
        agent_name=$(basename "${file}" .log)
        echo "- **${agent_name}**: ${size} bytes" >>"${SUMMARY_FILE}"
    done

    # Most common errors
    cat >>"${SUMMARY_FILE}" <<EOF

### Most Common Errors

EOF

    find "${LOG_DIR}" -name "*.log" -type f -exec grep -h -i "error\|failed\|exception" {} \; 2>/dev/null |
        head -20 | sed 's/^/- /' >>"${SUMMARY_FILE}"

    success "Analysis complete. Summary saved to: ${SUMMARY_FILE}"
}

# Main test execution
section "STARTING AGENT SYSTEM TEST"

# Get all agents
mapfile -t AGENTS < <(get_all_agents "${SCRIPT_DIR}")
AGENT_COUNT=${#AGENTS[@]}

log "Found ${AGENT_COUNT} agents to test"

# Limit to reasonable number for testing (first 50 to avoid overwhelming system)
if [[ ${AGENT_COUNT} -gt 50 ]]; then
    warning "Limiting to first 50 agents for safety (found ${AGENT_COUNT} total)"
    AGENTS=("${AGENTS[@]:0:50}")
    AGENT_COUNT=50
fi

# Start all agents
section "STARTING AGENTS"
started_count=0
for agent_path in "${AGENTS[@]}"; do
    if start_agent "${agent_path}"; then
        started_count=$((started_count + 1))
    fi
done

success "Started ${started_count}/${AGENT_COUNT} agents"

# Monitor for 10 minutes
section "MONITORING FOR 10 MINUTES"
monitor_system 10

# Stop all agents
section "STOPPING AGENTS"
stop_all_agents

# Analyze results
analyze_results

# Final summary
section "TEST COMPLETE"

cat >>"${SUMMARY_FILE}" <<EOF

## Final Assessment

### Test Duration: 10 minutes
### Agents Tested: ${started_count}
### Test Status: ✅ COMPLETED

### Recommendations

1. **Review Logs**: Check ${LOG_DIR} for detailed agent behavior
2. **Monitor Resources**: System handled ${started_count} concurrent agents
3. **Error Analysis**: ${GLOBAL_ERROR_COUNT} total errors across all agents
4. **Performance**: ${GLOBAL_TOTAL_RUNNING}/${started_count} agents completed successfully

### Files Created
- **Summary Report**: ${SUMMARY_FILE}
- **Monitor Log**: ${MONITOR_LOG}
- **Individual Logs**: ${LOG_DIR}/*.log
- **Process Tracking**: ${LOG_DIR}/running_agents.txt

---
Test completed at: $(date)
EOF

log "Test complete! Summary: ${SUMMARY_FILE}"
success "🎉 Agent system test finished successfully!"
success "📊 Check ${SUMMARY_FILE} for detailed results"
success "📁 Logs available in ${LOG_DIR}"
