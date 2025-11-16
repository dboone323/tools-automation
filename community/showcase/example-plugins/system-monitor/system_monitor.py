#!/usr/bin/env python3
"""
System Monitor Plugin
Comprehensive system monitoring with alerts and performance tracking.
"""

import psutil
import logging
import time
import threading
from datetime import datetime
from typing import Dict, Any, List
from dataclasses import dataclass

try:
    import requests

    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False

# Plugin metadata
PLUGIN_INFO = {
    "name": "System Monitor",
    "version": "1.0.0",
    "description": "Comprehensive system monitoring and alerting",
    "author": "Tools Automation Community",
}


@dataclass
class SystemMetrics:
    """Data class for system metrics."""

    timestamp: datetime
    cpu_percent: float
    memory_percent: float
    disk_percent: float
    network_bytes_sent: int
    network_bytes_recv: int
    load_average: tuple
    process_count: int


class SystemMonitor:
    """Main plugin class for system monitoring."""

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.check_interval = config.get("check_interval", 60)
        self.alert_thresholds = config.get("alert_thresholds", {})
        self.webhook_url = config.get("webhook_url")
        self.enable_prometheus = config.get("enable_prometheus", False)
        self.prometheus_port = config.get("prometheus_port", 9091)

        self.monitoring_active = False
        self.metrics_history: List[SystemMetrics] = []
        self.max_history_size = 1000

        # Prometheus metrics (if enabled)
        self.prometheus_metrics = {}

    def collect_metrics(self) -> SystemMetrics:
        """Collect current system metrics."""
        return SystemMetrics(
            timestamp=datetime.now(),
            cpu_percent=psutil.cpu_percent(interval=1),
            memory_percent=psutil.virtual_memory().percent,
            disk_percent=psutil.disk_usage("/").percent,
            network_bytes_sent=psutil.net_io_counters().bytes_sent,
            network_bytes_recv=psutil.net_io_counters().bytes_recv,
            load_average=psutil.getloadavg(),
            process_count=len(psutil.pids()),
        )

    def check_thresholds(self, metrics: SystemMetrics) -> List[str]:
        """Check if metrics exceed configured thresholds."""
        alerts = []

        if metrics.cpu_percent > self.alert_thresholds.get("cpu_percent", 80):
            alerts.append(f"High CPU usage: {metrics.cpu_percent:.1f}%")

        if metrics.memory_percent > self.alert_thresholds.get("memory_percent", 85):
            alerts.append(f"High memory usage: {metrics.memory_percent:.1f}%")

        if metrics.disk_percent > self.alert_thresholds.get("disk_percent", 90):
            alerts.append(f"Low disk space: {metrics.disk_percent:.1f}% used")

        return alerts

    def send_alert(self, alerts: List[str]):
        """Send alerts via configured webhook."""
        if not alerts or not self.webhook_url or not REQUESTS_AVAILABLE:
            return

        message = {
            "text": "🚨 System Monitor Alert",
            "blocks": [
                {
                    "type": "header",
                    "text": {"type": "plain_text", "text": "🚨 System Alert"},
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "\n".join(f"• {alert}" for alert in alerts),
                    },
                },
                {
                    "type": "context",
                    "elements": [
                        {
                            "type": "mrkdwn",
                            "text": f"Timestamp: {datetime.now().isoformat()}",
                        }
                    ],
                },
            ],
        }

        try:
            response = requests.post(
                self.webhook_url,
                json=message,
                headers={"Content-Type": "application/json"},
                timeout=10,
            )
            response.raise_for_status()
            self.logger.info(f"Alert sent successfully: {len(alerts)} alerts")
        except Exception as e:
            self.logger.error(f"Failed to send alert: {e}")

    def update_prometheus_metrics(self, metrics: SystemMetrics):
        """Update Prometheus metrics if enabled."""
        if not self.enable_prometheus:
            return

        # This would integrate with prometheus_client library
        # For now, just store in memory
        self.prometheus_metrics.update(
            {
                "cpu_percent": metrics.cpu_percent,
                "memory_percent": metrics.memory_percent,
                "disk_percent": metrics.disk_percent,
                "network_bytes_sent": metrics.network_bytes_sent,
                "network_bytes_recv": metrics.network_bytes_recv,
                "load_average_1m": metrics.load_average[0],
                "load_average_5m": metrics.load_average[1],
                "load_average_15m": metrics.load_average[2],
                "process_count": metrics.process_count,
            }
        )

    def store_metrics(self, metrics: SystemMetrics):
        """Store metrics in history."""
        self.metrics_history.append(metrics)

        # Maintain max history size
        if len(self.metrics_history) > self.max_history_size:
            self.metrics_history.pop(0)

    def get_system_info(self) -> Dict[str, Any]:
        """Get detailed system information."""
        return {
            "cpu": {
                "cores": psutil.cpu_count(),
                "cores_logical": psutil.cpu_count(logical=True),
                "frequency": psutil.cpu_freq().current if psutil.cpu_freq() else None,
            },
            "memory": {
                "total": psutil.virtual_memory().total,
                "available": psutil.virtual_memory().available,
            },
            "disk": {
                "total": psutil.disk_usage("/").total,
                "free": psutil.disk_usage("/").free,
            },
            "network": {"interfaces": list(psutil.net_if_addrs().keys())},
            "system": {
                "os": f"{psutil.os.uname().sysname} {psutil.os.uname().release}",
                "hostname": psutil.os.uname().nodename,
            },
        }

    def generate_report(self) -> Dict[str, Any]:
        """Generate a comprehensive system report."""
        if not self.metrics_history:
            return {"error": "No metrics available"}

        latest = self.metrics_history[-1]
        avg_cpu = sum(m.cpu_percent for m in self.metrics_history) / len(
            self.metrics_history
        )
        avg_memory = sum(m.memory_percent for m in self.metrics_history) / len(
            self.metrics_history
        )

        return {
            "timestamp": datetime.now().isoformat(),
            "current_metrics": {
                "cpu_percent": latest.cpu_percent,
                "memory_percent": latest.memory_percent,
                "disk_percent": latest.disk_percent,
                "load_average": latest.load_average,
                "process_count": latest.process_count,
            },
            "averages": {
                "cpu_percent": round(avg_cpu, 2),
                "memory_percent": round(avg_memory, 2),
            },
            "system_info": self.get_system_info(),
            "alert_thresholds": self.alert_thresholds,
            "metrics_count": len(self.metrics_history),
        }

    def monitoring_loop(self):
        """Main monitoring loop."""
        self.logger.info("Starting system monitoring loop")

        while self.monitoring_active:
            try:
                # Collect metrics
                metrics = self.collect_metrics()

                # Store metrics
                self.store_metrics(metrics)

                # Check thresholds and send alerts
                alerts = self.check_thresholds(metrics)
                if alerts:
                    self.logger.warning(f"System alerts: {alerts}")
                    self.send_alert(alerts)

                # Update Prometheus metrics
                self.update_prometheus_metrics(metrics)

                # Log current status
                self.logger.debug(".1f")

            except Exception as e:
                self.logger.error(f"Error in monitoring loop: {e}")

            # Wait for next check
            time.sleep(self.check_interval)

    def start_monitoring(self):
        """Start the monitoring system."""
        if self.monitoring_active:
            self.logger.warning("Monitoring already active")
            return

        self.logger.info("Starting system monitor")
        self.monitoring_active = True

        # Start monitoring in background thread
        monitor_thread = threading.Thread(target=self.monitoring_loop, daemon=True)
        monitor_thread.start()

        self.logger.info("System monitor started successfully")

    def stop_monitoring(self):
        """Stop the monitoring system."""
        self.logger.info("Stopping system monitor")
        self.monitoring_active = False

    def get_status(self) -> Dict[str, Any]:
        """Get current monitoring status."""
        return {
            "active": self.monitoring_active,
            "check_interval": self.check_interval,
            "metrics_count": len(self.metrics_history),
            "alert_thresholds": self.alert_thresholds,
            "prometheus_enabled": self.enable_prometheus,
            "last_check": (
                self.metrics_history[-1].timestamp.isoformat()
                if self.metrics_history
                else None
            ),
        }


# Plugin interface functions
def initialize_plugin(config: Dict[str, Any]) -> SystemMonitor:
    """Initialize the plugin with configuration."""
    return SystemMonitor(config)


def get_plugin_info() -> Dict[str, str]:
    """Get plugin information."""
    return PLUGIN_INFO


def get_required_permissions() -> List[str]:
    """Get required permissions for this plugin."""
    return ["system_info", "network_access"]


def get_supported_hooks() -> List[str]:
    """Get supported plugin hooks."""
    return ["startup", "shutdown", "health_check", "performance_alert"]


if __name__ == "__main__":
    # Example usage
    config = {
        "check_interval": 30,
        "alert_thresholds": {
            "cpu_percent": 80,
            "memory_percent": 85,
            "disk_percent": 90,
        },
        "webhook_url": "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK",
        "enable_prometheus": False,
    }

    monitor = SystemMonitor(config)
    monitor.start_monitoring()

    try:
        # Keep running for demo
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        monitor.stop_monitoring()
