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

AGENT_NAME="test_agents_quality_agent.sh"
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
# Test suite for quality_agent.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/quality_agent.sh"
SHELL_TEST_FRAMEWORK="${SCRIPT_DIR}/../shell_test_framework.sh"

# Source the test framework
source "${SHELL_TEST_FRAMEWORK}"

# Test 1: Script should be executable
test_agent_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}" "Script should be executable"
}

# Test 2: Should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}" "Should source shared_functions.sh"
}

# Test 3: Should define AGENT_NAME
test_defines_agent_name() {
    assert_pattern_in_file "AGENT_NAME=\"quality_agent.sh\"" "${AGENT_SCRIPT}" "Should define AGENT_NAME"
}

# Test 4: Should have log function
test_has_log_function() {
    assert_pattern_in_file "log\(\)" "${AGENT_SCRIPT}" "Should have log function"
}

# Test 5: Should have update_status function
test_has_update_status_function() {
    assert_pattern_in_file "update_status\(\)" "${AGENT_SCRIPT}" "Should have update_status function"
}

# Test 6: Should have process_task function
test_has_process_task_function() {
    assert_pattern_in_file "process_task\(\)" "${AGENT_SCRIPT}" "Should have process_task function"
}

# Test 7: Should have run_quality_analysis function
test_has_run_quality_analysis_function() {
    assert_pattern_in_file "run_quality_analysis\(\)" "${AGENT_SCRIPT}" "Should have run_quality_analysis function"
}

# Test 8: Should have case statement for task types
test_has_case_statement() {
    assert_pattern_in_file "case.*task_type" "${AGENT_SCRIPT}" "Should have case statement for task types"
}

# Test 9: Should handle quality/lint/metrics task types
test_handles_quality_tasks() {
    assert_pattern_in_file "\"quality\".*\"lint\".*\"metrics\"" "${AGENT_SCRIPT}" "Should handle quality/lint/metrics tasks"
}

# Test 10: Should have main loop with while true
test_has_main_loop() {
    assert_pattern_in_file "while true" "${AGENT_SCRIPT}" "Should have main loop"
}

# Run all tests
run_tests() {
    echo "Running tests for quality_agent.sh..."

    test_agent_script_executable
    test_sources_shared_functions
    test_defines_agent_name
    test_has_log_function
    test_has_update_status_function
    test_has_process_task_function
    test_has_run_quality_analysis_function
    test_has_case_statement
    test_handles_quality_tasks
    test_has_main_loop

    echo "✅ All tests passed!"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
