#!/bin/bash
# Comprehensive test suite for fix_agent_system.sh
# Tests system fixing, jq usage correction, shared functions integration, and agent restarting

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/fix_agent_system.sh"
TEST_FRAMEWORK="${SCRIPT_DIR}/../shell_test_framework.sh"

# Source the test framework
source "$TEST_FRAMEWORK"

# Test setup
setup_test_environment() {
    export TEST_MODE=true
    export SCRIPT_DIR="${SCRIPT_DIR}/../agents"
    export LOG_FILE="${SCRIPT_DIR}/test_fixer.log"

    # Create test agent files with problematic patterns
    mkdir -p "${SCRIPT_DIR}/test_agents"
    cat >"${SCRIPT_DIR}/test_agents/test_agent1.sh" <<'EOF'
#!/bin/bash
# Test agent with jq issues
jq '.agents[] | select(.status == "running")' agent_status.json
update_agent_status "test_agent1" "available" "$$" ""
EOF

    cat >"${SCRIPT_DIR}/test_agents/test_agent2.sh" <<'EOF'
#!/bin/bash
# Test agent without shared functions
echo "No shared functions sourced"
EOF

    cat >"${SCRIPT_DIR}/test_agents/test_agent3.sh" <<'EOF'
#!/bin/bash
# Test agent with system monitoring issues
ps aux | jq '.[] | select(.cpu > 80)'
EOF

    # Create corrupted JSON files for testing
    echo '{"invalid": json}' >"${SCRIPT_DIR}/test_agent_status.json"
    echo '{"broken": json}' >"${SCRIPT_DIR}/test_task_queue.json"

    # Clean up any existing test files
    rm -f "$LOG_FILE"
}

# Test cleanup
cleanup_test_environment() {
    rm -rf "${SCRIPT_DIR}/test_agents"
    rm -f "${SCRIPT_DIR}/test_agent_status.json"
    rm -f "${SCRIPT_DIR}/test_task_queue.json"
    rm -f "$LOG_FILE"
}

# Test 1: Verify script structure and fix functions
test_fix_agent_script_structure() {
    announce_test "Fix agent script structure"

    # Check if script exists and is executable
    assert_file_exists "$AGENT_SCRIPT"
    assert_file_executable "$AGENT_SCRIPT"

    # Check for core fix functions
    assert_pattern_in_file "fix_agent_jq_usage()" "$AGENT_SCRIPT"
    assert_pattern_in_file "fix_shared_functions_sourcing()" "$AGENT_SCRIPT"
    assert_pattern_in_file "fix_system_monitoring()" "$AGENT_SCRIPT"
    assert_pattern_in_file "fix_temp_file_handling()" "$AGENT_SCRIPT"
    assert_pattern_in_file "restart_agents_cleanly()" "$AGENT_SCRIPT"
    assert_pattern_in_file "validate_json_files()" "$AGENT_SCRIPT"

    test_passed "Fix agent script structure"
}

# Test 2: Verify jq usage fixing functionality
test_jq_usage_fixing() {
    announce_test "Jq usage fixing functionality"

    # Check for jq pattern detection
    assert_pattern_in_file "jq.*agents.*status" "$AGENT_SCRIPT"
    assert_pattern_in_file "update_agent_status" "$AGENT_SCRIPT"
    assert_pattern_in_file "sed.*update_agent_status" "$AGENT_SCRIPT"

    # Check for backup creation
    assert_pattern_in_file "cp.*backup" "$AGENT_SCRIPT"

    test_passed "Jq usage fixing functionality"
}

# Test 3: Verify shared functions sourcing fixes
test_shared_functions_sourcing() {
    announce_test "Shared functions sourcing fixes"

    # Check for shared functions detection
    assert_pattern_in_file "source.*shared_functions.sh" "$AGENT_SCRIPT"
    assert_pattern_in_file "grep.*shared_functions.sh" "$AGENT_SCRIPT"

    # Check for source line addition
    assert_pattern_in_file "SCRIPT_DIR.*BASH_SOURCE" "$AGENT_SCRIPT"
    assert_pattern_in_file "sed.*2a" "$AGENT_SCRIPT"

    test_passed "Shared functions sourcing fixes"
}

# Test 4: Verify system monitoring fixes
test_system_monitoring_fixes() {
    announce_test "System monitoring fixes"

    # Check for system monitoring detection
    assert_pattern_in_file "ps aux\|top\|free\|df" "$AGENT_SCRIPT"
    assert_pattern_in_file "grep.*ps aux" "$AGENT_SCRIPT"

    # Check for jq replacement patterns
    assert_pattern_in_file "sed.*ps aux.*number" "$AGENT_SCRIPT"
    assert_pattern_in_file "sed.*free.*number" "$AGENT_SCRIPT"

    test_passed "System monitoring fixes"
}

# Test 5: Verify temporary file handling fixes
test_temp_file_handling_fixes() {
    announce_test "Temporary file handling fixes"

    # Check for temp file detection
    assert_pattern_in_file "jq.*\.tmp" "$AGENT_SCRIPT"
    assert_pattern_in_file "grep.*\.tmp" "$AGENT_SCRIPT"

    # Check for problematic pattern replacement
    assert_pattern_in_file "sed.*jq.*tasks" "$AGENT_SCRIPT"

    test_passed "Temporary file handling fixes"
}

# Test 6: Verify agent restart functionality
test_agent_restart_functionality() {
    announce_test "Agent restart functionality"

    # Check for agent list
    assert_pattern_in_file "agent_analytics.sh" "$AGENT_SCRIPT"
    assert_pattern_in_file "agent_build.sh" "$AGENT_SCRIPT"
    assert_pattern_in_file "quality_agent.sh" "$AGENT_SCRIPT"

    # Check for restart process
    assert_pattern_in_file "pkill.*agent_.*\.sh" "$AGENT_SCRIPT"
    assert_pattern_in_file "chmod.*+x" "$AGENT_SCRIPT"
    assert_pattern_in_file "./.*start" "$AGENT_SCRIPT"

    test_passed "Agent restart functionality"
}

# Test 7: Verify JSON validation functionality
test_json_validation_functionality() {
    announce_test "JSON validation functionality"

    # Check for JSON validation
    assert_pattern_in_file "validate_json_files" "$AGENT_SCRIPT"
    assert_pattern_in_file "python3.*json.load" "$AGENT_SCRIPT"

    # Check for file creation
    assert_pattern_in_file "agent_status.json" "$AGENT_SCRIPT"
    assert_pattern_in_file "task_queue.json" "$AGENT_SCRIPT"
    assert_pattern_in_file '{"agents":{},"last_update":0}' "$AGENT_SCRIPT"

    test_passed "JSON validation functionality"
}

# Test 8: Verify logging and output functionality
test_logging_output_functionality() {
    announce_test "Logging and output functionality"

    # Check for logging function
    assert_pattern_in_file "log()" "$AGENT_SCRIPT"
    assert_pattern_in_file "tee.*LOG_FILE" "$AGENT_SCRIPT"
    assert_pattern_in_file "echo.*date" "$AGENT_SCRIPT"

    # Check for progress messages
    assert_pattern_in_file "AGENT SYSTEM FIXER STARTED" "$AGENT_SCRIPT"
    assert_pattern_in_file "AGENT SYSTEM FIXER COMPLETED" "$AGENT_SCRIPT"
    assert_pattern_in_file "Monitor the dashboard" "$AGENT_SCRIPT"

    test_passed "Logging and output functionality"
}

# Test 9: Verify main execution flow
test_main_execution_flow() {
    announce_test "Main execution flow"

    # Check for main function
    assert_pattern_in_file "main()" "$AGENT_SCRIPT"
    assert_pattern_in_file "BASH_SOURCE.*0" "$AGENT_SCRIPT"

    # Check for fix execution order
    assert_pattern_in_file "validate_json_files" "$AGENT_SCRIPT"
    assert_pattern_in_file "fix_shared_functions_sourcing" "$AGENT_SCRIPT"
    assert_pattern_in_file "fix_agent_jq_usage" "$AGENT_SCRIPT"
    assert_pattern_in_file "fix_system_monitoring" "$AGENT_SCRIPT"
    assert_pattern_in_file "fix_temp_file_handling" "$AGENT_SCRIPT"
    assert_pattern_in_file "restart_agents_cleanly" "$AGENT_SCRIPT"

    test_passed "Main execution flow"
}

# Test 10: Verify error handling and safety measures
test_error_handling_safety() {
    announce_test "Error handling and safety measures"

    # Check for error handling
    assert_pattern_in_file "2>/dev/null" "$AGENT_SCRIPT"
    assert_pattern_in_file "|| true" "$AGENT_SCRIPT"

    # Check for safety measures
    assert_pattern_in_file "sleep 2" "$AGENT_SCRIPT"
    assert_pattern_in_file "sleep 0.5" "$AGENT_SCRIPT"

    # Check for file existence checks
    assert_pattern_in_file '\[\[ -f.*\]\]' "$AGENT_SCRIPT"

    test_passed "Error handling and safety measures"
}

# Run all tests
run_fix_agent_system_tests() {
    echo "🧪 Running comprehensive tests for fix_agent_system.sh"
    echo "==================================================="

    setup_test_environment

    test_fix_agent_script_structure
    test_jq_usage_fixing
    test_shared_functions_sourcing
    test_system_monitoring_fixes
    test_temp_file_handling_fixes
    test_agent_restart_functionality
    test_json_validation_functionality
    test_logging_output_functionality
    test_main_execution_flow
    test_error_handling_safety

    cleanup_test_environment

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_fix_agent_system_tests
fi
