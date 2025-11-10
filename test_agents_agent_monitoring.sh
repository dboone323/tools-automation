#!/usr/bin/env bash
# Test file for agent_monitoring.sh
# This file validates the structure and key components of the monitoring agent

set -euo pipefail

# Source the shell test framework
source "./shell_test_framework.sh"

AGENT_FILE="agent_monitoring.sh"

echo "Testing agent_monitoring.sh..."

# Test 1: File should be executable
assert_file_executable "$AGENT_FILE" "agent_monitoring.sh should be executable"

# Test 2: Should contain monitoring directory setup
assert_pattern_in_file "MON_DIR=\"\$ROOT_DIR/monitoring\"" "$AGENT_FILE" "Should set monitoring directory"
assert_pattern_in_file "mkdir -p \"\$MON_DIR\"" "$AGENT_FILE" "Should create monitoring directory"

# Test 3: Should contain timestamp and logfile setup
assert_pattern_in_file "TIMESTAMP=\$(date +%Y%m%d_%H%M%S)" "$AGENT_FILE" "Should set timestamp"
assert_pattern_in_file "LOGFILE=\"\$MON_DIR/\${AGENT_NAME}_\$TIMESTAMP\.log\"" "$AGENT_FILE" "Should set logfile path"

# Test 4: Should contain initial logging statements
assert_pattern_in_file "echo \"\[MONITOR\] Starting agent: \$AGENT_NAME\"" "$AGENT_FILE" "Should log agent start"
assert_pattern_in_file "echo \"\[MONITOR\] Timestamp: \$(date -u)" "$AGENT_FILE" "Should log timestamp"
assert_pattern_in_file 'COMMAND\[\*\]' "$AGENT_FILE" "Should log command"

# Test 5: Should contain Ollama health check
assert_pattern_in_file "echo \"\[MONITOR\] Checking Ollama health\.\.\.\"" "$AGENT_FILE" "Should check Ollama health"
assert_pattern_in_file "command -v \./ollama_health\.sh" "$AGENT_FILE" "Should check for health script"
assert_pattern_in_file "jq -e '\.healthy == false'" "$AGENT_FILE" "Should parse health status"

# Test 6: Should contain background process execution
assert_pattern_in_file 'COMMAND.*&' "$AGENT_FILE" "Should run command in background"
assert_pattern_in_file "AGENT_PID=\$!" "$AGENT_FILE" "Should capture agent PID"

# Test 7: Should contain monitoring loop
assert_pattern_in_file "while kill -0 \"\$AGENT_PID\"" "$AGENT_FILE" "Should have monitoring loop"
assert_pattern_in_file "sleep 2" "$AGENT_FILE" "Should sample every 2 seconds"

# Test 8: Should contain PS monitoring
assert_pattern_in_file "echo \"\[PS\]\"" "$AGENT_FILE" "Should log PS section"
assert_pattern_in_file "ps -o pid,ppid,%cpu,%mem,etime,stat,command -p \"\$AGENT_PID\"" "$AGENT_FILE" "Should run ps command"

# Test 9: Should contain TOP monitoring (with macOS fallback)
assert_pattern_in_file "echo \"\[TOP\]\"" "$AGENT_FILE" "Should log TOP section"
assert_pattern_in_file "top -l 1 -pid \"\$AGENT_PID\"" "$AGENT_FILE" "Should run top command"
assert_pattern_in_file "command -v top" "$AGENT_FILE" "Should check for top command"

# Test 10: Should contain LSOF monitoring
assert_pattern_in_file "echo \"\[LSOF\]\"" "$AGENT_FILE" "Should log LSOF section"
assert_pattern_in_file "lsof -p \"\$AGENT_PID\"" "$AGENT_FILE" "Should run lsof command"

# Test 11: Should contain VMSTAT monitoring
assert_pattern_in_file "echo \"\[VMSTAT\]\"" "$AGENT_FILE" "Should log VMSTAT section"
assert_pattern_in_file "vm_stat" "$AGENT_FILE" "Should run vm_stat command"

# Test 12: Should contain periodic Ollama health check
assert_pattern_in_file "echo \"\[OLLAMA_HEALTH\]\"" "$AGENT_FILE" "Should log health check section"
assert_pattern_in_file "date +%s" "$AGENT_FILE" "Should check every 20 seconds"
assert_pattern_in_file "\./ollama_health\.sh >>" "$AGENT_FILE" "Should run health check periodically"

# Test 13: Should contain wait and exit code handling
assert_pattern_in_file "wait \"\$AGENT_PID\"" "$AGENT_FILE" "Should wait for agent completion"
assert_pattern_in_file "AG_EXIT_CODE=\$?" "$AGENT_FILE" "Should capture exit code"
assert_pattern_in_file '\${AG_EXIT_CODE:-\0\}' "$AGENT_FILE" "Should default exit code to 0"

# Test 14: Should contain final logging
assert_pattern_in_file "echo \"\[MONITOR\] Agent finished with exit code: \$AG_EXIT_CODE\"" "$AGENT_FILE" "Should log final exit code"
assert_pattern_in_file "Final snapshot" "$AGENT_FILE" "Should log final snapshot"

# Test 15: Should contain log file location output
assert_pattern_in_file "echo \"\[MONITOR\] Log saved to: \$LOGFILE\"" "$AGENT_FILE" "Should output log file location"

echo "All tests for agent_monitoring.sh completed successfully!"
echo "Passed: $PASSED_TESTS/$TOTAL_TESTS"
