#!/usr/bin/env bash
# Performance Profiling Script for Tools Automation
# Measures agent startup times, identifies bottlenecks, and provides optimization recommendations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULTS_DIR="${PROJECT_ROOT}/performance_results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_FILE="${RESULTS_DIR}/performance_profile_${TIMESTAMP}.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Create results directory
mkdir -p "${RESULTS_DIR}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# Measure command execution time
measure_time() {
    local cmd="$1"
    local description="$2"

    log_info "Measuring: ${description}"

    local start_time=$(date +%s.%3N)
    local exit_code=0

    # Execute command and capture exit code
    if eval "$cmd" >/dev/null 2>&1; then
        exit_code=$?
    else
        exit_code=$?
    fi

    local end_time=$(date +%s.%3N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")

    echo "{
        \"command\": \"$cmd\",
        \"description\": \"$description\",
        \"duration_seconds\": $duration,
        \"exit_code\": $exit_code,
        \"timestamp\": \"$TIMESTAMP\"
    }"
}

# Profile agent startup times
profile_agent_startup() {
    log_header "Profiling Agent Startup Times"

    local agents=(
        "./test_all_agents.sh"
        "./quantum_agents_dashboard.sh"
        "./encryption_agent.sh"
        "./quantum_agent_entrypoint.sh"
        "./quantum_agent_integration.sh"
    )

    local results=()

    for agent in "${agents[@]}"; do
        if [[ -f "$agent" ]]; then
            log_info "Profiling $agent"
            local result=$(measure_time "timeout 30s bash $agent --help 2>/dev/null || timeout 30s bash $agent 2>/dev/null || echo 'timeout'" "Agent startup: $agent")
            results+=("$result")
        else
            log_warning "Agent not found: $agent"
        fi
    done

    # Combine results
    local combined_results="["
    for ((i = 0; i < ${#results[@]}; i++)); do
        combined_results+="${results[$i]}"
        if [[ $i -lt $((${#results[@]} - 1)) ]]; then
            combined_results+=","
        fi
    done
    combined_results+="]"

    echo "$combined_results"
}

# Profile MCP server response times
profile_mcp_responses() {
    log_header "Profiling MCP Server Response Times"

    local endpoints=(
        "GET /health"
        "GET /status"
        "GET /api/controllers"
        "POST /api/tasks/submit"
    )

    local results=()

    for endpoint in "${endpoints[@]}"; do
        local method=$(echo "$endpoint" | cut -d' ' -f1)
        local path=$(echo "$endpoint" | cut -d' ' -f2)

        if [[ "$method" == "GET" ]]; then
            local cmd="curl -s -w '%{time_total}' -o /dev/null 'http://localhost:5005$path'"
        else
            local cmd="curl -s -w '%{time_total}' -o /dev/null -X $method -H 'Content-Type: application/json' -d '{}' 'http://localhost:5005$path'"
        fi

        local result=$(measure_time "$cmd" "MCP $endpoint response time")
        results+=("$result")
    done

    # Combine results
    local combined_results="["
    for ((i = 0; i < ${#results[@]}; i++)); do
        combined_results+="${results[$i]}"
        if [[ $i -lt $((${#results[@]} - 1)) ]]; then
            combined_results+=","
        fi
    done
    combined_results+="]"

    echo "$combined_results"
}

# Profile system resource usage
profile_system_resources() {
    log_header "Profiling System Resource Usage"

    local results=()

    # CPU usage
    local cpu_result=$(measure_time "ps aux | awk 'NR>1 {sum+=\$3} END {print sum}'" "System CPU usage calculation")
    results+=("$cpu_result")

    # Memory usage
    local mem_result=$(measure_time "ps aux | awk 'NR>1 {sum+=\$4} END {print sum}'" "System memory usage calculation")
    results+=("$mem_result")

    # Disk I/O
    local disk_result=$(measure_time "iostat -d 1 1 | tail -1 | awk '{print \$2}' 2>/dev/null || echo '0'" "Disk I/O measurement")
    results+=("$disk_result")

    # Network I/O
    local net_result=$(measure_time "netstat -i | wc -l 2>/dev/null || echo '0'" "Network interface count")
    results+=("$net_result")

    # Combine results
    local combined_results="["
    for ((i = 0; i < ${#results[@]}; i++)); do
        combined_results+="${results[$i]}"
        if [[ $i -lt $((${#results[@]} - 1)) ]]; then
            combined_results+=","
        fi
    done
    combined_results+="]"

    echo "$combined_results"
}

# Analyze task orchestrator performance
analyze_task_orchestrator() {
    log_header "Analyzing Task Orchestrator Performance"

    local orchestrator_file="${PROJECT_ROOT}/agents/orchestrator_v2.py"

    if [[ -f "$orchestrator_file" ]]; then
        # Count lines of code
        local loc=$(wc -l <"$orchestrator_file")

        # Check for potential bottlenecks
        local imports=$(grep -c "^import\|^from" "$orchestrator_file" 2>/dev/null || echo "0")
        local functions=$(grep -c "^def " "$orchestrator_file" 2>/dev/null || echo "0")
        local loops=$(grep -c "for \|while " "$orchestrator_file" 2>/dev/null || echo "0")

        echo "{
            \"orchestrator_file\": \"$orchestrator_file\",
            \"lines_of_code\": $loc,
            \"import_statements\": $imports,
            \"function_count\": $functions,
            \"loop_count\": $loops,
            \"analysis_timestamp\": \"$TIMESTAMP\"
        }"
    else
        echo "{
            \"error\": \"Task orchestrator file not found\",
            \"expected_path\": \"$orchestrator_file\"
        }"
    fi
}

# Generate performance recommendations
generate_recommendations() {
    log_header "Generating Performance Optimization Recommendations"

    local recommendations=()

    # Check for Redis
    if ! command -v redis-cli &>/dev/null; then
        recommendations+=("Install Redis for response caching")
    fi

    # Check for ccache
    if ! command -v ccache &>/dev/null; then
        recommendations+=("Install ccache for Swift compilation optimization")
    fi

    # Check Python optimization
    if [[ -f "${PROJECT_ROOT}/requirements.txt" ]]; then
        if ! grep -q "uvloop\|aiohttp" "${PROJECT_ROOT}/requirements.txt" 2>/dev/null; then
            recommendations+=("Consider adding uvloop for async performance improvement")
        fi
    fi

    # Check for parallel processing
    if [[ -f "${PROJECT_ROOT}/task_orchestrator.sh" ]]; then
        if ! grep -q "parallel\|xargs" "${PROJECT_ROOT}/task_orchestrator.sh" 2>/dev/null; then
            recommendations+=("Implement parallel task processing in orchestrator")
        fi
    fi

    # Convert to JSON
    local recs_json="["
    for ((i = 0; i < ${#recommendations[@]}; i++)); do
        recs_json+="\"${recommendations[$i]}\""
        if [[ $i -lt $((${#recommendations[@]} - 1)) ]]; then
            recs_json+=","
        fi
    done
    recs_json+="]"

    echo "$recs_json"
}

# Main profiling function
main() {
    log_header "Tools Automation Performance Profiling"
    log_info "Starting comprehensive performance analysis..."

    # Run all profiling functions
    local agent_results=$(profile_agent_startup)
    local mcp_results=$(profile_mcp_responses)
    local system_results=$(profile_system_resources)
    local orchestrator_analysis=$(analyze_task_orchestrator)
    local recommendations=$(generate_recommendations)

    # Combine all results
    local final_results="{
        \"profiling_timestamp\": \"$TIMESTAMP\",
        \"agent_startup_profiling\": $agent_results,
        \"mcp_response_profiling\": $mcp_results,
        \"system_resource_profiling\": $system_results,
        \"task_orchestrator_analysis\": $orchestrator_analysis,
        \"optimization_recommendations\": $recommendations
    }"

    # Save results
    echo "$final_results" | python3 -m json.tool >"$RESULTS_FILE" 2>/dev/null || echo "$final_results" >"$RESULTS_FILE"

    log_success "Performance profiling complete!"
    log_info "Results saved to: $RESULTS_FILE"

    # Display summary
    log_header "Performance Profiling Summary"

    # Extract and display key metrics
    local avg_agent_startup=$(echo "$agent_results" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data:
    times = [item['duration_seconds'] for item in data if 'duration_seconds' in item]
    if times:
        avg = sum(times) / len(times)
        print(f'Average agent startup time: {avg:.3f}s')
        print(f'Max agent startup time: {max(times):.3f}s')
        print(f'Min agent startup time: {min(times):.3f}s')
    else:
        print('No agent startup time data available')
else:
    print('No agent profiling data available')
" 2>/dev/null || echo "Could not calculate agent startup metrics")

    echo "$avg_agent_startup"

    log_info "Use './analyze_performance_results.sh $RESULTS_FILE' to analyze results in detail"
}

# Run main function
main "$@"
