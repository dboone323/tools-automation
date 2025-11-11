#!/usr/bin/env python3
"""
TODO Monitor
Real-time monitoring and progress tracking for TODO task processing
"""

import os
import json
import time
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Tuple
from collections import defaultdict, Counter
import subprocess


class TodoMonitor:
    """Real-time monitoring system for TODO task processing"""

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.config_dir = workspace_root / "config"
        self.task_queue_file = self.config_dir / "task_queue.json"
        self.agent_status_file = self.config_dir / "agent_status.json"
        self.monitoring_log_file = self.config_dir / "todo_monitoring.json"

        # Monitoring state
        self.last_snapshot = {}
        self.monitoring_active = False
        self.update_interval = 30  # seconds

        # Initialize monitoring log
        self._init_monitoring_log()

    def _init_monitoring_log(self):
        """Initialize monitoring log file"""
        if not self.monitoring_log_file.exists():
            initial_log = {
                "monitoring_start": datetime.now().isoformat(),
                "snapshots": [],
                "alerts": [],
                "metrics": {
                    "total_tasks_processed": 0,
                    "tasks_completed": 0,
                    "tasks_failed": 0,
                    "average_completion_time": 0,
                    "agent_utilization": {},
                    "peak_concurrent_tasks": 0,
                },
            }
            with open(self.monitoring_log_file, "w") as f:
                json.dump(initial_log, f, indent=2)

    def load_task_queue(self) -> Dict[str, Any]:
        """Load current task queue"""
        if not self.task_queue_file.exists():
            return {"tasks": []}

        try:
            with open(self.task_queue_file, "r") as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {"tasks": []}

    def load_agent_status(self) -> Dict[str, Any]:
        """Load current agent status"""
        if not self.agent_status_file.exists():
            return {}

        try:
            with open(self.agent_status_file, "r") as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

    def take_snapshot(self) -> Dict[str, Any]:
        """Take a snapshot of current system state"""
        tasks = self.load_task_queue().get("tasks", [])
        agents = self.load_agent_status()

        snapshot = {
            "timestamp": datetime.now().isoformat(),
            "total_tasks": len(tasks),
            "tasks_by_status": self._count_tasks_by_status(tasks),
            "tasks_by_agent": self._count_tasks_by_agent(tasks),
            "tasks_by_priority": self._count_tasks_by_priority(tasks),
            "agent_workload": self._calculate_agent_workload(agents),
            "system_health": self._assess_system_health(tasks, agents),
            "recent_activity": self._get_recent_activity(tasks),
        }

        return snapshot

    def _count_tasks_by_status(self, tasks: List[Dict[str, Any]]) -> Dict[str, int]:
        """Count tasks by status"""
        status_counts = Counter(task.get("status", "unknown") for task in tasks)
        return dict(status_counts)

    def _count_tasks_by_agent(self, tasks: List[Dict[str, Any]]) -> Dict[str, int]:
        """Count tasks by assigned agent"""
        agent_counts = Counter(
            task.get("assigned_agent", "unassigned") for task in tasks
        )
        return dict(agent_counts)

    def _count_tasks_by_priority(self, tasks: List[Dict[str, Any]]) -> Dict[str, int]:
        """Count tasks by priority level"""
        priority_counts = Counter(task.get("priority", 5) for task in tasks)
        return dict(priority_counts)

    def _calculate_agent_workload(self, agents: Dict[str, Any]) -> Dict[str, Any]:
        """Calculate current agent workload"""
        workload = {}

        # Get current task assignments from task queue
        tasks = self.load_task_queue().get("tasks", [])
        agent_task_counts = Counter(
            task.get("assigned_agent", "unassigned")
            for task in tasks
            if task.get("status") == "in_progress"
        )

        for agent_name, agent_data in agents.get("agents", {}).items():
            current_tasks = agent_task_counts.get(agent_name, 0)
            capacity = 10  # Default capacity, could be configurable
            utilization = (current_tasks / capacity * 100) if capacity > 0 else 0

            workload[agent_name] = {
                "current_tasks": current_tasks,
                "capacity": capacity,
                "utilization_percent": round(utilization, 1),
                "status": agent_data.get("status", "unknown"),
            }

        return workload

    def _assess_system_health(
        self, tasks: List[Dict[str, Any]], agents: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Assess overall system health"""
        health = {
            "overall_status": "healthy",
            "issues": [],
            "warnings": [],
            "metrics": {},
        }

        # Check for stuck tasks (very old pending tasks)
        now = datetime.now()
        stuck_tasks = 0
        for task in tasks:
            if task.get("status") == "pending":
                created_at = task.get("created_at")
                if created_at:
                    try:
                        created_time = datetime.fromisoformat(
                            created_at.replace("Z", "+00:00")
                        )
                        age_hours = (now - created_time).total_seconds() / 3600
                        if age_hours > 24:  # Tasks older than 24 hours
                            stuck_tasks += 1
                    except (ValueError, AttributeError):
                        pass

        if stuck_tasks > 0:
            health["warnings"].append(
                f"{stuck_tasks} tasks pending for more than 24 hours"
            )

        # Check agent utilization
        total_utilization = 0
        active_agents = 0
        for agent_name, workload in self._calculate_agent_workload(agents).items():
            utilization = workload["utilization_percent"]
            total_utilization += utilization
            active_agents += 1

            if utilization > 90:
                health["issues"].append(
                    f"Agent {agent_name} is over-utilized ({utilization}%)"
                )
            elif utilization == 0:
                health["warnings"].append(f"Agent {agent_name} has no active tasks")

        if active_agents > 0:
            avg_utilization = total_utilization / active_agents
            health["metrics"]["average_agent_utilization"] = round(avg_utilization, 1)

            if avg_utilization < 20:
                health["warnings"].append(f"Low agent utilization ({avg_utilization}%)")
            elif avg_utilization > 80:
                health["warnings"].append(
                    f"High agent utilization ({avg_utilization}%)"
                )

        # Overall status determination
        if health["issues"]:
            health["overall_status"] = "critical"
        elif health["warnings"]:
            health["overall_status"] = "warning"

        return health

    def _get_recent_activity(
        self, tasks: List[Dict[str, Any]], hours: int = 1
    ) -> List[Dict[str, Any]]:
        """Get recent task activity"""
        now = datetime.now()
        cutoff = now - timedelta(hours=hours)

        recent_tasks = []
        for task in tasks:
            created_at = task.get("created_at")
            if created_at:
                try:
                    created_time = datetime.fromisoformat(
                        created_at.replace("Z", "+00:00")
                    )
                    if created_time > cutoff:
                        recent_tasks.append(
                            {
                                "id": task.get("id"),
                                "status": task.get("status"),
                                "agent": task.get("assigned_agent"),
                                "created_at": created_at,
                            }
                        )
                except (ValueError, AttributeError):
                    pass

        return recent_tasks[-10:]  # Last 10 recent tasks

    def detect_changes(self, current_snapshot: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Detect changes from last snapshot"""
        changes = []

        if not self.last_snapshot:
            changes.append(
                {
                    "type": "system_start",
                    "message": "Monitoring started",
                    "timestamp": current_snapshot["timestamp"],
                }
            )
            return changes

        # Check task count changes
        prev_total = self.last_snapshot.get("total_tasks", 0)
        curr_total = current_snapshot.get("total_tasks", 0)

        if curr_total != prev_total:
            change_type = "increase" if curr_total > prev_total else "decrease"
            changes.append(
                {
                    "type": f"task_count_{change_type}",
                    "message": f"Task count {change_type}d from {prev_total} to {curr_total}",
                    "delta": curr_total - prev_total,
                    "timestamp": current_snapshot["timestamp"],
                }
            )

        # Check status changes
        prev_status = self.last_snapshot.get("tasks_by_status", {})
        curr_status = current_snapshot.get("tasks_by_status", {})

        for status in set(prev_status.keys()) | set(curr_status.keys()):
            prev_count = prev_status.get(status, 0)
            curr_count = curr_status.get(status, 0)

            if curr_count != prev_count:
                changes.append(
                    {
                        "type": "status_change",
                        "status": status,
                        "message": f"{status} tasks: {prev_count} → {curr_count}",
                        "delta": curr_count - prev_count,
                        "timestamp": current_snapshot["timestamp"],
                    }
                )

        # Check for completed tasks
        prev_pending = prev_status.get("pending", 0)
        curr_pending = curr_status.get("pending", 0)
        completed = prev_pending - curr_pending

        if completed > 0:
            changes.append(
                {
                    "type": "tasks_completed",
                    "message": f"{completed} tasks completed",
                    "count": completed,
                    "timestamp": current_snapshot["timestamp"],
                }
            )

        return changes

    def log_snapshot(self, snapshot: Dict[str, Any], changes: List[Dict[str, Any]]):
        """Log snapshot and changes to monitoring file"""
        try:
            with open(self.monitoring_log_file, "r") as f:
                log_data = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            log_data = {"snapshots": [], "alerts": [], "metrics": {}}

        # Add snapshot
        log_data["snapshots"].append(snapshot)

        # Add alerts for significant changes
        for change in changes:
            if change["type"] in [
                "tasks_completed",
                "task_count_increase",
                "status_change",
            ]:
                log_data["alerts"].append(change)

        # Keep only last 100 snapshots
        log_data["snapshots"] = log_data["snapshots"][-100:]

        # Update metrics
        self._update_metrics(log_data, snapshot)

        with open(self.monitoring_log_file, "w") as f:
            json.dump(log_data, f, indent=2)

    def _update_metrics(self, log_data: Dict[str, Any], snapshot: Dict[str, Any]):
        """Update monitoring metrics"""
        metrics = log_data.get("metrics", {})

        # Update completion metrics
        completed = snapshot["tasks_by_status"].get("completed", 0)
        failed = snapshot["tasks_by_status"].get("failed", 0)

        metrics["tasks_completed"] = completed
        metrics["tasks_failed"] = failed
        metrics["total_tasks_processed"] = completed + failed

        # Update agent utilization history
        agent_utilization = {}
        for agent, workload in snapshot.get("agent_workload", {}).items():
            agent_utilization[agent] = workload["utilization_percent"]

        metrics["agent_utilization"] = agent_utilization

        # Track peak concurrent tasks
        current_active = snapshot["tasks_by_status"].get("in_progress", 0)
        peak = max(metrics.get("peak_concurrent_tasks", 0), current_active)
        metrics["peak_concurrent_tasks"] = peak

        log_data["metrics"] = metrics

    def start_monitoring(self, interval_seconds: int = 30):
        """Start real-time monitoring"""
        print("🔍 Starting TODO monitoring system...")
        self.monitoring_active = True
        self.update_interval = interval_seconds

        try:
            while self.monitoring_active:
                snapshot = self.take_snapshot()
                changes = self.detect_changes(snapshot)

                if changes:
                    print(f"\n📊 [{snapshot['timestamp']}] System Update:")
                    for change in changes:
                        print(f"  {change['message']}")

                self.log_snapshot(snapshot, changes)
                self.last_snapshot = snapshot

                time.sleep(interval_seconds)

        except KeyboardInterrupt:
            print("\n⏹️  Monitoring stopped by user")
        except Exception as e:
            print(f"\n❌ Monitoring error: {e}")
        finally:
            self.monitoring_active = False

    def stop_monitoring(self):
        """Stop monitoring"""
        self.monitoring_active = False

    def get_dashboard_data(self) -> Dict[str, Any]:
        """Get data for dashboard display"""
        snapshot = self.take_snapshot()

        try:
            with open(self.monitoring_log_file, "r") as f:
                log_data = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            log_data = {"alerts": [], "metrics": {}}

        return {
            "current_snapshot": snapshot,
            "recent_alerts": log_data.get("alerts", [])[-10:],  # Last 10 alerts
            "metrics": log_data.get("metrics", {}),
            "monitoring_status": "active" if self.monitoring_active else "inactive",
        }

    def generate_report(self, hours: int = 24) -> Dict[str, Any]:
        """Generate a monitoring report for the specified time period"""
        try:
            with open(self.monitoring_log_file, "r") as f:
                log_data = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {"error": "No monitoring data available"}

        # Filter snapshots by time period
        cutoff = datetime.now() - timedelta(hours=hours)
        recent_snapshots = []

        for snapshot in log_data.get("snapshots", []):
            try:
                snapshot_time = datetime.fromisoformat(
                    snapshot["timestamp"].replace("Z", "+00:00")
                )
                if snapshot_time > cutoff:
                    recent_snapshots.append(snapshot)
            except (ValueError, AttributeError):
                continue

        if not recent_snapshots:
            return {"error": f"No data available for the last {hours} hours"}

        # Calculate trends
        first_snapshot = recent_snapshots[0]
        last_snapshot = recent_snapshots[-1]

        report = {
            "period_hours": hours,
            "start_time": first_snapshot["timestamp"],
            "end_time": last_snapshot["timestamp"],
            "trends": {
                "task_count_change": last_snapshot["total_tasks"]
                - first_snapshot["total_tasks"],
                "completed_tasks": last_snapshot["tasks_by_status"].get("completed", 0)
                - first_snapshot["tasks_by_status"].get("completed", 0),
                "average_agent_utilization": self._calculate_average_utilization(
                    recent_snapshots
                ),
            },
            "final_state": last_snapshot,
            "alerts_count": len(
                [
                    a
                    for a in log_data.get("alerts", [])
                    if self._is_alert_in_period(a, cutoff)
                ]
            ),
        }

        return report

    def _calculate_average_utilization(self, snapshots: List[Dict[str, Any]]) -> float:
        """Calculate average agent utilization across snapshots"""
        total_utilization = 0
        count = 0

        for snapshot in snapshots:
            for agent, workload in snapshot.get("agent_workload", {}).items():
                total_utilization += workload.get("utilization_percent", 0)
                count += 1

        return round(total_utilization / count, 1) if count > 0 else 0

    def _is_alert_in_period(self, alert: Dict[str, Any], cutoff: datetime) -> bool:
        """Check if alert is within the specified time period"""
        try:
            alert_time = datetime.fromisoformat(
                alert["timestamp"].replace("Z", "+00:00")
            )
            return alert_time > cutoff
        except (ValueError, AttributeError, KeyError):
            return False


def main():
    """Main entry point for monitoring"""
    import argparse

    parser = argparse.ArgumentParser(description="TODO Monitoring System")
    parser.add_argument(
        "--start", action="store_true", help="Start real-time monitoring"
    )
    parser.add_argument("--stop", action="store_true", help="Stop monitoring")
    parser.add_argument("--dashboard", action="store_true", help="Show dashboard data")
    parser.add_argument("--report", type=int, help="Generate report for last N hours")
    parser.add_argument(
        "--interval", type=int, default=30, help="Monitoring interval in seconds"
    )

    args = parser.parse_args()

    workspace_root = Path(__file__).parent.parent
    monitor = TodoMonitor(workspace_root)

    if args.start:
        print("🚀 Starting TODO monitoring system...")
        monitor.start_monitoring(args.interval)
    elif args.stop:
        monitor.stop_monitoring()
        print("⏹️  Monitoring stopped")
    elif args.dashboard:
        data = monitor.get_dashboard_data()
        print(json.dumps(data, indent=2))
    elif args.report:
        report = monitor.generate_report(args.report)
        print(json.dumps(report, indent=2))
    else:
        # Default: show current status
        snapshot = monitor.take_snapshot()
        print("📊 Current TODO System Status:")
        print(json.dumps(snapshot, indent=2))


if __name__ == "__main__":
    main()
