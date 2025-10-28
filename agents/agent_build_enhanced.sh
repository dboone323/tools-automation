#!/bin/bash

# Enhanced Agent Build - With Phase 1 Capabilities
# Autonomous build fixing with error learning

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/agent_helpers.sh"

#!/bin/bash

# Enhanced Agent Build - With Phase 1 Capabilities
# Autonomous build fixing with error learning

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/agent_helpers.sh"

# Enterprise reliability features
run_with_timeout() {
    local timeout_seconds="$1"
    local command="$2"
    local timeout_message="$3"

    echo "Running command with ${timeout_seconds}s timeout: ${command}"

    # Use timeout command if available, otherwise run without timeout
    if command -v timeout >/dev/null 2>&1; then
        if timeout "${timeout_seconds}s" bash -c "${command}"; then
            echo "Command completed successfully within timeout"
            return 0
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                echo "ERROR: Command timed out after ${timeout_seconds} seconds: ${timeout_message}"
                return 1
            else
                echo "Command failed with exit code ${exit_code}"
                return $exit_code
            fi
        fi
    else
        echo "WARNING: timeout command not available, running without timeout protection"
        if bash -c "${command}"; then
            echo "Command completed successfully"
            return 0
        else
            local exit_code=$?
            echo "Command failed with exit code ${exit_code}"
            return $exit_code
        fi
    fi
}

check_resource_limits() {
    local operation_name="$1"
    echo "Checking resource limits for: ${operation_name}"

    # Check available disk space (minimum 1GB)
    local available_space
    available_space=$(df -BG "${SCRIPT_DIR}/../../.." | tail -1 | awk '{print $4}' | sed 's/G//')
    if [[ ${available_space} -lt 1 ]]; then
        echo "ERROR: Insufficient disk space (${available_space}GB available, need 1GB minimum)"
        return 1
    fi

    # Check memory usage (maximum 90%)
    local memory_usage
    memory_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.' | xargs -I {} echo "scale=2; {}/1024/1024" | bc 2>/dev/null || echo "0")
    if [[ -n "${memory_usage}" ]] && (($(echo "${memory_usage} > 90" | bc -l 2>/dev/null || echo 0))); then
        echo "ERROR: Memory usage too high (${memory_usage}%)"
        return 1
    fi

    # Check file count in workspace (maximum 50,000 files)
    local file_count
    file_count=$(find "${SCRIPT_DIR}/../../.." -type f 2>/dev/null | wc -l)
    if [[ ${file_count} -gt 50000 ]]; then
        echo "ERROR: Too many files in workspace (${file_count}, maximum 50,000)"
        return 1
    fi

    echo "Resource limits check passed"
    return 0
}

# Main build with auto-fix
main() {
    local project="${1:-CodingReviewer}"
    local auto_fix="${2:-false}"

    echo "Building project: $project"

    # Check resource limits before starting build
    if ! check_resource_limits "build ${project}"; then
        echo "ERROR: Resource limits check failed, aborting build"
        exit 1
    fi

    # Create backup before build operations
    echo "Creating backup before build operations..."
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup "${project}" "build_operation_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || echo "WARNING: Backup creation failed, continuing anyway"

    # Initial build attempt
    local build_log
    build_log=$(mktemp)

    if run_with_timeout 600 "xcodebuild build -scheme '$project' -configuration Debug" "Build timed out"; then
        echo "✅ Build succeeded"
        rm -f "$build_log"
        exit 0
    else
        echo "❌ Build failed, analyzing..."

        # Extract errors from build log
        local errors
        errors=$(grep -E "(error:|failed)" "$build_log" | head -5)

        if [ -z "$errors" ]; then
            echo "No specific errors found in build log"
            rm -f "$build_log"
            exit 1
        fi

        # Try to fix each error
        while IFS= read -r error_line; do
            echo "Error: $error_line"

            if [ "$auto_fix" = "true" ]; then
                echo "Attempting auto-fix..."
                if run_with_timeout 300 "agent_auto_fix '$error_line' '{\"project\": \"$project\"}' 'true'" "Auto-fix timed out"; then
                    echo "Auto-fix successful, retrying build..."

                    # Retry build
                    if run_with_timeout 600 "xcodebuild build -scheme '$project' -configuration Debug" "Retry build timed out"; then
                        echo "✅ Build succeeded after auto-fix"
                        rm -f "$build_log"
                        exit 0
                    fi
                fi
            else
                # Just suggest fixes
                if run_with_timeout 120 "agent_suggest_fix '$error_line'" "Fix suggestion timed out"; then
                    local suggestion
                    suggestion=$(agent_suggest_fix "$error_line")
                    echo "Suggestion: $(echo "$suggestion" | jq -r '.primary_suggestion.action // "unknown"')"
                    echo "Confidence: $(echo "$suggestion" | jq -r '.confidence // 0')"
                else
                    echo "Fix suggestion timed out"
                fi
            fi
        done <<<"$errors"

        rm -f "$build_log"
        exit 1
    fi
}

main "$@"
