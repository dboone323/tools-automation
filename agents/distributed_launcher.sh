#!/bin/bash
# Distributed Agent Launcher
# Launches agents on remote hosts via SSH and coordinates health checks/logs.

# List of remote hosts (edit as needed)

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

REMOTE_HOSTS=("host1.example.com" "host2.example.com")
AGENT_SCRIPT="agent_supervisor.sh"
AGENTS_DIR="$(dirname "$0")"

for host in "${REMOTE_HOSTS[@]}"; do
  echo "Launching agent supervisor on ${host}..."
  ssh "${host}" bash -s -- "${AGENTS_DIR}" "${AGENT_SCRIPT}" <<'REMOTE_CMD'
dir="$1"
script="$2"
cd "${dir}" || exit 1
nohup "./${script}" > logs/supervisor_remote.log 2>&1 &
REMOTE_CMD
done

echo "Distributed agent supervisors launched. Check remote logs for status."
