# System Monitor Plugin

A comprehensive system monitoring plugin for the Tools Automation ecosystem that provides real-time system health tracking, alerting, and performance metrics.

## Features

- **Real-time Monitoring**: Continuous tracking of CPU, memory, disk, and network usage
- **Configurable Alerts**: Customizable thresholds for system resource alerts
- **Webhook Integration**: Send alerts to Slack, Discord, or other webhook services
- **Prometheus Support**: Optional metrics export for monitoring dashboards
- **Historical Data**: Maintains metrics history for trend analysis
- **Comprehensive Reports**: Generate detailed system health reports

## Installation

1. Copy the plugin files to your Tools Automation plugins directory
2. Install required dependencies:
   ```bash
   pip install psutil requests
   ```
3. Configure the plugin in your plugin registry

## Configuration

Create a `plugin.json` configuration file:

```json
{
  "name": "System Monitor",
  "version": "1.0.0",
  "description": "Comprehensive system monitoring and alerting",
  "author": "Tools Automation Community",
  "main": "system_monitor.py",
  "config": {
    "check_interval": 60,
    "alert_thresholds": {
      "cpu_percent": 80,
      "memory_percent": 85,
      "disk_percent": 90
    },
    "webhook_url": "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK",
    "enable_prometheus": false,
    "prometheus_port": 9091
  },
  "permissions": ["system_info", "network_access"],
  "hooks": ["startup", "shutdown", "health_check", "performance_alert"]
}
```

## Configuration Options

| Option                            | Type    | Default | Description                          |
| --------------------------------- | ------- | ------- | ------------------------------------ |
| `check_interval`                  | number  | 60      | Monitoring check interval in seconds |
| `alert_thresholds.cpu_percent`    | number  | 80      | CPU usage alert threshold (%)        |
| `alert_thresholds.memory_percent` | number  | 85      | Memory usage alert threshold (%)     |
| `alert_thresholds.disk_percent`   | number  | 90      | Disk usage alert threshold (%)       |
| `webhook_url`                     | string  | null    | Webhook URL for alerts               |
| `enable_prometheus`               | boolean | false   | Enable Prometheus metrics export     |
| `prometheus_port`                 | number  | 9091    | Prometheus metrics port              |

## Usage

### Basic Usage

```python
from system_monitor import SystemMonitor

config = {
    "check_interval": 30,
    "alert_thresholds": {
        "cpu_percent": 80,
        "memory_percent": 85,
        "disk_percent": 90
    }
}

monitor = SystemMonitor(config)
monitor.start_monitoring()

# Get current status
status = monitor.get_status()
print(f"Monitoring active: {status['active']}")

# Generate system report
report = monitor.generate_report()
print(json.dumps(report, indent=2))
```

### Plugin Integration

The plugin integrates with the Tools Automation ecosystem through standard plugin hooks:

- **startup**: Initialize monitoring on system startup
- **shutdown**: Gracefully stop monitoring on system shutdown
- **health_check**: Provide system health status
- **performance_alert**: Trigger alerts based on performance metrics

## Alert Examples

The plugin sends structured alerts via webhook when thresholds are exceeded:

```json
{
  "text": "🚨 System Monitor Alert",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "🚨 System Alert"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "• High CPU usage: 85.2%\n• High memory usage: 87.1%"
      }
    },
    {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "Timestamp: 2024-01-15T10:30:45.123456"
        }
      ]
    }
  ]
}
```

## Prometheus Integration

When Prometheus support is enabled, the plugin exposes metrics at `http://localhost:9091/metrics`:

```
# HELP cpu_percent Current CPU usage percentage
# TYPE cpu_percent gauge
cpu_percent 45.2

# HELP memory_percent Current memory usage percentage
# TYPE memory_percent gauge
memory_percent 67.8

# HELP disk_percent Current disk usage percentage
# TYPE disk_percent gauge
disk_percent 72.1
```

## System Information

The plugin provides detailed system information including:

- CPU: Core count, frequency, logical processors
- Memory: Total and available memory
- Disk: Total and free disk space
- Network: Available network interfaces
- System: OS version, hostname

## Dependencies

- `psutil`: System and process utilities
- `requests`: HTTP library for webhooks (optional)

## Permissions Required

- `system_info`: Access to system metrics and information
- `network_access`: Send alerts via webhooks

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This plugin is part of the Tools Automation ecosystem and follows the same license terms.

## Support

For issues and questions:

- Create an issue in the Tools Automation repository
- Check the community forums
- Review the contribution guidelines
