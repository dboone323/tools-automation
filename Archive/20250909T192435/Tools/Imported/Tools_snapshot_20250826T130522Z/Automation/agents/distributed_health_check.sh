#!/bin/bash
# Distributed Agent Health Check
# Checks health/status of agent supervisors on all remote hosts.

REMOTE_HOSTS=("host1.example.com" "host2.example.com")
AGENTS_DIR="$(dirname "$0")"

for host in "${REMOTE_HOSTS[@]}"; do
  echo "Checking $host..."
  ssh "$host" "tail -10 $AGENTS_DIR/logs/supervisor_remote.log"
done
