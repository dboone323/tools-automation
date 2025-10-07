#!/bin/bash
# Collaboration Agent: Coordinates all agents, aggregates plans, and ensures best practice learning

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="CollabAgent"
LOG_FILE="$(dirname "$0")/collab_agent.log"
PLANS_DIR="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/plans"

SLEEP_INTERVAL=900 # 15 minutes
MIN_INTERVAL=300
MAX_INTERVAL=3600

mkdir -p "${PLANS_DIR}"

while true; do
  next_sleep=$((SLEEP_INTERVAL + 300))
  if [[ ${next_sleep} -gt ${MAX_INTERVAL} ]]; then
    next_sleep=${MAX_INTERVAL}
  elif [[ ${next_sleep} -lt ${MIN_INTERVAL} ]]; then
    next_sleep=${MIN_INTERVAL}
  fi

  {
    echo "[$(date)] ${AGENT_NAME}: Aggregating agent plans and results..."
    cat "${PLANS_DIR}"/*.plan 2>/dev/null
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/plugins/collab_analyze.sh
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/auto_generate_knowledge_base.py
    echo "[$(date)] ${AGENT_NAME}: Collaboration and learning cycle complete."
    printf '[%s] %s: Sleeping for %s seconds.\n' "$(date)" "${AGENT_NAME}" "${next_sleep}"
  } >>"${LOG_FILE}" 2>&1

  SLEEP_INTERVAL=${next_sleep}
  sleep "${SLEEP_INTERVAL}"
done
