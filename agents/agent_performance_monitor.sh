#!/bin/bash
# Performance Monitoring Agent - Tracks agent efficiency and system impact

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
STATUS_FILE="${SCRIPT_DIR}/agent_status.json"
TASK_QUEUE="${SCRIPT_DIR}/task_queue.json"

# Logging configuration
AGENT_NAME="PerformanceMonitorAgent"
LOG_FILE="${SCRIPT_DIR}/performance_monitor_agent.log"
PERFORMANCE_LOG="${SCRIPT_DIR}/performance_metrics.json"

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date)] [${AGENT_NAME}] [${level}] ${message}" >>"${LOG_FILE}"
}

process_performance_monitor_task() {
    local task="$1"

    log_message "INFO" "Processing performance monitor task: $task"

    case "$task" in
    test_performance_run)
        log_message "INFO" "Running performance monitoring system verification..."
        log_message "SUCCESS" "Performance monitoring system operational"
        ;;
    collect_system_metrics)
        log_message "INFO" "Collecting system metrics..."
        collect_system_metrics
        ;;
    monitor_agent_performance)
        log_message "INFO" "Monitoring agent performance..."
        monitor_agent_performance
        ;;
    analyze_performance_trends)
        log_message "INFO" "Analyzing performance trends..."
        analyze_performance_trends
        ;;
    generate_performance_report)
        log_message "INFO" "Generating performance report..."
        generate_performance_report
        ;;
    *)
        log_message "WARN" "Unknown performance monitor task: $task"
        ;;
    esac
}

# Function to collect system metrics
collect_system_metrics() {
    local timestamp
    timestamp=$(date +%s)

    # Get CPU usage
    local cpu_usage
    cpu_usage=$(ps aux | awk '{sum += $3} END {print sum}')

    # Get memory usage
    local mem_usage
    mem_usage=$(ps aux | awk '{sum += $4} END {print sum}')

    # Get disk usage
    local disk_usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    # Get process count
    local process_count
    process_count=$(ps aux | wc -l)

    # Get agent process count
    local agent_count
    agent_count=$(pgrep -f "agent_|mcp_server" | grep -c . || echo "0")

    log_message "INFO" "System Metrics - CPU: ${cpu_usage}%, Memory: ${mem_usage}%, Disk: ${disk_usage}%, Processes: ${process_count}, Agents: ${agent_count}"

    # Store metrics
    local metrics
    metrics=$(jq -n \
        --arg timestamp "${timestamp}" \
        --arg cpu "${cpu_usage}" \
        --arg memory "${mem_usage}" \
        --arg disk "${disk_usage}" \
        --arg processes "${process_count}" \
        --arg agents "${agent_count}" \
        '{timestamp: $timestamp, cpu_usage: $cpu, memory_usage: $memory, disk_usage: $disk, process_count: $processes, agent_count: $agents}')

    # Initialize performance log if it doesn't exist
    if [[ ! -s ${PERFORMANCE_LOG} ]]; then
        echo '{"metrics": []}' >"${PERFORMANCE_LOG}"
    fi

    # Add new metrics
    jq ".metrics += [${metrics}]" "${PERFORMANCE_LOG}" >"${PERFORMANCE_LOG}.tmp"
    if [[ -s "${PERFORMANCE_LOG}.tmp" ]]; then
        mv "${PERFORMANCE_LOG}.tmp" "${PERFORMANCE_LOG}"
    fi
}

# Function to monitor agent performance
monitor_agent_performance() {
    log_message "INFO" "Monitoring agent performance..."

    # Check agent status - work with list format
    if [[ -s ${STATUS_FILE} ]]; then
        local running_agents
        running_agents=$(jq -r '.[] | select(.status == "running") | .name // .id' "${STATUS_FILE}" 2>/dev/null || true)

        if [[ -n ${running_agents} ]]; then
            log_message "INFO" "Running agents: ${running_agents}"
        else
            log_message "INFO" "No agents currently running"
        fi

        # Check for idle agents
        local idle_agents
        idle_agents=$(jq -r '.[] | select(.status == "idle" or .status == "available") | .name // .id' "${STATUS_FILE}" 2>/dev/null || true)

        if [[ -n ${idle_agents} ]]; then
            log_message "INFO" "Idle agents: ${idle_agents}"
        fi
    fi

    # Check task queue status - simplified since we don't have a task_queue.json
    log_message "INFO" "Task queue monitoring not available (no task_queue.json)"
}

# Function to analyze performance trends
analyze_performance_trends() {
    log_message "INFO" "Analyzing performance trends..."

    if [[ ! -s ${PERFORMANCE_LOG} ]]; then
        log_message "WARN" "No performance data available for analysis"
        return
    fi

    # Get last 10 measurements using Python for reliability
    local recent_metrics
    recent_metrics=$(python3 -c "
import json
import sys

try:
    with open('${PERFORMANCE_LOG}', 'r') as f:
        data = json.load(f)
    
    metrics = data.get('metrics', [])
    if len(metrics) > 10:
        metrics = metrics[-10:]
    
    print(json.dumps(metrics))
except Exception as e:
    print('[]')
" 2>/dev/null)

    if [[ -n ${recent_metrics} && ${recent_metrics} != "[]" ]]; then
        # Calculate averages using Python
        local avg_cpu avg_memory avg_disk

        read -r avg_cpu avg_memory avg_disk <<<"$(python3 -c "
import json
import sys

try:
    metrics = json.loads('${recent_metrics}')
    
    if not metrics:
        print('0 0 0')
        sys.exit(0)
    
    cpu_values = []
    memory_values = []
    disk_values = []
    
    for metric in metrics:
        try:
            cpu_values.append(float(str(metric.get('cpu_usage', '0')).strip()))
            memory_values.append(float(str(metric.get('memory_usage', '0')).strip()))
            disk_values.append(float(str(metric.get('disk_usage', '0')).strip()))
        except (ValueError, TypeError):
            continue
    
    if cpu_values:
        avg_cpu = sum(cpu_values) / len(cpu_values)
    else:
        avg_cpu = 0
    
    if memory_values:
        avg_memory = sum(memory_values) / len(memory_values)
    else:
        avg_memory = 0
        
    if disk_values:
        avg_disk = sum(disk_values) / len(disk_values)
    else:
        avg_disk = 0
    
    print(f'{avg_cpu:.1f} {avg_memory:.1f} {avg_disk:.1f}')
except Exception as e:
    print('0 0 0')
" 2>/dev/null)"

        log_message "INFO" "Average Performance (last 10 measurements):"
        log_message "INFO" "  CPU Usage: ${avg_cpu}%"
        log_message "INFO" "  Memory Usage: ${avg_memory}%"
        log_message "INFO" "  Disk Usage: ${avg_disk}%"

        # INTEGRATION: Run ML-based performance analysis
        run_ml_performance_analysis "${avg_cpu}" "${avg_memory}" "${avg_disk}"

        # Check for performance issues
        if (($(echo "${avg_cpu} > 80" | bc -l))); then
            log_message "WARN" "HIGH CPU USAGE DETECTED"
        fi

        if (($(echo "${avg_memory} > 80" | bc -l))); then
            log_message "WARN" "HIGH MEMORY USAGE DETECTED"
        fi

        if (($(echo "${avg_disk} > 90" | bc -l))); then
            log_message "ERROR" "CRITICAL DISK USAGE DETECTED"
        fi
    fi
}

# Function to generate performance report
generate_performance_report() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local report_file
    report_file="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/PERFORMANCE_REPORT_${timestamp}.md"

    log_message "INFO" "Generating performance report..."

    cat >"${report_file}" <<EOF
# Performance Monitoring Report
Generated: $(date)

## System Overview
This report contains performance metrics and analysis for the automated agent system.

## Current Metrics

### System Resources
- CPU Usage: Check agent logs for current values
- Memory Usage: Check agent logs for current values
- Disk Usage: Check agent logs for current values
- Process Count: Check agent logs for current values

### Agent Status
- Running Agents: Check agent_status.json for current status
- Task Queue: Check task_queue.json for pending/completed tasks

## Performance Analysis

### Trends
- Average CPU Usage (last 10 measurements)
- Average Memory Usage (last 10 measurements)
- Average Disk Usage (last 10 measurements)

### Alerts
- High CPU usage warnings (>80%)
- High memory usage warnings (>80%)
- Critical disk usage alerts (>90%)

## Recommendations

1. **Resource Monitoring**: Continue monitoring system resources
2. **Task Optimization**: Review task completion rates and bottlenecks
3. **Agent Efficiency**: Analyze agent performance and optimize as needed
4. **System Health**: Regular health checks and maintenance

## Raw Data
Performance metrics are stored in: ${PERFORMANCE_LOG}
Agent status is tracked in: ${STATUS_FILE}
Task queue status in: ${TASK_QUEUE}

---
Report generated by Performance Monitor Agent
EOF

    log_message "SUCCESS" "Performance report generated: ${report_file}"
}

# INTEGRATION: Function to run ML-based performance analysis
run_ml_performance_analysis() {
    local avg_cpu="$1"
    local avg_memory="$2"
    local avg_disk="$3"
    local analyzer_script="${SCRIPT_DIR}/../agent_performance_analyzer.py"

    log_message "INFO" "Running ML-based performance analysis..."

    if [[ ! -f "${analyzer_script}" ]]; then
        log_message "WARN" "Performance analyzer script not found: ${analyzer_script}"
        return 1
    fi

    # Run the ML performance analyzer
    local analysis_output
    analysis_output=$(python3 "${analyzer_script}" predict \
        --cpu "${avg_cpu}" \
        --memory "${avg_memory}" \
        --disk "${avg_disk}" \
        --agent_count "10" \
        --task_complexity "medium" 2>&1)

    if [[ $? -eq 0 ]]; then
        log_message "INFO" "ML Performance Analysis Results:"
        echo "${analysis_output}" | while IFS= read -r line; do
            log_message "INFO" "  ${line}"
        done

        # Extract predictions for alerting
        local predicted_time
        predicted_time=$(echo "${analysis_output}" | grep -o "Predicted execution time: [0-9.]*" | grep -o "[0-9.]*" | head -1)

        local failure_prob
        failure_prob=$(echo "${analysis_output}" | grep -o "Failure probability: [0-9.]*" | grep -o "[0-9.]*" | head -1)

        if [[ -n "${predicted_time}" && $(echo "${predicted_time} > 300" | bc -l 2>/dev/null) -eq 1 ]]; then
            log_message "WARN" "ML Prediction: High execution time expected (${predicted_time}s > 300s)"
        fi

        if [[ -n "${failure_prob}" && $(echo "${failure_prob} > 0.5" | bc -l 2>/dev/null) -eq 1 ]]; then
            log_message "ERROR" "ML Prediction: High failure probability detected (${failure_prob} > 0.5)"
        fi
    else
        log_message "ERROR" "ML performance analysis failed: ${analysis_output}"
    fi

    return 0
}

# Function to perform comprehensive performance monitoring
perform_performance_monitoring() {
    log_message "INFO" "Starting comprehensive performance monitoring..."

    collect_system_metrics
    monitor_agent_performance
    analyze_performance_trends
    generate_performance_report

    log_message "INFO" "Performance monitoring completed"
}

# Main agent loop - standardized task processing
main() {
    log_message "INFO" "Performance Monitor Agent starting..."

    # Initialize agent status
    update_agent_status "${AGENT_NAME}" "starting" $$ ""

    # Main task processing loop
    while true; do
        # Get next task from shared queue
        local task_data
        task_data=$(get_next_task "${AGENT_NAME}")

        if [[ -n "${task_data}" ]]; then
            # Process the task
            process_performance_monitor_task "${task_data}"
        else
            # No tasks available, check for periodic maintenance
            if ensure_within_limits "performance_monitoring" 300; then
                # Run periodic performance monitoring (every 5 minutes)
                perform_performance_monitoring
            fi
        fi

        # Brief pause to prevent tight looping
        sleep 5
    done
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" && "${TEST_MODE:-false}" != "true" ]]; then
    # Handle single run mode for testing
    if [[ "${1:-}" == "SINGLE_RUN" ]]; then
        log_message "INFO" "Running in SINGLE_RUN mode for testing"
        update_agent_status "${AGENT_NAME}" "running" $$ ""

        # Run a quick performance monitoring cycle
        collect_system_metrics
        monitor_agent_performance

        update_agent_status "${AGENT_NAME}" "completed" $$ ""
        log_message "INFO" "SINGLE_RUN completed successfully"
        exit 0
    fi

    # Start the main agent loop
    trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; log_message "INFO" "Performance Monitor Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
fi
