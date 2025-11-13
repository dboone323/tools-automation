        #!/usr/bin/env bash
        # Auto-injected health & reliability shim

        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer shared helpers when available
if [[ -f "$DIR/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="test_agents_updater_agent.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  issues=()
  if [[ ! -w "/tmp" ]]; then
    issues+=("tmp_not_writable")
  fi
  if [[ ! -d "$DIR" ]]; then
    issues+=("cwd_missing")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
    exit 2
  fi
  printf '{"ok":true}\n'
  exit 0
fi

# Original agent script continues below
#!/bin/bash
# Test suite for updater_agent.sh
# This test suite validates the updater agent functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/updater_agent.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"
}

# Test 3: Script should have AGENT_NAME variable
test_has_agent_name() {
    assert_pattern_in_file "AGENT_NAME=\"UpdaterAgent\"" "${AGENT_SCRIPT}"
}

# Test 4: Script should have LOG_FILE variable
test_has_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

# Test 5: Script should have SLEEP_INTERVAL variable
test_has_sleep_interval() {
    assert_pattern_in_file "SLEEP_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 6: Script should have MIN_INTERVAL variable
test_has_min_interval() {
    assert_pattern_in_file "MIN_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 7: Script should have MAX_INTERVAL variable
test_has_max_interval() {
    assert_pattern_in_file "MAX_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 8: Script should have main while loop
test_has_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"
}

# Test 9: Script should use brew update command
test_uses_brew_update() {
    assert_pattern_in_file "brew update" "${AGENT_SCRIPT}"
}

# Test 10: Script should use brew upgrade command
test_uses_brew_upgrade() {
    assert_pattern_in_file "brew upgrade" "${AGENT_SCRIPT}"
}

# Test 11: Script should use pip3 install command
test_uses_pip3_install() {
    assert_pattern_in_file "pip3 install" "${AGENT_SCRIPT}"
}

# Test 12: Script should use npm install command
test_uses_npm_install() {
    assert_pattern_in_file "npm install" "${AGENT_SCRIPT}"
}

# Test 13: Script should use npm update command
test_uses_npm_update() {
    assert_pattern_in_file "npm update" "${AGENT_SCRIPT}"
}

# Test 14: Script should use softwareupdate command
test_uses_softwareupdate() {
    assert_pattern_in_file "softwareupdate" "${AGENT_SCRIPT}"
}

# Test 15: Script should use xcode-select command
test_uses_xcode_select() {
    assert_pattern_in_file "xcode-select" "${AGENT_SCRIPT}"
}

# Test 16: Script should have sleep command in loop
test_has_sleep_in_loop() {
    assert_pattern_in_file "sleep.*SLEEP_INTERVAL" "${AGENT_SCRIPT}"
}

# Test 17: Script should increment SLEEP_INTERVAL
test_increments_sleep_interval() {
    assert_pattern_in_file "SLEEP_INTERVAL=\$((SLEEP_INTERVAL + 3600))" "${AGENT_SCRIPT}"
}

# Test 18: Script should cap SLEEP_INTERVAL at MAX_INTERVAL
test_caps_sleep_interval() {
    assert_pattern_in_file "if.*SLEEP_INTERVAL.*-gt.*MAX_INTERVAL" "${AGENT_SCRIPT}"
}

# Test 19: Script should log completion message
test_logs_completion() {
    assert_pattern_in_file "Update cycle complete" "${AGENT_SCRIPT}"
}

# Test 20: Script should log sleeping message
test_logs_sleeping() {
    assert_pattern_in_file "Sleeping for.*SLEEP_INTERVAL" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for updater_agent.sh..."
    echo "Test Results for updater_agent.sh" >"${SCRIPT_DIR}/test_results_updater_agent.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: updater_agent.sh is executable"
        echo "✅ Test 1 PASSED: updater_agent.sh is executable" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: updater_agent.sh is not executable"
        echo "❌ Test 1 FAILED: updater_agent.sh is not executable" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 2: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Sources shared_functions.sh"
        echo "✅ Test 2 PASSED: Sources shared_functions.sh" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define AGENT_NAME variable
    ((total_tests++))
    if assert_pattern_in_file "AGENT_NAME=\"UpdaterAgent\"" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines AGENT_NAME variable"
        echo "✅ Test 3 PASSED: Defines AGENT_NAME variable" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define AGENT_NAME variable"
        echo "❌ Test 3 FAILED: Does not define AGENT_NAME variable" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define LOG_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable"
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable"
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define SLEEP_INTERVAL variable
    ((total_tests++))
    if assert_pattern_in_file "SLEEP_INTERVAL=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines SLEEP_INTERVAL variable"
        echo "✅ Test 5 PASSED: Defines SLEEP_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define SLEEP_INTERVAL variable"
        echo "❌ Test 5 FAILED: Does not define SLEEP_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 6: Should define MIN_INTERVAL variable
    ((total_tests++))
    if assert_pattern_in_file "MIN_INTERVAL=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Defines MIN_INTERVAL variable"
        echo "✅ Test 6 PASSED: Defines MIN_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not define MIN_INTERVAL variable"
        echo "❌ Test 6 FAILED: Does not define MIN_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 7: Should define MAX_INTERVAL variable
    ((total_tests++))
    if assert_pattern_in_file "MAX_INTERVAL=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Defines MAX_INTERVAL variable"
        echo "✅ Test 7 PASSED: Defines MAX_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not define MAX_INTERVAL variable"
        echo "❌ Test 7 FAILED: Does not define MAX_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 8: Should have main loop with while true
    ((total_tests++))
    if assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Has main loop with while true"
        echo "✅ Test 8 PASSED: Has main loop with while true" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Missing main loop"
        echo "❌ Test 8 FAILED: Missing main loop" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 9: Should use brew update command
    ((total_tests++))
    if assert_pattern_in_file "brew update" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Uses brew update command"
        echo "✅ Test 9 PASSED: Uses brew update command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not use brew update command"
        echo "❌ Test 9 FAILED: Does not use brew update command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 10: Should use brew upgrade command
    ((total_tests++))
    if assert_pattern_in_file "brew upgrade" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Uses brew upgrade command"
        echo "✅ Test 10 PASSED: Uses brew upgrade command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not use brew upgrade command"
        echo "❌ Test 10 FAILED: Does not use brew upgrade command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 11: Should use pip3 install command
    ((total_tests++))
    if assert_pattern_in_file "pip3 install" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Uses pip3 install command"
        echo "✅ Test 11 PASSED: Uses pip3 install command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not use pip3 install command"
        echo "❌ Test 11 FAILED: Does not use pip3 install command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 12: Should use npm install command
    ((total_tests++))
    if assert_pattern_in_file "npm install" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Uses npm install command"
        echo "✅ Test 12 PASSED: Uses npm install command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not use npm install command"
        echo "❌ Test 12 FAILED: Does not use npm install command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 13: Should use npm update command
    ((total_tests++))
    if assert_pattern_in_file "npm update" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Uses npm update command"
        echo "✅ Test 13 PASSED: Uses npm update command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not use npm update command"
        echo "❌ Test 13 FAILED: Does not use npm update command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 14: Should use softwareupdate command
    ((total_tests++))
    if assert_pattern_in_file "softwareupdate" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Uses softwareupdate command"
        echo "✅ Test 14 PASSED: Uses softwareupdate command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not use softwareupdate command"
        echo "❌ Test 14 FAILED: Does not use softwareupdate command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 15: Should use xcode-select command
    ((total_tests++))
    if assert_pattern_in_file "xcode-select" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Uses xcode-select command"
        echo "✅ Test 15 PASSED: Uses xcode-select command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not use xcode-select command"
        echo "❌ Test 15 FAILED: Does not use xcode-select command" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 16: Should have sleep command in loop
    ((total_tests++))
    if assert_pattern_in_file "sleep.*SLEEP_INTERVAL" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Has sleep with SLEEP_INTERVAL in main loop"
        echo "✅ Test 16 PASSED: Has sleep with SLEEP_INTERVAL in main loop" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Missing sleep in main loop"
        echo "❌ Test 16 FAILED: Missing sleep in main loop" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 17: Should increment SLEEP_INTERVAL
    ((total_tests++))
    if assert_pattern_in_file "SLEEP_INTERVAL=\$((SLEEP_INTERVAL + 3600))" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Increments SLEEP_INTERVAL by 3600"
        echo "✅ Test 17 PASSED: Increments SLEEP_INTERVAL by 3600" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not increment SLEEP_INTERVAL"
        echo "❌ Test 17 FAILED: Does not increment SLEEP_INTERVAL" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 18: Should cap SLEEP_INTERVAL at MAX_INTERVAL
    ((total_tests++))
    if assert_pattern_in_file "if.*SLEEP_INTERVAL.*-gt.*MAX_INTERVAL" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Caps SLEEP_INTERVAL at MAX_INTERVAL"
        echo "✅ Test 18 PASSED: Caps SLEEP_INTERVAL at MAX_INTERVAL" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not cap SLEEP_INTERVAL"
        echo "❌ Test 18 FAILED: Does not cap SLEEP_INTERVAL" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 19: Should log completion message
    ((total_tests++))
    if assert_pattern_in_file "Update cycle complete" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Logs update cycle completion"
        echo "✅ Test 19 PASSED: Logs update cycle completion" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not log completion message"
        echo "❌ Test 19 FAILED: Does not log completion message" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Test 20: Should log sleeping message
    ((total_tests++))
    if assert_pattern_in_file "Sleeping for.*SLEEP_INTERVAL" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Logs sleeping message with SLEEP_INTERVAL"
        echo "✅ Test 20 PASSED: Logs sleeping message with SLEEP_INTERVAL" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not log sleeping message"
        echo "❌ Test 20 FAILED: Does not log sleeping message" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for updater_agent.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_updater_agent.txt"
    fi
}

# Run the tests
run_tests
