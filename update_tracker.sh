#!/bin/bash
# update_tracker.sh - Automated progress tracking updates
# Updates ENHANCEMENT_PLAN_TRACKER.md with current system status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACKER_FILE="${SCRIPT_DIR}/ENHANCEMENT_PLAN_TRACKER.md"
TEMP_FILE="${TRACKER_FILE}.tmp"

echo "🔄 Updating Enhancement Plan Tracker..."

# Function to get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S %Z'
}

# Function to update last modified timestamp
update_timestamp() {
    local timestamp
    timestamp=$(get_timestamp)
    sed -i.bak "s|Last updated: .*|Last updated: ${timestamp}|" "${TRACKER_FILE}"
    rm -f "${TRACKER_FILE}.bak"
}

# Function to get system health metrics
get_system_health() {
    # Check MCP server status
    if curl -f -s http://localhost:5005/health >/dev/null 2>&1; then
        echo "✅ MCP Server: UP"
    else
        echo "❌ MCP Server: DOWN"
    fi

    # Check monitoring stack
    if curl -f -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
        echo "✅ Prometheus: UP"
    else
        echo "❌ Prometheus: DOWN"
    fi

    # Check agent count
    if [[ -f "${SCRIPT_DIR}/agent_status.json" ]]; then
        agent_count=$(jq '.agents | length' "${SCRIPT_DIR}/agent_status.json" 2>/dev/null || echo "0")
        echo "📊 Agents Tracked: ${agent_count}"
    fi
}

# Function to get TODO processing status
get_todo_status() {
    if [[ -f "${SCRIPT_DIR}/todo_batch_progress.json" ]]; then
        processed=$(jq -r '.processed // 0' "${SCRIPT_DIR}/todo_batch_progress.json" 2>/dev/null || echo "0")
        total=$(jq -r '.total_todos // 0' "${SCRIPT_DIR}/todo_batch_progress.json" 2>/dev/null || echo "0")
        successful=$(jq -r '.successful // 0' "${SCRIPT_DIR}/todo_batch_progress.json" 2>/dev/null || echo "0")

        if [[ ${total} -gt 0 ]]; then
            percentage=$((processed * 100 / total))
            echo "📋 TODO Progress: ${processed}/${total} (${percentage}%) - ${successful} successful"
        else
            echo "📋 TODO Progress: No data available"
        fi
    else
        echo "📋 TODO Progress: Progress file not found"
    fi
}

# Function to get test coverage status
get_test_status() {
    if command -v pytest >/dev/null 2>&1; then
        # Try to get coverage from pytest-cov if available
        if [[ -f "${SCRIPT_DIR}/coverage.xml" ]]; then
            # Extract coverage percentage from coverage.xml
            coverage_pct=$(grep -o 'line-rate="[0-9.]*"' "${SCRIPT_DIR}/coverage.xml" | head -1 | sed 's/line-rate="//;s/"//' | awk '{printf "%.1f", $1 * 100}')
            if [[ -n "${coverage_pct}" ]]; then
                echo "🧪 Test Coverage: ${coverage_pct}%"
                return
            fi
        fi

        # Fallback: check if tests exist and can run
        if [[ -d "${SCRIPT_DIR}/tests" ]]; then
            test_count=$(find "${SCRIPT_DIR}/tests" -name "*.py" | wc -l)
            echo "🧪 Tests Available: ${test_count} test files"
        fi
    else
        echo "🧪 pytest not available"
    fi
}

# Function to get performance metrics
get_performance_status() {
    # Check for recent load test results
    load_test_files=("${SCRIPT_DIR}/load_test_results_"*.json)
    if [[ -f "${load_test_files[0]}" ]]; then
        latest_load_test="${load_test_files[0]}"
        for file in "${load_test_files[@]}"; do
            if [[ "${file}" -nt "${latest_load_test}" ]]; then
                latest_load_test="${file}"
            fi
        done

        if [[ -f "${latest_load_test}" ]]; then
            rps=$(jq -r '.summary.requests_per_second // 0' "${latest_load_test}" 2>/dev/null || echo "0")
            p95=$(jq -r '.summary.response_time_p95 // 0' "${latest_load_test}" 2>/dev/null || echo "0")
            echo "⚡ Performance: ${rps} RPS, ${p95}ms p95"
        fi
    else
        echo "⚡ Performance: No recent load tests"
    fi
}

# Function to check quality gates
check_quality_gates() {
    local issues=0

    echo "🔍 Checking Quality Gates..."

    # Check MCP server health
    if ! curl -f -s http://localhost:5005/health >/dev/null 2>&1; then
        echo "❌ CRITICAL: MCP server not responding"
        ((issues++))
    else
        echo "✅ MCP server health check passed"
    fi

    # Check for critical errors in logs
    if [[ -f "${SCRIPT_DIR}/mcp_server.log" ]]; then
        critical_errors=$(grep -c "ERROR\|CRITICAL" "${SCRIPT_DIR}/mcp_server.log" 2>/dev/null)
        critical_errors=${critical_errors:-0} # Ensure it's a number
        if [[ ${critical_errors} -gt 10 ]]; then
            echo "⚠️  WARNING: High error count in MCP logs (${critical_errors})"
        else
            echo "✅ Error rate within acceptable limits"
        fi
    fi

    # Check agent status
    if [[ -f "${SCRIPT_DIR}/agent_status.json" ]]; then
        healthy_agents=$(jq '[.agents[] | select(.status == "healthy")] | length' "${SCRIPT_DIR}/agent_status.json" 2>/dev/null || echo "0")
        total_agents=$(jq '.agents | length' "${SCRIPT_DIR}/agent_status.json" 2>/dev/null || echo "0")
        healthy_agents=${healthy_agents:-0}
        total_agents=${total_agents:-0}

        if [[ ${total_agents} -gt 0 ]]; then
            health_pct=$((healthy_agents * 100 / total_agents))
            if [[ ${health_pct} -lt 80 ]]; then
                echo "⚠️  WARNING: Agent health below 80% (${health_pct}%)"
                ((issues++))
            else
                echo "✅ Agent health acceptable (${health_pct}%)"
            fi
        fi
    fi

    return ${issues}
}

# Main update process
echo "📊 Gathering system metrics..."

# Get current status
SYSTEM_HEALTH=$(get_system_health)
TODO_STATUS=$(get_todo_status)
TEST_STATUS=$(get_test_status)
PERFORMANCE_STATUS=$(get_performance_status)

echo "📈 Current Status:"
echo "${SYSTEM_HEALTH}"
echo "${TODO_STATUS}"
echo "${TEST_STATUS}"
echo "${PERFORMANCE_STATUS}"

# Check quality gates
if check_quality_gates; then
    echo "✅ All quality gates passed"
else
    echo "❌ Quality gate issues detected"
fi

# Update timestamp
update_timestamp

echo "✅ Enhancement Plan Tracker updated successfully"
echo "📅 Last updated: $(get_timestamp)"

# Optional: Generate summary report
if [[ "${1:-}" == "--report" ]]; then
    echo ""
    echo "📋 System Status Summary"
    echo "========================"
    echo "${SYSTEM_HEALTH}"
    echo "${TODO_STATUS}"
    echo "${TEST_STATUS}"
    echo "${PERFORMANCE_STATUS}"
    echo ""
    echo "📧 Report generated at $(get_timestamp)"
fi
