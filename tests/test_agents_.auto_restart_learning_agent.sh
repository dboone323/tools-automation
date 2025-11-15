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

AGENT_NAME="test_agents_.auto_restart_learning_agent.sh"
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
# Auto-generated test for .auto_restart_learning_agent.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKER_FILE="$SCRIPT_DIR/agents/.auto_restart_learning_agent.sh"
AGENT_FILE="$SCRIPT_DIR/agents/learning_agent.sh"

# Source test framework
source "$SCRIPT_DIR/shell_test_framework.sh"

run_tests() {
    announce_test "check_marker__auto_restart_learning_agent"

    assert_file_exists "$MARKER_FILE" "Marker file should exist"
    assert_file_executable "$MARKER_FILE" "Marker file should be executable"

    local content
    content=$(cat "$MARKER_FILE" 2>/dev/null || echo "")
    assert_contains "$content" "exit 0" "Marker file should exit 0"

    assert_file_exists "$AGENT_FILE" "Corresponding agent should exist"
    assert_file_executable "$AGENT_FILE" "Corresponding agent should be executable"

    test_passed "check_marker__auto_restart_learning_agent"
}

if [[ "tests/generate_auto_restart_marker_tests.sh" == "tests/generate_auto_restart_marker_tests.sh" ]]; then
    run_tests
    exit 0
fi
