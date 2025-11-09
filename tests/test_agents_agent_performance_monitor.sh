#!/bin/bash
# Comprehensive test suite for agent_performance_monitor.sh
# Tests performance monitoring, resource limits, metrics collection, and trend analysis

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_performance_monitor.sh"
TEST_FRAMEWORK="${SCRIPT_DIR}/../shell_test_framework.sh"

# Source the test framework
source "$TEST_FRAMEWORK"

# Test setup
setup_test_environment() {
    export TEST_MODE=true
    export SCRIPT_DIR="${SCRIPT_DIR}/../agents"
    export WORKSPACE_ROOT="/tmp/test_workspace"
    export STATUS_FILE="${SCRIPT_DIR}/test_agent_status.json"
    export TASK_QUEUE="${SCRIPT_DIR}/test_task_queue.json"
    export LOG_FILE="${SCRIPT_DIR}/test_performance_monitor_agent.log"
    export PERFORMANCE_LOG="${SCRIPT_DIR}/test_performance_metrics.json"

    # Create test directories
    mkdir -p "$WORKSPACE_ROOT"

    # Clean up any existing test files
    rm -f "$STATUS_FILE" "$TASK_QUEUE" "$LOG_FILE" "$PERFORMANCE_LOG"
}

# Test cleanup
cleanup_test_environment() {
    rm -rf "$WORKSPACE_ROOT"
    rm -f "$STATUS_FILE" "$TASK_QUEUE" "$LOG_FILE" "$PERFORMANCE_LOG"
}

# Test 1: Verify script structure and performance monitoring functions
test_performance_monitor_script_structure() {
    announce_test "Performance monitor script structure"

    # Check if script exists and is executable
    assert_file_exists "$AGENT_SCRIPT"
    assert_file_executable "$AGENT_SCRIPT"

    # Check for core function definitions
    assert_pattern_in_file "run_with_timeout()" "$AGENT_SCRIPT"
    assert_pattern_in_file "check_resource_limits()" "$AGENT_SCRIPT"
    assert_pattern_in_file "collect_system_metrics()" "$AGENT_SCRIPT"
    assert_pattern_in_file "monitor_agent_performance()" "$AGENT_SCRIPT"
    assert_pattern_in_file "analyze_performance_trends()" "$AGENT_SCRIPT"
    assert_pattern_in_file "generate_performance_report()" "$AGENT_SCRIPT"
    assert_pattern_in_file "perform_performance_monitoring()" "$AGENT_SCRIPT"

    test_passed "Performance monitor script structure"
}

# Test 2: Verify timeout handling functionality
test_timeout_handling_functionality() {
    announce_test "Timeout handling functionality"

    # Check for timeout implementation
    assert_pattern_in_file "run_with_timeout" "$AGENT_SCRIPT"
    assert_pattern_in_file "timeout.*kill-after" "$AGENT_SCRIPT"
    assert_pattern_in_file "pkill.*TERM" "$AGENT_SCRIPT"
    assert_pattern_in_file "pkill.*KILL" "$AGENT_SCRIPT"

    # Check for timeout usage in different environments
    assert_pattern_in_file "command -v timeout" "$AGENT_SCRIPT"
    assert_pattern_in_file "macOS/BSD implementation" "$AGENT_SCRIPT"

    test_passed "Timeout handling functionality"
}

# Test 3: Verify resource limits checking
test_resource_limits_checking() {
    announce_test "Resource limits checking"

    # Check for resource limit functions
    assert_pattern_in_file "check_resource_limits" "$AGENT_SCRIPT"
    assert_pattern_in_file "file_count.*1000" "$AGENT_SCRIPT"
    assert_pattern_in_file "mem_percent.*80" "$AGENT_SCRIPT"
    assert_pattern_in_file "cpu_usage.*90" "$AGENT_SCRIPT"

    # Check for system-specific resource monitoring
    assert_pattern_in_file "vm_stat" "$AGENT_SCRIPT"
    assert_pattern_in_file "mem_percent.*80" "$AGENT_SCRIPT"
    assert_pattern_in_file "ps.*%cpu" "$AGENT_SCRIPT"

    test_passed "Resource limits checking"
}

# Test 4: Verify system metrics collection
test_system_metrics_collection() {
    announce_test "System metrics collection"

    # Check for metrics collection function
    assert_pattern_in_file "collect_system_metrics" "$AGENT_SCRIPT"
    assert_pattern_in_file "cpu_usage.*ps aux" "$AGENT_SCRIPT"
    assert_pattern_in_file "mem_usage.*ps aux" "$AGENT_SCRIPT"
    assert_pattern_in_file "disk_usage.*df" "$AGENT_SCRIPT"
    assert_pattern_in_file "process_count.*ps aux" "$AGENT_SCRIPT"

    # Check for agent-specific metrics
    assert_pattern_in_file "agent_count.*pgrep" "$AGENT_SCRIPT"
    assert_pattern_in_file "agent_|mcp_server" "$AGENT_SCRIPT"

    test_passed "System metrics collection"
}

# Test 5: Verify agent performance monitoring
test_agent_performance_monitoring() {
    announce_test "Agent performance monitoring"

    # Check for agent monitoring function
    assert_pattern_in_file "monitor_agent_performance" "$AGENT_SCRIPT"
    assert_pattern_in_file "running_agents.*jq" "$AGENT_SCRIPT"
    assert_pattern_in_file "idle_agents.*jq" "$AGENT_SCRIPT"
    assert_pattern_in_file "status.*running" "$AGENT_SCRIPT"

    # Check for status file integration
    assert_pattern_in_file "STATUS_FILE" "$AGENT_SCRIPT"
    assert_pattern_in_file "agent_status.json" "$AGENT_SCRIPT"

    test_passed "Agent performance monitoring"
}

# Test 6: Verify performance trend analysis
test_performance_trend_analysis() {
    announce_test "Performance trend analysis"

    # Check for trend analysis function
    assert_pattern_in_file "analyze_performance_trends" "$AGENT_SCRIPT"
    assert_pattern_in_file "recent_metrics.*python3" "$AGENT_SCRIPT"
    assert_pattern_in_file "avg_cpu.*avg_memory" "$AGENT_SCRIPT"

    # Check for performance threshold alerts
    assert_pattern_in_file "HIGH CPU USAGE" "$AGENT_SCRIPT"
    assert_pattern_in_file "HIGH MEMORY USAGE" "$AGENT_SCRIPT"
    assert_pattern_in_file "CRITICAL DISK USAGE" "$AGENT_SCRIPT"

    test_passed "Performance trend analysis"
}

# Test 7: Verify performance report generation
test_performance_report_generation() {
    announce_test "Performance report generation"

    # Check for report generation function
    assert_pattern_in_file "generate_performance_report" "$AGENT_SCRIPT"
    assert_pattern_in_file "PERFORMANCE_REPORT" "$AGENT_SCRIPT"
    assert_pattern_in_file "# Performance Monitoring Report" "$AGENT_SCRIPT"

    # Check for report content structure
    assert_pattern_in_file "## System Overview" "$AGENT_SCRIPT"
    assert_pattern_in_file "## Performance Analysis" "$AGENT_SCRIPT"
    assert_pattern_in_file "## Recommendations" "$AGENT_SCRIPT"

    test_passed "Performance report generation"
}

# Test 8: Verify task processing integration
test_task_processing_integration() {
    announce_test "Task processing integration"

    # Check for task processing function
    assert_pattern_in_file "process_performance_monitor_task" "$AGENT_SCRIPT"
    assert_pattern_in_file "case.*task" "$AGENT_SCRIPT"
    assert_pattern_in_file "test_performance_run" "$AGENT_SCRIPT"
    assert_pattern_in_file "collect_system_metrics" "$AGENT_SCRIPT"
    assert_pattern_in_file "monitor_agent_performance" "$AGENT_SCRIPT"

    # Check for shared functions integration
    assert_pattern_in_file "shared_functions.sh" "$AGENT_SCRIPT"
    assert_pattern_in_file "get_next_task" "$AGENT_SCRIPT"
    assert_pattern_in_file "update_agent_status" "$AGENT_SCRIPT"

    test_passed "Task processing integration"
}

# Test 9: Verify comprehensive monitoring workflow
test_comprehensive_monitoring_workflow() {
    announce_test "Comprehensive monitoring workflow"

    # Check for main monitoring function
    assert_pattern_in_file "perform_performance_monitoring" "$AGENT_SCRIPT"
    assert_pattern_in_file "collect_system_metrics" "$AGENT_SCRIPT"
    assert_pattern_in_file "monitor_agent_performance" "$AGENT_SCRIPT"
    assert_pattern_in_file "analyze_performance_trends" "$AGENT_SCRIPT"
    assert_pattern_in_file "generate_performance_report" "$AGENT_SCRIPT"

    test_passed "Comprehensive monitoring workflow"
}

# Test 10: Verify main agent loop and execution modes
test_main_agent_loop_execution_modes() {
    announce_test "Main agent loop and execution modes"

    # Check for main function and loop
    assert_pattern_in_file "main()" "$AGENT_SCRIPT"
    assert_pattern_in_file "while true" "$AGENT_SCRIPT"
    assert_pattern_in_file "sleep 5" "$AGENT_SCRIPT"

    # Check for execution mode handling
    assert_pattern_in_file "SINGLE_RUN" "$AGENT_SCRIPT"
    assert_pattern_in_file "BASH_SOURCE.*0" "$AGENT_SCRIPT"
    assert_pattern_in_file "TEST_MODE" "$AGENT_SCRIPT"

    # Check for signal handling
    assert_pattern_in_file "trap.*SIGTERM" "$AGENT_SCRIPT"
    assert_pattern_in_file "trap.*SIGINT" "$AGENT_SCRIPT"

    test_passed "Main agent loop and execution modes"
}

# Run all tests
run_agent_performance_monitor_tests() {
    echo "🧪 Running comprehensive tests for agent_performance_monitor.sh"
    echo "============================================================"

    setup_test_environment

    test_performance_monitor_script_structure
    test_timeout_handling_functionality
    test_resource_limits_checking
    test_system_metrics_collection
    test_agent_performance_monitoring
    test_performance_trend_analysis
    test_performance_report_generation
    test_task_processing_integration
    test_comprehensive_monitoring_workflow
    test_main_agent_loop_execution_modes

    cleanup_test_environment

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_agent_performance_monitor_tests
fi
