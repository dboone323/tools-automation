#!/bin/bash
# Test suite for check_persistence.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_PATH="${SCRIPT_DIR}/../agents/check_persistence.sh"
SHELL_TEST_FRAMEWORK="${SCRIPT_DIR}/../shell_test_framework.sh"

# Source the test framework
source "${SHELL_TEST_FRAMEWORK}"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_PATH}"
}

# Test 2: Script should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_PATH}"
}

# Test 3: Script should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_PATH}"
}

# Test 4: Script should define LOG_FILE variable
test_defines_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_PATH}"
}

# Test 5: Script should check launch daemon status
test_checks_launch_daemon() {
    assert_pattern_in_file "launchctl list" "${AGENT_PATH}"
}

# Test 6: Script should check auto-restart monitor process
test_checks_auto_restart_monitor() {
    assert_pattern_in_file "auto_restart_monitor" "${AGENT_PATH}"
}

# Test 7: Script should check core agents
test_checks_core_agents() {
    assert_pattern_in_file "agent_build.sh" "${AGENT_PATH}"
}

# Test 8: Script should check task queue status
test_checks_task_queue() {
    assert_pattern_in_file "task_queue.json" "${AGENT_PATH}"
}

# Test 9: Script should check Ollama status
test_checks_ollama_status() {
    assert_pattern_in_file "ollama serve" "${AGENT_PATH}"
}

# Test 10: Script should display summary to console
test_displays_summary() {
    assert_pattern_in_file "echo.*Agent Persistence Status" "${AGENT_PATH}"
}

# Run all tests
run_check_persistence_tests() {
    echo "🧪 Running tests for check_persistence.sh"
    echo "========================================"

    test_script_executable
    test_sources_shared_functions
    test_defines_script_dir
    test_defines_log_file
    test_checks_launch_daemon
    test_checks_auto_restart_monitor
    test_checks_core_agents
    test_checks_task_queue
    test_checks_ollama_status
    test_displays_summary

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_check_persistence_tests
fi
