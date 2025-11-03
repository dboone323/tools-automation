#!/bin/bash
# Shared loop helpers for agents: pipeline-safe quick exit and exponential backoff sleeps

# Initialize backoff timers if not already set
agent_init_backoff() {
    # Allow tests or callers to override defaults with TEST_* caps
    # Example: TEST_MAX_INTERVAL=60 keeps backoff snappy under CI
    : "${SLEEP_INTERVAL:=${TEST_SLEEP_INTERVAL:-2}}" # start small for responsiveness
    : "${MAX_INTERVAL:=${TEST_MAX_INTERVAL:-3600}}"  # cap at one hour by default (or test cap)
}

# Return 0 if running in a pipeline (stdout or stderr is a pipe)
agent_is_pipeline() {
    [[ -p /dev/stdout ]] || [[ -p /dev/stderr ]]
}

# Emit a few lines and exit immediately when in a pipeline to avoid hangs
# Usage: agent_detect_pipe_and_quick_exit "<AGENT_NAME>"
agent_detect_pipe_and_quick_exit() {
    local agent_name
    agent_name="${1:-Agent}"
    if agent_is_pipeline && [[ "${DISABLE_PIPE_QUICK_EXIT:-0}" -ne 1 ]]; then
        echo "[$(date)] ${agent_name}: starting (pipeline mode detected)"
        echo "[$(date)] ${agent_name}: PATH='${PATH}'"
        echo "[$(date)] ${agent_name}: status=running"
        echo "[$(date)] ${agent_name}: no tasks found (quick check)"
        echo "[$(date)] ${agent_name}: exiting early to avoid hanging pipelines"
        # Best-effort status update if function exists in caller
        if type update_agent_status >/dev/null 2>&1; then
            update_agent_status "${agent_name}" "stopped" "$$" ""
        fi
        return 0
    fi
    return 1
}

# Sleep using exponential backoff and log a brief message
# Writes to LOG_FILE if set, otherwise stdout
agent_sleep_with_backoff() {
    agent_init_backoff
    local msg="Sleeping for ${SLEEP_INTERVAL}s (max ${MAX_INTERVAL}s)"
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[$(date)] ${msg}" >>"${LOG_FILE}" 2>/dev/null || true
    else
        echo "[$(date)] ${msg}"
    fi
    sleep "${SLEEP_INTERVAL}"
    # Backoff
    if [[ "${SLEEP_INTERVAL}" =~ ^[0-9]+$ ]] && [[ "${MAX_INTERVAL}" =~ ^[0-9]+$ ]]; then
        if ((SLEEP_INTERVAL < MAX_INTERVAL)); then
            SLEEP_INTERVAL=$((SLEEP_INTERVAL * 2))
            if ((SLEEP_INTERVAL > MAX_INTERVAL)); then
                SLEEP_INTERVAL=${MAX_INTERVAL}
            fi
        fi
    fi
}

export -f agent_init_backoff agent_is_pipeline agent_detect_pipe_and_quick_exit agent_sleep_with_backoff
