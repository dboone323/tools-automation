#!/bin/bash
# Distributed Agent Health Check
# Checks health/status of agent supervisors on all remote hosts.

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

REMOTE_HOSTS=("host1.example.com" "host2.example.com")
AGENTS_DIR="$(dirname "$0")"

for host in "${REMOTE_HOSTS[@]}"; do
  echo "Checking ${host}..."
  log_path="${AGENTS_DIR}/logs/supervisor_remote.log"
  ssh "${host}" tail -n 10 "${log_path}"
done
