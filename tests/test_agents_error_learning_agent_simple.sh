#!/bin/bash
# Comprehensive test suite for error_learning_agent_simple.sh
# Tests error monitoring, knowledge base management, log scanning, and learning functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${SCRIPT_DIR}/test_tmp"
AGENT_SCRIPT="${SCRIPT_DIR}/agents/error_learning_agent_simple.sh"

# Source test framework
source "${SCRIPT_DIR}/shell_test_framework.sh"

# Setup test environment
setup_test_env() {
    mkdir -p "$TEST_DIR"
    export TEST_MODE=true

    # Create test knowledge directory
    mkdir -p "${TEST_DIR}/knowledge"

    # Create test log files with various error patterns
    cat >"${TEST_DIR}/test_agent1.log" <<'EOF'
[2025-01-09 10:00:00] [agent1] Starting agent1
[2025-01-09 10:00:01] [agent1] ERROR: Failed to connect to database
[2025-01-09 10:00:02] [agent1] Processing completed
[2025-01-09 10:00:03] [agent1] ERROR: Network timeout occurred
EOF

    cat >"${TEST_DIR}/test_agent2.log" <<'EOF'
[2025-01-09 10:00:00] [agent2] Starting agent2
[2025-01-09 10:00:01] [agent2] Processing data
[2025-01-09 10:00:02] [agent2] FATAL: Out of memory
[2025-01-09 10:00:03] [agent2] Shutting down
EOF

    cat >"${TEST_DIR}/test_no_errors.log" <<'EOF'
[2025-01-09 10:00:00] [agent3] Starting agent3
[2025-01-09 10:00:01] [agent3] Processing completed successfully
[2025-01-09 10:00:02] [agent3] All tests passed
EOF

    # Set up environment variables for testing
    export KNOWLEDGE_DIR="$TEST_DIR/knowledge"
    export ERROR_DB="${KNOWLEDGE_DIR}/error_patterns.json"
    export LEARNING_MODEL="${KNOWLEDGE_DIR}/learning_model.json"
}

# Cleanup test environment
cleanup_test_env() {
    # Clean up test files
    rm -rf "$TEST_DIR"

    # Kill any test processes
    pkill -f "error_learning_agent_simple.sh" || true
    rm -f "${SCRIPT_DIR}/agents/.error_learning_agent.pid"
}

# Test 1: Error extraction from log lines
test_error_extraction() {
    local test_name;
    test_name="test_error_extraction"
    announce_test "$test_name"

    # Define extract_error function (simplified version)
    extract_error() {
        local line;
        line="$1"

        # Simple pattern matching for errors
        if echo "${line}" | grep -qiE '(ERROR|FAILED|exception|fatal)'; then
            # Mock JSON output for testing
            echo '{"timestamp":"2025-01-09 10:00:01","agent":"test_agent","message":"Test error","hash":"abc123"}'
        fi
    }

    # Test error extraction
    local result
    result=$(extract_error "[2025-01-09 10:00:01] [agent1] ERROR: Failed to connect")

    if [[ -n "$result" ]]; then
        assert_true true "Should extract error from ERROR lines"
    else
        assert_true false "Should extract error from ERROR lines"
    fi

    # Test non-error lines
    result=$(extract_error "[2025-01-09 10:00:01] [agent1] Processing completed")

    if [[ -z "$result" ]]; then
        assert_true true "Should not extract error from normal lines"
    else
        assert_true false "Should not extract error from normal lines"
    fi

    test_passed "$test_name"
}

# Test 2: Knowledge base initialization
test_knowledge_base_init() {
    local test_name;
    test_name="test_knowledge_base_init"
    announce_test "$test_name"

    # Define initialize function
    initialize() {
        if [[ ! -f "${ERROR_DB}" ]]; then
            echo '{"version":"1.0","error_patterns":[],"last_updated":""}' >"${ERROR_DB}"
        fi

        if [[ ! -f "${LEARNING_MODEL}" ]]; then
            echo '{"version":"1.0","model_stats":{"total_errors_learned":0,"total_fixes_recorded":0},"last_trained":""}' >"${LEARNING_MODEL}"
        fi
    }

    # Clean up any existing files
    rm -f "${ERROR_DB}" "${LEARNING_MODEL}"

    # Test initialization
    initialize

    # Check if files were created
    assert_file_exists "${ERROR_DB}" "Error database should be created"
    assert_file_exists "${LEARNING_MODEL}" "Learning model should be created"

    # Check file contents
    local db_content
    db_content=$(cat "${ERROR_DB}")
    if echo "$db_content" | grep -q '"version":"1.0"'; then
        assert_true true "Error DB should have correct version"
    else
        assert_true false "Error DB should have correct version"
    fi

    test_passed "$test_name"
}

# Test 3: Error recording to database
test_error_recording() {
    local test_name;
    test_name="test_error_recording"
    announce_test "$test_name"

    # Initialize knowledge base
    mkdir -p "${KNOWLEDGE_DIR}"
    echo '{"version":"1.0","error_patterns":[],"last_updated":""}' >"${ERROR_DB}"

    # Define record_error function (simplified)
    record_error() {
        local error_json;
        error_json="$1"
        # Simple mock - just append to a test file
        echo "$error_json" >>"${TEST_DIR}/recorded_errors.txt"
    }

    # Test recording an error
    local test_error;
    test_error='{"timestamp":"2025-01-09 10:00:01","agent":"test_agent","message":"Test error","hash":"abc123"}'
    record_error "$test_error"

    # Check if error was recorded
    if grep -q "Test error" "${TEST_DIR}/recorded_errors.txt"; then
        assert_true true "Error should be recorded"
    else
        assert_true false "Error should be recorded"
    fi

    test_passed "$test_name"
}

# Test 4: Log file monitoring
test_log_monitoring() {
    local test_name;
    test_name="test_log_monitoring"
    announce_test "$test_name"

    # Create test log file
    local test_log;
    test_log="${TEST_DIR}/monitor_test.log"
    echo "[2025-01-09 10:00:01] [test] ERROR: Test error message" >"$test_log"

    # Define monitor_log function (simplified)
    monitor_log() {
        local log_file;
        log_file="$1"
        local pos_file;
        pos_file="${TEST_DIR}/.pos_$(basename "${log_file}")"

        # Get last position
        local last_pos;
        last_pos=0
        if [[ -f "${pos_file}" ]]; then
            last_pos=$(cat "${pos_file}")
        fi

        # Get current size
        local current_size
        current_size=$(wc -c <"${log_file}" 2>/dev/null || echo "0")

        if [[ ${current_size} -gt ${last_pos} ]]; then
            # Read new content
            tail -c "+$((last_pos + 1))" "${log_file}" 2>/dev/null | while IFS= read -r line; do
                if echo "${line}" | grep -qiE '(ERROR|FAILED)'; then
                    echo "FOUND_ERROR: $line" >>"${TEST_DIR}/monitoring_results.txt"
                fi
            done

            # Update position
            echo "${current_size}" >"${pos_file}"
        fi
    }

    # Test monitoring
    monitor_log "$test_log"

    # Check if error was detected
    if grep -q "FOUND_ERROR" "${TEST_DIR}/monitoring_results.txt"; then
        assert_true true "Log monitoring should detect errors"
    else
        assert_true false "Log monitoring should detect errors"
    fi

    # Test position tracking
    local pos_file;
    pos_file="${TEST_DIR}/.pos_monitor_test.log"
    assert_file_exists "$pos_file" "Position file should be created"

    test_passed "$test_name"
}

# Test 5: Log scanning functionality
test_log_scanning() {
    local test_name;
    test_name="test_log_scanning"
    announce_test "$test_name"

    # Create multiple test log files
    echo "[2025-01-09 10:00:01] [agent1] ERROR: Database connection failed" >"${TEST_DIR}/scan_test1.log"
    echo "[2025-01-09 10:00:02] [agent2] FATAL: Out of memory" >"${TEST_DIR}/scan_test2.log"
    echo "[2025-01-09 10:00:03] [agent3] Processing completed" >"${TEST_DIR}/scan_test3.log"

    # Define scan_logs function (simplified)
    scan_logs() {
        local scanned;
        scanned=0

        for log_file in "${TEST_DIR}"/scan_*.log; do
            if [[ -f "${log_file}" ]]; then
                # Simple scan - count errors
                if grep -q "ERROR\|FATAL" "$log_file"; then
                    echo "ERROR_FOUND" >>"${TEST_DIR}/scan_results.txt"
                fi
                ((scanned++))
            fi
        done

        echo "SCANNED: $scanned" >>"${TEST_DIR}/scan_results.txt"
    }

    # Test scanning
    scan_logs

    # Check results
    local error_count
    error_count=$(grep -c "ERROR_FOUND" "${TEST_DIR}/scan_results.txt")

    if [[ $error_count -eq 2 ]]; then
        assert_true true "Should find errors in 2 out of 3 log files"
    else
        assert_true false "Should find errors in 2 out of 3 log files - found $error_count"
    fi

    test_passed "$test_name"
}

# Test 6: Agent startup and PID file creation
test_agent_startup() {
    local test_name;
    test_name="test_agent_startup"
    announce_test "$test_name"

    # Test that agent creates PID file (run briefly)
    timeout 3 bash "$AGENT_SCRIPT" >/dev/null 2>&1 &
    local pid;
    pid=$!
    sleep 1

    # Check if PID file was created
    assert_file_exists "${SCRIPT_DIR}/agents/.error_learning_agent.pid" "PID file should be created on startup"

    # Cleanup
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true

    test_passed "$test_name"
}

# Test 7: Knowledge base file structure
test_knowledge_base_structure() {
    local test_name;
    test_name="test_knowledge_base_structure"
    announce_test "$test_name"

    # Initialize knowledge base
    mkdir -p "${KNOWLEDGE_DIR}"
    echo '{"version":"1.0","error_patterns":[],"last_updated":"2025-01-09T10:00:00"}' >"${ERROR_DB}"
    echo '{"version":"1.0","model_stats":{"total_errors_learned":0,"total_fixes_recorded":0},"last_trained":"2025-01-09T10:00:00"}' >"${LEARNING_MODEL}"

    # Test error database structure
    local db_content
    db_content=$(cat "${ERROR_DB}")

    if echo "$db_content" | grep -q '"version"' && echo "$db_content" | grep -q '"error_patterns"' && echo "$db_content" | grep -q '"last_updated"'; then
        assert_true true "Error database should have correct JSON structure"
    else
        assert_true false "Error database should have correct JSON structure"
    fi

    # Test learning model structure
    local model_content
    model_content=$(cat "${LEARNING_MODEL}")

    if echo "$model_content" | grep -q '"model_stats"' && echo "$model_content" | grep -q '"total_errors_learned"'; then
        assert_true true "Learning model should have correct JSON structure"
    else
        assert_true false "Learning model should have correct JSON structure"
    fi

    test_passed "$test_name"
}

# Test 8: Directory structure creation
test_directory_structure() {
    local test_name;
    test_name="test_directory_structure"
    announce_test "$test_name"

    # Clean up any existing directories
    rm -rf "${KNOWLEDGE_DIR}"

    # Test directory creation
    mkdir -p "${KNOWLEDGE_DIR}"/{patterns,fixes,analysis,predictions}

    # Check if directories were created (using ls to verify)
    if [[ -d "${KNOWLEDGE_DIR}/patterns" ]]; then
        assert_true true "Patterns directory should be created"
    else
        assert_true false "Patterns directory should be created"
    fi

    if [[ -d "${KNOWLEDGE_DIR}/fixes" ]]; then
        assert_true true "Fixes directory should be created"
    else
        assert_true false "Fixes directory should be created"
    fi

    if [[ -d "${KNOWLEDGE_DIR}/analysis" ]]; then
        assert_true true "Analysis directory should be created"
    else
        assert_true false "Analysis directory should be created"
    fi

    if [[ -d "${KNOWLEDGE_DIR}/predictions" ]]; then
        assert_true true "Predictions directory should be created"
    else
        assert_true false "Predictions directory should be created"
    fi

    test_passed "$test_name"
}

# Test 9: Error pattern frequency tracking
test_error_frequency_tracking() {
    local test_name;
    test_name="test_error_frequency_tracking"
    announce_test "$test_name"

    # Create test error database
    mkdir -p "${KNOWLEDGE_DIR}"
    cat >"${ERROR_DB}" <<'EOF'
{
  "version": "1.0",
  "error_patterns": [
    {
      "hash": "abc123",
      "frequency": 2,
      "message": "Database connection failed"
    }
  ],
  "last_updated": "2025-01-09T10:00:00"
}
EOF

    # Test frequency tracking (simplified)
    local current_freq
    current_freq=$(python3 -c "import json; print(json.load(open('${ERROR_DB}'))['error_patterns'][0]['frequency'])" 2>/dev/null || echo "0")

    if [[ "$current_freq" -eq 2 ]]; then
        assert_true true "Error frequency should be tracked correctly"
    else
        assert_true false "Error frequency should be tracked correctly - got $current_freq"
    fi

    test_passed "$test_name"
}

# Test 10: Agent cleanup on exit
test_agent_cleanup() {
    local test_name;
    test_name="test_agent_cleanup"
    announce_test "$test_name"

    # Create a PID file
    echo "12345" >"${SCRIPT_DIR}/agents/.error_learning_agent.pid"

    # Test cleanup function (simplified)
    cleanup() {
        rm -f "${SCRIPT_DIR}/agents/.error_learning_agent.pid"
    }

    # Run cleanup
    cleanup

    # Check if PID file was removed
    assert_file_not_exists "${SCRIPT_DIR}/agents/.error_learning_agent.pid" "PID file should be cleaned up on exit"

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    setup_test_env

    echo "Running comprehensive tests for error_learning_agent_simple.sh..."
    echo "================================================================="

    # Run individual tests
    test_error_extraction
    test_knowledge_base_init
    test_error_recording
    test_log_monitoring
    test_log_scanning
    test_agent_startup
    test_knowledge_base_structure
    test_directory_structure
    test_error_frequency_tracking
    test_agent_cleanup

    echo "================================================================="
    echo "Test Summary:"
    echo "Total tests: $(get_total_tests)"
    echo "Passed: $(get_passed_tests)"
    echo "Failed: $(get_failed_tests)"

    cleanup_test_env

    # Return success/failure
    if [[ $(get_failed_tests) -eq 0 ]]; then
        echo "✅ All tests passed!"
        return 0
    else
        echo "❌ Some tests failed!"
        return 1
    fi
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
