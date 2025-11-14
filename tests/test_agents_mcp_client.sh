#!/bin/bash
# Comprehensive test suite for mcp_client.sh
# Tests MCP client functionality and structural validation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/mcp_client.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing mcp_client.sh structural validation..."

# Test 1: Script exists and is executable
test_script_exists_and_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: SCRIPT_DIR variable definition
test_script_dir_variable() {
    assert_pattern_in_file 'SCRIPT_DIR=' "${AGENT_SCRIPT}"
}

# Test 3: ROOT_DIR variable definition
test_root_dir_variable() {
    assert_pattern_in_file 'ROOT_DIR=' "${AGENT_SCRIPT}"
}

# Test 4: MCP_CONFIG variable definition
test_mcp_config_variable() {
    assert_pattern_in_file 'MCP_CONFIG=' "${AGENT_SCRIPT}"
}

# Test 5: MCP_TIMEOUT variable definition
test_mcp_timeout_variable() {
    assert_pattern_in_file 'MCP_TIMEOUT=' "${AGENT_SCRIPT}"
}

# Test 6: OLLAMA_MODEL variable definition
test_ollama_model_variable() {
    assert_pattern_in_file 'OLLAMA_MODEL=' "${AGENT_SCRIPT}"
}

# Test 7: OLLAMA_HOST variable definition
test_ollama_host_variable() {
    assert_pattern_in_file 'OLLAMA_HOST=' "${AGENT_SCRIPT}"
}

# Test 8: log function declaration
test_log_function() {
    assert_pattern_in_file 'log\(\)' "${AGENT_SCRIPT}"
}

# Test 9: error function declaration
test_error_function() {
    assert_pattern_in_file 'error\(\)' "${AGENT_SCRIPT}"
}

# Test 10: check_ollama function declaration
test_check_ollama_function() {
    assert_pattern_in_file 'check_ollama\(\)' "${AGENT_SCRIPT}"
}

# Test 11: query_ollama function declaration
test_query_ollama_function() {
    assert_pattern_in_file 'query_ollama\(\)' "${AGENT_SCRIPT}"
}

# Test 12: analyze_error function declaration
test_analyze_error_function() {
    assert_pattern_in_file 'analyze_error\(\)' "${AGENT_SCRIPT}"
}

# Test 13: suggest_fix function declaration
test_suggest_fix_function() {
    assert_pattern_in_file 'suggest_fix\(\)' "${AGENT_SCRIPT}"
}

# Test 14: evaluate_situation function declaration
test_evaluate_situation_function() {
    assert_pattern_in_file 'evaluate_situation\(\)' "${AGENT_SCRIPT}"
}

# Test 15: verify_outcome function declaration
test_verify_outcome_function() {
    assert_pattern_in_file 'verify_outcome\(\)' "${AGENT_SCRIPT}"
}

# Test 16: main function declaration
test_main_function() {
    assert_pattern_in_file 'main\(\)' "${AGENT_SCRIPT}"
}

# Test 17: set -euo pipefail
test_strict_mode() {
    assert_pattern_in_file 'set -euo pipefail' "${AGENT_SCRIPT}"
}

# Test 18: command -v ollama check
test_ollama_command_check() {
    assert_pattern_in_file 'command -v ollama' "${AGENT_SCRIPT}"
}

# Test 19: curl usage for Ollama API
test_curl_usage() {
    assert_pattern_in_file 'curl.*OLLAMA_HOST' "${AGENT_SCRIPT}"
}

# Test 20: jq usage for JSON processing
test_jq_usage() {
    assert_pattern_in_file 'jq -n' "${AGENT_SCRIPT}"
}

# Test 21: Case statement in main function
test_case_statement() {
    assert_pattern_in_file 'case.*command' "${AGENT_SCRIPT}"
}

# Test 22: analyze-error command handling
test_analyze_error_command() {
    assert_pattern_in_file 'analyze-error)' "${AGENT_SCRIPT}"
}

# Test 23: suggest-fix command handling
test_suggest_fix_command() {
    assert_pattern_in_file 'suggest-fix)' "${AGENT_SCRIPT}"
}

# Test 24: evaluate command handling
test_evaluate_command() {
    assert_pattern_in_file 'evaluate)' "${AGENT_SCRIPT}"
}

# Test 25: verify command handling
test_verify_command() {
    assert_pattern_in_file 'verify)' "${AGENT_SCRIPT}"
}

# Test 26: test command handling
test_test_command() {
    assert_pattern_in_file 'test)' "${AGENT_SCRIPT}"
}

# Test 27: help command handling
test_help_command() {
    assert_pattern_in_file 'help \| --help \| -h' "${AGENT_SCRIPT}"
}

# Test 28: Python script usage in suggest_fix
test_python_script_usage() {
    assert_pattern_in_file 'python3 -c' "${AGENT_SCRIPT}"
}

# Test 29: Error pattern knowledge base file reference
test_knowledge_base_reference() {
    assert_pattern_in_file 'knowledge/error_patterns.json' "${AGENT_SCRIPT}"
}

# Test 30: Usage examples in help text
test_usage_examples() {
    assert_pattern_in_file 'Examples:' "${AGENT_SCRIPT}"
}

# Array of all test functions
tests=(
    test_script_exists_and_executable
    test_script_dir_variable
    test_root_dir_variable
    test_mcp_config_variable
    test_mcp_timeout_variable
    test_ollama_model_variable
    test_ollama_host_variable
    test_log_function
    test_error_function
    test_check_ollama_function
    test_query_ollama_function
    test_analyze_error_function
    test_suggest_fix_function
    test_evaluate_situation_function
    test_verify_outcome_function
    test_main_function
    test_strict_mode
    test_ollama_command_check
    test_curl_usage
    test_jq_usage
    test_case_statement
    test_analyze_error_command
    test_suggest_fix_command
    test_evaluate_command
    test_verify_command
    test_test_command
    test_help_command
    test_python_script_usage
    test_knowledge_base_reference
    test_usage_examples
)

echo "Running ${#tests[@]} tests for mcp_client.sh..."

passed=0
failed=0
results=()

for test in "${tests[@]}"; do
    echo -n "Running $test... "
    if $test; then
        echo -e "${GREEN}PASSED${NC}"
        ((passed++))
        results+=("$test: PASSED")
    else
        echo -e "${RED}FAILED${NC}"
        ((failed++))
        results+=("$test: FAILED")
    fi
done

echo ""
echo "mcp_client.sh Test Results"
echo "=========================="
echo "Total tests: ${#tests[@]}"
echo -e "Passed: ${GREEN}$passed${NC}"
echo -e "Failed: ${RED}$failed${NC}"
echo ""

if [[ $failed -gt 0 ]]; then
    echo "Failed tests:"
    for result in "${results[@]}"; do
        if [[ $result == *": FAILED" ]]; then
            echo -e "${RED}$result${NC}"
        fi
    done
fi

# Save results to file
RESULTS_FILE="${TEST_RESULTS_DIR}/test_mcp_client_results.txt"
{
    echo "mcp_client.sh Test Results"
    echo "=========================="
    echo "Total tests: ${#tests[@]}"
    echo "Passed: $passed"
    echo "Failed: $failed"
    echo ""
    echo "Detailed Results:"
    for result in "${results[@]}"; do
        echo "$result"
    done
} >"$RESULTS_FILE"

echo "Results saved to: $RESULTS_FILE"

# Exit with failure if any tests failed
if [[ $failed -gt 0 ]]; then
    exit 1
fi

echo "mcp_client.sh structural validation complete."
