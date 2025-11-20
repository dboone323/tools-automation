#!/bin/bash
set -euo pipefail

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
print_step() { echo "[uninstall_launchd] $1"; }

remove_plist() {
    local label="$1"
    local file="$LAUNCH_AGENTS_DIR/${label}.plist"
    if [[ -f "$file" ]]; then
        print_step "Unloading $label"
        launchctl unload "$file" 2>/dev/null || true
        print_step "Removing $file"
        rm -f "$file"
    else
        print_step "SKIP: $file not found"
    fi
}

remove_plist "com.quantum.mcp"
remove_plist "com.tools.ollama.serve"
remove_plist "com.tools.task_orchestrator"
remove_plist "com.tools.dependency_graph"
remove_plist "com.tools.agent.monitoring"
remove_plist "com.tools.dashboard"

print_step "Done."
