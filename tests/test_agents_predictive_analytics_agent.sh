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

AGENT_NAME="test_agents_predictive_analytics_agent.sh"
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
# Comprehensive test suite for predictive_analytics_agent.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/predictive_analytics_agent.sh"

# Source shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "$AGENT_SCRIPT" "predictive_analytics_agent.sh should be executable"
}

# Test 2: Script should have proper shebang
test_shebang() {
    assert_pattern_in_file "#!/bin/bash" "$AGENT_SCRIPT" "Should have bash shebang"
}

# Test 3: Should source shared_functions.sh
test_shared_functions_source() {
    assert_pattern_in_file "source.*shared_functions.sh" "$AGENT_SCRIPT" "Should source shared_functions.sh"
}

# Test 4: Should define AGENT_NAME variable
test_agent_name_definition() {
    assert_pattern_in_file "AGENT_NAME=" "$AGENT_SCRIPT" "Should define AGENT_NAME variable"
}

# Test 5: Should have log function
test_log_function() {
    assert_pattern_in_file "log\(\)" "$AGENT_SCRIPT" "Should have log function"
}

# Test 6: Should have ollama_query function
test_ollama_query_function() {
    assert_pattern_in_file "ollama_query\(\)" "$AGENT_SCRIPT" "Should have ollama_query function"
}

# Test 7: Should have update_status function
test_update_status_function() {
    assert_pattern_in_file "update_status\(\)" "$AGENT_SCRIPT" "Should have update_status function"
}

# Test 8: Should have process_task function
test_process_task_function() {
    assert_pattern_in_file "process_task\(\)" "$AGENT_SCRIPT" "Should have process_task function"
}

# Test 9: Should have run_predictive_analysis function
test_run_predictive_analysis_function() {
    assert_pattern_in_file "run_predictive_analysis\(\)" "$AGENT_SCRIPT" "Should have run_predictive_analysis function"
}

# Test 10: Should have main loop with while true
test_main_loop() {
    assert_pattern_in_file "while true" "$AGENT_SCRIPT" "Should have main loop"
}

# Run all tests
run_tests() {
    echo "Running comprehensive tests for predictive_analytics_agent.sh..."
    echo "================================================================="

    test_script_executable
    test_shebang
    test_shared_functions_source
    test_agent_name_definition
    test_log_function
    test_ollama_query_function
    test_update_status_function
    test_process_task_function
    test_run_predictive_analysis_function
    test_main_loop

    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
