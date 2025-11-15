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

AGENT_NAME="test_agents_performance_agent.sh"
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
# Test suite for performance_agent.sh

# Source test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shell_test_framework.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && git rev-parse --show-toplevel 2>/dev/null || cd "$SCRIPT_DIR/.." && pwd)"
AGENT_FILE="$REPO_ROOT/agents/performance_agent.sh"

# Test 1: Script should be executable
test_performance_agent_executable() {
    assert_file_executable "${AGENT_FILE}" "performance_agent.sh should be executable"
}

# Test 2: Script should have proper shebang
test_performance_agent_shebang() {
    assert_pattern_in_file "^#!/bin/bash" "${AGENT_FILE}" "performance_agent.sh should have bash shebang"
}

# Test 3: Script should source shared_functions.sh
test_performance_agent_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_FILE}" "performance_agent.sh should source shared_functions.sh"
}

# Test 4: Script should define AGENT_NAME
test_performance_agent_defines_agent_name() {
    assert_pattern_in_file "AGENT_NAME=\"performance_agent.sh\"" "${AGENT_FILE}" "performance_agent.sh should define AGENT_NAME"
}

# Test 5: Script should have update_status function
test_performance_agent_has_update_status_function() {
    assert_pattern_in_file "update_status\(\)" "${AGENT_FILE}" "performance_agent.sh should have update_status function"
}

# Test 6: Script should have process_task function
test_performance_agent_has_process_task_function() {
    assert_pattern_in_file "process_task\(\)" "${AGENT_FILE}" "performance_agent.sh should have process_task function"
}

# Test 7: Script should have run_performance_analysis function
test_performance_agent_has_run_performance_analysis_function() {
    assert_pattern_in_file "run_performance_analysis\(\)" "${AGENT_FILE}" "performance_agent.sh should have run_performance_analysis function"
}

# Test 8: Script should have count_matching_files function
test_performance_agent_has_count_matching_files_function() {
    assert_pattern_in_file "count_matching_files\(\)" "${AGENT_FILE}" "performance_agent.sh should have count_matching_files function"
}

# Test 9: Script should have main loop
test_performance_agent_has_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_FILE}" "performance_agent.sh should have main processing loop"
}

# Test 10: Script should have case statement for task types
test_performance_agent_has_case_statement() {
    assert_pattern_in_file "case.*task_type" "${AGENT_FILE}" "performance_agent.sh should have case statement for task processing"
}

# Run all tests
run_performance_agent_tests() {
    echo "🧪 Running tests for performance_agent.sh"
    echo "========================================"

    test_performance_agent_executable
    test_performance_agent_shebang
    test_performance_agent_sources_shared_functions
    test_performance_agent_defines_agent_name
    test_performance_agent_has_update_status_function
    test_performance_agent_has_process_task_function
    test_performance_agent_has_run_performance_analysis_function
    test_performance_agent_has_count_matching_files_function
    test_performance_agent_has_main_loop
    test_performance_agent_has_case_statement

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_performance_agent_tests
fi
