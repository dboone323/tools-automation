# Tools Automation Monitoring Setup

This directory contains the monitoring stack for the Tools Automation project, providing comprehensive observability and health monitoring.

## 🏗️ Architecture

The monitoring stack consists of:

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Uptime Kuma**: Service uptime monitoring
- **Node Exporter**: System metrics collection
- **Metrics Exporter**: Custom Python application for agent metrics

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Python 3.8+ (for metrics exporter)

### Start Monitoring Stack

```bash
# Start all monitoring services
./monitoring.sh start

# Or use docker-compose directly
docker-compose -f docker-compose.monitoring.yml up -d
```

### Access Services

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Uptime Kuma**: http://localhost:3001
- **Node Exporter**: http://localhost:9100

### Start Metrics Exporter

```bash
# Install dependencies
pip install flask prometheus_client

# Start the metrics exporter
python metrics_exporter.py
```

Metrics will be available at: http://localhost:8080/metrics

## 📊 Dashboards

### System Overview Dashboard

Pre-configured dashboard showing:

- System CPU and memory usage
- Disk usage statistics
- Network traffic
- Agent status indicators

### Custom Dashboards

Create additional dashboards in Grafana for:

- Agent performance metrics
- Task completion rates
- Error tracking
- Resource utilization

## 🔧 Configuration

### Prometheus Configuration

Edit `monitoring/prometheus.yml` to add new scrape targets:

```yaml
- job_name: "my-new-service"
  static_configs:
    - targets: ["localhost:9091"]
  scrape_interval: 30s
```

### Grafana Data Sources

Additional data sources can be configured in `monitoring/grafana/provisioning/datasources/`

### Agent Status

Update `agent_status.json` to reflect current agent states:

```json
{
  "agent_name": {
    "status": "running|stopped",
    "tasks_completed": 0,
    "tasks_failed": 0,
    "memory_usage": 0,
    "cpu_usage": 0.0
  }
}
```

## 📈 Metrics

### Agent Metrics

- `agent_status{agent_name, agent_type}`: Agent operational status (0=down, 1=up)
- `agent_tasks_completed_total{agent_name, task_type}`: Tasks completed
- `agent_tasks_failed_total{agent_name, task_type}`: Tasks failed
- `agent_memory_usage_bytes{agent_name}`: Memory usage in bytes
- `agent_cpu_usage_percent{agent_name}`: CPU usage percentage

### System Metrics

- `system_agents_total`: Total registered agents
- `system_tasks_queued`: Tasks waiting in queue
- `system_tasks_processing`: Tasks currently being processed

## 🛠️ Management Commands

```bash
# Start monitoring stack
./monitoring.sh start

# Stop monitoring stack
./monitoring.sh stop

# Restart monitoring stack
./monitoring.sh restart

# Check service status
./monitoring.sh status

# View logs
./monitoring.sh logs [service]

# Clean up (removes all data)
./monitoring.sh cleanup
```

## 🔍 Troubleshooting

### Services Not Starting

1. Check Docker is running: `docker info`
2. Check port conflicts: `lsof -i :3000,9090,3001,9100`
3. View logs: `./monitoring.sh logs`

### Metrics Not Appearing

1. Verify metrics exporter is running: `curl http://localhost:8080/metrics`
2. Check Prometheus targets: http://localhost:9090/targets
3. Validate JSON format in `agent_status.json`

### Grafana Not Loading

1. Wait 30 seconds after startup for initialization
2. Check Grafana logs: `./monitoring.sh logs grafana`
3. Reset admin password if needed

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Uptime Kuma Documentation](https://github.com/louislam/uptime-kuma/wiki)
- [Prometheus Python Client](https://github.com/prometheus/client_python)

## 🤝 Contributing

When adding new metrics:

1. Define metrics in `metrics_exporter.py`
2. Update `agent_status.json` structure if needed
3. Add visualizations to Grafana dashboards
4. Update this documentation

---

_Last updated: November 11, 2025_
