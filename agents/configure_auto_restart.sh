#!/bin/bash
# Configure agent auto-restart

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

usage() {
  cat <<EOF
Usage: $0 [enable|disable|status] <agent_name>

Commands:
  enable   - Enable auto-restart for an agent
  disable  - Disable auto-restart for an agent
  status   - Check auto-restart status for all agents

Examples:
  $0 enable agent_build.sh
  $0 disable agent_testing.sh
  $0 status
EOF
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

command="$1"

case "$command" in
enable)
  if [[ $# -lt 2 ]]; then
    echo "ERROR: Agent name required"
    usage
  fi
  agent_name="$2"
  enable_auto_restart "$agent_name"
  echo "✓ Auto-restart enabled for $agent_name"
  ;;

disable)
  if [[ $# -lt 2 ]]; then
    echo "ERROR: Agent name required"
    usage
  fi
  agent_name="$2"
  disable_auto_restart "$agent_name"
  echo "✓ Auto-restart disabled for $agent_name"
  ;;

status)
  echo "Auto-Restart Status"
  echo "==================="
  for agent_file in "$SCRIPT_DIR"/*.sh; do
    [[ ! -f "$agent_file" ]] && continue
    agent_name=$(basename "$agent_file")
    [[ "$agent_name" == "shared_functions.sh" ]] && continue
    [[ "$agent_name" == "configure_auto_restart.sh" ]] && continue

    if should_auto_restart "$agent_name"; then
      echo "✓ $agent_name - ENABLED"
    else
      echo "✗ $agent_name - DISABLED"
    fi
  done
  ;;

*)
  echo "ERROR: Unknown command: $command"
  usage
  ;;
esac
