#!/bin/bash

# Agent Persistence Status Check Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/persistence_status.log"

echo "=== Agent Persistence Status Report ===" >>"$LOG_FILE"
echo "Timestamp: $(date)" >>"$LOG_FILE"
echo "" >>"$LOG_FILE"

# Check launch daemon status
echo "1. Launch Daemon Status:" >>"$LOG_FILE"
launchctl list | grep quantum >>"$LOG_FILE" 2>&1
echo "" >>"$LOG_FILE"

# Check auto-restart monitor process
echo "2. Auto-Restart Monitor Process:" >>"$LOG_FILE"
ps aux | grep auto_restart_monitor | grep -v grep >>"$LOG_FILE" 2>&1
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

    echo "Total tasks: $total" >>"$LOG_FILE"
    echo "Completed: $completed" >>"$LOG_FILE"
    echo "In progress: $in_progress" >>"$LOG_FILE"
    echo "Queued: $queued" >>"$LOG_FILE"
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

echo "=== End Report ===" >>"$LOG_FILE"
echo "" >>"$LOG_FILE"

# Display summary to console
echo "Agent Persistence Status Check Complete"
echo "Report saved to: $LOG_FILE"
echo ""
echo "Quick Status:"
launchctl list | grep quantum | awk '{print "Launch daemon: PID " $1}'
ps aux | grep -c "auto_restart_monitor\|agent_build\|agent_debug\|agent_codegen" | grep -v grep | xargs echo "Agent processes running:"
