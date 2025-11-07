# Scheduling: LaunchAgents vs. Cron

This document explains how agents in this workspace are scheduled on macOS via launchd, which agents run on intervals vs. continuously, how to install/uninstall them, and how we handled overlaps with existing cron jobs.

## LaunchAgents (installed)

Labels and behavior configured under `~/Library/LaunchAgents`:

- com.quantum.mcp

  - What: MCP local server (`agents/run_mcp_server.sh` → `mcp_server.py`)
  - Schedule: RunAtLoad + KeepAlive (long-running)
  - Logs: `~/Library/Logs/tools-automation/mcp_server.{out,err}.log`

- com.tools.ollama.serve

  - What: `ollama serve`
  - Schedule: RunAtLoad + KeepAlive (long-running)
  - Logs: `~/Library/Logs/tools-automation/ollama-serve*.log`

- com.tools.task_orchestrator

  - What: Task orchestrator (`agents/run_task_orchestrator.sh`)
  - Schedule: RunAtLoad + KeepAlive (long-running)
  - Logs: `~/Library/Logs/tools-automation/task_orchestrator*.log`

- com.tools.dependency_graph

  - What: Dependency Graph Agent (`agents/dependency_graph_agent.sh`)
  - Schedule: RunAtLoad + KeepAlive (long-running); `SCAN_INTERVAL=600`
  - Logs: `~/Library/Logs/tools-automation/dependency_graph*.log`

- com.tools.agent.monitoring

  - What: Agent health monitoring (`agent_monitoring.sh --once`)
  - Schedule: `StartInterval=300` seconds + RunAtLoad (periodic)
  - Logs: `~/Library/Logs/tools-automation/agent_monitoring*.log`

- com.tools.dashboard
  - What: Dashboard summary (`dashboard_unified.sh summary`)
  - Schedule: `StartInterval=900` seconds + RunAtLoad (periodic)
  - Logs: `~/Library/Logs/tools-automation/dashboard*.log`

## Install / Uninstall / Verify

Install or update all launch agents:

```zsh
./scripts/install_launchd_jobs.sh
```

Uninstall all launch agents from this workspace:

```zsh
./scripts/uninstall_launchd_jobs.sh
```

Verify launch agents are loaded:

```zsh
launchctl list | egrep 'com\.tools|com\.quantum'
```

Tail recent logs:

```zsh
tail -n 200 ~/Library/Logs/tools-automation/*.log
```

Manual control for a single label:

```zsh
launchctl unload ~/Library/LaunchAgents/<label>.plist
launchctl load   ~/Library/LaunchAgents/<label>.plist
```

## Cron deconflict assessment

We captured current user cron entries:

```cron
# Agent Health Monitoring Cron Jobs
# Installed: Mon Oct  6 20:03:30 CDT 2025

# Health checks every hour

# Lock timeout monitoring every 6 hours

# Analytics generation daily at 2 AM
# Quantum-workspace daily CI/CD monitoring (6 AM)
0 6 * * * cd /Users/danielstevens/Desktop/Quantum-workspace && /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/local_ci_orchestrator.sh full > ~/.quantum-workspace/artifacts/logs/daily_$(date +\%Y\%m\%d).log 2>&1
```

- This cron job targets a different workspace (`Quantum-workspace`) and does not duplicate the launchd agents we installed for `tools-automation`.
- Decision: Keep this cron job as-is. No overlapping jobs were found for the new launchd-managed agents.

### Optional migration (example)

If you prefer to move that daily Quantum job to launchd, use a LaunchAgent like:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.quantum.daily-ci</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>cd /Users/danielstevens/Desktop/Quantum-workspace && /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/local_ci_orchestrator.sh full >> ~/.quantum-workspace/artifacts/logs/daily_$(date +%Y%m%d).log 2>&1</string>
  </array>
  <key>RunAtLoad</key>
  <false/>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>6</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
```

If you migrate, remember to remove the cron entry with `crontab -e`.

## Troubleshooting

- If a label shows `Exit Status` non-zero in `launchctl list`, check the related log in `~/Library/Logs/tools-automation/`.
- Validate plist syntax:

```zsh
plutil -lint ~/Library/LaunchAgents/<label>.plist
```

- Ensure `PATH` includes `/opt/homebrew/bin` for Homebrew-managed tools.
- After editing a plist, `launchctl unload` then `launchctl load` it again.
