# Automation Agents System

This directory contains autonomous agents for continuous automation, AI/ML log analysis, multi-level backup/restore, plugin extensibility, and secure API access.

## Agents & Tools

- **agent_build.sh**: Watches for triggers and builds the project automatically, with backup/restore and test validation.
- **agent_debug.sh**: Runs diagnostics/tests and applies auto-fixes if errors are detected, with backup/restore.
- **agent_codegen.sh**: Runs code generation and auto-fix routines on a schedule, with backup/restore.
- **agent_supervisor.sh**: Starts and monitors all agents, restarts on error/rollback, runs AI log analyzer.
- **backup_manager.sh**: Multi-level backup/restore for projects, with audit logging.
- **plugin_api.sh**: Plugin system with access control and policy enforcement.
- **api_server.py**: HTTP API for plugin listing/execution, with audit logging and policy enforcement.
- **ai_log_analyzer.py**: AI/ML log analysis for anomaly detection and recommendations.

## Onboarding

Run the onboarding script to set up permissions and environment:

```sh
./onboard.sh
```

## Usage

1. Start the supervisor to launch all agents:
   ```sh
   ./agent_supervisor.sh
   ```
2. Run the API server for plugin access:
   ```sh
   python3 api_server.py
   ```
3. Analyze logs with AI/ML:
   ```sh
   python3 ai_log_analyzer.py
   ```
4. Check logs and `audit.log` for all actions and events.

## Security & Policy

- All critical actions are logged to `audit.log`.
- Plugins and API require `API_TOKEN` and are restricted by `policy.conf`.

## Knowledge Base

See `KNOWLEDGE_BASE.md` for an auto-generated summary of all agents, tools, and policies.

-

## Distributed/Scalable Agents

- Use `distributed_launcher.sh` to launch agent supervisors on remote hosts via SSH.
- Use `distributed_health_check.sh` to check health/status of remote agent supervisors.

## Customization

- Edit agent scripts to change intervals, add notifications, or extend agent logic.
- Add new agents or plugins by following the same pattern.
