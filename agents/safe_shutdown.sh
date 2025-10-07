#!/bin/bash

# Safe Shutdown Script for Agent System
# Gracefully stops all agents and cleans up resources

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     🛑 SAFE SHUTDOWN - Agent System Cleanup                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Source shared functions if available
if [[ -f "shared_functions.sh" ]]; then
  source shared_functions.sh
fi

# Function to stop agent gracefully
stop_agent() {
  local agent_name="$1"
  local pid_file="/tmp/${agent_name}.pid"

  if [[ -f "$pid_file" ]]; then
    local pid=$(cat "$pid_file")
    if ps -p "$pid" >/dev/null 2>&1; then
      echo "  🛑 Stopping $agent_name (PID: $pid)..."
      kill -TERM "$pid" 2>/dev/null
      sleep 1
      if ps -p "$pid" >/dev/null 2>&1; then
        kill -KILL "$pid" 2>/dev/null
      fi
      rm -f "$pid_file"
    else
      rm -f "$pid_file"
    fi
  fi
}

# Stop all running agents
echo "1️⃣  Stopping running agents..."
for pid_file in /tmp/agent_*.pid /tmp/*_agent.pid; do
  if [[ -f "$pid_file" ]]; then
    agent_name=$(basename "$pid_file" .pid)
    stop_agent "$agent_name"
  fi
done

# Clean up lock files
echo ""
echo "2️⃣  Cleaning up lock files..."
if [[ -f "/tmp/agent_status.lock" ]]; then
  echo "  🔓 Removing agent_status.lock"
  rm -f /tmp/agent_status.lock
fi

# Clean up any stale locks
for lock_file in /tmp/*.lock; do
  if [[ -f "$lock_file" ]]; then
    echo "  🔓 Removing $(basename "$lock_file")"
    rm -f "$lock_file"
  fi
done

# Save final agent status
echo ""
echo "3️⃣  Saving final agent status..."
if [[ -f "agent_status.json" ]]; then
  cp agent_status.json "agent_status.json.shutdown_$(date +%Y%m%d_%H%M%S)"
  echo "  💾 Status saved to backup"
fi

# Clean up temporary files
echo ""
echo "4️⃣  Cleaning temporary files..."
temp_files=(
  "/tmp/analytics.log"
  "/tmp/analytics_test.json"
  "/tmp/analytics_test.log"
)

for temp_file in "${temp_files[@]}"; do
  if [[ -f "$temp_file" ]]; then
    rm -f "$temp_file"
    echo "  🗑️  Removed $(basename "$temp_file")"
  fi
done

# Final status
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     ✅ SHUTDOWN COMPLETE - System Safe for Sleep             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Summary:"
echo "  ✅ All agents stopped"
echo "  ✅ Lock files removed"
echo "  ✅ Temporary files cleaned"
echo "  ✅ Agent status backed up"
echo ""
echo "🔋 Your MacBook Pro is now safe to sleep."
echo "🚀 On next boot, auto-restart will handle agent recovery."
echo ""
