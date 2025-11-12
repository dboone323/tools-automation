#!/bin/bash
# AI Code Review Agent: Automated code review with AI-powered analysis and suggestions

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Agent throttling configuration
MAX_CONCURRENCY="${MAX_CONCURRENCY:-1}" # Maximum concurrent instances of this agent (code review is intensive)
LOAD_THRESHOLD="${LOAD_THRESHOLD:-3.0}" # System load threshold (code review needs more resources)
WAIT_WHEN_BUSY="${WAIT_WHEN_BUSY:-60}"  # Seconds to wait when system is busy

# Function to check if we should proceed with task processing
ensure_within_limits() {
    local agent_name="ai_code_review_agent.sh"

    # Check concurrent instances
    local running_count=$(pgrep -f "${agent_name}" | wc -l)
    if [[ ${running_count} -gt ${MAX_CONCURRENCY} ]]; then
        log "Too many concurrent instances (${running_count}/${MAX_CONCURRENCY}). Waiting..."
        return 1
    fi

    # Check system load (macOS compatible)
    local load_avg
    if command -v sysctl >/dev/null 2>&1; then
        # macOS: use sysctl vm.loadavg
        load_avg=$(sysctl -n vm.loadavg | awk '{print $2}')
    else
        # Fallback: use uptime
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
    fi

    # Compare load as float
    if (($(echo "${load_avg} >= ${LOAD_THRESHOLD}" | bc -l 2>/dev/null || echo "0"))); then
        log "System load too high (${load_avg} >= ${LOAD_THRESHOLD}). Waiting..."
        return 1
    fi

    return 0
}

AGENT_NAME="ai_code_review_agent.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/ai_code_review_agent.log"
NOTIFICATION_FILE="${WORKSPACE}/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
OLLAMA_ENDPOINT="http://localhost:11434"
RESULTS_DIR="${WORKSPACE}/Tools/Automation/results"

# Logging function
log() {
    echo "[$(date)] ${AGENT_NAME}: $*" >>"${LOG_FILE}"
}

# Ollama Integration Functions (policy-aware)
ollama_query() {
    local prompt="$1"
    # Route via unified client with task mapping for analysis
    local input_json
    input_json=$(jq -n --arg task "codeAnalysis" --arg prompt "$prompt" '{task:$task, prompt:$prompt}')
    echo "$input_json" | "$SCRIPT_DIR/../ollama_client.sh" | jq -r '.text // empty'
}

# Update agent status
update_status() {
    local status="$1"
    if command -v jq &>/dev/null; then
        jq "(.[] | select(.id == \"${AGENT_NAME}\") | .status) = \"${status}\" | (.[] | select(.id == \"${AGENT_NAME}\") | .last_seen) = $(date +%s)" "${AGENT_STATUS_FILE}" >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
    fi
    echo "[$(date)] ${AGENT_NAME}: Status updated to ${status}" >>"${LOG_FILE}"
}

# Process a specific task
process_task() {
    local task_id="$1"
    echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id}" >>"${LOG_FILE}"

    # Get task details
    if command -v jq &>/dev/null; then
        local task_desc
        task_desc=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .description" "${TASK_QUEUE_FILE}")
        local task_type
        task_type=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .type" "${TASK_QUEUE_FILE}")
        echo "[$(date)] ${AGENT_NAME}: Task description: ${task_desc}" >>"${LOG_FILE}"
        echo "[$(date)] ${AGENT_NAME}: Task type: ${task_type}" >>"${LOG_FILE}"

        # Process based on task type
        case "${task_type}" in
        "code_review" | "ai_review" | "review")
            run_ai_code_review "${task_desc}"
            ;;
        *)
            echo "[$(date)] ${AGENT_NAME}: Unknown task type: ${task_type}" >>"${LOG_FILE}"
            ;;
        esac

        # Mark task as completed
        update_task_status "${task_id}" "completed"
    increment_task_count "${AGENT_NAME}"
        echo "[$(date)] ${AGENT_NAME}: Task ${task_id} completed" >>"${LOG_FILE}"
    fi
}

# Update task status
update_task_status() {
    local task_id="$1"
    local status="$2"
    if command -v jq &>/dev/null; then
        jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
    fi
}

# Main AI code review function
run_ai_code_review() {
    local task_desc="$1"
    log "Running AI code review for: ${task_desc}"

    # Get changed files from git
    local changed_files
    changed_files=$(git diff --name-only HEAD~1 2>/dev/null || git diff --name-only --cached 2>/dev/null || find "${WORKSPACE}/Projects" -name "*.swift" -type f | head -10)

    if [[ -z "${changed_files}" ]]; then
        log "No changed files detected, reviewing all Swift files"
        changed_files=$(find "${WORKSPACE}/Projects" -name "*.swift" -type f | head -20)
    fi

    local review_results=""
    local total_files=0
    local issues_found=0
    local suggestions_made=0

    for file in ${changed_files}; do
        if [[ -f "${file}" && "${file}" == *.swift ]]; then
            log "Reviewing file: ${file}"
            ((total_files++))

            # Perform comprehensive code review
            local file_issues
            file_issues=$(review_swift_file "${file}")
            if [[ -n "${file_issues}" ]]; then
                review_results+="# ${file}\n\n${file_issues}\n\n"
                ((issues_found++))
            fi

            # Generate improvement suggestions
            local file_suggestions
            file_suggestions=$(generate_improvements "${file}")
            if [[ -n "${file_suggestions}" ]]; then
                review_results+="# ${file}\n\n${file_suggestions}\n\n"
                ((suggestions_made++))
            fi
        fi
    done

    # Generate overall review report
    generate_review_report "${review_results}" "${total_files}" "${issues_found}" "${suggestions_made}"

    # Run security-focused review
    run_security_review "${changed_files}"

    # Generate performance analysis
    run_performance_analysis "${changed_files}"

    log "AI code review completed: ${total_files} files reviewed, ${issues_found} issues found, ${suggestions_made} suggestions made"
}

# Review a single Swift file
review_swift_file() {
    local file_path="$1"
    local file_content
    file_content=$(head -100 "${file_path}") # Limit to first 100 lines for analysis

    local file_name
    file_name=$(basename "${file_path}")

    # Analyze code quality aspects
    local issues=""

    # Check for common Swift issues
    if grep -q "TODO\|FIXME\|HACK" "${file_path}"; then
        issues+="### Code Quality Issues\n"
        issues+="- **TODO/FIXME Comments**: Found markers that should be addressed\n"
    fi

    if grep -q "print(" "${file_path}"; then
        issues+="### Debug Code\n"
        issues+="- **Print Statements**: Debug print statements should be removed from production code\n"
    fi

    if grep -q "force unwrap" "${file_path}" || grep -q "!" "${file_path}"; then
        issues+="### Force Unwrapping\n"
        issues+="- **Force Unwrap**: Consider using optional binding instead of force unwrapping\n"
    fi

    # Use AI for deeper analysis
    local ai_review_prompt="Analyze this Swift code for potential issues, improvements, and best practices:

File: ${file_name}
Code:
${file_content}

Please identify:
1. Code quality issues (naming, structure, complexity)
2. Potential bugs or logic errors
3. Performance concerns
4. Security vulnerabilities
5. Swift best practices violations
6. Architecture or design issues

Format as a structured code review with specific recommendations."

    local ai_issues
    ai_issues=$(ollama_query "${ai_review_prompt}")

    if [[ -n "${ai_issues}" ]]; then
        issues+="### AI-Powered Analysis\n"
        issues+="${ai_issues}\n"
    fi

    echo "${issues}"
}

# Generate improvement suggestions
generate_improvements() {
    local file_path="$1"
    local file_content
    file_content=$(head -100 "${file_path}")

    local file_name
    file_name=$(basename "${file_path}")

    local improvement_prompt="Suggest specific improvements for this Swift code:

File: ${file_name}
Code:
${file_content}

Please suggest:
1. Code refactoring opportunities
2. Performance optimizations
3. Better error handling patterns
4. More idiomatic Swift usage
5. Documentation improvements
6. Testability enhancements

Focus on actionable, specific suggestions with code examples where helpful."

    local ai_suggestions
    ai_suggestions=$(ollama_query "${improvement_prompt}")

    if [[ -n "${ai_suggestions}" ]]; then
        echo "### AI Improvement Suggestions
${ai_suggestions}"
    fi
}

# Generate comprehensive review report
generate_review_report() {
    local review_results="$1"
    local total_files="$2"
    local issues_found="$3"
    local suggestions_made="$4"

    local report_file="${RESULTS_DIR}/ai_code_review_report_$(date +%Y%m%d_%H%M%S).md"
    mkdir -p "${RESULTS_DIR}"

    {
        echo "# AI Code Review Report"
        echo "**Generated:** $(date)"
        echo "**Framework:** AI-Powered Code Analysis"
        echo ""
        echo "## Summary"
        echo ""
        echo "- **Files Reviewed:** ${total_files}"
        echo "- **Issues Found:** ${issues_found}"
        echo "- **Suggestions Made:** ${suggestions_made}"
        echo "- **Review Type:** Comprehensive AI Analysis"
        echo ""
        echo "## Review Results"
        echo ""
        if [[ -n "${review_results}" ]]; then
            echo "${review_results}"
        else
            echo "### No Major Issues Found"
            echo ""
            echo "The AI code review analysis completed successfully with no significant issues detected."
            echo "All reviewed code appears to follow good practices and patterns."
            echo ""
        fi
        echo "## Recommendations"
        echo ""
        echo "### Code Quality"
        echo "- Address any TODO/FIXME comments found"
        echo "- Remove debug print statements"
        echo "- Use optional binding instead of force unwrapping where safe"
        echo "- Follow Swift naming conventions"
        echo ""
        echo "### Best Practices"
        echo "- Add comprehensive error handling"
        echo "- Include unit tests for new functionality"
        echo "- Document public APIs and complex logic"
        echo "- Consider performance implications of algorithms"
        echo ""
        echo "### Security Considerations"
        echo "- Validate input data thoroughly"
        echo "- Use secure coding practices for sensitive operations"
        echo "- Consider thread safety for shared resources"
        echo ""
        echo "---"
        echo "*Generated by AI Code Review Agent*"
    } >"${report_file}"

    log "Review report generated: ${report_file}"
}

# Run security-focused code review
run_security_review() {
    local changed_files="$1"
    log "Running security-focused code review..."

    local security_issues=""

    for file in ${changed_files}; do
        if [[ -f "${file}" && "${file}" == *.swift ]]; then
            local file_security
            file_security=$(analyze_security "${file}")
            if [[ -n "${file_security}" ]]; then
                security_issues+="# ${file}\n\n${file_security}\n\n"
            fi
        fi
    done

    if [[ -n "${security_issues}" ]]; then
        local security_report="${RESULTS_DIR}/security_review_report_$(date +%Y%m%d_%H%M%S).md"
        {
            echo "# Security Code Review Report"
            echo "**Generated:** $(date)"
            echo "**Focus:** Security Vulnerabilities and Best Practices"
            echo ""
            echo "## Security Analysis Results"
            echo ""
            echo "${security_issues}"
            echo "---"
            echo "*Generated by AI Code Review Agent*"
        } >"${security_report}"

        log "Security review report generated: ${security_report}"
    fi
}

# Analyze security aspects of a file
analyze_security() {
    local file_path="$1"
    local file_content
    file_content=$(head -100 "${file_path}")

    local security_prompt="Analyze this Swift code for security vulnerabilities and concerns:

Code:
${file_content}

Please identify:
1. Input validation issues
2. Potential injection vulnerabilities
3. Insecure data handling
4. Authentication/authorization problems
5. Cryptographic issues
6. Privacy concerns
7. Secure coding best practices violations

Focus on actionable security recommendations."

    local ai_security
    ai_security=$(ollama_query "${security_prompt}")

    if [[ -n "${ai_security}" ]]; then
        echo "### Security Analysis
${ai_security}"
    fi
}

# Run performance analysis
run_performance_analysis() {
    local changed_files="$1"
    log "Running performance analysis..."

    local performance_issues=""

    for file in ${changed_files}; do
        if [[ -f "${file}" && "${file}" == *.swift ]]; then
            local file_performance
            file_performance=$(analyze_performance "${file}")
            if [[ -n "${file_performance}" ]]; then
                performance_issues+="# ${file}\n\n${file_performance}\n\n"
            fi
        fi
    done

    if [[ -n "${performance_issues}" ]]; then
        local perf_report="${RESULTS_DIR}/performance_analysis_report_$(date +%Y%m%d_%H%M%S).md"
        {
            echo "# Performance Analysis Report"
            echo "**Generated:** $(date)"
            echo "**Focus:** Code Performance and Optimization"
            echo ""
            echo "## Performance Analysis Results"
            echo ""
            echo "${performance_issues}"
            echo "---"
            echo "*Generated by AI Code Review Agent*"
        } >"${perf_report}"

        log "Performance analysis report generated: ${perf_report}"
    fi
}

# Analyze performance aspects of a file
analyze_performance() {
    local file_path="$1"
    local file_content
    file_content=$(head -100 "${file_path}")

    local perf_prompt="Analyze this Swift code for performance issues and optimization opportunities:

Code:
${file_content}

Please identify:
1. Inefficient algorithms or data structures
2. Memory leaks or retain cycles
3. Unnecessary computations
4. UI blocking operations
5. Large object allocations
6. Optimization opportunities
7. Concurrency issues affecting performance

Provide specific performance recommendations with code examples where helpful."

    local ai_performance
    ai_performance=$(ollama_query "${perf_prompt}")

    if [[ -n "${ai_performance}" ]]; then
        echo "### Performance Analysis
${ai_performance}"
    fi
}

# Main agent loop
echo "[$(date)] ${AGENT_NAME}: Starting AI code review agent..." >>"${LOG_FILE}"
update_status "available"

# Track processed tasks to avoid duplicates
processed_tasks_file="${WORKSPACE}/Tools/Automation/agents/${AGENT_NAME}_processed_tasks.txt"
touch "${processed_tasks_file}"

# Check for command-line arguments (direct execution mode)
if [[ $# -gt 0 ]]; then
    case "$1" in
    "review" | "code_review" | "ai_review")
        log "Direct execution mode: running AI code review"
        update_status "busy"
        run_ai_code_review "Comprehensive AI-powered code review"
        update_status "available"
        log "Direct execution completed"
        exit 0
        ;;
    *)
        log "Unknown command: $1"
        exit 1
        ;;
    esac
fi

while true; do
    # Check if we should proceed (throttling)
    if ! ensure_within_limits; then
        # Wait when busy, with exponential backoff
        wait_time=${WAIT_WHEN_BUSY}
        attempts=0
        while ! ensure_within_limits && [[ ${attempts} -lt 10 ]]; do
            log "Waiting ${wait_time}s before retry (attempt $((attempts + 1))/10)"
            sleep "${wait_time}"
            wait_time=$((wait_time * 2))                          # Exponential backoff
            if [[ ${wait_time} -gt 300 ]]; then wait_time=300; fi # Cap at 5 minutes
            ((attempts++))
        done

        # If still busy after retries, skip this cycle
        if ! ensure_within_limits; then
            log "System still busy after retries. Skipping cycle."
            sleep 60
            continue
        fi
    fi

    # Check for new task notifications
    if [[ -f ${NOTIFICATION_FILE} ]]; then
        while IFS='|' read -r _ action task_id; do
            if [[ ${action} == "execute_task" && -z $(grep "^${task_id}$" "${processed_tasks_file}") ]]; then
                update_status "busy"
                process_task "${task_id}"
                update_status "available"
                echo "${task_id}" >>"${processed_tasks_file}"
                echo "[$(date)] ${AGENT_NAME}: Marked task ${task_id} as processed" >>"${LOG_FILE}"
            fi
        done <"${NOTIFICATION_FILE}"

        # Clear processed notifications to prevent re-processing
        true >"${NOTIFICATION_FILE}"
    fi

    # Update last seen timestamp
    update_status "available"

    sleep 60 # Check every 60 seconds (code review is less frequent)
done
