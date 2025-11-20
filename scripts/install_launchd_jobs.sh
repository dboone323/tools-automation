#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_SRC_DIR="$ROOT_DIR/launchd"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/tools-automation"

mkdir -p "$LAUNCH_AGENTS_DIR" "$LOG_DIR"

print_step() { echo "[install_launchd] $1"; }

# Copy and install plist
install_plist() {
    local plist_name="$1"
    local src="$2"
    local dest="$LAUNCH_AGENTS_DIR/${plist_name}.plist"

    if [[ ! -f "$src" ]]; then
        print_step "SKIP: missing $src"
        return 0
    fi

    print_step "Installing $plist_name -> $dest"
    cp "$src" "$dest"
    plutil -lint "$dest"
    launchctl unload "$dest" 2>/dev/null || true
    launchctl load "$dest"
}

# MCP server
install_plist "com.quantum.mcp" "$ROOT_DIR/com.quantum.mcp.plist"

# Ollama serve
install_plist "com.tools.ollama.serve" "$PLIST_SRC_DIR/com.tools.ollama.serve.plist"

# Task Orchestrator (long-running)
install_plist "com.tools.task_orchestrator" "$PLIST_SRC_DIR/com.tools.task_orchestrator.plist"

# Dependency Graph Agent (long-running)
install_plist "com.tools.dependency_graph" "$PLIST_SRC_DIR/com.tools.dependency_graph.plist"

# Agent Monitoring (periodic)
install_plist "com.tools.agent.monitoring" "$PLIST_SRC_DIR/com.tools.agent.monitoring.plist"

# Dashboard (periodic)
install_plist "com.tools.dashboard" "$PLIST_SRC_DIR/com.tools.dashboard.plist"

print_step "Done. Use 'launchctl list | grep tools\|quantum' to verify."
