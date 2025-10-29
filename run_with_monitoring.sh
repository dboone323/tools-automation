#!/usr/bin/env bash
# Run any command with agent monitoring
# Usage: run_with_monitoring.sh <command> [args...]

set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <command> [args...]"
    exit 1
fi

COMMAND=("$@")
AGENT_NAME=$(basename "${COMMAND[0]}" | sed 's/\.[^.]*$//') # Remove extension

# Call the agent monitoring wrapper
exec "$(dirname "$0")/agent_monitoring.sh" "$AGENT_NAME" "${COMMAND[@]}"
