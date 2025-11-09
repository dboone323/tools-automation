#!/bin/bash
# Test suite for run_task_orchestrator.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/run_task_orchestrator.sh"
SHELL_TEST_FRAMEWORK="${SCRIPT_DIR}/../shell_test_framework.sh"

# Source the test framework
source "${SHELL_TEST_FRAMEWORK}"

# Test 1: Script should be executable
test_agent_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}" "Script should be executable"
}

# Test 2: Should set ROOT_DIR variable
test_sets_root_dir() {
    assert_pattern_in_file "ROOT_DIR=" "${AGENT_SCRIPT}" "Should set ROOT_DIR variable"
}

# Test 3: Should change to ROOT_DIR/agents
test_changes_to_agents_dir() {
    assert_pattern_in_file "cd.*ROOT_DIR/agents" "${AGENT_SCRIPT}" "Should change to agents directory"
}

# Test 4: Should execute task_orchestrator.sh
test_executes_task_orchestrator() {
    assert_pattern_in_file "exec.*task_orchestrator.sh" "${AGENT_SCRIPT}" "Should execute task_orchestrator.sh"
}

# Test 5: Should use set -euo pipefail
test_uses_strict_mode() {
    assert_pattern_in_file "set -euo pipefail" "${AGENT_SCRIPT}" "Should use strict mode"
}

# Test 6: Should use zsh shebang
test_uses_zsh_shebang() {
    assert_pattern_in_file "#!/bin/zsh" "${AGENT_SCRIPT}" "Should use zsh shebang"
}

# Test 7: Should use dirname and pwd for path resolution
test_uses_path_resolution() {
    assert_pattern_in_file "dirname.*pwd" "${AGENT_SCRIPT}" "Should use dirname and pwd"
}

# Test 8: Should use $0 for script location
test_uses_dollar_zero() {
    assert_pattern_in_file '\$0' "${AGENT_SCRIPT}" "Should use \$0 for script location"
}

# Test 9: Should have proper quoting
test_has_proper_quoting() {
    assert_pattern_in_file 'dirname.*\$0' "${AGENT_SCRIPT}" "Should have proper quoting"
}

# Test 10: Should have double quotes around variables
test_has_double_quotes() {
    assert_pattern_in_file "cd.*ROOT_DIR" "${AGENT_SCRIPT}" "Should have double quotes around variables"
}

# Run all tests
run_tests() {
    echo "Running tests for run_task_orchestrator.sh..."

    test_agent_script_executable
    test_sets_root_dir
    test_changes_to_agents_dir
    test_executes_task_orchestrator
    test_uses_strict_mode
    test_uses_zsh_shebang
    test_uses_path_resolution
    test_uses_dollar_zero
    test_has_proper_quoting
    test_has_double_quotes

    echo "✅ All tests passed!"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
