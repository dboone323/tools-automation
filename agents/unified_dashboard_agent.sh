#!/bin/bash
# Legacy wrapper to invoke the shared unified dashboard agent implementation.


# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="${SCRIPT_DIR%/Tools/Automation/agents}"
AGENT_IMPL="${REPO_ROOT}/Tools/agents/unified_dashboard_agent.sh"

if [[ -x ${AGENT_IMPL} ]]; then
  exec "${AGENT_IMPL}" "$@"
fi

echo "Unified dashboard agent implementation not found at ${AGENT_IMPL}" >&2
exit 1
