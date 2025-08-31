## Install service templates

Use `install_services.sh` to copy unit files and plists into common system locations.

By default the script runs in dry-run mode and only prints the planned actions. To apply changes:

./install_services.sh --apply

If you need to overwrite existing files, add `--force`.

Note: Make the installer executable after checkout:

chmod +x Automation/monitoring/install_services.sh

The script will use `sudo` when writing to locations that require elevated privileges.
Monitoring services (MCP & GitHub workflow monitor)

This folder contains helper scripts and service templates to run the MCP coordinator and the GitHub workflow monitor from the project virtualenv at Automation/.venv.

Quick start (run under your user account):

- Create venv (if not present):
  - python3 -m venv Automation/.venv
  - Automation/.venv/bin/pip install -r Automation/requirements.txt # or install 'requests'

- Start services (nohup mode):
  - Automation/monitoring/start_mcp.sh
  - Automation/monitoring/start_monitor.sh

- Stop services:
  - Automation/monitoring/stop_monitor.sh
  - Automation/monitoring/stop_mcp.sh

- Check status and recent logs:
  - Automation/monitoring/status_services.sh

Launchd (macOS) installation (optional):

1. Copy the prepared plist files to ~/Library/LaunchAgents/:
   cp Automation/monitoring/com.quantum.mcp_server.plist ~/Library/LaunchAgents/
   cp Automation/monitoring/com.quantum.github_workflow_monitor.plist ~/Library/LaunchAgents/

2. Load the agents (will start them immediately):
   launchctl unload ~/Library/LaunchAgents/com.quantum.mcp_server.plist || true
   launchctl load -w ~/Library/LaunchAgents/com.quantum.mcp_server.plist
   launchctl unload ~/Library/LaunchAgents/com.quantum.github_workflow_monitor.plist || true
   launchctl load -w ~/Library/LaunchAgents/com.quantum.github_workflow_monitor.plist

3. To remove/unload:
   launchctl unload -w ~/Library/LaunchAgents/com.quantum.mcp_server.plist || true
   launchctl unload -w ~/Library/LaunchAgents/com.quantum.github_workflow_monitor.plist || true

Notes & troubleshooting:

- The plists reference the project's venv python at the absolute path; ensure your workspace location matches the paths in the plist files.
- If a process refuses to start because the port is in use, find the conflicting process (lsof -i :5005) and stop it.
- Logs are written to Automation/logs/_.out and _.err and pidfiles to Automation/logs/\*.pid
