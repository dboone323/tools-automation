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
if [ -n "$multitail_installed" ]; then
    multitail -cS bash $(for log in "${LOGS[@]}"; do echo "$AGENTS_DIR/$log"; done)
else
    tail -F $(for log in "${LOGS[@]}"; do echo "$AGENTS_DIR/$log"; done) |
    grep --color=always -E "error|fail|stuck|timeout|complete|sleep|cycle|$" || true
fi
