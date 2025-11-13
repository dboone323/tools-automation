# System Health Monitoring

A comprehensive system health monitoring and alerting platform for the Tools Automation ecosystem. This system provides real-time monitoring, performance regression detection, predictive maintenance, and automated reporting.

## Features

- **Real-time System Monitoring**: CPU, memory, disk, and network metrics
- **Performance Tracking**: Response times, throughput, and error rates
- **Automated Alerting**: Configurable thresholds with multiple notification channels
- **Performance Regression Detection**: Statistical analysis to detect performance degradation
- **Predictive Maintenance**: Trend analysis and maintenance predictions
- **Health Dashboards**: Web-based dashboard for visualizing system health
- **Automated Reporting**: Daily and weekly health reports with notifications
- **REST API**: Programmatic access to monitoring data

## Quick Start

### 1. Initialize the System

```bash
cd monitoring/
./start_monitoring.sh init
```

### 2. Start Monitoring

```bash
./start_monitoring.sh start
```

This will start:

- Monitoring daemon (collects metrics every 60 seconds)
- API server (serves dashboard and data on port 8081)
- Automated tasks (daily reports, maintenance analysis)

### 3. Access Dashboard

Open your browser to: http://localhost:8081

## Architecture

```
monitoring/
├── health_monitor.sh          # Main monitoring daemon
├── monitoring_api.py          # REST API server
├── performance_regression.py  # Regression detection
├── predictive_maintenance.py  # Maintenance predictions
├── health_reporter.py         # Automated reporting
├── start_monitoring.sh        # Startup script
├── config.json                # Configuration
├── metrics/                   # Collected metrics
├── alerts/                    # Generated alerts
├── reports/                   # Health reports
├── dashboard/                 # Web dashboard files
└── predictions/               # Maintenance predictions
```

## Configuration

Edit `config.json` to customize:

```json
{
  "monitoring": {
    "intervals": {
      "system_check": 60,
      "performance_check": 300
    },
    "thresholds": {
      "cpu_usage_percent": 80,
      "memory_usage_percent": 85,
      "response_time_ms": 500
    }
  },
  "alerting": {
    "channels": {
      "email": {
        "enabled": true,
        "recipients": ["admin@example.com"]
      },
      "slack": {
        "enabled": true,
        "webhook_url": "https://hooks.slack.com/..."
      }
    }
  }
}
```

## API Endpoints

- `GET /api/health` - Health check
- `GET /api/metrics` - Latest system metrics
- `GET /api/metrics/history?hours=24` - Historical metrics
- `GET /api/alerts` - Active alerts
- `GET /api/baselines` - Performance baselines
- `GET /api/reports` - Available reports
- `GET /api/services` - Service status
- `GET /api/stats` - Monitoring statistics

## Command Line Tools

### Monitoring Daemon

```bash
./health_monitor.sh status     # Show status
./health_monitor.sh start      # Start daemon
./health_monitor.sh stop       # Stop daemon
./health_monitor.sh collect    # Collect metrics manually
./health_monitor.sh baseline   # Generate baselines
./health_monitor.sh report     # Generate daily report
```

### Performance Analysis

```bash
python3 performance_regression.py analyze    # Detect regressions
python3 performance_regression.py report     # Generate regression report
```

### Predictive Maintenance

```bash
python3 predictive_maintenance.py analyze    # Analyze maintenance needs
```

### Health Reporting

```bash
python3 health_reporter.py generate 2024-01-15  # Generate specific date report
python3 health_reporter.py send                 # Generate and send today's report
```

## Automated Tasks

The system sets up automated tasks via cron:

- **Daily Reports**: 6:00 AM - Generate and send daily health reports
- **Weekly Maintenance**: 7:00 AM Monday - Predictive maintenance analysis
- **Performance Checks**: 8:00 AM - Regression detection
- **Data Cleanup**: 2:00 AM - Remove old monitoring data

## Alert Types

### System Alerts

- High CPU usage (>80%)
- High memory usage (>85%)
- High disk usage (>90%)
- Network connectivity issues

### Performance Alerts

- Slow response times (>500ms)
- High error rates (>5%)
- Throughput degradation
- Service unavailability

### Predictive Alerts

- Performance regression trends
- Maintenance predictions
- Capacity warnings

## Health Score

The system calculates a health score (0-100) based on:

- **System Health (40%)**: CPU, memory, disk usage
- **Performance (40%)**: Response times, error rates
- **Alerts (20%)**: Number and severity of alerts

## Integration

### Slack Notifications

Configure webhook in `config.json`:

```json
{
  "alerting": {
    "channels": {
      "slack": {
        "enabled": true,
        "webhook_url": "https://hooks.slack.com/...",
        "channel": "#alerts"
      }
    }
  }
}
```

### Email Notifications

Configure SMTP in `config.json`:

```json
{
  "alerting": {
    "channels": {
      "email": {
        "enabled": true,
        "smtp_server": "smtp.gmail.com",
        "smtp_port": 587,
        "recipients": ["admin@example.com"]
      }
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **Dashboard not loading**

   - Check if API server is running: `ps aux | grep monitoring_api.py`
   - Check port 8081 availability: `lsof -i :8081`
   - Check logs: `tail -f monitoring/api.log`

2. **No metrics being collected**

   - Check monitoring daemon: `./health_monitor.sh status`
   - Check permissions for metric directories
   - Check system monitoring tools availability

3. **Alerts not sending**
   - Verify configuration in `config.json`
   - Check webhook URLs and credentials
   - Check network connectivity

### Logs

- `monitoring.log` - Main monitoring daemon logs
- `api.log` - API server logs
- `alerts/` - JSON alert files with timestamps
- `reports/` - Generated health reports

### Manual Data Collection

```bash
# Collect current metrics
./health_monitor.sh collect

# Check current status
./health_monitor.sh status

# Generate manual report
./health_monitor.sh report
```

## Performance Baselines

The system automatically generates performance baselines after collecting sufficient data (minimum 100 samples). Baselines include:

- Average values for all metrics
- 95th percentile values
- Standard deviations
- Trend analysis confidence

## Maintenance Mode

To perform maintenance on the monitoring system:

```bash
# Stop all components
./start_monitoring.sh stop

# Perform maintenance tasks
# ... maintenance work ...

# Restart all components
./start_monitoring.sh restart
```

## Backup and Recovery

Monitoring data can be backed up:

```bash
# Manual backup
tar -czf monitoring_backup_$(date +%Y%m%d).tar.gz monitoring/

# Automated backup (configured in config.json)
# Backs up to ../backups/monitoring/ weekly
```

## Security Considerations

- API server runs on localhost by default
- Configure authentication in `config.json` for production use
- Regularly rotate alert webhook tokens
- Monitor access to monitoring data
- Use HTTPS for production deployments

## Contributing

When adding new monitoring features:

1. Update `config.json` schema
2. Add API endpoints in `monitoring_api.py`
3. Update dashboard if needed
4. Add CLI commands to appropriate scripts
5. Update this documentation

## Support

For issues and questions:

1. Check logs in the `monitoring/` directory
2. Review configuration in `config.json`
3. Check system resources and permissions
4. Review automated task schedules

## License

This monitoring system is part of the Tools Automation project.
