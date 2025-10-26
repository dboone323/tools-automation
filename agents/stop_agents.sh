#!/bin/bash
# stop_agents.sh: Gracefully stop all running agent processes and update agent_status.json

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

STATUS_FILE="$(dirname "$0")/agent_status.json"
AGENT_NAMES=(build_agent debug_agent codegen_agent)

if [[ ! -f ${STATUS_FILE} ]]; then
  echo "No agent_status.json found. Nothing to stop."
  exit 1
fi

for AGENT in "${AGENT_NAMES[@]}"; do
  PID=$(jq -r ".agents.${AGENT}.pid" "${STATUS_FILE}")
  if [[ ${PID} != "null" && -n ${PID} ]]; then
    if kill -0 "${PID}" 2>/dev/null; then
      kill "${PID}"
      echo "Stopped ${AGENT} (PID ${PID})"
      jq ".agents.${AGENT}.status = \"stopped\" | .agents.${AGENT}.pid = null | .last_update = $(date +%s)" "${STATUS_FILE}" >"${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
    else
      echo "${AGENT} (PID ${PID}) not running."
    fi
  else
    echo "${AGENT} has no recorded PID."
  fi
done
