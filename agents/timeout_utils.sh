#!/bin/bash
# Cross-platform timeout helper for agents and tests
# Preference: gtimeout (coreutils) > timeout > python fallback > bash loop

timeout_cmd() {
    local seconds="$1"
    shift

    # Edge cases
    if [[ -z "$seconds" || ! "$seconds" =~ ^-?[0-9]+$ ]]; then
        # Invalid timeout value: just run the command
        "$@"
        return $?
    fi
    if (( seconds <= 0 )); then
        "$@"
        return $?
    fi

    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$seconds" "$@"
        return $?
    fi
    if command -v timeout >/dev/null 2>&1; then
        timeout "$seconds" "$@"
        return $?
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$seconds" -- "$@" <<'PY'
import os, sys, shlex, subprocess, signal

def main():
    secs = int(sys.argv[1])
    # everything after -- is our command
    # find the separator index
    try:
        sep = sys.argv.index('--')
    except ValueError:
        sep = 2
    cmd = sys.argv[sep+1:]
    if not cmd:
        return 0
    # Run as a child process group so we can kill descendants
    proc = subprocess.Popen(cmd, preexec_fn=os.setsid)
    try:
        proc.wait(timeout=secs)
        return proc.returncode
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except Exception:
            pass
        return 124

if __name__ == '__main__':
    rc = main()
    sys.exit(rc)
PY
        return $?
    fi

    # Bash fallback
    ( 
        "$@" &
        local cmd_pid=$!
        local count=0
        while (( count < seconds )) && kill -0 "$cmd_pid" 2>/dev/null; do
            sleep 1
            ((count++))
        done
        if kill -0 "$cmd_pid" 2>/dev/null; then
            kill -TERM "$cmd_pid" 2>/dev/null || true
            sleep 1
            kill -KILL "$cmd_pid" 2>/dev/null || true
            exit 124
        fi
        wait "$cmd_pid"
    )
    return $?
}

export -f timeout_cmd
