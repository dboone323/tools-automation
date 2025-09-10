#!/bin/bash
# Agent System Onboarding Script
# Sets up environment, permissions, and provides quickstart info for developers.

set -e

AGENTS_DIR="$(dirname "$0")"
LOGS_DIR="$AGENTS_DIR/logs"
PLUGINS_DIR="$AGENTS_DIR/plugins"

# Ensure directories exist
mkdir -p "$LOGS_DIR" "$PLUGINS_DIR"

# Make all agent scripts executable
chmod +x "$AGENTS_DIR"/*.sh "$PLUGINS_DIR"/*.sh || true

# Print quickstart info
cat <<EOF
Agent System Onboarding Complete!

Key scripts:
- agent_build.sh, agent_debug.sh, agent_codegen.sh: Main agents
- agent_supervisor.sh: Orchestrates and monitors agents
- backup_manager.sh: Multi-level backup/restore
- plugin_api.sh: Plugin system
- api_server.py: HTTP API for plugins
- ai_log_analyzer.py: AI/ML log analysis

To start supervisor: ./agent_supervisor.sh
To run API server:   python3 api_server.py
To analyze logs:     python3 ai_log_analyzer.py

See README.md or Documentation/ for more details.
EOF
