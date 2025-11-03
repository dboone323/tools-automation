#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./shared_functions.sh
source "${SCRIPT_DIR}/shared_functions.sh"
# Agent Persistence Status Check Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/persistence_status.log"

{
    echo "=== Agent Persistence Status Report ==="
    echo "Timestamp: $(date)"
    echo ""
    echo "1. Launch Daemon Status:"
    launchctl list | grep quantum 2>&1 || echo "No quantum launch daemons found"
    echo ""
} >>"$LOG_FILE"

# Check auto-restart monitor process
echo "2. Auto-Restart Monitor Process:" >>"$LOG_FILE"
if pgrep -f "auto_restart_monitor" >/dev/null; then
    pgrep -f "auto_restart_monitor" | xargs ps -p >>"$LOG_FILE" 2>&1
fi
echo "" >>"$LOG_FILE"

# Check core agents
echo "3. Core Agent Status:" >>"$LOG_FILE"
for agent in agent_build.sh agent_debug.sh agent_codegen.sh; do
    if pgrep -f "$agent" >/dev/null; then
        pid=$(pgrep -f "$agent")
        echo "✓ $agent running (PID: $pid)" >>"$LOG_FILE"
    else
        echo "✗ $agent not running" >>"$LOG_FILE"
    fi
done
echo "" >>"$LOG_FILE"

# Check task queue status
echo "4. Task Queue Status:" >>"$LOG_FILE"
if [[ -f "${SCRIPT_DIR}/task_queue.json" ]]; then
    completed=$(jq '.tasks | map(select(.status == "completed")) | length' "${SCRIPT_DIR}/task_queue.json" 2>/dev/null || echo "0")
    in_progress=$(jq '.tasks | map(select(.status == "in_progress")) | length' "${SCRIPT_DIR}/task_queue.json" 2>/dev/null || echo "0")
    queued=$(jq '.tasks | map(select(.status == "queued")) | length' "${SCRIPT_DIR}/task_queue.json" 2>/dev/null || echo "0")
    total=$(jq '.tasks | length' "${SCRIPT_DIR}/task_queue.json" 2>/dev/null || echo "0")

    {
        echo "Total tasks: $total"
        echo "Completed: $completed"
        echo "In progress: $in_progress"
        echo "Queued: $queued"
    } >>"$LOG_FILE"
else
    echo "Task queue file not found" >>"$LOG_FILE"
fi
echo "" >>"$LOG_FILE"

# Check Ollama status
echo "5. Ollama Integration Status:" >>"$LOG_FILE"
if pgrep -f "ollama serve" >/dev/null; then
    echo "✓ Ollama server running" >>"$LOG_FILE"
    # Check available models
    ollama list 2>/dev/null | head -5 >>"$LOG_FILE" 2>&1 || echo "Could not list models" >>"$LOG_FILE"
else
    echo "✗ Ollama server not running" >>"$LOG_FILE"
fi
echo "" >>"$LOG_FILE"

{
    echo "=== End Report ==="
    echo ""
} >>"$LOG_FILE"

# Display summary to console
echo "Agent Persistence Status Check Complete"
echo "Report saved to: $LOG_FILE"
echo ""
echo "Quick Status:"
launchctl list | grep quantum | awk '{print "Launch daemon: PID " $1}' || echo "No daemons found"
if pgrep -f "auto_restart_monitor|agent_build|agent_debug|agent_codegen" >/dev/null; then
    echo "Agent processes running: $(pgrep -f 'auto_restart_monitor|agent_build|agent_debug|agent_codegen' | wc -l | tr -d ' ')"
else
    echo "Agent processes running: 0"
fi
