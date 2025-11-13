"""
Sample Plugin - Demonstrates MCP Plugin Architecture

This plugin shows how to create plugins for the MCP server with monitoring,
notification, and data processing capabilities.
"""

import logging
import time
from typing import Any, Dict, List
from plugin_manager import PluginBase, PluginMetadata


class SamplePlugin(PluginBase):
    """Sample plugin implementation"""

    def __init__(self, config: Dict[str, Any] = None):
        super().__init__(config)
        self.monitoring_data = []
        self.last_notification = 0

    @property
    def metadata(self) -> PluginMetadata:
        """Plugin metadata"""
        return self._get_metadata()

    def _get_metadata(self) -> PluginMetadata:
        """Get plugin metadata"""
        return PluginMetadata(
            name="sample_plugin",
            version="1.0.0",
            description="Sample plugin demonstrating the MCP plugin architecture",
            author="Tools Automation Team",
            license="MIT",
            capabilities=["monitoring", "notification", "data_processing"],
            tags=["sample", "demo", "monitoring"],
        )

    def initialize(self) -> None:
        """Initialize the plugin"""
        self.logger.info("Initializing Sample Plugin")

        # Validate configuration
        enabled_features = self.config.get("enabled_features", ["monitoring"])
        notification_interval = self.config.get("notification_interval", 300)
        max_retries = self.config.get("max_retries", 3)

        self.logger.info(f"Enabled features: {enabled_features}")
        self.logger.info(f"Notification interval: {notification_interval}s")
        self.logger.info(f"Max retries: {max_retries}")

        # Initialize monitoring data
        self.monitoring_data = []
        self.last_notification = time.time()

        self.logger.info("Sample Plugin initialized successfully")

    def shutdown(self) -> None:
        """Shutdown the plugin"""
        self.logger.info("Shutting down Sample Plugin")

        # Clean up resources
        self.monitoring_data.clear()

        self.logger.info("Sample Plugin shutdown complete")

    def is_healthy(self) -> bool:
        """Check plugin health"""
        return True  # Simple health check

    def get_capabilities(self) -> List[str]:
        """Get plugin capabilities"""
        return self.metadata.capabilities

    def handle_event(self, event_type: str, data: Dict[str, Any]) -> None:
        """Handle system events"""
        self.logger.info(f"Received event: {event_type}")

        # Process different event types
        if event_type == "agent_status_change":
            self._handle_agent_status_change(data)
        elif event_type == "task_completed":
            self._handle_task_completed(data)
        elif event_type == "system_health_check":
            self._handle_system_health_check(data)
        else:
            self.logger.debug(f"Unhandled event type: {event_type}")

    def _handle_agent_status_change(self, data: Dict[str, Any]) -> None:
        """Handle agent status change events"""
        agent_name = data.get("agent_name", "unknown")
        old_status = data.get("old_status", "unknown")
        new_status = data.get("new_status", "unknown")

        self.logger.info(
            f"Agent {agent_name} status changed: {old_status} -> {new_status}"
        )

        # Store monitoring data
        self.monitoring_data.append(
            {
                "timestamp": time.time(),
                "type": "agent_status_change",
                "agent_name": agent_name,
                "old_status": old_status,
                "new_status": new_status,
            }
        )

        # Check if notification is needed
        self._check_notification_threshold()

    def _handle_task_completed(self, data: Dict[str, Any]) -> None:
        """Handle task completion events"""
        task_id = data.get("task_id", "unknown")
        agent_name = data.get("agent_name", "unknown")
        success = data.get("success", False)
        duration = data.get("duration", 0)

        self.logger.info(
            f"Task {task_id} completed by {agent_name}: {'success' if success else 'failed'} ({duration}s)"
        )

        # Store monitoring data
        self.monitoring_data.append(
            {
                "timestamp": time.time(),
                "type": "task_completed",
                "task_id": task_id,
                "agent_name": agent_name,
                "success": success,
                "duration": duration,
            }
        )

    def _handle_system_health_check(self, data: Dict[str, Any]) -> None:
        """Handle system health check events"""
        health_score = data.get("health_score", 0)
        total_agents = data.get("total_agents", 0)
        healthy_agents = data.get("healthy_agents", 0)

        self.logger.info(
            f"System health check: {healthy_agents}/{total_agents} agents healthy (score: {health_score})"
        )

        # Store monitoring data
        self.monitoring_data.append(
            {
                "timestamp": time.time(),
                "type": "system_health_check",
                "health_score": health_score,
                "total_agents": total_agents,
                "healthy_agents": healthy_agents,
            }
        )

    def _check_notification_threshold(self) -> None:
        """Check if notification threshold is reached"""
        notification_interval = self.config.get("notification_interval", 300)
        current_time = time.time()

        if current_time - self.last_notification >= notification_interval:
            self._send_notification()
            self.last_notification = current_time

    def _send_notification(self) -> None:
        """Send notification with monitoring summary"""
        if "notification" not in self.config.get("enabled_features", []):
            return

        # Generate summary
        recent_events = [
            event for event in self.monitoring_data[-10:]
        ]  # Last 10 events

        summary = {
            "plugin": "sample_plugin",
            "timestamp": time.time(),
            "events_count": len(recent_events),
            "summary": self._generate_summary(recent_events),
        }

        self.logger.info(f"Sending notification: {summary}")

        # In a real plugin, this would send to external systems
        # For demo purposes, just log it

    def _generate_summary(self, events: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Generate monitoring summary"""
        summary = {
            "total_events": len(events),
            "event_types": {},
            "agent_status_changes": 0,
            "task_completions": 0,
            "successful_tasks": 0,
            "failed_tasks": 0,
        }

        for event in events:
            event_type = event.get("type", "unknown")
            summary["event_types"][event_type] = (
                summary["event_types"].get(event_type, 0) + 1
            )

            if event_type == "agent_status_change":
                summary["agent_status_changes"] += 1
            elif event_type == "task_completed":
                summary["task_completions"] += 1
                if event.get("success", False):
                    summary["successful_tasks"] += 1
                else:
                    summary["failed_tasks"] += 1

        return summary

    def get_monitoring_data(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Get recent monitoring data"""
        return self.monitoring_data[-limit:]

    def clear_monitoring_data(self) -> None:
        """Clear monitoring data"""
        self.monitoring_data.clear()
        self.logger.info("Monitoring data cleared")

    def get_stats(self) -> Dict[str, Any]:
        """Get plugin statistics"""
        return {
            "monitoring_events": len(self.monitoring_data),
            "last_notification": self.last_notification,
            "config": self.config,
            "healthy": self.is_healthy(),
        }


# Plugin instance creation function (required by plugin system)
def create_plugin(config: Dict[str, Any] = None) -> SamplePlugin:
    """Create plugin instance"""
    return SamplePlugin(config)
