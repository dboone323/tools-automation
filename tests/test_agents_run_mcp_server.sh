#!/bin/bash
# Test suite for run_mcp_server.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/run_mcp_server.sh"
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

# Test 3: Should export MCP_HOST
test_exports_mcp_host() {
    assert_pattern_in_file "export MCP_HOST" "${AGENT_SCRIPT}" "Should export MCP_HOST"
}

# Test 4: Should export MCP_PORT
test_exports_mcp_port() {
    assert_pattern_in_file "export MCP_PORT" "${AGENT_SCRIPT}" "Should export MCP_PORT"
}

# Test 5: Should export MCP_AUTH_TOKEN
test_exports_mcp_auth_token() {
    assert_pattern_in_file "export MCP_AUTH_TOKEN" "${AGENT_SCRIPT}" "Should export MCP_AUTH_TOKEN"
}

# Test 6: Should call mcp_auth_token.sh script
test_calls_auth_token_script() {
    assert_pattern_in_file "mcp_auth_token.sh" "${AGENT_SCRIPT}" "Should call mcp_auth_token.sh"
}

# Test 7: Should change to ROOT_DIR
test_changes_to_root_dir() {
    assert_pattern_in_file "cd.*ROOT_DIR" "${AGENT_SCRIPT}" "Should change to ROOT_DIR"
}

# Test 8: Should execute python3 mcp_server.py
test_executes_mcp_server() {
    assert_pattern_in_file "exec python3.*mcp_server.py" "${AGENT_SCRIPT}" "Should execute mcp_server.py"
}

# Test 9: Should use set -euo pipefail
test_uses_strict_mode() {
    assert_pattern_in_file "set -euo pipefail" "${AGENT_SCRIPT}" "Should use strict mode"
}

# Test 10: Should use zsh shebang
test_uses_zsh_shebang() {
    assert_pattern_in_file "#!/bin/zsh" "${AGENT_SCRIPT}" "Should use zsh shebang"
}

# Run all tests
run_tests() {
    echo "Running tests for run_mcp_server.sh..."

    test_agent_script_executable
    test_sets_root_dir
    test_exports_mcp_host
    test_exports_mcp_port
    test_exports_mcp_auth_token
    test_calls_auth_token_script
    test_changes_to_root_dir
    test_executes_mcp_server
    test_uses_strict_mode
    test_uses_zsh_shebang

    echo "✅ All tests passed!"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
