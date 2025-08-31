# Unified Agent Dashboard

A comprehensive monitoring and visualization system for the Quantum Workspace Agent ecosystem.

## Overview

The Unified Agent Dashboard provides real-time monitoring, visualization, and management capabilities for all agents in the Quantum Workspace system. It offers a web-based interface for tracking agent health, system metrics, task queues, and performance analytics.

## Features

### 🖥️ Real-time Monitoring

- **Agent Status**: Live status of all agents (healthy, degraded, critical, unknown)
- **System Metrics**: CPU, memory, disk usage, network connections, process count
- **Task Queue**: Active tasks, priorities, and assignments
- **Performance Analytics**: Health scores, utilization metrics, completion rates

### 📊 Visual Dashboard

- **Modern Web Interface**: Responsive design with real-time updates
- **Interactive Elements**: Color-coded status indicators, progress bars, task lists
- **Auto-refresh**: Updates every 30 seconds automatically
- **Mobile-friendly**: Responsive design for all devices

### 🤖 Agent Integration

- **Health Monitoring**: Automatic agent health assessment
- **Communication**: Inter-agent messaging and coordination
- **Task Distribution**: Real-time task assignment and completion tracking
- **Error Handling**: Comprehensive error reporting and recovery

### 📈 Reporting & Analytics

- **Automated Reports**: Hourly dashboard reports in Markdown format
- **Historical Data**: Track performance trends over time
- **Export Capabilities**: Generate reports for documentation
- **Alert System**: Configurable alerts for critical events

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Web Browser   │────│  Dashboard HTML  │────│ Dashboard Agent │
│                 │    │                  │    │                 │
│ http://localhost│    │ dashboard.html   │    │ unified_dashboard│
│ :8080           │    │                  │    │ _agent.sh       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Agent Data    │    │   System Metrics │    │   Task Queue    │
│                 │    │                  │    │                 │
│ agent_*.json    │    │ top, df, ps     │    │ task_orchestrator│
│                 │    │                  │    │ .json           │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Installation & Setup

### Prerequisites

- **Python 3**: For the web server (built-in HTTP server)
- **jq**: For JSON processing (optional but recommended)
- **bash**: Shell environment
- **Web Browser**: For accessing the dashboard

### Quick Start

1. **Navigate to the agents directory:**

   ```bash
   cd /Users/danielstevens/Desktop/Code/Tools/Automation/agents
   ```

2. **Start the dashboard:**

   ```bash
   ./dashboard_launcher.sh start
   ```

3. **Open your browser:**

   ```
   http://localhost:8080
   ```

4. **Stop the dashboard:**
   ```bash
   ./dashboard_launcher.sh stop
   ```

## Usage

### Dashboard Launcher Commands

```bash
# Start the dashboard
./dashboard_launcher.sh start

# Stop the dashboard
./dashboard_launcher.sh stop

# Restart the dashboard
./dashboard_launcher.sh restart

# Check status
./dashboard_launcher.sh status

# Show help
./dashboard_launcher.sh help
```

### Dashboard Features

#### Agent Status Panel

- **Real-time Status**: Color-coded agent health indicators
- **Task Completion**: Track completed tasks per agent
- **Last Seen**: Monitor agent activity timestamps
- **Health Scores**: Percentage-based health assessment

#### System Metrics Panel

- **CPU Usage**: Real-time processor utilization
- **Memory Usage**: RAM consumption monitoring
- **Disk Usage**: Storage utilization tracking
- **Network Connections**: Active connection count
- **Process Count**: Total system processes

#### Task Queue Panel

- **Active Tasks**: Currently running tasks
- **Task Priorities**: High, medium, low priority indicators
- **Assigned Agents**: Which agent is handling each task
- **Task Descriptions**: Detailed task information

#### Performance Panel

- **Agent Health**: Overall system health percentage
- **Progress Bars**: Visual health indicators
- **Active Tasks**: Current task count
- **System Health Score**: Comprehensive health metric

## Configuration

### Dashboard Settings

The dashboard can be configured by modifying the following variables in `unified_dashboard_agent.sh`:

```bash
# Dashboard configuration
DASHBOARD_PORT=8080          # Web server port
DASHBOARD_HOST="localhost"   # Web server host
UPDATE_INTERVAL=30           # Update frequency in seconds
```

### Status Colors

Customize status indicators by modifying the `STATUS_COLORS` array:

```bash
declare -A STATUS_COLORS
STATUS_COLORS=(
    ["healthy"]="#28a745"     # Green
    ["degraded"]="#ffc107"    # Yellow
    ["critical"]="#dc3545"    # Red
    ["unknown"]="#6c757d"     # Gray
)
```

## File Structure

```
agents/
├── unified_dashboard_agent.sh     # Main dashboard agent
├── dashboard_launcher.sh          # Launcher script
├── dashboard_data.json           # Dashboard data storage
├── dashboard.html               # Generated dashboard HTML
├── dashboard_server.pid        # Server process ID
├── dashboard_agent.pid          # Agent process ID
├── dashboard_reports/           # Generated reports
│   └── dashboard_report_*.md
└── communication/               # Inter-agent communication
    ├── unified_dashboard_agent_notification.txt
    └── unified_dashboard_agent_completed.txt
```

## Integration with Agent System

### Communication Protocol

The dashboard integrates with the agent ecosystem through:

1. **Status Files**: Each agent maintains a JSON status file
2. **Notification System**: File-based inter-agent communication
3. **Task Orchestrator**: Centralized task management and distribution
4. **Completion Tracking**: Task completion and success monitoring

### Agent Requirements

For full dashboard integration, agents should:

1. **Maintain Status Files**: Create and update `agent_name.json` files
2. **Report Health**: Include health metrics in status files
3. **Handle Notifications**: Process notifications from the orchestrator
4. **Log Activities**: Maintain comprehensive activity logs

### Status File Format

```json
{
  "status": "healthy",
  "last_seen": 1640995200,
  "tasks_completed": 42,
  "health_score": 95,
  "memory_usage": 128,
  "cpu_usage": 15
}
```

## Monitoring & Maintenance

### Health Checks

The dashboard performs automatic health checks:

- **Agent Responsiveness**: Ping agents for activity
- **Resource Usage**: Monitor system resource consumption
- **Task Completion**: Track task success rates
- **Error Detection**: Identify and report system errors

### Log Files

Monitor dashboard activity through log files:

- **Agent Log**: `unified_dashboard_agent.log`
- **Launcher Log**: `dashboard_launcher.log`
- **System Logs**: Integration with system logging

### Performance Optimization

- **Caching**: Dashboard data is cached and updated periodically
- **Efficient Updates**: Only changed data triggers HTML regeneration
- **Resource Monitoring**: Automatic resource usage tracking
- **Background Processing**: Non-blocking dashboard operations

## Troubleshooting

### Common Issues

#### Dashboard Not Starting

```bash
# Check if port 8080 is available
lsof -i :8080

# Kill conflicting processes
kill -9 <PID>

# Restart dashboard
./dashboard_launcher.sh restart
```

#### Agents Not Showing

```bash
# Check agent status files
ls -la agent_*.json

# Verify agent processes
ps aux | grep agent

# Check agent logs
tail -f agent_*.log
```

#### High Resource Usage

```bash
# Monitor dashboard process
top -p $(cat dashboard_agent.pid)

# Check update frequency
# Reduce UPDATE_INTERVAL in unified_dashboard_agent.sh

# Restart with lower frequency
./dashboard_launcher.sh restart
```

### Debug Mode

Enable debug logging by modifying the log level in the dashboard agent:

```bash
# In unified_dashboard_agent.sh
LOG_LEVEL="DEBUG"  # Options: DEBUG, INFO, WARN, ERROR
```

## Security Considerations

### Access Control

- **Local Access Only**: Dashboard runs on localhost by default
- **No Authentication**: Consider adding authentication for production use
- **Firewall Rules**: Ensure proper firewall configuration

### Data Protection

- **Log Rotation**: Implement log rotation for long-term operation
- **Sensitive Data**: Avoid logging sensitive information
- **File Permissions**: Restrict access to dashboard files

## Future Enhancements

### Planned Features

- **Authentication System**: User login and role-based access
- **Alert Notifications**: Email/SMS alerts for critical events
- **Historical Analytics**: Long-term performance trend analysis
- **Custom Dashboards**: User-configurable dashboard layouts
- **API Integration**: REST API for external system integration
- **Mobile App**: Native mobile dashboard application

### Extensibility

- **Plugin System**: Modular dashboard components
- **Custom Metrics**: User-defined monitoring metrics
- **Third-party Integration**: Support for external monitoring tools
- **Multi-environment**: Support for multiple workspace environments

## Contributing

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Code Standards

- Follow bash best practices
- Include comprehensive error handling
- Add detailed logging
- Document all functions and variables
- Test all changes before committing

## License

This dashboard system is part of the Quantum Workspace Agent ecosystem.

## Support

For issues and questions:

1. Check the troubleshooting section
2. Review log files for error messages
3. Verify agent integration requirements
4. Contact the development team

---

**Dashboard Version**: 2.0
**Last Updated**: $(date)
**Compatibility**: Quantum Workspace Agent System v2.0+
