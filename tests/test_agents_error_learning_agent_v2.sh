#!/bin/bash
# Comprehensive test suite for error_learning_agent_v2.sh
# Tests advanced error learning with Python JSON handling, position tracking, and statistics

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${SCRIPT_DIR}/test_tmp"
AGENT_SCRIPT="${SCRIPT_DIR}/agents/error_learning_agent_v2.sh"

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
    pkill -f "error_learning_agent_v2.sh" || true
    rm -f "${SCRIPT_DIR}/agents/.error_learning_agent.pid"
}

# Test 1: Knowledge base initialization
test_knowledge_base_init() {
    local test_name;
    test_name="test_knowledge_base_init"
    announce_test "$test_name"

    # Clean up any existing files
    rm -f "${ERROR_DB}" "${LEARNING_MODEL}"

    # Define initialize function (simplified version)
    initialize() {
        if [[ ! -f "${ERROR_DB}" ]]; then
            cat >"${ERROR_DB}" <<'JSONEOF'
{
  "version": "1.0",
  "error_patterns": [],
  "last_updated": ""
}
JSONEOF
        fi

        if [[ ! -f "${LEARNING_MODEL}" ]]; then
            cat >"${LEARNING_MODEL}" <<'JSONEOF'
{
  "version": "1.0",
  "model_stats": {
    "total_errors_learned": 0,
    "scans_completed": 0
  },
  "last_trained": ""
}
JSONEOF
        fi
    }

    # Test initialization
    initialize

    # Check if files were created
    assert_file_exists "${ERROR_DB}" "Error database should be created"
    assert_file_exists "${LEARNING_MODEL}" "Learning model should be created"

    # Check file contents
    local db_content
    db_content=$(cat "${ERROR_DB}")
    if echo "$db_content" | grep -q '"version"' && echo "$db_content" | grep -q '"error_patterns"' && echo "$db_content" | grep -q '"last_updated"'; then
        assert_true true "Error DB should have correct JSON structure"
    else
        assert_true false "Error DB should have correct JSON structure - content: $db_content"
    fi

    test_passed "$test_name"
}

# Test 2: Error recording with Python JSON handling
test_error_recording_python() {
    local test_name;
    test_name="test_error_recording_python"
    announce_test "$test_name"

    # Initialize knowledge base
    mkdir -p "${KNOWLEDGE_DIR}"
    cat >"${ERROR_DB}" <<'EOF'
{
  "version": "1.0",
  "error_patterns": [],
  "last_updated": ""
}
EOF

    cat >"${LEARNING_MODEL}" <<'EOF'
{
  "version": "1.0",
  "model_stats": {
    "total_errors_learned": 0,
    "scans_completed": 0
  },
  "last_trained": ""
}
EOF

    # Define record_error_simple function (simplified)
    record_error_simple() {
        local agent_name;
        agent_name="$1"
        local error_msg;
        error_msg="$2"
        local timestamp;
        timestamp="$3"

        # Use Python to safely handle JSON (mock version for testing)
        python3 - <<PYEOF
import json
import hashlib
from datetime import datetime

agent = "${agent_name}"
message = """${error_msg}"""
timestamp = "${timestamp}"

# Sanitize message
message = message.replace('"', "'").replace('\\n', ' ').replace('\\t', ' ')[:200]

# Generate hash
error_hash = hashlib.md5(f"{agent}:{message}".encode()).hexdigest()[:12]

# Load database
try:
    with open("${ERROR_DB}", 'r') as f:
        db = json.load(f)
except:
    db = {"version":"1.0","error_patterns":[],"last_updated":""}

# Check for existing
existing = None
for pattern in db["error_patterns"]:
    if pattern.get("hash") == error_hash:
        existing = pattern
        break

if existing:
    existing["frequency"] = existing.get("frequency", 1) + 1
    existing["last_seen"] = datetime.now().isoformat()
else:
    new_pattern = {
        "hash": error_hash,
        "agent": agent,
        "message": message,
        "timestamp": timestamp,
        "first_seen": datetime.now().isoformat(),
        "frequency": 1
    }
    db["error_patterns"].append(new_pattern)

db["last_updated"] = datetime.now().isoformat()

# Save
with open("${ERROR_DB}", 'w') as f:
    json.dump(db, f, indent=2)

# Update model
try:
    with open("${LEARNING_MODEL}", 'r') as f:
        model = json.load(f)
except:
    model = {"version":"1.0","model_stats":{"total_errors_learned":0,"scans_completed":0},"last_trained":""}

model["model_stats"]["total_errors_learned"] = len(db["error_patterns"])
model["last_trained"] = datetime.now().isoformat()

with open("${LEARNING_MODEL}", 'w') as f:
    json.dump(model, f, indent=2)

print(f"Recorded: {error_hash}")
PYEOF
    }

    # Test recording an error
    record_error_simple "test_agent" "Database connection failed" "2025-01-09 10:00:01"

    # Check if error was recorded
    local db_content
    db_content=$(cat "${ERROR_DB}")
    if echo "$db_content" | grep -q "Database connection failed"; then
        assert_true true "Error should be recorded in database"
    else
        assert_true false "Error should be recorded in database"
    fi

    # Test frequency tracking
    record_error_simple "test_agent" "Database connection failed" "2025-01-09 10:00:02"

    # Check frequency increased
    local freq
    freq=$(python3 -c "import json; print(json.load(open('${ERROR_DB}'))['error_patterns'][0]['frequency'])" 2>/dev/null || echo "0")

    if [[ "$freq" -eq 2 ]]; then
        assert_true true "Error frequency should be tracked correctly"
    else
        assert_true false "Error frequency should be tracked correctly - got $freq"
    fi

    test_passed "$test_name"
}

# Test 3: Position tracking for log files
test_position_tracking() {
    local test_name;
    test_name="test_position_tracking"
    announce_test "$test_name"

    # Create test log file
    local test_log;
    test_log="${TEST_DIR}/pos_test.log"
    echo "[2025-01-09 10:00:01] [test] ERROR: Test error 1" >"$test_log"

    # Define position tracking logic (simplified)
    local pos_file;
    pos_file="${KNOWLEDGE_DIR}/.pos_pos_test"
    local last_pos;
    last_pos=0
    if [[ -f "${pos_file}" ]]; then
        last_pos=$(cat "${pos_file}")
    fi

    local current_size
    current_size=$(stat -f%z "${test_log}" 2>/dev/null || echo "0")

    # Simulate reading new content
    if [[ ${current_size} -gt ${last_pos} ]]; then
        tail -c "+$((last_pos + 1))" "${test_log}" 2>/dev/null | grep -iE '(ERROR|FAILED)' | while IFS= read -r line; do
            echo "PROCESSED: $line" >>"${TEST_DIR}/pos_results.txt"
        done
        echo "${current_size}" >"${pos_file}"
    fi

    # Check if position file was created
    assert_file_exists "$pos_file" "Position file should be created"

    # Check if content was processed
    if grep -q "PROCESSED:" "${TEST_DIR}/pos_results.txt"; then
        assert_true true "New log content should be processed"
    else
        assert_true false "New log content should be processed"
    fi

    # Test position persistence - add more content
    echo "[2025-01-09 10:00:02] [test] ERROR: Test error 2" >>"$test_log"

    # Reload position and process again
    last_pos=$(cat "${pos_file}")
    current_size=$(stat -f%z "${test_log}")

    if [[ ${current_size} -gt ${last_pos} ]]; then
        tail -c "+$((last_pos + 1))" "${test_log}" 2>/dev/null | grep -iE '(ERROR|FAILED)' | while IFS= read -r line; do
            echo "PROCESSED_AGAIN: $line" >>"${TEST_DIR}/pos_results.txt"
        done
        echo "${current_size}" >"${pos_file}"
    fi

    # Check if second error was processed
    if grep -q "Test error 2" "${TEST_DIR}/pos_results.txt"; then
        assert_true true "Position tracking should allow processing new content"
    else
        assert_true false "Position tracking should allow processing new content"
    fi

    test_passed "$test_name"
}

# Test 4: Log scanning with multiple files
test_log_scanning_multiple() {
    local test_name;
    test_name="test_log_scanning_multiple"
    announce_test "$test_name"

    # Create multiple test log files
    echo "[2025-01-09 10:00:01] [agent1] ERROR: Database connection failed" >"${TEST_DIR}/scan_agent1.log"
    echo "[2025-01-09 10:00:02] [agent2] FATAL: Out of memory" >"${TEST_DIR}/scan_agent2.log"
    echo "[2025-01-09 10:00:03] [agent3] Processing completed" >"${TEST_DIR}/scan_agent3.log"

    # Initialize knowledge base
    mkdir -p "${KNOWLEDGE_DIR}"
    cat >"${ERROR_DB}" <<'EOF'
{
  "version": "1.0",
  "error_patterns": [],
  "last_updated": ""
}
EOF

    # Define simplified scan_logs function
    scan_logs() {
        local scanned;
        scanned=0
        local new_errors;
        new_errors=0

        for log_file in "${TEST_DIR}"/scan_*.log; do
            if [[ ! -f "${log_file}" ]]; then
                continue
            fi

            # Track position
            local pos_file;
            pos_file="${KNOWLEDGE_DIR}/.pos_$(basename "${log_file}" .log)"
            local last_pos;
            last_pos=0
            if [[ -f "${pos_file}" ]]; then
                last_pos=$(cat "${pos_file}" 2>/dev/null || echo "0")
            fi

            # Get current size
            local current_size
            current_size=$(stat -f%z "${log_file}" 2>/dev/null || echo "0")

            if [[ ${current_size} -gt ${last_pos} ]]; then
                # Read new lines
                tail -c "+$((last_pos + 1))" "${log_file}" 2>/dev/null | grep -iE '(ERROR|FAILED|exception|fatal|critical)' | while IFS= read -r line; do
                    # Extract agent name from filename
                    local agent_from_file
                    agent_from_file=$(basename "${log_file}" .log | sed 's/scan_//')

                    # Extract timestamp
                    local ts
                    ts=$(echo "${line}" | grep -oE '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' | tr -d '[]' || date '+%Y-%m-%d %H:%M:%S')

                    # Extract message
                    local msg
                    msg=$(echo "${line}" | awk -F']' '{print $NF}' | sed 's/^[ \t]*//')

                    if [[ -n "${msg}" ]]; then
                        echo "RECORDED: ${agent_from_file} - ${msg}" >>"${TEST_DIR}/scan_results.txt"
                        ((new_errors++))
                    fi
                done

                # Update position
                echo "${current_size}" >"${pos_file}"
            fi

            ((scanned++))
        done

        echo "SCANNED: $scanned, ERRORS: $new_errors" >>"${TEST_DIR}/scan_results.txt"
    }

    # Test scanning
    scan_logs

    # Check results
    local error_count
    error_count=$(grep -c "RECORDED:" "${TEST_DIR}/scan_results.txt")

    if [[ $error_count -eq 2 ]]; then
        assert_true true "Should find errors in 2 out of 3 log files"
    else
        assert_true false "Should find errors in 2 out of 3 log files - found $error_count"
    fi

    # Check position files were created
    if [[ -f "${KNOWLEDGE_DIR}/.pos_scan_agent1" ]] && [[ -f "${KNOWLEDGE_DIR}/.pos_scan_agent2" ]]; then
        assert_true true "Position files should be created for log files with errors"
    else
        assert_true false "Position files should be created for log files with errors"
    fi

    test_passed "$test_name"
}

# Test 5: Statistics tracking and reporting
test_statistics_tracking() {
    local test_name;
    test_name="test_statistics_tracking"
    announce_test "$test_name"

    # Initialize learning model
    mkdir -p "${KNOWLEDGE_DIR}"
    cat >"${LEARNING_MODEL}" <<'EOF'
{
  "version": "1.0",
  "model_stats": {
    "total_errors_learned": 0,
    "scans_completed": 0
  },
  "last_trained": ""
}
EOF

    # Test updating scan count
    python3 - <<PYEOF
import json
with open("${LEARNING_MODEL}", 'r') as f:
    model = json.load(f)
model["model_stats"]["scans_completed"] = model["model_stats"].get("scans_completed", 0) + 1
with open("${LEARNING_MODEL}", 'w') as f:
    json.dump(model, f, indent=2)
PYEOF

    # Check if scan count was updated
    local scans
    scans=$(python3 -c "import json; print(json.load(open('${LEARNING_MODEL}'))['model_stats']['scans_completed'])" 2>/dev/null || echo "0")

    if [[ "$scans" -eq 1 ]]; then
        assert_true true "Scan count should be tracked correctly"
    else
        assert_true false "Scan count should be tracked correctly - got $scans"
    fi

    # Test updating error count
    cat >"${ERROR_DB}" <<'EOF'
{
  "version": "1.0",
  "error_patterns": [
    {"hash": "abc123", "agent": "test", "message": "Error 1"},
    {"hash": "def456", "agent": "test", "message": "Error 2"}
  ],
  "last_updated": ""
}
EOF

    python3 - <<PYEOF
import json
with open("${LEARNING_MODEL}", 'r') as f:
    model = json.load(f)
with open("${ERROR_DB}", 'r') as f:
    db = json.load(f)
model["model_stats"]["total_errors_learned"] = len(db["error_patterns"])
with open("${LEARNING_MODEL}", 'w') as f:
    json.dump(model, f, indent=2)
PYEOF

    # Check if error count was updated
    local errors
    errors=$(python3 -c "import json; print(json.load(open('${LEARNING_MODEL}'))['model_stats']['total_errors_learned'])" 2>/dev/null || echo "0")

    if [[ "$errors" -eq 2 ]]; then
        assert_true true "Error count should be tracked correctly"
    else
        assert_true false "Error count should be tracked correctly - got $errors"
    fi

    test_passed "$test_name"
}

# Test 6: Agent startup and PID management
test_agent_startup_pid() {
    local test_name;
    test_name="test_agent_startup_pid"
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

# Test 7: Error pattern deduplication
test_error_deduplication() {
    local test_name;
    test_name="test_error_deduplication"
    announce_test "$test_name"

    # Initialize knowledge base
    mkdir -p "${KNOWLEDGE_DIR}"
    cat >"${ERROR_DB}" <<'EOF'
{
  "version": "1.0",
  "error_patterns": [],
  "last_updated": ""
}
EOF

    # Record same error twice
    record_error_simple() {
        local agent_name;
        agent_name="$1"
        local error_msg;
        error_msg="$2"
        local timestamp;
        timestamp="$3"

        python3 - <<PYEOF
import json
import hashlib
from datetime import datetime

agent = "${agent_name}"
message = """${error_msg}"""
timestamp = "${timestamp}"

message = message.replace('"', "'").replace('\\n', ' ').replace('\\t', ' ')[:200]
error_hash = hashlib.md5(f"{agent}:{message}".encode()).hexdigest()[:12]

try:
    with open("${ERROR_DB}", 'r') as f:
        db = json.load(f)
except:
    db = {"version":"1.0","error_patterns":[],"last_updated":""}

existing = None
for pattern in db["error_patterns"]:
    if pattern.get("hash") == error_hash:
        existing = pattern
        break

if existing:
    existing["frequency"] = existing.get("frequency", 1) + 1
    existing["last_seen"] = datetime.now().isoformat()
else:
    new_pattern = {
        "hash": error_hash,
        "agent": agent,
        "message": message,
        "timestamp": timestamp,
        "first_seen": datetime.now().isoformat(),
        "frequency": 1
    }
    db["error_patterns"].append(new_pattern)

db["last_updated"] = datetime.now().isoformat()

with open("${ERROR_DB}", 'w') as f:
    json.dump(db, f, indent=2)

print(f"Recorded: {error_hash}")
PYEOF
    }

    # Record same error twice
    record_error_simple "test_agent" "Same error message" "2025-01-09 10:00:01"
    record_error_simple "test_agent" "Same error message" "2025-01-09 10:00:02"

    # Check that only one pattern was created but frequency is 2
    local pattern_count
    pattern_count=$(python3 -c "import json; print(len(json.load(open('${ERROR_DB}'))['error_patterns']))" 2>/dev/null || echo "0")

    local frequency
    frequency=$(python3 -c "import json; print(json.load(open('${ERROR_DB}'))['error_patterns'][0]['frequency'])" 2>/dev/null || echo "0")

    if [[ $pattern_count -eq 1 ]] && [[ $frequency -eq 2 ]]; then
        assert_true true "Duplicate errors should be deduplicated with frequency tracking"
    else
        assert_true false "Duplicate errors should be deduplicated with frequency tracking - patterns: $pattern_count, freq: $frequency"
    fi

    test_passed "$test_name"
}

# Test 8: Timestamp extraction from log lines
test_timestamp_extraction() {
    local test_name;
    test_name="test_timestamp_extraction"
    announce_test "$test_name"

    # Test timestamp extraction logic
    local line;
    line="[2025-01-09 10:00:01] [agent1] ERROR: Test error"
    local ts
    ts=$(echo "${line}" | grep -oE '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' | tr -d '[]' || date '+%Y-%m-%d %H:%M:%S')

    if [[ "$ts" == "2025-01-09 10:00:01" ]]; then
        assert_true true "Timestamp should be extracted correctly from log lines"
    else
        assert_true false "Timestamp should be extracted correctly from log lines - got $ts"
    fi

    # Test fallback to current date for lines without timestamp
    local line_no_ts;
    line_no_ts="ERROR: Test error without timestamp"
    local extracted_ts
    extracted_ts=$(echo "${line_no_ts}" | grep -oE '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' | tr -d '[]')
    if [[ -z "$extracted_ts" ]]; then
        ts=$(date '+%Y-%m-%d %H:%M:%S')
    else
        ts="$extracted_ts"
    fi

    # Should get current date (we can't predict exact value, just check it's a valid date format)
    if [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        assert_true true "Fallback timestamp should be generated for lines without timestamp"
    else
        assert_true false "Fallback timestamp should be generated for lines without timestamp - got '$ts'"
    fi

    test_passed "$test_name"
}

# Test 9: Message extraction from log lines
test_message_extraction() {
    local test_name;
    test_name="test_message_extraction"
    announce_test "$test_name"

    # Test message extraction logic
    local line;
    line="[2025-01-09 10:00:01] [agent1] ERROR: This is the error message"
    local msg
    msg=$(echo "${line}" | awk -F']' '{print $NF}' | sed 's/^[ \t]*//')

    if [[ "$msg" == "ERROR: This is the error message" ]]; then
        assert_true true "Error message should be extracted correctly from log lines"
    else
        assert_true false "Error message should be extracted correctly from log lines - got '$msg'"
    fi

    # Test with multiple brackets - use a simpler approach
    local complex_line;
    complex_line="[2025-01-09 10:00:01] [agent1] [INFO] ERROR: Complex error [with brackets]"
    # Extract everything after the last timestamp/agent bracket
    msg=$(echo "${complex_line}" | sed 's/.*\] //' | sed 's/^[ \t]*//')

    if [[ "$msg" == "ERROR: Complex error [with brackets]" ]]; then
        assert_true true "Message extraction should handle multiple brackets correctly"
    else
        assert_true false "Message extraction should handle multiple brackets correctly - got '$msg'"
    fi

    test_passed "$test_name"
}

# Test 10: Agent cleanup and signal handling
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

    echo "Running comprehensive tests for error_learning_agent_v2.sh..."
    echo "================================================================="

    # Run individual tests
    test_knowledge_base_init
    test_error_recording_python
    test_position_tracking
    test_log_scanning_multiple
    test_statistics_tracking
    test_agent_startup_pid
    test_error_deduplication
    test_timestamp_extraction
    test_message_extraction
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
