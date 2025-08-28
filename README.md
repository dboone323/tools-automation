# Tools/Automation - MCP quickstart

This folder contains a minimal MCP (Micro-Coordinator Protocol) local server and helper agents used to coordinate automation across the workspace.

Quick start

1. Start the MCP server (from this directory):

```bash
python3 mcp_server.py &
```

2. (Optional) Run the controller agent which polls for queued tasks and executes them:

```bash
python3 mcp_controller.py &
```

3. Use the dashboard to list tasks:

```bash
./mcp_dashboard.sh list
```

Artifacts

- By default artifacts are saved under `~/mcp_artifacts` (configurable via `ARTIFACT_DIR`).
- To enable remote uploads, set `ARTIFACT_DEST` (e.g. `export ARTIFACT_DEST="s3://my-bucket/path"`) and ensure `aws` CLI is configured.

Web dashboard

Start a minimal web dashboard that proxies the MCP server and provides a simple UI:

```bash
python3 mcp_web_dashboard.py &
# then open http://127.0.0.1:8080
```

Daemon helper & log rotation

Use `run_mcp_daemon.sh` to start the MCP server and auto-rotate logs before start.
You can configure rotation via env vars:

````bash
export MAX_LOG_BYTES=2097152   # 2MB
export MAX_LOG_COUNT=10
./run_mcp_daemon.sh

Flask-based dashboard (optional)

If you prefer a richer UI, a Flask-based dashboard is included. Install dependencies and run:

```bash
python3 -m pip install -r requirements.txt
python3 mcp_dashboard_flask.py
# open http://127.0.0.1:8080
````

````


Notes

- `mcp_server.py` implements an allowlist of commands mapped to workspace scripts to reduce risk.
- `mcp_controller.py` prevents concurrent execution per project.
- For CI integration, run the server inside a background service or container.
# Master Automation

This folder contains the master automation controller and helper scripts used across the workspace.

Key scripts:


Notes:


Usage examples:

```bash
# List projects with quick status
./master_automation.sh list

# Run automation for a single project (e.g., PlannerApp)
./master_automation.sh run PlannerApp

# Run all project automations
./master_automation.sh all

# Validate workflows only
./deploy_workflows_all_projects.sh --validate
````

If you'd like I can also add a lightweight GitHub Actions workflow to run `master_automation.sh --validate` on PRs. Let me know if you want that added.

Note: retrigger marker — CI test edit.
