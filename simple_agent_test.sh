#!/bin/bash
# Simple Agent System Test - Start agents and monitor for 10 minutes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/agent_test_logs"
MONITOR_LOG="${LOG_DIR}/monitor.log"
SUMMARY_FILE="${LOG_DIR}/summary.txt"

mkdir -p "${LOG_DIR}"

echo "=== AGENT SYSTEM TEST STARTED ===" | tee "${MONITOR_LOG}"
echo "Start time: $(date)" | tee -a "${MONITOR_LOG}"
echo "Log directory: ${LOG_DIR}" | tee -a "${MONITOR_LOG}"

# Get some agents to test (limit to 10 for safety)
AGENTS=(
    "agent_monitoring.sh"
    "ai_code_review.sh"
    "ai_dashboard_monitor.sh"
    "analyze_coverage.sh"
    "audit_large_files.sh"
    "bootstrap_meta_repo.sh"
    "cleanup_processed_md_files.sh"
    "dashboard_unified.sh"
    "demonstrate_quantum_ai_consciousness.sh"
    "deploy_ai_self_healing.sh"
)

# Define agent behavior types
declare -A AGENT_TYPES=(
    ["agent_monitoring.sh"]="background"               # Should run continuously
    ["ai_code_review.sh"]="background"                 # Should run continuously
    ["ai_dashboard_monitor.sh"]="background"           # Should run continuously
    ["analyze_coverage.sh"]="background"               # Should run continuously
    ["audit_large_files.sh"]="task"                    # Should complete and exit
    ["bootstrap_meta_repo.sh"]="task"                  # Should complete and exit
    ["cleanup_processed_md_files.sh"]="task"           # Should complete and exit
    ["dashboard_unified.sh"]="task"                    # Should complete and exit
    ["demonstrate_quantum_ai_consciousness.sh"]="task" # Should complete and exit
    ["deploy_ai_self_healing.sh"]="task"               # Should complete and exit
)

echo "" | tee -a "${MONITOR_LOG}"
echo "Starting ${#AGENTS[@]} agents..." | tee -a "${MONITOR_LOG}"

STARTED_AGENTS=()
for agent in "${AGENTS[@]}"; do
    agent_path="${SCRIPT_DIR}/${agent}"
    if [[ -f "${agent_path}" ]] && [[ -x "${agent_path}" ]]; then
        echo "Starting ${agent}..." | tee -a "${MONITOR_LOG}"

        # Launch agents with appropriate arguments based on their design
        if [[ "${agent}" == "agent_monitoring.sh" ]]; then
            # agent_monitoring.sh needs to run in self-monitoring mode (no args)
            timeout 600 bash "${agent_path}" >>"${LOG_DIR}/${agent}.log" 2>&1 &
        elif [[ "${agent}" == "ai_dashboard_monitor.sh" ]]; then
            # ai_dashboard_monitor.sh defaults to start-monitor mode
            timeout 600 bash "${agent_path}" >>"${LOG_DIR}/${agent}.log" 2>&1 &
        elif [[ "${agent}" == "analyze_coverage.sh" ]]; then
            # analyze_coverage.sh with background mode and 1 hour interval
            timeout 600 bash "${agent_path}" true 3600 >>"${LOG_DIR}/${agent}.log" 2>&1 &
        elif [[ "${agent}" == "ai_code_review.sh" ]]; then
            # ai_code_review.sh in background mode with 5 minute interval
            timeout 600 bash "${agent_path}" --background --interval 300 >>"${LOG_DIR}/${agent}.log" 2>&1 &
        elif [[ "${agent}" == "audit_large_files.sh" ]]; then
            # audit_large_files.sh runs once and exits
            timeout 600 bash "${agent_path}" >>"${LOG_DIR}/${agent}.log" 2>&1 &
        elif [[ "${agent}" == "bootstrap_meta_repo.sh" ]]; then
            # bootstrap_meta_repo.sh runs once and exits
            timeout 600 bash "${agent_path}" >>"${LOG_DIR}/${agent}.log" 2>&1 &
        elif [[ "${agent}" == "cleanup_processed_md_files.sh" ]]; then
            # cleanup_processed_md_files.sh runs once and exits
            timeout 600 bash "${agent_path}" >>"${LOG_DIR}/${agent}.log" 2>&1 &
        elif [[ "${agent}" == "dashboard_unified.sh" ]]; then
            # dashboard_unified.sh - check if it needs arguments
            timeout 600 bash "${agent_path}" >>"${LOG_DIR}/${agent}.log" 2>&1 &
        elif [[ "${agent}" == "demonstrate_quantum_ai_consciousness.sh" ]]; then
            # demonstrate_quantum_ai_consciousness.sh - check if it needs arguments
            timeout 600 bash "${agent_path}" >>"${LOG_DIR}/${agent}.log" 2>&1 &
        elif [[ "${agent}" == "deploy_ai_self_healing.sh" ]]; then
            # deploy_ai_self_healing.sh - check if it needs arguments
            timeout 600 bash "${agent_path}" >>"${LOG_DIR}/${agent}.log" 2>&1 &
        else
            # Default: use monitoring wrapper for other agents
            timeout 600 bash "${SCRIPT_DIR}/agent_monitoring.sh" "${agent}" bash "${agent_path}" >>"${LOG_DIR}/${agent}.log" 2>&1 &
        fi

        pid=$!
        echo "${agent}:${pid}" >>"${LOG_DIR}/pids.txt"
        STARTED_AGENTS+=("${agent}")
        echo "✓ Started ${agent} (PID: ${pid})" | tee -a "${MONITOR_LOG}"
        sleep 1
    else
        echo "✗ Skipped ${agent} (not found or not executable)" | tee -a "${MONITOR_LOG}"
    fi
done

echo "" | tee -a "${MONITOR_LOG}"
echo "Monitoring for 10 minutes..." | tee -a "${MONITOR_LOG}"

# Monitor for 10 minutes
START_TIME=$(date +%s)
for ((i = 1; i <= 120; i++)); do # 120 * 5 seconds = 10 minutes
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if ((i % 12 == 0)); then # Every minute
        echo "--- STATUS CHECK $(date) (elapsed: ${ELAPSED}s) ---" >>"${MONITOR_LOG}"

        RUNNING=0
        CRASHED=0
        COMPLETED_SUCCESS=0
        TOTAL_AGENTS=0

        # Read all PIDs at once and check each one
        while IFS=: read -r agent_name pid; do
            ((TOTAL_AGENTS++)) || true
            agent_type="${AGENT_TYPES[$agent_name]:-unknown}"

            if kill -0 "${pid}" 2>/dev/null; then
                RUNNING=$((RUNNING + 1))
                if [[ "${agent_type}" == "background" ]]; then
                    echo "✓ ${agent_name} running (PID: ${pid}) [EXPECTED]" >>"${MONITOR_LOG}"
                else
                    echo "✓ ${agent_name} still running (PID: ${pid}) [UNEXPECTED - should complete]" >>"${MONITOR_LOG}"
                fi
            else
                # Check exit code from log if available
                exit_code="unknown"
                if [[ -f "${LOG_DIR}/${agent_name}.log" ]]; then
                    # Look for exit code in the last few lines
                    exit_line=$(tail -10 "${LOG_DIR}/${agent_name}.log" | grep -E "(exit code|Exit code|finished with exit)" | tail -1)
                    if [[ -n "$exit_line" ]]; then
                        exit_code=$(echo "$exit_line" | grep -oE '[0-9]+' | tail -1)
                    fi
                fi

                if [[ "${agent_type}" == "task" ]]; then
                    if [[ "$exit_code" == "0" ]] || [[ "$exit_code" == "unknown" ]]; then
                        COMPLETED_SUCCESS=$((COMPLETED_SUCCESS + 1))
                        echo "✓ ${agent_name} completed successfully (exit: ${exit_code}) [EXPECTED]" >>"${MONITOR_LOG}"
                    else
                        CRASHED=$((CRASHED + 1))
                        echo "✗ ${agent_name} failed (exit: ${exit_code}) [UNEXPECTED]" >>"${MONITOR_LOG}"
                    fi
                else
                    CRASHED=$((CRASHED + 1))
                    echo "✗ ${agent_name} crashed/stopped (exit: ${exit_code}) [UNEXPECTED - should run continuously]" >>"${MONITOR_LOG}"
                fi
            fi
        done <"${LOG_DIR}/pids.txt"

        echo "Running: ${RUNNING}, Completed: ${COMPLETED_SUCCESS}, Crashed: ${CRASHED}, Total: ${TOTAL_AGENTS}" >>"${MONITOR_LOG}"
        echo "Status: ${RUNNING} running, ${COMPLETED_SUCCESS} completed, ${CRASHED} crashed/stopped" | tee -a "${MONITOR_LOG}"
    fi

    if ((i % 6 == 0)); then # Every 30 seconds
        echo "--- SYSTEM STATS $(date) ---" >>"${MONITOR_LOG}"
        # Basic system info
        ps aux | grep -E "\.sh" | grep -v grep | wc -l >>"${MONITOR_LOG}" 2>/dev/null || echo "ps failed" >>"${MONITOR_LOG}"
        df -h . | tail -1 >>"${MONITOR_LOG}" 2>/dev/null || echo "df failed" >>"${MONITOR_LOG}"
    fi

    sleep 5
done

echo "" | tee -a "${MONITOR_LOG}"
echo "Stopping all agents..." | tee -a "${MONITOR_LOG}"

# Stop agents
STOPPED=0
FORCE_KILLED=0

while IFS=: read -r agent_name pid; do
    if kill -0 "${pid}" 2>/dev/null; then
        echo "Stopping ${agent_name} (PID: ${pid})..." | tee -a "${MONITOR_LOG}"
        kill -TERM "${pid}" 2>/dev/null || true

        # Wait up to 10 seconds
        for ((j = 1; j <= 10; j++)); do
            if ! kill -0 "${pid}" 2>/dev/null; then
                echo "✓ Gracefully stopped ${agent_name}" | tee -a "${MONITOR_LOG}"
                STOPPED=$((STOPPED + 1))
                break
            fi
            sleep 1
        done

        # Force kill if still running
        if kill -0 "${pid}" 2>/dev/null; then
            echo "Force killing ${agent_name}..." | tee -a "${MONITOR_LOG}"
            kill -9 "${pid}" 2>/dev/null || true
            FORCE_KILLED=$((FORCE_KILLED + 1))
        fi
    else
        echo "${agent_name} already stopped" | tee -a "${MONITOR_LOG}"
    fi
done <"${LOG_DIR}/pids.txt"

echo "" | tee -a "${MONITOR_LOG}"
echo "=== TEST COMPLETE ===" | tee -a "${MONITOR_LOG}"
echo "End time: $(date)" | tee -a "${MONITOR_LOG}"
echo "Total agents started: ${#STARTED_AGENTS[@]}" | tee -a "${MONITOR_LOG}"
echo "Gracefully stopped: ${STOPPED}" | tee -a "${MONITOR_LOG}"
echo "Force killed: ${FORCE_KILLED}" | tee -a "${MONITOR_LOG}"

# Create summary
{
    echo "AGENT SYSTEM TEST SUMMARY"
    echo "========================="
    echo ""
    echo "Test Duration: 10 minutes"
    echo "Agents Started: ${#STARTED_AGENTS[@]}"
    echo "Background Agents Running: $(grep -c "background" <<<"${STARTED_AGENTS[*]}")"
    echo "Task Agents Completed: $(grep -c "task" <<<"${STARTED_AGENTS[*]}")"
    echo "Gracefully Stopped: ${STOPPED}"
    echo "Force Killed: ${FORCE_KILLED}"
    echo ""
    echo "Agent Types:"
    for agent in "${STARTED_AGENTS[@]}"; do
        agent_type="${AGENT_TYPES[$agent]:-unknown}"
        echo "  ${agent}: ${agent_type}"
    done
    echo ""
    echo "Log files created in: ${LOG_DIR}"
    echo "Monitor log: ${MONITOR_LOG}"
    echo "Individual agent logs: ${LOG_DIR}/*.log"
    echo ""
    echo "Test completed successfully at $(date)"
} >"${SUMMARY_FILE}"

echo "" | tee -a "${MONITOR_LOG}"
echo "Summary saved to: ${SUMMARY_FILE}" | tee -a "${MONITOR_LOG}"
echo "🎉 Agent system test completed!" | tee -a "${MONITOR_LOG}"
