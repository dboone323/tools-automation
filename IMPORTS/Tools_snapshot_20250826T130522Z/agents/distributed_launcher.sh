#!/bin/bash
# Distributed Agent Launcher
# Launches agents on remote hosts via SSH and coordinates health checks/logs.

# List of remote hosts (edit as needed)
REMOTE_HOSTS=("host1.example.com" "host2.example.com")
AGENT_SCRIPT="agent_supervisor.sh"
AGENTS_DIR="$(dirname "$0")"

for host in "${REMOTE_HOSTS[@]}"; do
  echo "Launching agent supervisor on $host..."
  ssh "$host" "cd $AGENTS_DIR && nohup ./$AGENT_SCRIPT > logs/supervisor_remote.log 2>&1 &"
done

echo "Distributed agent supervisors launched. Check remote logs for status."
