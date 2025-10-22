#!/bin/bash
# start_agents.sh: Launch all automation agents and initialize agent_status.json
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENTS=(agent_build.sh agent_debug.sh agent_codegen.sh)
AGENT_PIDS=()
STATUS_FILE="$(dirname "$0")/agent_status.json"

# Initialize agent_status.json
cat <<EOF >"${STATUS_FILE}"
{
  "agents": {
    "build_agent": {"status": "starting", "pid": null},
    "debug_agent": {"status": "starting", "pid": null},
    "codegen_agent": {"status": "starting", "pid": null}
  },
  "last_update": $(date +%s)
}
EOF

# Start each agent in the background and record PID
for AGENT in "${AGENTS[@]}"; do
  AGENT_PATH="$(dirname "$0")/${AGENT}"
  if [[ -x ${AGENT_PATH} ]]; then
    bash "${AGENT_PATH}" &
    PID=$!
    AGENT_NAME=$(basename "${AGENT}" .sh | sed 's/agent_//')
    # Update status file with running PID
    update_agent_status "$AGENT_NAME" "running" "$$"\" | .agents.${AGENT_NAME}_agent.pid = ${PID} | .last_update = $(date +%s)" "${STATUS_FILE}" >"${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
    AGENT_PIDS+=("${PID}")
    echo "Started ${AGENT} as PID ${PID}"
  else
    echo "Agent script ${AGENT_PATH} not found or not executable."
  fi
done

echo "All agents started. To stop, run ./stop_agents.sh"
