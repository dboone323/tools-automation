# Full Agent Autonomy - Installation Guide

## 🎯 Overview

This guide will set up your agents to run 24/7 with automatic restarts, daily rotation, and system-level persistence.

## ✅ Prerequisites

All scripts are already created and validated:
- ✅ LaunchAgent configurations
- ✅ Orchestration scripts (start/stop/restart)
- ✅ Enhanced auto-restart monitor (30s intervals)
- ✅ Validation script

## 🚀 Quick Start (3 Steps)

### Step 1: Install Supervisor Service

```bash
cd /Users/danielstevens/Desktop/github-projects/tools-automation
./scripts/install_agent_service.sh
```

**What this does:**
- Installs system-level supervisor service
- Auto-starts agents on every system boot
- Restarts supervisor on crashes
- Logs to `/tmp/agent-supervisor.log`

### Step 2: Install Daily Rotation Schedule

```bash
# Copy daily restart plist
cp com.tools-automation.daily-restart.plist ~/Library/LaunchAgents/

# Load the schedule
launchctl load ~/Library/LaunchAgents/com.tools-automation.daily-restart.plist
```

**What this does:**
- Schedules daily agent restart at 3:00 AM
- Keeps agents fresh (prevents memory leaks)
- Logs to `/tmp/agent-daily-restart.log`

### Step 3: Validate Installation

```bash
./scripts/validate_autonomy.sh
```

**Expected output:**
```
✅ Perfect! Full autonomy system is configured and operational

System Status:
  • Supervisor service: Active
  • Daily rotation: Scheduled (3:00 AM)
  • Agent health checks: 30-second intervals  
  • Auto-restart: Enabled
```

## 🎛️ Management Commands

### Start/Stop All Agents
```bash
# Start all agents
./agents/start_all_agents.sh

# Stop all agents  
./agents/stop_all_agents.sh

# Restart all agents (with cleanup)
./agents/restart_all_agents.sh
```

### Service Management
```bash
# Check service status
launchctl list | grep agent-supervisor

# View supervisor logs
tail -f /tmp/agent-supervisor.log

# Stop supervisor service
launchctl unload ~/Library/LaunchAgents/com.tools-automation.agent-supervisor.plist

# Start supervisor service
launchctl load ~/Library/LaunchAgents/com.tools-automation.agent-supervisor.plist

# Restart supervisor
launchctl unload ~/Library/LaunchAgents/com.tools-automation.agent-supervisor.plist
launchctl load ~/Library/LaunchAgents/com.tools-automation.agent-supervisor.plist
```

### View Logs
```bash
# All agent logs
tail -f agents/logs/*.log

# Supervisor log
tail -f /tmp/agent-supervisor.log

# Daily restart log  
tail -f /tmp/agent-daily-restart.log

# Auto-restart monitor
tail -f agents/logs/auto_restart_monitor.log
```

## 📊 System Architecture

```
┌─────────────────────────────────────────┐
│       macOS LaunchAgent System          │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Supervisor Service (24/7)        │  │
│  │  - Auto-start on boot             │  │
│  │  - Restart on crash               │  │
│  │  - Manages agent lifecycle        │  │
│  └───────────────┬───────────────────┘  │
│                  │                      │
│  ┌───────────────▼───────────────────┐  │
│  │  Auto-Restart Monitor (30s)       │  │
│  │  - Health checks every 30s        │  │
│  │  - Restart failed agents          │  │
│  │  - Track restart counts           │  │
│  └───────────────┬───────────────────┘  │
│                  │                      │
│  ┌───────────────▼───────────────────┐  │
│  │  128 Agents (Dynamic Config)      │  │
│  │  - Environment-agnostic           │  │
│  │  - Dynamic path discovery         │  │
│  │  - Auto-restart enabled           │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Daily Rotation (3 AM)            │  │
│  │  - Graceful stop all agents       │  │
│  │  - Clean restart                  │  │
│  │  - Health validation              │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## 🔒 Safety Features

1. **Graceful Shutdown**: 10-second SIGTERM timeout before force-kill
2. **PID Tracking**: All agents tracked with PID files
3. **Health Checks**: 30-second monitoring intervals
4. **Restart Limits**: Throttle interval prevents restart loops
5. **Logging**: Comprehensive logs for debugging

## 🐛 Troubleshooting

### Service won't load
```bash
# Check for errors
launchctl load -w ~/Library/LaunchAgents/com.tools-automation.agent-supervisor.plist 2>&1

# Check plist syntax
plutil -lint ~/Library/LaunchAgents/com.tools-automation.agent-supervisor.plist
```

### Agents not starting
```bash
# Check supervisor log
cat /tmp/agent-supervisor-error.log

# Manually start agents
./agents/start_all_agents.sh

# Check agent health
./scripts/verify_agents.sh
```

### Daily restart not running
```bash
# Check schedule is loaded
launchctl list | grep daily-restart

# Force run now (for testing)
./agents/restart_all_agents.sh
```

## 🗑️ Uninstall

```bash
# Stop and unload supervisor
launchctl unload ~/Library/LaunchAgents/com.tools-automation.agent-supervisor.plist
rm ~/Library/LaunchAgents/com.tools-automation.agent-supervisor.plist

# Stop and unload daily restart
launchctl unload ~/Library/LaunchAgents/com.tools-automation.daily-restart.plist
rm ~/Library/LaunchAgents/com.tools-automation.daily-restart.plist

# Stop all agents
./agents/stop_all_agents.sh
```

## 📈 Next Steps

Your system is now **100% autonomous**! Consider:

1. **Monitor performance**: Check logs after 24 hours
2. **Tune intervals**: Adjust SLEEP_INTERVAL in auto_restart_monitor.sh if needed
3. **Add notifications**: Set up alerts for critical failures
4. **(Optional) Build desktop app**: For visual monitoring (see implementation_plan.md)

## 🎉 Success Criteria

After installation, your system will:
- ✅ Auto-start all agents on system boot
- ✅ Monitor agent health every 30 seconds
- ✅ Auto-restart failed agents within 30 seconds
- ✅ Perform daily clean restart at 3 AM
- ✅ Maintain logs for debugging
- ✅ Survive system reboots

**Your tools-automation system is now fully autonomous! 🚀**
