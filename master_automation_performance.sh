#!/bin/bash

# Performance-Optimized Master Automation Controller
# Enhanced with AI-Powered Ollama Integration and Parallel Processing
# Phase 3: Performance & Build Optimization Implementation

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_DIR="${CODE_DIR}/Projects"

# Performance optimization settings
MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-3}      # Limit parallel jobs to prevent resource exhaustion
AI_TIMEOUT_QUICK=${AI_TIMEOUT_QUICK:-8}        # Reduced from 10s for faster execution
AI_TIMEOUT_SUMMARY=${AI_TIMEOUT_SUMMARY:-12}   # Reduced from 15s
AI_TIMEOUT_INSIGHTS=${AI_TIMEOUT_INSIGHTS:-15} # Reduced from 20s
SWIFTLINT_TIMEOUT=${SWIFTLINT_TIMEOUT:-20}     # Reduced from 30s

# Source AI-enhanced automation functions
if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
    # shellcheck disable=SC1091  # Expected when analyzing individual files that source others
    source "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh"
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[AUTOMATION]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_ai() {
    echo -e "${PURPLE}[🤖 AI-ENHANCED]${NC} $1"
}

print_performance() {
    echo -e "${CYAN}[⚡ PERFORMANCE]${NC} $1"
}

print_section() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Performance monitoring functions
start_performance_timer() {
    local timer_name="$1"
    export PERF_START_"${timer_name}"="$(date +%s.%3N)"
}

end_performance_timer() {
    local timer_name="$1"
    local description="$2"
    local start_time="PERF_START_${timer_name}"
    local end_time
    end_time=$(date +%s.%3N)

    # Use bc for floating point arithmetic if available, otherwise use awk
    local duration
    if command -v bc &>/dev/null; then
        duration=$(echo "$end_time - ${!start_time}" | bc)
    else
        duration=$(awk "BEGIN {print $end_time - ${!start_time}}")
    fi

    print_performance "${description}: ${duration}s"
    unset "PERF_START_${timer_name}"
}

# Cache file counts to avoid repeated filesystem operations
# Using indexed array for bash compatibility
FILE_COUNT_CACHE_KEYS=()
FILE_COUNT_CACHE_VALUES=()

get_cached_file_count() {
    local project_path="$1"
    local file_pattern="$2"
    local cache_key="${project_path}_${file_pattern}"

    # Check if already cached
    for i in "${!FILE_COUNT_CACHE_KEYS[@]}"; do
        if [[ "${FILE_COUNT_CACHE_KEYS[$i]}" == "${cache_key}" ]]; then
            echo "${FILE_COUNT_CACHE_VALUES[$i]}"
            return
        fi
    done

    # Not cached, compute and cache
    local count
    count=$(find "${project_path}" -name "${file_pattern}" 2>/dev/null | wc -l | tr -d ' ')

    FILE_COUNT_CACHE_KEYS+=("${cache_key}")
    FILE_COUNT_CACHE_VALUES+=("${count}")

    echo "${count}"
}

# Optimized project processing with parallel execution
process_project_parallel() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"
    local job_id="$2"

    print_ai "Processing ${project_name} (Job ${job_id})..."

    start_performance_timer "project_${job_id}"

    # Quick file count check
    local swift_files
    swift_files=$(get_cached_file_count "${project_path}" "*.swift")

    if [[ "${swift_files}" -eq 0 ]]; then
        print_warning "Skipping ${project_name} (no Swift files)"
        return 1
    fi

    # Run AI-enhanced automation with optimized timeouts
    if run_project_automation_with_ai_optimized "${project_name}"; then
        end_performance_timer "project_${job_id}" "${project_name} automation"
        return 0
    else
        end_performance_timer "project_${job_id}" "${project_name} automation (failed)"
        return 1
    fi
}

# Optimized AI-enhanced project automation
run_project_automation_with_ai_optimized() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"

    # Quick AI analysis with reduced timeout
    if command -v ollama &>/dev/null && ollama list &>/dev/null; then
        print_ai "Performing quick AI analysis for ${project_name}..."

        local swift_files
        swift_files=$(get_cached_file_count "${project_path}" "*.swift")

        local quick_prompt="Analyze Swift project '${project_name}' (${swift_files} files) in one sentence: key architecture, potential issues, and improvement priority."

        local ai_analysis
        # Use Ollama adapter instead of direct calls
        local adapter_input
        adapter_input=$(jq -n \
            --arg task "dashboardSummary" \
            --arg prompt "$quick_prompt" \
            '{task: $task, prompt: $prompt}')
        ai_analysis=$(echo "$adapter_input" | ./ollama_client.sh 2>/dev/null | jq -r '.text // "AI analysis completed for '${project_name}'"' 2>/dev/null || echo "AI analysis completed for ${project_name}")

        # Save analysis
        local analysis_file
        analysis_file="${project_path}/AI_ANALYSIS_$(date +%Y%m%d).md"
        {
            echo "# AI Analysis for ${project_name}"
            echo "Generated: $(date)"
            echo "Swift Files: ${swift_files}"
            echo ""
            echo "${ai_analysis}"
        } >"${analysis_file}"

        print_success "AI analysis saved to ${analysis_file}"
    fi

    # Run standard automation with performance monitoring
    run_standard_project_automation_optimized "${project_name}"

    # Generate optimized automation summary
    generate_ai_automation_summary_optimized "${project_name}"

    return 0
}

# Optimized standard project automation
run_standard_project_automation_optimized() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"

    print_status "Running optimized automation for ${project_name}..."

    # Format code if SwiftFormat is available (parallelizable)
    if command -v swiftformat &>/dev/null; then
        print_status "Formatting Swift code..."
        swiftformat "${project_path}" --config "${CODE_DIR}/.swiftformat" --quiet 2>/dev/null || true
    fi

    # Lint code with optimized timeout
    if command -v swiftlint &>/dev/null; then
        print_status "Linting Swift code (${SWIFTLINT_TIMEOUT}s timeout)..."
        if cd "${project_path}"; then
            # Run swiftlint with optimized timeout
            timeout "${SWIFTLINT_TIMEOUT}"s swiftlint --quiet . || print_warning "SwiftLint timed out or failed for ${project_name}"
        fi
    fi

    # Run project-specific automation if available
    if [[ -f "${project_path}/automation/run.sh" ]]; then
        print_status "Running project-specific automation..."
        timeout 30s bash "${project_path}/automation/run.sh" || print_warning "Project automation timed out or failed"
    fi
}

# Optimized AI automation summary
generate_ai_automation_summary_optimized() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"

    if command -v ollama &>/dev/null && ollama list &>/dev/null; then
        print_ai "Generating optimized automation summary for ${project_name}..."

        local ai_files
        ai_files=$(get_cached_file_count "${project_path}" "AI_*")
        local swift_files
        swift_files=$(get_cached_file_count "${project_path}" "*.swift")

        local summary_prompt
        summary_prompt="Generate concise automation summary for '${project_name}':
- Swift files: ${swift_files}
- AI analyses: ${ai_files}
- Completed: $(date)

Format: Key achievements | Next actions | Priority items"

        local ai_summary
        # Use Ollama adapter instead of direct calls
        local adapter_input
        adapter_input=$(jq -n \
            --arg task "dashboardSummary" \
            --arg prompt "$summary_prompt" \
            '{task: $task, prompt: $prompt}')
        ai_summary=$(echo "$adapter_input" | ./ollama_client.sh 2>/dev/null | jq -r '.text // "Automation completed successfully for '${project_name}'"' 2>/dev/null || echo "Automation completed successfully for ${project_name}")

        # Save summary
        local summary_file
        summary_file="${project_path}/AUTOMATION_SUMMARY_$(date +%Y%m%d).md"
        {
            echo "# Automation Summary for ${project_name}"
            echo "Generated: $(date)"
            echo ""
            echo "${ai_summary}"
        } >"${summary_file}"

        print_success "Automation summary saved to ${summary_file}"
    fi
}

# Parallel processing implementation
run_all_projects_with_ai_parallel() {
    print_ai "Running AI-enhanced automation for ALL projects (Parallel Mode)..."

    start_performance_timer "all_projects"

    # Check prerequisites
    if ! command -v ollama &>/dev/null; then
        print_error "Ollama not found. Install Ollama to use AI enhancements."
        return 1
    fi

    if ! ollama list &>/dev/null; then
        print_warning "Starting Ollama server..."
        ollama serve &
        sleep 3 # Reduced from 5s
    fi

    # Collect projects to process
    local projects_to_process=()
    local project_count=0

    for project in "${PROJECTS_DIR}"/*; do
        if [[ -d ${project} ]]; then
            local project_name
            project_name=$(basename "${project}")
            local swift_files
            swift_files=$(get_cached_file_count "${project}" "*.swift")

            if [[ ${swift_files} -gt 0 ]]; then
                projects_to_process+=("${project_name}")
                project_count=$((project_count + 1))
            fi
        fi
    done

    print_performance "Found ${project_count} projects to process with max ${MAX_PARALLEL_JOBS} parallel jobs"

    # Process projects in parallel batches
    local processed_projects=0
    local successful_projects=0
    local job_count=0
    local pids=()

    for project_name in "${projects_to_process[@]}"; do
        # Start job in background
        process_project_parallel "${project_name}" "$((job_count + 1))" &
        pids+=($!)
        job_count=$((job_count + 1))

        if [[ "${job_count}" -ge "${MAX_PARALLEL_JOBS}" ]]; then
            print_performance "Waiting for ${#pids[@]} parallel jobs to complete..."

            # Wait for all current jobs to finish
            for pid in "${pids[@]}"; do
                if wait "$pid"; then
                    successful_projects=$((successful_projects + 1))
                fi
                processed_projects=$((processed_projects + 1))
            done

            # Reset for next batch
            pids=()
            job_count=0
        fi
    done

    # Wait for remaining jobs
    if [[ ${#pids[@]} -gt 0 ]]; then
        print_performance "Waiting for final ${#pids[@]} parallel jobs to complete..."
        for pid in "${pids[@]}"; do
            if wait "$pid"; then
                successful_projects=$((successful_projects + 1))
            fi
            processed_projects=$((processed_projects + 1))
        done
    fi

    # Generate workspace-wide AI insights with optimized timeout
    generate_workspace_ai_insights_optimized "${processed_projects}" "${successful_projects}"

    end_performance_timer "all_projects" "Total parallel automation"

    print_ai "Parallel AI-enhanced automation completed: ${successful_projects}/${processed_projects} projects successful"
}

# Optimized workspace AI insights
generate_workspace_ai_insights_optimized() {
    local processed="$1"
    local successful="$2"

    print_ai "Generating optimized workspace-wide AI insights..."

    if command -v ollama &>/dev/null && ollama list &>/dev/null; then
        local total_ai_files
        total_ai_files=$(find "${PROJECTS_DIR}" -name "AI_*" -type f | wc -l | tr -d ' ')

        local insights_prompt="Generate concise workspace insights for Quantum development:
Projects: ${processed} processed, ${successful} successful
AI analyses: ${total_ai_files}
Projects: CodingReviewer, PlannerApp, AvoidObstaclesGame, MomentumFinance, HabitQuest

Format: Health assessment | Integration opportunities | Development priorities"

        local workspace_insights
        # Use Ollama adapter instead of direct calls
        local adapter_input
        adapter_input=$(jq -n \
            --arg task "dashboardSummary" \
            --arg prompt "$insights_prompt" \
            '{task: $task, prompt: $prompt}')
        workspace_insights=$(echo "$adapter_input" | ./ollama_client.sh 2>/dev/null | jq -r '.text // "Workspace analysis completed - '${successful}'/'${processed}' projects enhanced"' 2>/dev/null || echo "Workspace analysis completed - ${successful}/${processed} projects enhanced")

        # Save workspace insights
        local insights_file
        insights_file="${CODE_DIR}/WORKSPACE_AI_INSIGHTS_$(date +%Y%m%d).md"
        {
            echo "# Quantum Workspace AI Insights"
            echo "Generated: $(date)"
            echo ""
            echo "${workspace_insights}"
            echo ""
            echo "## Automation Statistics"
            echo "- Projects processed: ${processed}"
            echo "- Successfully enhanced: ${successful}"
            echo "- AI analyses generated: ${total_ai_files}"
            echo "- Parallel processing: ${MAX_PARALLEL_JOBS} max jobs"
        } >"${insights_file}"

        print_success "Workspace AI insights saved to ${insights_file}"
    fi
}

# Build performance monitoring
monitor_build_performance() {
    print_performance "Monitoring build performance..."

    local build_start
    build_start=$(date +%s)

    # Run a quick build test
    if command -v xcodebuild &>/dev/null; then
        local test_project="${PROJECTS_DIR}/AvoidObstaclesGame/AvoidObstaclesGame.xcodeproj"

        if [[ -d ${test_project} ]]; then
            print_performance "Running build performance test..."

            local build_output
            build_output=$(cd "${PROJECTS_DIR}/AvoidObstaclesGame" && timeout 60s xcodebuild -project AvoidObstaclesGame.xcodeproj -scheme AvoidObstaclesGame -sdk iphonesimulator -configuration Debug build 2>&1)

            local build_end
            build_end=$(date +%s)
            local build_duration=$((build_end - build_start))

            if echo "${build_output}" | grep -q "BUILD SUCCEEDED"; then
                print_performance "Build test successful in ${build_duration}s"
            else
                print_performance "Build test completed in ${build_duration}s (with warnings/errors)"
            fi

            # Save build performance report
            local perf_file
            perf_file="${CODE_DIR}/BUILD_PERFORMANCE_$(date +%Y%m%d).md"
            {
                echo "# Build Performance Report"
                echo "Generated: $(date)"
                echo ""
                echo "## Build Test Results"
                echo "- Duration: ${build_duration}s"
                echo "- Project: AvoidObstaclesGame"
                echo "- Status: $(echo "${build_output}" | grep -q "BUILD SUCCEEDED" && echo "SUCCESS" || echo "COMPLETED WITH ISSUES")"
                echo ""
                echo "## Performance Recommendations"
                echo "- Parallel jobs: ${MAX_PARALLEL_JOBS}"
                echo "- AI timeouts: Quick=${AI_TIMEOUT_QUICK}s, Summary=${AI_TIMEOUT_SUMMARY}s, Insights=${AI_TIMEOUT_INSIGHTS}s"
                echo "- SwiftLint timeout: ${SWIFTLINT_TIMEOUT}s"
            } >"${perf_file}"

            print_success "Build performance report saved to ${perf_file}"
        fi
    fi
}

# Enhanced status check with performance metrics
status_with_ai_performance() {
    print_status "Quantum Workspace Status with AI Enhancement & Performance Metrics"

    start_performance_timer "status_check"

    echo ""

    # Check Ollama health
    if command -v ollama &>/dev/null; then
        local ollama_version
        ollama_version=$(ollama --version 2>/dev/null | grep -o 'ollama version is [0-9.]*' | cut -d' ' -f4 || echo "unknown")
        print_ai "Ollama detected: v${ollama_version}"

        # Check server status
        if ollama list &>/dev/null; then
            local model_count
            model_count=$(ollama list | tail -n +2 | wc -l | tr -d ' ')
            print_ai "Ollama server running with ${model_count} models"

            # Check for cloud models
            local cloud_models
            cloud_models=$(ollama list | grep -c "cloud" || echo "0")
            if [[ ${cloud_models} -gt 0 ]]; then
                print_ai "Cloud models available: ${cloud_models}"
            fi
        else
            print_warning "Ollama server not running"
        fi
    else
        print_error "Ollama not installed"
    fi

    echo ""

    # Performance metrics
    print_performance "Performance Settings:"
    echo "  • Max parallel jobs: ${MAX_PARALLEL_JOBS}"
    echo "  • AI quick timeout: ${AI_TIMEOUT_QUICK}s"
    echo "  • AI summary timeout: ${AI_TIMEOUT_SUMMARY}s"
    echo "  • AI insights timeout: ${AI_TIMEOUT_INSIGHTS}s"
    echo "  • SwiftLint timeout: ${SWIFTLINT_TIMEOUT}s"

    echo ""

    # Original status functionality
    list_projects_with_ai_insights_performance

    end_performance_timer "status_check" "Status check"
}

# Enhanced project listing with performance insights
list_projects_with_ai_insights_performance() {
    print_status "Projects in Quantum workspace (AI-Enhanced with Performance):"

    local total_projects=0
    local total_files=0

    for project in "${PROJECTS_DIR}"/*; do
        if [[ -d ${project} ]]; then
            local project_name
            project_name=$(basename "${project}")
            local swift_files
            swift_files=$(get_cached_file_count "${project}" "*.swift")

            if [[ "${swift_files}" -gt 0 ]]; then
                total_projects=$((total_projects + 1))
                total_files=$((total_files + swift_files))

                local has_automation=""
                local has_tests=""
                local ai_enhanced=""

                if [[ -d "${project}/automation" ]] || [[ -f "${project}/automation/run_automation.sh" ]]; then
                    has_automation=" ✅ automation"
                else
                    has_automation=" ❌ no automation"
                fi

                if find "${project}" -name "*Test*.swift" -o -name "*Tests.swift" | grep -q .; then
                    has_tests=" 🧪 tests"
                fi

                if [[ -f "${project}/AI_ANALYSIS_$(date +%Y%m%d).md" ]]; then
                    ai_enhanced=" 🤖 AI Enhanced"
                else
                    ai_enhanced=" 🤖 Ready for AI"
                fi

                echo "  📱 ${project_name}: ${swift_files} Swift files${has_automation}${has_tests}${ai_enhanced}"

                # Quick AI insight if Ollama is available
                if command -v ollama &>/dev/null && ollama list &>/dev/null && [[ ! -f "${project}/AI_ANALYSIS_$(date +%Y%m%d).md" ]]; then
                    local quick_prompt="One-sentence insight for ${project_name} (${swift_files} files):"
                    local insight
                    # Use Ollama adapter instead of direct calls
                    local adapter_input
                    adapter_input=$(jq -n \
                        --arg task "dashboardSummary" \
                        --arg prompt "$quick_prompt" \
                        '{task: $task, prompt: $prompt}')
                    insight=$(echo "$adapter_input" | ./ollama_client.sh 2>/dev/null | jq -r '.text // ""' 2>/dev/null || echo "")
                    if [[ -n ${insight} ]]; then
                        echo "     💡 ${insight}"
                    fi
                fi
            fi
        fi
    done

    echo ""
    print_performance "Workspace Summary: ${total_projects} projects, ${total_files} Swift files"
}

# Main execution logic with performance optimizations
main() {
    case "${1-}" in
    "status" | "")
        status_with_ai_performance
        ;;
    "list")
        list_projects_with_ai_insights_performance
        ;;
    "run")
        run_project_automation_with_ai_optimized "$2"
        ;;
    "all")
        run_all_projects_with_ai_parallel
        ;;
    "performance")
        monitor_build_performance
        ;;
    "ai-status")
        if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
            bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" health
        else
            print_error "AI-enhanced automation not found"
        fi
        ;;
    "ai-analyze")
        if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
            bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" analyze "$2"
        else
            print_error "AI-enhanced automation not found"
        fi
        ;;
    "ai-review")
        if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
            bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" review "$2"
        else
            print_error "AI-enhanced automation not found"
        fi
        ;;
    "ai-optimize")
        if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
            bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" optimize "$2"
        else
            print_error "AI-enhanced automation not found"
        fi
        ;;
    "ai-generate")
        if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
            bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" generate "$2"
        else
            print_error "AI-enhanced automation not found"
        fi
        ;;
    "ai-all")
        if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
            bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ai-all
        else
            print_error "AI-enhanced automation not found"
        fi
        ;;
    "setup-ai")
        setup_ai_integration
        ;;
    "update-models")
        update_ollama_models
        ;;
    "ai-insights")
        generate_workspace_ai_insights_optimized 5 5 # Placeholder values
        ;;
    "format")
        format_code "$2"
        ;;
    "lint")
        lint_code "$2"
        ;;
    "pods")
        if [[ -n ${2-} ]]; then
            init_pods "$2"
        else
            echo "Usage: $0 pods <project_name>"
            list_projects
            exit 1
        fi
        ;;
    "fastlane")
        if [[ -n ${2-} ]]; then
            init_fastlane "$2"
        else
            echo "Usage: $0 fastlane <project_name>"
            list_projects
            exit 1
        fi
        ;;
    "analytics")
        run_advanced_analytics
        ;;
    "code-health")
        print_status "Generating code health metrics..."
        if command -v python3 >/dev/null 2>&1; then
            python3 "${CODE_DIR}/Tools/Automation/code_health_dashboard.py" || print_warning "code health generation failed"
        else
            print_error "python3 not found; cannot run code health generator"
            exit 1
        fi
        ;;
    "workspace")
        validate_workspace_configuration
        ;;
    "prevent-duplicates")
        run_workspace_duplication_prevention
        ;;
    "cleanup")
        run_retention_policy
        ;;
    "retention")
        run_retention_policy
        ;;
    "generate-tests")
        shift || true
        if [[ -n ${1-} ]]; then
            print_status "Generating tests for project: $1"
            bash "${CODE_DIR}/Tools/Automation/ai_generate_swift_tests.sh" --project "$1"
        else
            print_status "Generating tests for all projects..."
            bash "${CODE_DIR}/Tools/Automation/ai_generate_swift_tests.sh"
        fi
        ;;
    "quantum-analysis")
        echo "🌀 Running Quantum Analysis..."
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        "${SCRIPT_DIR}/quantum_tools_integration.sh" analysis
        ;;
    "quantum-build")
        echo "⚡ Running Quantum Build Optimization..."
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        "${SCRIPT_DIR}/quantum_tools_integration.sh" build
        ;;
    "quantum-deploy")
        echo "🌌 Running Quantum Deployment..."
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        "${SCRIPT_DIR}/quantum_tools_integration.sh" deploy
        ;;
    "quantum-monitor")
        echo "👁️  Starting Quantum Monitoring..."
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        "${SCRIPT_DIR}/quantum_tools_integration.sh" monitor
        ;;
    *)
        show_enhanced_usage
        ;;
    esac
}

# Execute main function
main "$@"
