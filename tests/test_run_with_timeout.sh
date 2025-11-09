#!/bin/bash

# Tests for run_with_timeout behavior using small mock scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_codegen.sh"
TEST_FRAMEWORK="${SCRIPT_DIR}/shell_test_framework.sh"

# shellcheck source=shell_test_framework.sh
source "${TEST_FRAMEWORK}"

setup_local_mocks() {
    # long-running script that traps TERM and writes a sentinel
    cat >/tmp/mock_long_sleep_trap.sh <<'EOF'
#!/bin/bash
trap 'echo SIGTERM_RECEIVED >/tmp/run_with_timeout_sig_received; exit 2' TERM
while true; do sleep 1; done
EOF
    chmod +x /tmp/mock_long_sleep_trap.sh

    # quick script that exits immediately
    cat >/tmp/mock_quick_exit.sh <<'EOF'
#!/bin/bash
echo quick
exit 0
EOF
    chmod +x /tmp/mock_quick_exit.sh
}

teardown_local_mocks() {
    rm -f /tmp/mock_long_sleep_trap.sh /tmp/mock_quick_exit.sh /tmp/run_with_timeout_sig_received
}

test_run_with_timeout_times_out_and_signals() {
    setup_test_env
    export DISABLE_PIPE_QUICK_EXIT=1
    setup_local_mocks

    # Prepare minimal workspace/project layout so sourcing the agent doesn't exit
    export WORKSPACE="/tmp/test_workspace"
    export PROJECT_NAME="TestProject"
    export PROJECT_DIR="/tmp/test_project"
    mkdir -p "${PROJECT_DIR}"
    mkdir -p "${WORKSPACE}/Tools/Automation/agents"
    touch "${WORKSPACE}/Tools/Automation/agents/agent_status.json" || true

    # Source agent script to get run_with_timeout
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Ensure function exists
    if ! declare -f run_with_timeout >/dev/null 2>&1; then
        assert_failure "run_with_timeout should be defined after sourcing agent script"
        teardown_local_mocks
        teardown_test_env
        return
    fi

    rm -f /tmp/run_with_timeout_sig_received

    run_with_timeout 1 /tmp/mock_long_sleep_trap.sh
    local rc=$?

    assert_equals "124" "${rc}" "run_with_timeout should return 124 on timeout"

    teardown_local_mocks
    teardown_test_env
}

test_run_with_timeout_allows_quick_exit() {
    setup_test_env
    export DISABLE_PIPE_QUICK_EXIT=1
    setup_local_mocks

    # Prepare minimal workspace/project layout so sourcing the agent doesn't exit
    export WORKSPACE="/tmp/test_workspace"
    export PROJECT_NAME="TestProject"
    export PROJECT_DIR="/tmp/test_project"
    mkdir -p "${PROJECT_DIR}"
    mkdir -p "${WORKSPACE}/Tools/Automation/agents"
    touch "${WORKSPACE}/Tools/Automation/agents/agent_status.json" || true

    # Source agent script to get run_with_timeout
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    if ! declare -f run_with_timeout >/dev/null 2>&1; then
        assert_failure "run_with_timeout should be defined after sourcing agent script"
        teardown_local_mocks
        teardown_test_env
        return
    fi

    run_with_timeout 5 /tmp/mock_quick_exit.sh
    local rc=$?
    assert_equals "0" "${rc}" "run_with_timeout should return 0 when command finishes before timeout"

    teardown_local_mocks
    teardown_test_env
}
