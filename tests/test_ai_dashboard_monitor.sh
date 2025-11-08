#!/bin/bash

# Test suite for ai_dashboard_monitor.sh
# Comprehensive tests covering all dashboard and monitoring functionality

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shell_test_framework.sh"

# Override PROJECT_ROOT for this test
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DASHBOARD_SCRIPT="$PROJECT_ROOT/ai_dashboard_monitor.sh"

# Test: Initialize dashboard directories
test_dashboard_init() {
    echo "Testing dashboard initialization..."

    # Clean up any existing test directories
    rm -rf "${PROJECT_ROOT}/Tools/Automation/dashboard"
    rm -rf "${PROJECT_ROOT}/Tools/Automation/monitoring"

    # Run init command from the correct location
    cd "${PROJECT_ROOT}"
    local output
    output=$("$DASHBOARD_SCRIPT" init 2>&1)

    # Check if directories were created
    if [[ -d "${PROJECT_ROOT}/Tools/Automation/dashboard" ]] && [[ -d "${PROJECT_ROOT}/Tools/Automation/monitoring" ]]; then
        assert_success "Dashboard directories initialized correctly"
    else
        assert_failure "Dashboard directories not created"
    fi
}

# Test: Generate dashboard (basic functionality)
test_dashboard_generate() {
    echo "Testing dashboard generation..."

    # Ensure init has been run
    cd "${PROJECT_ROOT}"
    "$DASHBOARD_SCRIPT" init >/dev/null 2>&1

    # Create some mock project structure
    mkdir -p "${PROJECT_ROOT}/Projects/TestProject"
    echo "print('hello')" >"${PROJECT_ROOT}/Projects/TestProject/main.py"
    echo "AI generated content" >"${PROJECT_ROOT}/Projects/TestProject/AI_enhanced.py"
    echo "Test quality report" >"${PROJECT_ROOT}/Projects/TestProject/QUALITY_REPORT.md"

    # Run generate command
    local output
    output=$("$DASHBOARD_SCRIPT" generate 2>&1)

    # Check if dashboard was generated
    if [[ -f "${PROJECT_ROOT}/Tools/Automation/dashboard/ai_dashboard.html" ]]; then
        assert_success "Dashboard HTML file generated"
    else
        assert_failure "Dashboard HTML file not generated"
    fi

    # Clean up mock files
    rm -rf "${PROJECT_ROOT}/Projects/TestProject"
}

# Test: Start monitoring
test_monitoring_start() {
    echo "Testing monitoring start..."

    # Ensure init has been run
    cd "${PROJECT_ROOT}"
    "$DASHBOARD_SCRIPT" init >/dev/null 2>&1

    # Stop any existing monitoring first
    "$DASHBOARD_SCRIPT" stop-monitor >/dev/null 2>&1

    # Start monitoring
    local output
    output=$("$DASHBOARD_SCRIPT" start-monitor 2>&1)

    # Check if monitoring script was created and PID file exists
    if [[ -f "${PROJECT_ROOT}/Tools/Automation/monitoring/ai_monitor.sh" ]] && [[ -f "${PROJECT_ROOT}/Tools/Automation/monitoring/ai_monitor.pid" ]]; then
        assert_success "Monitoring started successfully"
    else
        assert_failure "Monitoring not started properly"
    fi

    # Stop monitoring to clean up
    "$DASHBOARD_SCRIPT" stop-monitor >/dev/null 2>&1
}

# Test: Stop monitoring
test_monitoring_stop() {
    echo "Testing monitoring stop..."

    # Ensure init and start monitoring
    cd "${PROJECT_ROOT}"
    "$DASHBOARD_SCRIPT" init >/dev/null 2>&1
    "$DASHBOARD_SCRIPT" start-monitor >/dev/null 2>&1

    # Stop monitoring
    local output
    output=$("$DASHBOARD_SCRIPT" stop-monitor 2>&1)

    # Check if PID file was removed
    if [[ ! -f "${PROJECT_ROOT}/Tools/Automation/monitoring/ai_monitor.pid" ]]; then
        assert_success "Monitoring stopped successfully"
    else
        assert_failure "Monitoring PID file still exists"
    fi
}

# Test: Generate monitoring report
test_monitoring_report() {
    echo "Testing monitoring report generation..."

    # Ensure init has been run
    cd "${PROJECT_ROOT}"
    "$DASHBOARD_SCRIPT" init >/dev/null 2>&1

    # Create some mock log files
    mkdir -p "${PROJECT_ROOT}/Tools/Automation/monitoring/logs"
    echo "[2025-11-07 10:00:00] AI activity detected: 2 new files" >"${PROJECT_ROOT}/Tools/Automation/monitoring/logs/ai_monitor_20251107.log"
    echo "[2025-11-07 10:05:00] Ollama healthy: 5 models available" >>"${PROJECT_ROOT}/Tools/Automation/monitoring/logs/ai_monitor_20251107.log"

    # Generate report
    local output
    output=$("$DASHBOARD_SCRIPT" report 2>&1)

    # Check if report was generated
    local report_files
    report_files=$(find "${PROJECT_ROOT}/Tools/Automation/monitoring/reports" -name "*.md" 2>/dev/null | wc -l)

    if [[ $report_files -gt 0 ]]; then
        assert_success "Monitoring report generated"
    else
        assert_failure "Monitoring report not generated"
    fi

    # Clean up mock logs
    rm -rf "${PROJECT_ROOT}/Tools/Automation/monitoring/logs"
}

# Test: Show dashboard status
test_dashboard_status() {
    echo "Testing dashboard status display..."

    # Ensure init has been run
    cd "${PROJECT_ROOT}"
    "$DASHBOARD_SCRIPT" init >/dev/null 2>&1

    # Run status command
    local output
    output=$("$DASHBOARD_SCRIPT" status 2>&1)

    # Check if status information is displayed
    if echo "$output" | grep -q "Dashboard\|Monitoring"; then
        assert_success "Dashboard status displayed correctly"
    else
        assert_failure "Dashboard status not displayed"
    fi
}

# Test: Command line argument parsing
test_dashboard_arguments() {
    echo "Testing command line argument parsing..."

    # Test help/usage (default when no args)
    local output
    output=$("$DASHBOARD_SCRIPT" 2>&1)

    if echo "$output" | grep -q "Usage:\|Commands:"; then
        assert_success "Help/usage information displayed"
    else
        assert_failure "Help/usage information not displayed"
    fi

    # Test invalid command
    output=$("$DASHBOARD_SCRIPT" invalid-command 2>&1)

    if echo "$output" | grep -q "Usage:\|Commands:"; then
        assert_success "Invalid command handled gracefully"
    else
        assert_failure "Invalid command not handled properly"
    fi
}

# Test: Open dashboard (when dashboard doesn't exist)
test_dashboard_open_missing() {
    echo "Testing dashboard open when file doesn't exist..."

    # Ensure init has been run but no dashboard generated
    cd "${PROJECT_ROOT}"
    "$DASHBOARD_SCRIPT" init >/dev/null 2>&1

    # Remove any existing dashboard
    rm -f "${PROJECT_ROOT}/Tools/Automation/dashboard/ai_dashboard.html"

    # Try to open dashboard without generating it first
    local output
    output=$("$DASHBOARD_SCRIPT" open 2>&1)

    # Should show error message
    if echo "$output" | grep -q "not found\|Run 'generate'"; then
        assert_success "Missing dashboard handled correctly"
    else
        assert_failure "Missing dashboard not handled properly"
    fi
}

# Test: Directory structure creation
test_directory_structure() {
    echo "Testing directory structure creation..."

    # Clean up and re-init
    cd "${PROJECT_ROOT}"
    rm -rf "${PROJECT_ROOT}/Tools/Automation/dashboard" "${PROJECT_ROOT}/Tools/Automation/monitoring"
    "$DASHBOARD_SCRIPT" init >/dev/null 2>&1

    # Check all expected directories exist
    local dirs_exist=true
    for dir in "${PROJECT_ROOT}/Tools/Automation/dashboard" "${PROJECT_ROOT}/Tools/Automation/monitoring" "${PROJECT_ROOT}/Tools/Automation/monitoring/logs" "${PROJECT_ROOT}/Tools/Automation/monitoring/metrics" "${PROJECT_ROOT}/Tools/Automation/monitoring/reports"; do
        if [[ ! -d "$dir" ]]; then
            dirs_exist=false
            break
        fi
    done

    if [[ "$dirs_exist" == "true" ]]; then
        assert_success "All required directories created"
    else
        assert_failure "Some required directories missing"
    fi
}

# Test: Monitoring script creation
test_monitoring_script_creation() {
    echo "Testing monitoring script creation..."

    # Ensure init and start monitoring
    cd "${PROJECT_ROOT}"
    "$DASHBOARD_SCRIPT" init >/dev/null 2>&1
    "$DASHBOARD_SCRIPT" start-monitor >/dev/null 2>&1

    # Check if monitoring script is executable
    if [[ -x "${PROJECT_ROOT}/Tools/Automation/monitoring/ai_monitor.sh" ]]; then
        assert_success "Monitoring script created and executable"
    else
        assert_failure "Monitoring script not created or not executable"
    fi

    # Stop monitoring
    "$DASHBOARD_SCRIPT" stop-monitor >/dev/null 2>&1
}

# Run all tests
# run_test_suite "$0"  # This is handled by run_shell_tests.sh
