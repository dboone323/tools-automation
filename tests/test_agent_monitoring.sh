#!/bin/bash

# Test suite for agent_monitoring.sh
# Comprehensive tests covering all functionality

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shell_test_framework.sh"

# Override PROJECT_ROOT for this test
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$PROJECT_ROOT/agents"

AGENT_MONITORING_SCRIPT="$PROJECT_ROOT/agent_monitoring.sh"

# Test: Basic agent monitoring functionality
test_agent_monitoring_basic() {
    echo "Testing basic agent monitoring functionality..."

    # Run agent monitoring with a simple command
    "$AGENT_MONITORING_SCRIPT" "test_agent" "echo" "Hello World"

    assert_success "Basic agent monitoring execution"

    # Find the log file created by the agent (it's created one level up)
    local log_file
    log_file=$(find "$PROJECT_ROOT/../monitoring" -name "test_agent_*.log" -type f | xargs ls -t | head -1)

    assert_file_exists "$log_file" "Log file should be created"
    assert_file_contains "$log_file" "Starting agent: test_agent" "Log should contain agent start message"
    assert_file_contains "$log_file" "Agent finished with exit code: 0" "Log should contain successful completion"
}

# Test: Agent monitoring with failing command
test_agent_monitoring_failure() {
    echo "Testing agent monitoring with failing command..."

    # Run agent monitoring with a command that fails
    "$AGENT_MONITORING_SCRIPT" "test_agent_fail" "false"

    local exit_code=$?
    assert_equals 1 "$exit_code" "Should exit with code 1 when command fails"

    # Find the log file
    local log_file
    log_file=$(find "$PROJECT_ROOT/../monitoring" -name "test_agent_fail_*.log" -type f | xargs ls -t | head -1)

    assert_file_exists "$log_file" "Log file should be created for failed command"
    assert_file_contains "$log_file" "Agent finished with exit code: 1" "Log should contain failure exit code"
}

# Test: Ollama health check integration
test_agent_monitoring_ollama_health() {
    echo "Testing Ollama health check integration..."

    # Create a mock ollama_health.sh in the project root
    cat >"$PROJECT_ROOT/ollama_health.sh" <<'EOF'
#!/bin/bash
echo '{"healthy": true, "mem_free_mb": 8192}'
EOF
    chmod +x "$PROJECT_ROOT/ollama_health.sh"

    # Run agent monitoring
    "$AGENT_MONITORING_SCRIPT" "test_agent_health" "echo" "test"

    assert_success "Agent monitoring with healthy Ollama"

    # Find the log file
    local log_file
    log_file=$(find "$PROJECT_ROOT/../monitoring" -name "test_agent_health_*.log" -type f | xargs ls -t | head -1)

    assert_file_contains "$log_file" "Ollama Health:" "Should log Ollama health status"
    assert_file_contains "$log_file" '"healthy": true' "Should log healthy status"

    # Clean up mock
    rm -f "$PROJECT_ROOT/ollama_health.sh"
}

# Test: Circuit breaker when Ollama is unhealthy
test_agent_monitoring_ollama_unhealthy() {
    echo "Testing circuit breaker for unhealthy Ollama..."

    # Create a mock ollama_health.sh in the project root
    cat >"$PROJECT_ROOT/ollama_health.sh" <<'EOF'
#!/bin/bash
echo '{"healthy": false, "issues": ["Low memory", "High CPU"], "mem_free_mb": 512}'
EOF
    chmod +x "$PROJECT_ROOT/ollama_health.sh"

    # Run agent monitoring - should abort
    "$AGENT_MONITORING_SCRIPT" "test_agent_unhealthy" "echo" "test"

    local exit_code=$?
    assert_equals 1 "$exit_code" "Should exit with code 1 when Ollama is unhealthy"

    # Find the log file
    local log_file
    log_file=$(find "$PROJECT_ROOT/../monitoring" -name "test_agent_unhealthy_*.log" -type f | xargs ls -t | head -1)

    assert_file_contains "$log_file" "Ollama health check failed - aborting agent execution" "Should abort on unhealthy Ollama"
    assert_file_contains "$log_file" "Low memory" "Should log health issues"

    # Clean up mock
    rm -f "$PROJECT_ROOT/ollama_health.sh"
}

# Test: Missing ollama_health.sh script
test_agent_monitoring_missing_health_script() {
    echo "Testing behavior when ollama_health.sh is missing..."

    # Ensure ollama_health.sh doesn't exist
    rm -f "$PROJECT_ROOT/ollama_health.sh"

    # Run agent monitoring
    "$AGENT_MONITORING_SCRIPT" "test_agent_no_health" "echo" "test"

    assert_success "Agent monitoring without health script"

    # Find the log file
    local log_file
    log_file=$(find "$PROJECT_ROOT/../monitoring" -name "test_agent_no_health_*.log" -type f | xargs ls -t | head -1)

    assert_file_contains "$log_file" "ollama_health.sh not found - skipping health check" "Should warn about missing health script"
}

# Test: Process monitoring and logging
test_agent_monitoring_process_info() {
    echo "Testing process monitoring and logging..."

    # Mock system commands
    mock_command "ps" "PID PPID %CPU %MEM ELAPSED STAT COMMAND
12345 1 5.0 2.1 00:00:05 S+ sleep"
    mock_command "top" "PID COMMAND %CPU %MEM
12345 sleep 5.0 2.1"
    mock_command "lsof" "COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
sleep 12345 user 0r CHR 1,3 0t0 6 /dev/null"
    mock_command "vm_stat" "Mach Virtual Memory Statistics: (page size of 4096 bytes)
Pages free: 100000"

    # Run agent monitoring with a command that runs long enough to be monitored
    "$AGENT_MONITORING_SCRIPT" "test_agent_monitor" "sleep" "3"

    assert_success "Process monitoring execution"

    # Find the log file
    local log_file
    log_file=$(find "$PROJECT_ROOT/../monitoring" -name "test_agent_monitor_*.log" -type f | xargs ls -t | head -1)

    assert_file_contains "$log_file" "[PS]" "Should log PS information"
    assert_file_contains "$log_file" "[TOP]" "Should log TOP information"
    assert_file_contains "$log_file" "[LSOF]" "Should log LSOF information"
    assert_file_contains "$log_file" "[VMSTAT]" "Should log VMSTAT information"
}

# Test: Log file creation and naming
test_agent_monitoring_log_files() {
    echo "Testing log file creation and naming..."

    # Run agent monitoring
    "$AGENT_MONITORING_SCRIPT" "test_agent_logs" "echo" "log test"

    assert_success "Log file creation"

    # Find the actual log file
    local log_file
    log_file=$(find "$PROJECT_ROOT/../monitoring" -name "test_agent_logs_*.log" -type f | xargs ls -t | head -1)

    assert_file_exists "$log_file" "Log file should exist"

    # Check log file naming pattern (should contain agent name and timestamp)
    local log_basename
    log_basename=$(basename "$log_file")
    if [[ $log_basename =~ ^test_agent_logs_[0-9]{8}_[0-9]{6}\.log$ ]]; then
        assert_success "Log file naming pattern is correct"
    else
        assert_failure "Log file naming pattern is incorrect: $log_basename"
    fi
}

# Test: Command line argument handling
test_agent_monitoring_arguments() {
    echo "Testing command line argument handling..."

    # Test with multiple arguments
    "$AGENT_MONITORING_SCRIPT" "test_agent_args" "echo" "arg1" "arg2" "arg3"

    assert_success "Multi-argument command execution"

    # Find the log file
    local log_file
    log_file=$(find "$PROJECT_ROOT/../monitoring" -name "test_agent_args_*.log" -type f | xargs ls -t | head -1)

    assert_file_contains "$log_file" "Command: echo arg1 arg2 arg3" "Should log full command with arguments"
}

# Test: Directory creation
test_agent_monitoring_directories() {
    echo "Testing monitoring directory creation..."

    local monitor_dir="$PROJECT_ROOT/monitoring"

    # Clean up any existing monitoring directory
    rm -rf "$monitor_dir"

    # Run agent monitoring
    "$AGENT_MONITORING_SCRIPT" "test_agent_dirs" "echo" "test"

    assert_success "Directory creation test"
    [[ -d "$PROJECT_ROOT/../monitoring" ]]
    assert_success "Monitoring directory should be created"
}

# Test: Background process monitoring
test_agent_monitoring_background_process() {
    echo "Testing background process monitoring..."

    # Create a script that runs in background briefly
    local bg_script="/tmp/test_bg.sh"
    cat >"$bg_script" <<'EOF'
#!/bin/bash
sleep 1
echo "Background process completed"
EOF
    chmod +x "$bg_script"

    # Run agent monitoring with background script
    "$AGENT_MONITORING_SCRIPT" "test_agent_bg" "bash" "$bg_script"

    assert_success "Background process monitoring"

    # Find the log file
    local log_file
    log_file=$(find "$PROJECT_ROOT/../monitoring" -name "test_agent_bg_*.log" -type f | xargs ls -t | head -1)

    assert_file_exists "$log_file" "Log file should be created for background process"
}

# Test: Error handling and logging
test_agent_monitoring_error_handling() {
    echo "Testing error handling and logging..."

    # Run with a command that produces stderr
    "$AGENT_MONITORING_SCRIPT" "test_agent_error" "sh" "-c" "echo 'stdout output'; echo 'stderr output' >&2; exit 42"

    local exit_code=$?
    assert_equals 42 "$exit_code" "Should preserve command exit code"

    # Find the log file
    local log_file
    log_file=$(find "$PROJECT_ROOT/../monitoring" -name "test_agent_error_*.log" -type f | xargs ls -t | head -1)

    assert_file_contains "$log_file" "Agent finished with exit code: 42" "Should log correct exit code"
}
