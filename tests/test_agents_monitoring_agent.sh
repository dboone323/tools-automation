#!/bin/bash
# Comprehensive test suite for monitoring_agent.sh
# Tests advanced monitoring, AI integration, analytics, and predictive capabilities

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/monitoring_agent.sh"
TEST_FRAMEWORK="${SCRIPT_DIR}/../shell_test_framework.sh"

# Source the test framework
source "$TEST_FRAMEWORK"

# Test setup
setup_test_environment() {
    export TEST_MODE=true
    export SCRIPT_DIR="${SCRIPT_DIR}/../agents"
    export WORKSPACE="/tmp/test_workspace"
    export LOG_FILE="${WORKSPACE}/monitoring_agent.log"
    export NOTIFICATION_FILE="${WORKSPACE}/communication/monitoring_agent.sh_notification.txt"
    export AGENT_STATUS_FILE="${WORKSPACE}/agent_status.json"
    export TASK_QUEUE_FILE="${WORKSPACE}/task_queue.json"
    export MONITORING_DATA_FILE="${WORKSPACE}/monitoring_data.json"
    export OLLAMA_ENDPOINT="http://localhost:11434"

    # Create test directories
    mkdir -p "$WORKSPACE/communication"
    mkdir -p "$WORKSPACE/Tools/Automation/analytics_results"
    mkdir -p "$WORKSPACE/Tools/Automation/metrics"
    mkdir -p "$WORKSPACE/Tools/Automation/config"

    # Clean up any existing test files
    rm -f "$LOG_FILE" "$NOTIFICATION_FILE" "$AGENT_STATUS_FILE" "$TASK_QUEUE_FILE" "$MONITORING_DATA_FILE"
}

# Test cleanup
cleanup_test_environment() {
    rm -rf "$WORKSPACE"
}

# Test 1: Verify script structure and advanced function definitions
test_monitoring_agent_script_structure() {
    announce_test "Advanced monitoring agent script structure"

    # Check if script exists and is executable
    assert_file_exists "$AGENT_SCRIPT"
    assert_file_executable "$AGENT_SCRIPT"

    # Check for advanced function definitions
    assert_pattern_in_file "ollama_query()" "$AGENT_SCRIPT"
    assert_pattern_in_file "analyze_system_health()" "$AGENT_SCRIPT"
    assert_pattern_in_file "detect_anomalies()" "$AGENT_SCRIPT"
    assert_pattern_in_file "generate_monitoring_report()" "$AGENT_SCRIPT"
    assert_pattern_in_file "collect_system_metrics()" "$AGENT_SCRIPT"
    assert_pattern_in_file "analyze_performance_trends()" "$AGENT_SCRIPT"
    assert_pattern_in_file "generate_predictive_analytics()" "$AGENT_SCRIPT"
    assert_pattern_in_file "generate_analytics_dashboard()" "$AGENT_SCRIPT"

    test_passed "Advanced monitoring agent script structure"
}

# Test 2: Verify AI integration configuration
test_ai_integration_configuration() {
    announce_test "AI integration configuration"

    # Check for Ollama endpoint configuration
    assert_pattern_in_file "OLLAMA_ENDPOINT=" "$AGENT_SCRIPT"
    assert_pattern_in_file "ollama_query" "$AGENT_SCRIPT"
    assert_pattern_in_file "curl.*api/generate" "$AGENT_SCRIPT"

    # Check for AI analysis functions
    assert_pattern_in_file "analyze_system_health" "$AGENT_SCRIPT"
    assert_pattern_in_file "detect_anomalies" "$AGENT_SCRIPT"
    assert_pattern_in_file "generate_monitoring_report" "$AGENT_SCRIPT"

    test_passed "AI integration configuration"
}

# Test 3: Verify metrics collection functionality
test_metrics_collection_functionality() {
    announce_test "Metrics collection functionality"

    # Check for system metrics collection
    assert_pattern_in_file "collect_system_metrics" "$AGENT_SCRIPT"
    assert_pattern_in_file "cpu_usage" "$AGENT_SCRIPT"
    assert_pattern_in_file "memory_usage" "$AGENT_SCRIPT"
    assert_pattern_in_file "disk_usage" "$AGENT_SCRIPT"
    assert_pattern_in_file "vm_stat" "$AGENT_SCRIPT"
    assert_pattern_in_file "timestamp" "$AGENT_SCRIPT"

    # Check for metrics storage
    assert_pattern_in_file "store_monitoring_data" "$AGENT_SCRIPT"
    assert_pattern_in_file "MONITORING_DATA_FILE" "$AGENT_SCRIPT"

    test_passed "Metrics collection functionality"
}

# Test 4: Verify advanced analytics capabilities
test_advanced_analytics_capabilities() {
    announce_test "Advanced analytics capabilities"

    # Check for performance trend analysis
    assert_pattern_in_file "analyze_performance_trends" "$AGENT_SCRIPT"
    assert_pattern_in_file "performance_trends" "$AGENT_SCRIPT"
    assert_pattern_in_file "cpu_direction" "$AGENT_SCRIPT"
    assert_pattern_in_file "memory_direction" "$AGENT_SCRIPT"

    # Check for predictive analytics
    assert_pattern_in_file "generate_predictive_analytics" "$AGENT_SCRIPT"
    assert_pattern_in_file "predictive_analytics" "$AGENT_SCRIPT"
    assert_pattern_in_file "resource_utilization" "$AGENT_SCRIPT"

    test_passed "Advanced analytics capabilities"
}

# Test 5: Verify dashboard and reporting functionality
test_dashboard_reporting_functionality() {
    announce_test "Dashboard and reporting functionality"

    # Check for analytics dashboard generation
    assert_pattern_in_file "generate_analytics_dashboard" "$AGENT_SCRIPT"
    assert_pattern_in_file "analytics_dashboard" "$AGENT_SCRIPT"
    assert_pattern_in_file "dashboard_data.json" "$AGENT_SCRIPT"

    # Check for advanced monitoring reports
    assert_pattern_in_file "generate_advanced_monitoring_report" "$AGENT_SCRIPT"
    assert_pattern_in_file "monitoring_report" "$AGENT_SCRIPT"
    assert_pattern_in_file "# Advanced Monitoring" "$AGENT_SCRIPT"

    test_passed "Dashboard and reporting functionality"
}

# Test 6: Verify task processing and status management
test_task_processing_status_management() {
    announce_test "Task processing and status management"

    # Check for task processing
    assert_pattern_in_file "process_task" "$AGENT_SCRIPT"
    assert_pattern_in_file "update_task_status" "$AGENT_SCRIPT"
    assert_pattern_in_file "task_queue.json" "$AGENT_SCRIPT"

    # Check for status management
    assert_pattern_in_file "update_status" "$AGENT_SCRIPT"
    assert_pattern_in_file "agent_status.json" "$AGENT_SCRIPT"
    assert_pattern_in_file "last_seen" "$AGENT_SCRIPT"

    test_passed "Task processing and status management"
}

# Test 7: Verify monitoring configuration and initialization
test_monitoring_configuration_initialization() {
    announce_test "Monitoring configuration and initialization"

    # Check for advanced monitoring configuration
    assert_pattern_in_file "initialize_advanced_monitoring" "$AGENT_SCRIPT"
    assert_pattern_in_file "monitoring_config.json" "$AGENT_SCRIPT"
    assert_pattern_in_file "real_time_enabled" "$AGENT_SCRIPT"
    assert_pattern_in_file "alerting_enabled" "$AGENT_SCRIPT"

    # Check for configuration thresholds
    assert_pattern_in_file "cpu_threshold" "$AGENT_SCRIPT"
    assert_pattern_in_file "memory_threshold" "$AGENT_SCRIPT"
    assert_pattern_in_file "disk_threshold" "$AGENT_SCRIPT"

    test_passed "Monitoring configuration and initialization"
}

# Test 8: Verify alert system and anomaly detection
test_alert_system_anomaly_detection() {
    announce_test "Alert system and anomaly detection"

    # Check for alert generation
    assert_pattern_in_file "ALERT:" "$AGENT_SCRIPT"
    assert_pattern_in_file "cpu_threshold=80" "$AGENT_SCRIPT"
    assert_pattern_in_file "mem_threshold=85" "$AGENT_SCRIPT"
    assert_pattern_in_file "disk_threshold=90" "$AGENT_SCRIPT"

    # Check for anomaly detection
    assert_pattern_in_file "detect_anomalies" "$AGENT_SCRIPT"
    assert_pattern_in_file "anomaly_detection" "$AGENT_SCRIPT"
    assert_pattern_in_file "historical_data" "$AGENT_SCRIPT"

    test_passed "Alert system and anomaly detection"
}

# Test 9: Verify comprehensive monitoring analysis
test_comprehensive_monitoring_analysis() {
    announce_test "Comprehensive monitoring analysis"

    # Check for comprehensive analysis function
    assert_pattern_in_file "run_comprehensive_monitoring_analysis" "$AGENT_SCRIPT"
    assert_pattern_in_file "run_monitoring_analysis" "$AGENT_SCRIPT"
    assert_pattern_in_file "analyze_performance_trends" "$AGENT_SCRIPT"
    assert_pattern_in_file "generate_predictive_analytics" "$AGENT_SCRIPT"
    assert_pattern_in_file "generate_analytics_dashboard" "$AGENT_SCRIPT"

    test_passed "Comprehensive monitoring analysis"
}

# Test 10: Verify main agent loop and execution modes
test_main_agent_loop_execution_modes() {
    announce_test "Main agent loop and execution modes"

    # Check for main loop structure
    assert_pattern_in_file "while true" "$AGENT_SCRIPT"
    assert_pattern_in_file "sleep 60" "$AGENT_SCRIPT"
    assert_pattern_in_file "processed_tasks" "$AGENT_SCRIPT"

    # Check for direct execution modes
    assert_pattern_in_file "run_monitoring" "$AGENT_SCRIPT"
    assert_pattern_in_file "monitoring_analysis" "$AGENT_SCRIPT"
    assert_pattern_in_file 'case "$1" in' "$AGENT_SCRIPT"

    # Check for notification processing
    assert_pattern_in_file "NOTIFICATION_FILE" "$AGENT_SCRIPT"
    assert_pattern_in_file "execute_task" "$AGENT_SCRIPT"

    test_passed "Main agent loop and execution modes"
}

# Run all tests
run_monitoring_agent_tests() {
    echo "🧪 Running comprehensive tests for monitoring_agent.sh"
    echo "===================================================="

    setup_test_environment

    test_monitoring_agent_script_structure
    test_ai_integration_configuration
    test_metrics_collection_functionality
    test_advanced_analytics_capabilities
    test_dashboard_reporting_functionality
    test_task_processing_status_management
    test_monitoring_configuration_initialization
    test_alert_system_anomaly_detection
    test_comprehensive_monitoring_analysis
    test_main_agent_loop_execution_modes

    cleanup_test_environment

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_monitoring_agent_tests
fi
