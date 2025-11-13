#!/bin/bash
# generate_weekly_report.sh - Generate comprehensive weekly progress reports

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS_DIR="${SCRIPT_DIR}/reports"
TRACKER_FILE="${SCRIPT_DIR}/ENHANCEMENT_PLAN_TRACKER.md"

# Create reports directory if it doesn't exist
mkdir -p "${REPORTS_DIR}"

# Function to get current week
get_week_info() {
    # macOS compatible date calculation
    local monday
    local sunday
    monday=$(date -v-monday +%Y-%m-%d)
    sunday=$(date -v+sunday +%Y-%m-%d)
    echo "${monday} to ${sunday}"
}

# Function to extract phase progress from tracker
get_phase_progress() {
    if [[ ! -f "${TRACKER_FILE}" ]]; then
        echo "Tracker file not found"
        return
    fi

    echo "## Phase Progress Summary"
    echo ""

    # Extract phase status using awk
    awk '
    /^### ✅ \*\*PHASE [0-9]+:/ {
        print "### " substr($0, 7) "\n✅ **COMPLETED**\n"
    }
    /^### 🔄 \*\*PHASE [0-9]+:/ {
        print "### " substr($0, 7) "\n🔄 **IN PROGRESS**\n"
    }
    /^### ⏳ \*\*PHASE [0-9]+:/ {
        print "### " substr($0, 7) "\n⏳ **PENDING**\n"
    }
    ' "${TRACKER_FILE}"
}

# Function to get system metrics
get_system_metrics() {
    echo "## System Health Metrics"
    echo ""

    # MCP Server status
    if curl -f -s http://localhost:5005/health >/dev/null 2>&1; then
        echo "✅ **MCP Server**: Operational"
    else
        echo "❌ **MCP Server**: Not responding"
    fi

    # Agent status
    if [[ -f "${SCRIPT_DIR}/agent_status.json" ]]; then
        healthy=$(jq '[.agents[] | select(.status == "healthy")] | length' "${SCRIPT_DIR}/agent_status.json" 2>/dev/null || echo "0")
        total=$(jq '.agents | length' "${SCRIPT_DIR}/agent_status.json" 2>/dev/null || echo "0")
        healthy=${healthy:-0}
        total=${total:-0}
        if [[ $total -gt 0 ]]; then
            pct=$((healthy * 100 / total))
            echo "📊 **Agent Health**: ${healthy}/${total} (${pct}%)"
        fi
    fi

    # Test coverage
    if [[ -f "${SCRIPT_DIR}/coverage.xml" ]]; then
        coverage=$(grep -o 'line-rate="[0-9.]*"' "${SCRIPT_DIR}/coverage.xml" | head -1 | sed 's/line-rate="//;s/"//' | awk '{printf "%.1f", $1 * 100}' 2>/dev/null || echo "0")
        echo "🧪 **Test Coverage**: ${coverage}%"
    fi

    # Performance metrics
    load_test_files=("${SCRIPT_DIR}/load_test_results_"*.json)
    if [[ -f "${load_test_files[0]}" ]]; then
        latest="${load_test_files[0]}"
        for file in "${load_test_files[@]}"; do
            [[ $file -nt $latest ]] && latest=$file
        done

        rps=$(jq -r '.summary.requests_per_second // 0' "$latest" 2>/dev/null || echo "0")
        p95=$(jq -r '.summary.response_time_p95 // 0' "$latest" 2>/dev/null || echo "0")
        echo "⚡ **Performance**: ${rps} RPS, ${p95}ms p95 response time"
    fi

    echo ""
}

# Function to get TODO progress
get_todo_progress() {
    echo "## TODO Processing Progress"
    echo ""

    if [[ -f "${SCRIPT_DIR}/todo_batch_progress.json" ]]; then
        processed=$(jq -r '.processed // 0' "${SCRIPT_DIR}/todo_batch_progress.json" 2>/dev/null)
        total=$(jq -r '.total_todos // 0' "${SCRIPT_DIR}/todo_batch_progress.json" 2>/dev/null)
        successful=$(jq -r '.successful // 0' "${SCRIPT_DIR}/todo_batch_progress.json" 2>/dev/null)
        failed=$(jq -r '.failed // 0' "${SCRIPT_DIR}/todo_batch_progress.json" 2>/dev/null)
        processed=${processed:-0}
        total=${total:-0}
        successful=${successful:-0}
        failed=${failed:-0}

        if [[ $total -gt 0 ]]; then
            pct=$((processed * 100 / total))
            if [[ $processed -gt 0 ]]; then
                success_pct=$((successful * 100 / processed))
            else
                success_pct=0
            fi
            echo "📋 **Overall Progress**: ${processed}/${total} (${pct}%)"
            echo "✅ **Success Rate**: ${successful}/${processed} (${success_pct}%)"
            echo "❌ **Failed**: ${failed}"
        else
            echo "📋 No TODO processing data available"
        fi
    else
        echo "📋 TODO progress file not found"
    fi

    echo ""
}

# Function to get recent commits and PRs
get_recent_activity() {
    echo "## Recent Development Activity"
    echo ""

    echo "### Recent Commits"
    if command -v git >/dev/null 2>&1 && [[ -d "${SCRIPT_DIR}/.git" ]]; then
        cd "${SCRIPT_DIR}"
        git log --oneline -10 --since="1 week ago" | sed 's/^/- /' || echo "No recent commits"
        cd - >/dev/null
    else
        echo "Git not available or not a git repository"
    fi

    echo ""
    echo "### Recent Pull Requests"
    # This would integrate with GitHub API in a real implementation
    echo "- PR tracking integration pending"
    echo ""
}

# Function to get quality gate status
get_quality_gates() {
    echo "## Quality Gates Status"
    echo ""

    local issues=0

    # Check MCP server
    if ! curl -f -s http://localhost:5005/health >/dev/null 2>&1; then
        echo "❌ **CRITICAL**: MCP server not responding"
        ((issues++))
    else
        echo "✅ MCP server health check passed"
    fi

    # Check error rates
    if [[ -f "${SCRIPT_DIR}/mcp_server.log" ]]; then
        errors=$(grep -c "ERROR\|CRITICAL" "${SCRIPT_DIR}/mcp_server.log" 2>/dev/null)
        errors=${errors:-0}
        if [[ $errors -gt 50 ]]; then
            echo "⚠️  **WARNING**: High error count (${errors})"
            ((issues++))
        else
            echo "✅ Error rate within acceptable limits"
        fi
    fi

    # Check agent health
    if [[ -f "${SCRIPT_DIR}/agent_status.json" ]]; then
        healthy=$(jq '[.agents[] | select(.status == "healthy")] | length' "${SCRIPT_DIR}/agent_status.json" 2>/dev/null || echo "0")
        total=$(jq '.agents | length' "${SCRIPT_DIR}/agent_status.json" 2>/dev/null || echo "0")
        healthy=${healthy:-0}
        total=${total:-0}

        if [[ $total -gt 0 ]]; then
            pct=$((healthy * 100 / total))
            if [[ $pct -lt 80 ]]; then
                echo "⚠️  **WARNING**: Agent health below 80% (${pct}%)"
                ((issues++))
            else
                echo "✅ Agent health acceptable"
            fi
        fi
    fi

    echo ""
    echo "**Total Quality Issues**: ${issues}"

    if [[ $issues -eq 0 ]]; then
        echo "🎉 **All quality gates passed!**"
    else
        echo "⚠️  **Action required**: ${issues} quality issues detected"
    fi

    echo ""
}

# Function to get next steps and priorities
get_next_steps() {
    echo "## Next Steps & Priorities"
    echo ""

    echo "### Immediate Priorities"
    echo "- Complete Step 11 automated updates integration"
    echo "- Implement GitHub Project board synchronization"
    echo "- Set up weekly progress report distribution"
    echo ""

    echo "### Medium-term Goals"
    echo "- Enhance monitoring dashboard with real-time metrics"
    echo "- Implement automated issue/PR updates"
    echo "- Add predictive analytics for system health"
    echo ""

    echo "### Long-term Vision"
    echo "- Full autonomous system evolution"
    echo "- Multi-dimensional deployment capabilities"
    echo "- Quantum-enhanced AI consciousness integration"
    echo ""
}

# Main report generation
main() {
    local week_info
    local report_file
    week_info=$(get_week_info)
    report_file="${REPORTS_DIR}/weekly_progress_$(date +%Y%m%d).md"

    echo "📊 Generating Weekly Progress Report..."
    echo "📅 Week: ${week_info}"
    echo "📄 Report: ${report_file}"

    # Generate report
    {
        echo "# Weekly Progress Report"
        echo ""
        echo "**Report Period**: ${week_info}"
        echo "**Generated**: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo ""

        get_phase_progress
        get_system_metrics
        get_todo_progress
        get_recent_activity
        get_quality_gates
        get_next_steps

        echo "---"
        echo "*This report was automatically generated by the Enhancement Plan Tracker system.*"
    } >"${report_file}"

    echo "✅ Weekly progress report generated: ${report_file}"
}

# Run main function
main "$@"
