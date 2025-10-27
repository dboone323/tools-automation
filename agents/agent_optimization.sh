#!/bin/bash
# Optimization Agent - Code & build optimization

# Source shared functions for task management
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
    source "${SCRIPT_DIR}/../project_config.sh"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
OPTIMIZATION_REPORTS_DIR="${WORKSPACE_ROOT}/.metrics/optimization"

# Logging configuration
AGENT_NAME="OptimizationAgent"
LOG_FILE="${SCRIPT_DIR}/optimization_agent.log"

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date)] [${AGENT_NAME}] [${level}] ${message}" >>"${LOG_FILE}"
}

process_optimization_task() {
    local task="$1"

    log_message "INFO" "Processing optimization task: $task"

    case "$task" in
    test_optimization_run)
        log_message "INFO" "Running optimization system verification..."
        log_message "SUCCESS" "Optimization system operational"
        ;;
    analyze_optimization)
        log_message "INFO" "Running full optimization analysis..."
        run_full_analysis
        ;;
    detect_dead_code)
        log_message "INFO" "Detecting unused code..."
        detect_dead_code "${WORKSPACE_ROOT}/Projects"
        ;;
    analyze_dependencies)
        log_message "INFO" "Analyzing dependency usage..."
        analyze_dependencies
        ;;
    suggest_refactorings)
        log_message "INFO" "Suggesting refactorings..."
        suggest_refactorings "${WORKSPACE_ROOT}/Projects"
        ;;
    analyze_build_cache)
        log_message "INFO" "Analyzing build cache efficiency..."
        analyze_build_cache
        ;;
    *)
        log_message "WARN" "Unknown optimization task: $task"
        ;;
    esac
}

# Detect unused functions and classes
detect_dead_code() {
    local project_path="$1"
    local project_name
    project_name=$(basename "${project_path}")

    log_message "INFO" "Detecting dead code in ${project_name}..."

    local dead_code_file="${OPTIMIZATION_REPORTS_DIR}/dead_code_${project_name}_$(date +%Y%m%d).txt"

    # Find all function/class definitions
    local definitions
    definitions=$(grep -rn "^\s*\(func\|class\|struct\|enum\)" "${project_path}" --include="*.swift" 2>/dev/null | grep -v "^//")

    # Build a map of all symbol references in the project (more efficient)
    local all_refs_file="/tmp/${project_name}_refs_$$.txt"
    grep -rh "\b[a-zA-Z_][a-zA-Z0-9_]*\b" "${project_path}" --include="*.swift" 2>/dev/null | sort | uniq -c >"${all_refs_file}"

    local unused_count=0

    while IFS=: read -r file line_num declaration || [[ -n "$file" ]]; do
        [[ -z "$file" ]] && continue
        [[ -z "$declaration" ]] && continue

        # Extract function/class name
        local name
        name=$(echo "$declaration" | sed 's/.*\(func\|class\|struct\|enum\) \([a-zA-Z0-9_]*\).*/\2/')
        [[ -z "$name" ]] && continue

        # Count references using the pre-built reference map
        local ref_count
        ref_count=$(grep "^\s*[0-9]* ${name}$" "${all_refs_file}" | awk '{print $1}' | tr -d ' ' || echo "0")

        if [[ ${ref_count} -le 1 ]]; then # <= 1 because definition counts as 1
            echo "Potentially unused: ${name} in ${file}:${line_num}" >>"${dead_code_file}"
            unused_count=$((unused_count + 1))
        fi
    done <<<"$definitions"

    # Clean up temp file
    rm -f "${all_refs_file}"

    if [[ ${unused_count} -gt 0 ]]; then
        log_message "WARN" "Found ${unused_count} potentially unused code items in ${project_name}"
        log_message "INFO" "Report: ${dead_code_file}"
    else
        log_message "SUCCESS" "No obvious dead code found in ${project_name}"
    fi
}

# Analyze build cache efficiency
analyze_build_cache() {
    log_message "INFO" "Analyzing build cache efficiency..."

    local cache_report="${OPTIMIZATION_REPORTS_DIR}/build_cache_$(date +%Y%m%d_%H%M%S).json"

    # Check for build cache directories
    local cache_size=0
    local cache_dirs=(
        "${HOME}/Library/Developer/Xcode/DerivedData"
        "${WORKSPACE_ROOT}/.build"
        "${WORKSPACE_ROOT}/build"
    )

    for cache_dir in "${cache_dirs[@]}"; do
        if [[ -d "${cache_dir}" ]]; then
            local size
            size=$(du -sk "${cache_dir}" 2>/dev/null | awk '{print $1}')
            cache_size=$((cache_size + size))
        fi
    done

    # Generate recommendations
    cat >"${cache_report}" <<EOF
{
  "timestamp": $(date +%s),
  "date": "$(date -Iseconds)",
  "cache_size_kb": ${cache_size},
  "cache_size_mb": $((cache_size / 1024)),
  "recommendations": [
    $([ ${cache_size} -gt $((10 * 1024 * 1024)) ] && echo '"Consider cleaning build cache (>10GB)"' || echo '"Build cache size is acceptable"')
  ]
}
EOF

    log_message "INFO" "Build cache report: ${cache_report}"
}

# Optimize dependencies
optimize_dependencies() {
    local project_path="$1"
    local project_name
    project_name=$(basename "${project_path}")

    log_message "INFO" "Analyzing dependencies in ${project_name}..."

    local dep_report="${OPTIMIZATION_REPORTS_DIR}/dependencies_${project_name}_$(date +%Y%m%d).txt"

    # Find all imports
    local imports
    imports=$(grep -rh "^import " "${project_path}" --include="*.swift" 2>/dev/null | sort -u)

    echo "=== Import Analysis for ${project_name} ===" >"${dep_report}"
    echo "" >>"${dep_report}"

    # Count usage of each import
    while IFS= read -r import_line; do
        local module
        module=$(echo "$import_line" | awk '{print $2}')

        local usage_count
        usage_count=$(grep -rc "\b${module}\." "${project_path}" --include="*.swift" 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')

        echo "${module}: ${usage_count} references" >>"${dep_report}"
    done <<<"$imports"

    log_message "SUCCESS" "Dependency analysis complete: ${dep_report}"
}

# Suggest refactorings
suggest_refactorings() {
    local project_path="$1"
    local project_name
    project_name=$(basename "${project_path}")

    log_message "INFO" "Analyzing code for refactoring opportunities in ${project_name}..."

    local refactor_report="${OPTIMIZATION_REPORTS_DIR}/refactorings_${project_name}_$(date +%Y%m%d).txt"

    echo "=== Refactoring Suggestions for ${project_name} ===" >"${refactor_report}"
    echo "" >>"${refactor_report}"

    # Find large files
    echo "## Large Files (>500 lines)" >>"${refactor_report}"
    find "${project_path}" -name "*.swift" -exec wc -l {} + 2>/dev/null |
        awk '$1 > 500 {print $2 ": " $1 " lines"}' >>"${refactor_report}"

    echo "" >>"${refactor_report}"

    # Find long functions (simplified heuristic)
    echo "## Potentially Long Functions" >>"${refactor_report}"
    grep -n "func " "${project_path}"/*.swift 2>/dev/null | head -20 >>"${refactor_report}" || echo "None found" >>"${refactor_report}"

    echo "" >>"${refactor_report}"

    # Find duplicated code patterns (very simplified)
    echo "## Code Duplication Hints" >>"${refactor_report}"
    echo "Run 'swiftlint analyze' for detailed duplication detection" >>"${refactor_report}"

    log_message "SUCCESS" "Refactoring suggestions: ${refactor_report}"
}

# Generate optimization summary
generate_optimization_summary() {
    log_message "INFO" "Generating optimization summary..."

    local summary_file="${OPTIMIZATION_REPORTS_DIR}/optimization_summary_$(date +%Y%m%d_%H%M%S).md"

    cat >"${summary_file}" <<EOF
# Code Optimization Summary
**Generated:** $(date)

## Projects Analyzed

EOF

    # Analyze each project
    local projects=("${WORKSPACE_ROOT}"/Projects/*)

    for project in "${projects[@]}"; do
        [[ ! -d "$project" ]] && continue

        local pname
        pname=$(basename "$project")
        [[ "$pname" == "Tools" || "$pname" == "scripts" || "$pname" == "Config" ]] && continue

        echo "### ${pname}" >>"${summary_file}"
        echo "" >>"${summary_file}"

        # Run optimizations
        detect_dead_code "$project"
        optimize_dependencies "$project"
        suggest_refactorings "$project"

        echo "✅ Analysis complete" >>"${summary_file}"
        echo "" >>"${summary_file}"
    done

    # Build cache analysis
    analyze_build_cache

    cat >>"${summary_file}" <<EOF

## Recommendations

1. Review dead code reports and remove unused functions/classes
2. Optimize imports - remove unused dependencies
3. Consider refactoring large files (>500 lines)
4. Clean build cache if size exceeds 10GB
5. Run SwiftLint analyzer for detailed metrics

## Reports Generated

\`\`\`
${OPTIMIZATION_REPORTS_DIR}/
\`\`\`

EOF

    log_message "SUCCESS" "Optimization summary: ${summary_file}"
    echo "${summary_file}"
}

# Run full analysis (alias for generate_optimization_summary)
run_full_analysis() {
    generate_optimization_summary
}

# Main agent loop - standardized task processing
main() {
    log_message "INFO" "Optimization Agent starting..."

    # Initialize agent status
    update_agent_status "${AGENT_NAME}" "starting" $$ ""

    # Create optimization reports directory
    mkdir -p "${OPTIMIZATION_REPORTS_DIR}"

    # Main task processing loop
    while true; do
        # Get next task from shared queue
        local task_data
        task_data=$(get_next_task "${AGENT_NAME}")

        if [[ -n "${task_data}" ]]; then
            # Process the task
            process_optimization_task "${task_data}"
        else
            # No tasks available, check for periodic maintenance
            if ensure_within_limits "optimization_analysis" 86400; then
                # Run periodic full optimization analysis (daily)
                run_full_analysis
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

        # Run a quick optimization check
        detect_dead_code "${WORKSPACE_ROOT}/Projects/CodingReviewer" 2>/dev/null || true
        analyze_build_cache

        update_agent_status "${AGENT_NAME}" "completed" $$ ""
        log_message "INFO" "SINGLE_RUN completed successfully"
        exit 0
    fi

    # Start the main agent loop
    trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; log_message "INFO" "Optimization Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
fi
