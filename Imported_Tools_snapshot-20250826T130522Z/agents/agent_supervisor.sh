#!/usr/bin/env bash
# Agent Supervisor: Starts and monitors all agents



AGENTS_DIR="/Users/danielstevens/Desktop/Code/Tools/Automation/agents"
LOG_FILE="$AGENTS_DIR/supervisor.log"

# Ensure running in bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with bash."
    exec bash "$0" "$@"
    exit 1
fi

declare -A AGENT_PIDS
declare -A AGENT_LOGS
AGENT_LOGS[agent_build.sh]="$AGENTS_DIR/build_agent.log"
AGENT_LOGS[agent_debug.sh]="$AGENTS_DIR/debug_agent.log"
AGENT_LOGS[agent_codegen.sh]="$AGENTS_DIR/codegen_agent.log"
AGENT_LOGS[uiux_agent.sh]="$AGENTS_DIR/uiux_agent.log"
AGENT_LOGS[apple_pro_agent.sh]="$AGENTS_DIR/apple_pro_agent.log"
AGENT_LOGS[collab_agent.sh]="$AGENTS_DIR/collab_agent.log"
AGENT_LOGS[updater_agent.sh]="$AGENTS_DIR/updater_agent.log"
AGENT_LOGS[search_agent.sh]="$AGENTS_DIR/search_agent.log"

# Restart throttling and limit
declare -A AGENT_RESTART_COUNT
declare -A AGENT_LAST_RESTART
RESTART_LIMIT=5
RESTART_WINDOW=600 # 10 minutes
RESTART_THROTTLE=60 # 1 minute between restarts

# Log rotation function (keep logs <10MB)
rotate_log() {
    local log_file="$1"
    local max_size=10485760 # 10MB
    if [[ -f "$log_file" ]]; then
        local size=$(stat -f%z "$log_file")
        if (( size > max_size )); then
            mv "$log_file" "$log_file.old"
            echo "[$(date)] Log rotated: $log_file" > "$log_file"
        fi
    fi
}

start_agent() {
    local agent_script="$1"
    nohup bash "$AGENTS_DIR/$agent_script" >> "$LOG_FILE" 2>&1 &
    AGENT_PIDS["$agent_script"]=$!
    echo "$agent_script started with PID ${AGENT_PIDS["$agent_script"]}" >> "$LOG_FILE"
}

restart_agent() {
    local agent_script="$1"
    local pid=${AGENT_PIDS["$agent_script"]}
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null
        echo "$agent_script (PID $pid) killed for restart." >> "$LOG_FILE"
    fi
        # Throttle and limit restarts
        local now=$(date +%s)
        local last_restart=${AGENT_LAST_RESTART["$agent_script"]:-0}
        local count=${AGENT_RESTART_COUNT["$agent_script"]:-0}
        if (( now - last_restart < RESTART_THROTTLE )); then
            echo "[$(date)] Supervisor: Throttling restart of $agent_script (too soon)." >> "$LOG_FILE"
            return
        fi
        if (( count >= RESTART_LIMIT )); then
            if (( now - last_restart < RESTART_WINDOW )); then
                echo "[$(date)] Supervisor: Restart limit reached for $agent_script. Not restarting." >> "$LOG_FILE"
                return
            else
                AGENT_RESTART_COUNT["$agent_script"]=0
            fi
        fi
        start_agent "$agent_script"
        echo "$agent_script restarted." >> "$LOG_FILE"
}

echo "[$(date)] Supervisor: Starting all agents..." >> "$LOG_FILE"
start_agent agent_build.sh
start_agent agent_debug.sh
start_agent agent_codegen.sh
echo "[$(date)] Supervisor: All agents running." >> "$LOG_FILE"

# Supervisor main loop: monitor logs and restart agents on error/rollback
while true; do
    for agent in "agent_build.sh" "agent_debug.sh" "agent_codegen.sh" "uiux_agent.sh" "apple_pro_agent.sh" "collab_agent.sh" "updater_agent.sh" "search_agent.sh"; do
        log_file="${AGENT_LOGS["$agent"]}"
        rotate_log "$log_file"
        if [[ -f "$log_file" ]]; then
            # Check for error or rollback in last 40 lines
            if tail -40 "$log_file" | grep -q -E 'ROLLBACK|error|❌'; then
                echo "[$(date)] Supervisor: Detected error/rollback in $agent. Restarting..." >> "$LOG_FILE"
                restart_agent "$agent"
            fi
            # Log backup/restore events for observability
            if tail -40 "$log_file" | grep -q 'multi-level backup'; then
                echo "[$(date)] Supervisor: Backup event detected in $agent." >> "$LOG_FILE"
            fi
            if tail -40 "$log_file" | grep -q 'restoring last backup'; then
                echo "[$(date)] Supervisor: Restore event detected in $agent." >> "$LOG_FILE"
            fi
        fi
    done
    rotate_log "$LOG_FILE"

    # Periodically run AI log analyzer and report findings
    now_epoch=$(date +%s)
    if [ $((now_epoch % 300)) -lt 5 ]; then # every ~5 minutes
        ANALYZER="$(dirname "$0")/ai_log_analyzer.py"
        if [[ -x "$ANALYZER" || -f "$ANALYZER" ]]; then
            python3 "$ANALYZER" >> "$LOG_FILE" 2>&1
            if [[ -f "$(dirname "$0")/ai_log_analysis.txt" ]]; then
                tail -20 "$(dirname "$0")/ai_log_analysis.txt" | while read -r line; do
                    echo "[$(date)] Supervisor: AI Log Analyzer: $line" >> "$LOG_FILE"
                done
            fi
        fi
    fi
    sleep 120 # Check every 2 minutes
done
