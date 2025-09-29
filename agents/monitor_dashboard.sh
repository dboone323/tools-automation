#!/bin/bash
# Monitor Dashboard: Tails all agent logs and highlights errors or stalls

AGENTS_DIR="$(dirname "$0")"
LOGS=(build_agent.log debug_agent.log codegen_agent.log uiux_agent.log apple_pro_agent.log collab_agent.log updater_agent.log search_agent.log supervisor.log)

# Print header
clear
echo "==================== AGENT MONITOR DASHBOARD ===================="
echo "Press Ctrl+C to exit."
echo "---------------------------------------------------------------"

# Tail all logs in parallel, highlight errors and inactivity
multitail_installed=$(command -v multitail)
log_paths=()
for log in "${LOGS[@]}"; do
  log_paths+=("${AGENTS_DIR}/${log}")
done

if [[ -n ${multitail_installed} ]]; then
  multitail -cS bash "${log_paths[@]}"
else
  tail -F "${log_paths[@]}" |
    grep --color=always -E "error|fail|stuck|timeout|complete|sleep|cycle|$" || true
fi
