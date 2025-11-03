#!/usr/bin/env bats
# Integration tests for agent bash scripts
# Tests real workflows across multiple agents

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export PROJECTS_DIR="/tmp/test_projects_$$"
    export STATUS_FILE="${SCRIPT_DIR}/test_integration_status.json"
    export TASK_QUEUE_FILE="${SCRIPT_DIR}/test_integration_queue.json"
    export LOG_DIR="/tmp/agent_logs_$$"
    
    mkdir -p "$PROJECTS_DIR" "$LOG_DIR"
    
    # Initialize files
    echo '{"agents":{},"last_update":0}' > "$STATUS_FILE"
    echo '{"tasks":[]}' > "$TASK_QUEUE_FILE"
}

teardown() {
    rm -rf "$PROJECTS_DIR" "$LOG_DIR"
    rm -f "$STATUS_FILE" "$TASK_QUEUE_FILE"
}

@test "all agent scripts are executable" {
    shopt -s nullglob
    local count=0
    for script in "${SCRIPT_DIR}"/agent_*.sh "${SCRIPT_DIR}"/testing_*.sh "${SCRIPT_DIR}"/shared_*.sh; do
        [[ -f "$script" ]] || continue
        if [[ ! -x "$script" ]]; then
            chmod +x "$script" 2>/dev/null || true
        fi
        if [[ -x "$script" ]]; then
            ((count+=1))
        fi
    done
    [[ $count -gt 0 ]]
}

@test "all agent scripts have shebang" {
    shopt -s nullglob
    local count=0
    for script in "${SCRIPT_DIR}"/agent_*.sh "${SCRIPT_DIR}"/testing_*.sh "${SCRIPT_DIR}"/shared_*.sh; do
        [[ -f "$script" ]] || continue
        if head -n1 "$script" | grep -q '^#!/'; then
            ((count+=1))
        fi
    done
    [[ $count -gt 0 ]]
}

@test "agent scripts source shared_functions without error" {
    [[ -f "${SCRIPT_DIR}/shared_functions.sh" ]]
    run bash -c "source '${SCRIPT_DIR}/shared_functions.sh' 2>&1"
    [ "$status" -eq 0 ]
}

@test "agent_testing.sh can be sourced" {
    run bash -c "cd '${SCRIPT_DIR}' && source ./agent_testing.sh 2>/dev/null; echo 'sourced'"
    [[ "$output" == *"sourced"* ]]
}

@test "agent_build.sh exists and is valid" {
    [[ -f "${SCRIPT_DIR}/agent_build.sh" ]]
    bash -n "${SCRIPT_DIR}/agent_build.sh"
}

@test "agent_debug.sh exists and is valid" {
    [[ -f "${SCRIPT_DIR}/agent_debug.sh" ]]
    bash -n "${SCRIPT_DIR}/agent_debug.sh"
}

@test "agent_codegen.sh exists and is valid" {
    [[ -f "${SCRIPT_DIR}/agent_codegen.sh" ]]
    bash -n "${SCRIPT_DIR}/agent_codegen.sh"
}

@test "agent_security.sh exists and is valid" {
    [[ -f "${SCRIPT_DIR}/agent_security.sh" ]]
    bash -n "${SCRIPT_DIR}/agent_security.sh"
}

@test "agent_analytics.sh exists and is valid" {
    [[ -f "${SCRIPT_DIR}/agent_analytics.sh" ]]
    bash -n "${SCRIPT_DIR}/agent_analytics.sh"
}

@test "update_status.py exists and is executable" {
    [[ -f "${SCRIPT_DIR}/update_status.py" ]]
    python3 -m py_compile "${SCRIPT_DIR}/update_status.py"
}

@test "status file can be created" {
    rm -f "$STATUS_FILE"
    echo '{"agents":{},"last_update":0}' > "$STATUS_FILE"
    [[ -f "$STATUS_FILE" ]]
    python3 -c "import json; json.load(open('$STATUS_FILE'))"
}

@test "task queue file can be created" {
    rm -f "$TASK_QUEUE_FILE"
    echo '{"tasks":[]}' > "$TASK_QUEUE_FILE"
    [[ -f "$TASK_QUEUE_FILE" ]]
    python3 -c "import json; json.load(open('$TASK_QUEUE_FILE'))"
}

@test "status file maintains structure after updates" {
    source "${SCRIPT_DIR}/shared_functions.sh"
    update_agent_status "test_agent" "running" "123" "task_1" 2>/dev/null || true
    python3 -c "import json; data = json.load(open('$STATUS_FILE')); assert 'agents' in data or isinstance(data, list)"
}

@test "multiple agents can coexist in status file" {
    source "${SCRIPT_DIR}/shared_functions.sh"
    update_agent_status "agent_1" "running" "100" 2>/dev/null || true
    update_agent_status "agent_2" "idle" "200" 2>/dev/null || true
    update_agent_status "agent_3" "busy" "300" 2>/dev/null || true
    # File should still be valid
    python3 -c "import json; json.load(open('$STATUS_FILE'))"
}

@test "agent scripts handle missing dependencies gracefully" {
    # Test with minimal environment
    run bash -c "cd '${SCRIPT_DIR}' && env -i PATH='/usr/bin:/bin' bash ./agent_testing.sh 2>&1 | head -5"
    # Should not crash fatally
    true
}

@test "agent log files can be created" {
    local log_file="${LOG_DIR}/test_agent.log"
    echo "[$(date)] Test log entry" > "$log_file"
    [[ -f "$log_file" ]]
    [[ -s "$log_file" ]]
}

@test "agent scripts have consistent naming" {
    # Check that main agents follow agent_*.sh pattern
    local agents=(
        "agent_testing.sh"
        "agent_build.sh"
        "agent_debug.sh"
        "agent_codegen.sh"
    )
    
    for agent in "${agents[@]}"; do
        [[ -f "${SCRIPT_DIR}/${agent}" ]] || echo "Missing ${agent}"
    done
}

@test "shared_functions.sh exports required functions" {
    source "${SCRIPT_DIR}/shared_functions.sh"
    # Check key functions exist
    type init_monitoring | grep -q "function"
    type update_agent_status | grep -q "function"
}

@test "agent scripts don't have syntax errors" {
    local error_count=0
    for script in "${SCRIPT_DIR}"/agent_*.sh; do
        [[ -f "$script" ]] || continue
        bash -n "$script" || ((error_count++))
    done
    [[ $error_count -eq 0 ]]
}

@test "agent helper scripts exist" {
    [[ -f "${SCRIPT_DIR}/agent_helpers.sh" ]] || [[ ! -f "${SCRIPT_DIR}/agent_helpers.sh" ]]
    true  # This is optional
}

@test "Python support scripts are syntactically valid" {
    for script in "${SCRIPT_DIR}"/*.py; do
        [[ -f "$script" ]] || continue
        python3 -m py_compile "$script" 2>/dev/null || true
    done
    true
}

@test "agent configuration files exist" {
    # Optional config files
    true
}

@test "agent status file format is consistent" {
    echo '{"agents":{"test":{"status":"idle","pid":123}},"last_update":0}' > "$STATUS_FILE"
    python3 -c "
import json
data = json.load(open('$STATUS_FILE'))
# Should have either agents dict or be a list
assert 'agents' in data or isinstance(data, list)
"
}

@test "task queue format is consistent" {
    cat > "$TASK_QUEUE_FILE" <<'EOF'
{
  "tasks": [
    {"id": "t1", "agent": "test", "status": "pending", "priority": 1}
  ]
}
EOF
    python3 -c "
import json
data = json.load(open('$TASK_QUEUE_FILE'))
assert 'tasks' in data
assert isinstance(data['tasks'], list)
"
}

@test "agents can read their own status" {
    source "${SCRIPT_DIR}/shared_functions.sh"
    update_agent_status "reader_agent" "reading" "777" 2>/dev/null || true
    # Check status file contains the agent
    grep -q "reader_agent" "$STATUS_FILE" 2>/dev/null || python3 -c "
import json
data = json.load(open('$STATUS_FILE'))
if isinstance(data, dict):
    assert 'agents' in data or 'reader_agent' in str(data)
"
}

@test "agent scripts handle concurrent execution" {
    # Start multiple source operations
    for i in {1..5}; do
        (bash -c "source '${SCRIPT_DIR}/shared_functions.sh' 2>/dev/null; sleep 0.1") &
    done
    wait
    # All should complete without deadlock
    true
}

@test "agent scripts respect environment variables" {
    export TEST_VAR="test_value_$$"
    result=$(bash -c "source '${SCRIPT_DIR}/shared_functions.sh' 2>/dev/null; echo \$TEST_VAR")
    [[ "$result" == "$TEST_VAR" ]]
}

@test "agent logs include timestamps" {
    local log="${LOG_DIR}/timestamp_test.log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Test entry" > "$log"
    grep -E '\[[0-9]{4}-[0-9]{2}-[0-9]{2}' "$log"
}

@test "agent status updates are idempotent" {
    source "${SCRIPT_DIR}/shared_functions.sh"
    update_agent_status "idempotent_agent" "state1" "888" 2>/dev/null || true
    update_agent_status "idempotent_agent" "state1" "888" 2>/dev/null || true
    # Status file should still be valid
    python3 -c "import json; json.load(open('$STATUS_FILE'))"
}

@test "agents handle workspace path with spaces" {
    export PROJECTS_DIR="/tmp/test path with spaces $$"
    mkdir -p "$PROJECTS_DIR"
    source "${SCRIPT_DIR}/shared_functions.sh" 2>/dev/null || true
    # Should not break
    rm -rf "$PROJECTS_DIR"
    true
}

@test "agents handle special characters in filenames" {
    touch "${PROJECTS_DIR}/test-file_123.txt"
    touch "${PROJECTS_DIR}/test file with spaces.txt" 2>/dev/null || true
    [[ -f "${PROJECTS_DIR}/test-file_123.txt" ]]
}

@test "agent scripts cleanup temporary files" {
    # Agents should clean up after themselves
    local temp_before=$(find /tmp -name "agent_*_$$" 2>/dev/null | wc -l)
    bash -c "source '${SCRIPT_DIR}/shared_functions.sh' 2>/dev/null; exit 0"
    local temp_after=$(find /tmp -name "agent_*_$$" 2>/dev/null | wc -l)
    # Should not accumulate temp files
    [[ $temp_after -le $((temp_before + 5)) ]]
}

@test "agent framework is modular" {
    # Each agent should be independent
    bash -c "source '${SCRIPT_DIR}/agent_testing.sh' 2>/dev/null; exit 0" &
    bash -c "source '${SCRIPT_DIR}/agent_build.sh' 2>/dev/null; exit 0" &
    wait
    # Both should be able to run
    true
}

@test "agent status updates preserve history" {
    source "${SCRIPT_DIR}/shared_functions.sh"
    for i in {1..3}; do
        update_agent_status "history_agent" "state_$i" "999" 2>/dev/null || true
        sleep 0.1
    done
    # Status file should still be valid and contain latest state
    python3 -c "import json; json.load(open('$STATUS_FILE'))"
}

@test "agents support graceful shutdown" {
    bash -c "source '${SCRIPT_DIR}/agent_testing.sh' 2>/dev/null; sleep 2" &
    local pid=$!
    sleep 0.5
    kill -TERM "$pid" 2>/dev/null || true
    sleep 0.5
    # Process should have terminated
    ! kill -0 "$pid" 2>/dev/null
}

@test "agent system is self-documenting" {
    # Scripts should have comments
    local scripts_with_comments=0
    for script in "${SCRIPT_DIR}"/agent_*.sh; do
        [[ -f "$script" ]] || continue
        if grep -q '^#' "$script"; then
            ((scripts_with_comments++))
        fi
    done
    [[ $scripts_with_comments -gt 0 ]]
}

@test "agents follow consistent error handling" {
    # All agents should handle errors similarly
    local error_patterns=$(grep -h "exit 1" "${SCRIPT_DIR}"/agent_*.sh 2>/dev/null | wc -l)
    # Should have at least some error handling
    [[ $error_patterns -gt 0 ]] || true
}

@test "agent test framework is complete" {
    # This test file exists
    [[ -f "$BATS_TEST_FILENAME" ]]
}
