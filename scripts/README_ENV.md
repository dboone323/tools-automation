# Workspace Environment Setup

This document explains how to make this repository portable across machines and CI.

## Required environment variables
- WORKSPACE_ROOT: path to the repository root. Defaults to `git rev-parse --show-toplevel`.
- CODE_DIR: Optional override for code folder (defaults to WORKSPACE_ROOT)
- PROJECT_DIR: Optional override for Projects folder (defaults to `${WORKSPACE_ROOT}/Projects`)
- AGENT_STATUS_PATH: Path to `agent_status.json` (defaults to `${WORKSPACE_ROOT}/config/agent_status.json`)
- OLLAMA_URL: Local inference endpoint for models (defaults to `http://localhost:11434`)

## Quick setup

1. Source the setup script to set sensible defaults:

```bash
source "$(git rev-parse --show-toplevel)/scripts/setup_paths.sh"
```

2. Generate a launch agent plist (macOS):

```bash
scripts/generate_plist.sh
launchctl load ~/Library/LaunchAgents/com.tools.automation.dashboard-server.plist
```

3. Run a script:

```bash
source scripts/setup_paths.sh
bash shared-kit/Tools/Automation/quantum_dashboard.sh
```

## CI notes
- CI should call `git submodule update --init --recursive`.
- CI jobs should set `WORKSPACE_ROOT` or rely on `git rev-parse --show-toplevel`.

## Why this is needed
- Removes hard-coded paths and makes the repository portable for other developers.
- Prevents leaking personal paths into artifacts.
- Enables CI to run reproducible builds across different OS runners.
