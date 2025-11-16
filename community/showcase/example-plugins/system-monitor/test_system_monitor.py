#!/usr/bin/env python3
"""
Test suite for System Monitor Plugin
"""

import unittest
from unittest.mock import patch
from datetime import datetime
from system_monitor import (
    SystemMonitor,
    SystemMetrics,
    get_plugin_info,
    get_required_permissions,
    get_supported_hooks,
)


class TestSystemMonitor(unittest.TestCase):
    """Test cases for SystemMonitor class."""

    def setUp(self):
        """Set up test fixtures."""
        self.config = {
            "check_interval": 1,
            "alert_thresholds": {
                "cpu_percent": 50,
                "memory_percent": 60,
                "disk_percent": 70,
            },
            "webhook_url": "https://example.com/webhook",
            "enable_prometheus": False,
        }
        self.monitor = SystemMonitor(self.config)

    def test_initialization(self):
        """Test monitor initialization."""
        self.assertEqual(self.monitor.check_interval, 1)
        self.assertEqual(self.monitor.alert_thresholds["cpu_percent"], 50)
        self.assertFalse(self.monitor.monitoring_active)
        self.assertEqual(len(self.monitor.metrics_history), 0)

    @patch("psutil.cpu_percent")
    @patch("psutil.virtual_memory")
    @patch("psutil.disk_usage")
    @patch("psutil.net_io_counters")
    @patch("psutil.getloadavg")
    @patch("psutil.pids")
    def test_collect_metrics(
        self, mock_pids, mock_loadavg, mock_net, mock_disk, mock_memory, mock_cpu
    ):
        """Test metrics collection."""
        # Mock return values
        mock_cpu.return_value = 45.5
        mock_memory.return_value.percent = 67.8
        mock_disk.return_value.percent = 72.1
        mock_net.return_value.bytes_sent = 1000000
        mock_net.return_value.bytes_recv = 2000000
        mock_loadavg.return_value = (1.5, 1.2, 1.0)
        mock_pids.return_value = [1, 2, 3, 4, 5]

        metrics = self.monitor.collect_metrics()

        self.assertIsInstance(metrics, SystemMetrics)
        self.assertEqual(metrics.cpu_percent, 45.5)
        self.assertEqual(metrics.memory_percent, 67.8)
        self.assertEqual(metrics.disk_percent, 72.1)
        self.assertEqual(metrics.network_bytes_sent, 1000000)
        self.assertEqual(metrics.network_bytes_recv, 2000000)
        self.assertEqual(metrics.load_average, (1.5, 1.2, 1.0))
        self.assertEqual(metrics.process_count, 5)

    def test_check_thresholds(self):
        """Test threshold checking."""
        # Create test metrics
        metrics = SystemMetrics(
            timestamp=datetime.now(),
            cpu_percent=60,  # Above threshold
            memory_percent=50,  # Below threshold
            disk_percent=80,  # Above threshold
            network_bytes_sent=1000,
            network_bytes_recv=2000,
            load_average=(1, 1, 1),
            process_count=100,
        )

        alerts = self.monitor.check_thresholds(metrics)

        self.assertIn("High CPU usage: 60.0%", alerts)
        self.assertIn("Low disk space: 80.0% used", alerts)
        self.assertNotIn("memory", " ".join(alerts))

    @patch("requests.post")
    def test_send_alert(self, mock_post):
        """Test alert sending."""
        mock_post.return_value.raise_for_status.return_value = None

        alerts = ["High CPU usage: 90.0%", "High memory usage: 95.0%"]
        self.monitor.send_alert(alerts)

        # Verify webhook was called
        mock_post.assert_called_once()
        call_args = mock_post.call_args
        self.assertEqual(call_args[0][0], self.config["webhook_url"])

        # Verify message structure
        message = call_args[1]["json"]
        self.assertIn("🚨 System Monitor Alert", message["text"])
        self.assertIn("High CPU usage", message["blocks"][1]["text"]["text"])

    def test_store_metrics(self):
        """Test metrics storage."""
        metrics = SystemMetrics(
            timestamp=datetime.now(),
            cpu_percent=50,
            memory_percent=60,
            disk_percent=70,
            network_bytes_sent=1000,
            network_bytes_recv=2000,
            load_average=(1, 1, 1),
            process_count=100,
        )

        self.monitor.store_metrics(metrics)
        self.assertEqual(len(self.monitor.metrics_history), 1)
        self.assertEqual(self.monitor.metrics_history[0], metrics)

    def test_metrics_history_limit(self):
        """Test metrics history size limit."""
        # Add more metrics than max_history_size
        for i in range(self.monitor.max_history_size + 10):
            metrics = SystemMetrics(
                timestamp=datetime.now(),
                cpu_percent=i,
                memory_percent=60,
                disk_percent=70,
                network_bytes_sent=1000,
                network_bytes_recv=2000,
                load_average=(1, 1, 1),
                process_count=100,
            )
            self.monitor.store_metrics(metrics)

        # Should maintain max_history_size
        self.assertEqual(
            len(self.monitor.metrics_history), self.monitor.max_history_size
        )

    def test_generate_report_no_metrics(self):
        """Test report generation with no metrics."""
        report = self.monitor.generate_report()
        self.assertIn("error", report)
        self.assertEqual(report["error"], "No metrics available")

    def test_generate_report_with_metrics(self):
        """Test report generation with metrics."""
        # Add some test metrics
        for i in range(3):
            metrics = SystemMetrics(
                timestamp=datetime.now(),
                cpu_percent=40 + i * 10,  # 40, 50, 60
                memory_percent=50 + i * 5,  # 50, 55, 60
                disk_percent=70,
                network_bytes_sent=1000,
                network_bytes_recv=2000,
                load_average=(1, 1, 1),
                process_count=100,
            )
            self.monitor.store_metrics(metrics)

        report = self.monitor.generate_report()

        self.assertIn("current_metrics", report)
        self.assertIn("averages", report)
        self.assertIn("system_info", report)
        self.assertEqual(report["averages"]["cpu_percent"], 50.0)  # (40+50+60)/3
        self.assertEqual(report["averages"]["memory_percent"], 55.0)  # (50+55+60)/3

    def test_get_status(self):
        """Test status retrieval."""
        status = self.monitor.get_status()

        self.assertIn("active", status)
        self.assertIn("check_interval", status)
        self.assertIn("metrics_count", status)
        self.assertIn("alert_thresholds", status)
        self.assertEqual(status["active"], False)
        self.assertEqual(status["check_interval"], 1)

    def test_plugin_info_functions(self):
        """Test plugin interface functions."""
        info = get_plugin_info()
        self.assertEqual(info["name"], "System Monitor")
        self.assertEqual(info["version"], "1.0.0")

        permissions = get_required_permissions()
        self.assertIn("system_info", permissions)
        self.assertIn("network_access", permissions)

        hooks = get_supported_hooks()
        self.assertIn("startup", hooks)
        self.assertIn("shutdown", hooks)
        self.assertIn("health_check", hooks)


class TestSystemMetrics(unittest.TestCase):
    """Test cases for SystemMetrics dataclass."""

    def test_system_metrics_creation(self):
        """Test SystemMetrics object creation."""
        timestamp = datetime.now()
        metrics = SystemMetrics(
            timestamp=timestamp,
            cpu_percent=45.5,
            memory_percent=67.8,
            disk_percent=72.1,
            network_bytes_sent=1000000,
            network_bytes_recv=2000000,
            load_average=(1.5, 1.2, 1.0),
            process_count=150,
        )

        self.assertEqual(metrics.timestamp, timestamp)
        self.assertEqual(metrics.cpu_percent, 45.5)
        self.assertEqual(metrics.memory_percent, 67.8)
        self.assertEqual(metrics.disk_percent, 72.1)
        self.assertEqual(metrics.network_bytes_sent, 1000000)
        self.assertEqual(metrics.network_bytes_recv, 2000000)
        self.assertEqual(metrics.load_average, (1.5, 1.2, 1.0))
        self.assertEqual(metrics.process_count, 150)


if __name__ == "__main__":
    unittest.main()
