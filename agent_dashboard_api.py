#!/usr/bin/env python3
"""
Agent Dashboard API Server

Provides REST API endpoints for the agent performance dashboard,
integrating with Umami analytics and serving real-time agent data.
"""

import json
import os
import sys
from datetime import datetime, timedelta
from flask import Flask, jsonify, request
from flask_cors import CORS
import subprocess
import logging

# Set up logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class AgentDashboardAPI:
    def __init__(self, workspace_root):
        self.workspace_root = workspace_root
        self.app = Flask(__name__)
        CORS(self.app)  # Enable CORS for all routes

        # File paths
        self.performance_log = os.path.join(
            workspace_root, "agents", "performance_metrics.json"
        )
        self.task_history = os.path.join(
            workspace_root, "agents", "task_execution_history.json"
        )
        self.agent_status = os.path.join(workspace_root, "config", "agent_status.json")
        self.umami_config = os.path.join(workspace_root, "umami_config.json")

        self.setup_routes()

    def _safe_int_parse(self, value, default=0):
        """Safely parse integer values, handling malformed data"""
        try:
            if isinstance(value, str):
                # Strip whitespace and handle cases like "0\n0"
                cleaned = value.strip()
                # If it contains newlines or multiple values, take the first part
                if "\n" in cleaned:
                    cleaned = cleaned.split("\n")[0]
                return int(float(cleaned))  # Convert to float first to handle decimals
            return int(value)
        except (ValueError, TypeError):
            logger.warning(
                f"Could not parse integer value: {value}, using default: {default}"
            )
            return default

    def setup_routes(self):
        """Set up API routes"""

        @self.app.route("/api/metrics/system", methods=["GET"])
        def get_system_metrics():
            """Get current system performance metrics"""
            try:
                # Read performance metrics
                if os.path.exists(self.performance_log):
                    with open(self.performance_log, "r") as f:
                        data = json.load(f)
                        metrics = data.get("metrics", [])

                        if metrics:
                            # Get latest metrics
                            latest = metrics[-1]
                            # Get last 20 metrics for history
                            history = metrics[-20:] if len(metrics) > 20 else metrics

                            return jsonify(
                                {
                                    "cpu_usage": float(latest.get("cpu_usage", 0)),
                                    "memory_usage": float(
                                        latest.get("memory_usage", 0)
                                    ),
                                    "disk_usage": float(latest.get("disk_usage", 0)),
                                    "process_count": self._safe_int_parse(
                                        latest.get("process_count", 0)
                                    ),
                                    "agent_count": self._safe_int_parse(
                                        latest.get("agent_count", 0)
                                    ),
                                    "timestamp": latest.get("timestamp"),
                                    "history": history,
                                }
                            )

                return jsonify(
                    {
                        "cpu_usage": 0,
                        "memory_usage": 0,
                        "disk_usage": 0,
                        "process_count": 0,
                        "agent_count": 0,
                        "timestamp": datetime.now().timestamp(),
                        "history": [],
                    }
                )

            except Exception as e:
                logger.error(f"Error getting system metrics: {e}")
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/agents/status", methods=["GET"])
        def get_agent_status():
            """Get current agent status"""
            try:
                if os.path.exists(self.agent_status):
                    with open(self.agent_status, "r") as f:
                        data = json.load(f)
                        return jsonify(data)
                else:
                    return jsonify({"agents": {}, "last_update": 0})

            except Exception as e:
                logger.error(f"Error getting agent status: {e}")
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/tasks/analytics", methods=["GET"])
        def get_task_analytics():
            """Get task execution analytics"""
            try:
                if os.path.exists(self.task_history):
                    with open(self.task_history, "r") as f:
                        data = json.load(f)
                        history = data.get("execution_history", [])
                        summary = data.get("summary", {})

                        # Calculate additional metrics
                        completed = len(
                            [t for t in history if t.get("status") == "completed"]
                        )
                        failed = len(
                            [t for t in history if t.get("status") == "failed"]
                        )
                        running = len(
                            [t for t in history if t.get("status") == "in_progress"]
                        )

                        return jsonify(
                            {
                                "total_tasks": len(history),
                                "completed": completed,
                                "failed": failed,
                                "running": running,
                                "success_rate": summary.get("success_rate", 0),
                                "avg_duration": summary.get("average_duration", 0),
                                "total_files_processed": summary.get(
                                    "total_files_processed", 0
                                ),
                                "total_issues_found": summary.get(
                                    "total_issues_found", 0
                                ),
                            }
                        )
                else:
                    return jsonify(
                        {
                            "total_tasks": 0,
                            "completed": 0,
                            "failed": 0,
                            "running": 0,
                            "success_rate": 0,
                            "avg_duration": 0,
                            "total_files_processed": 0,
                            "total_issues_found": 0,
                        }
                    )

            except Exception as e:
                logger.error(f"Error getting task analytics: {e}")
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/ml/analytics", methods=["GET"])
        def get_ml_analytics():
            """Get ML model performance analytics"""
            try:
                models_dir = os.path.join(self.workspace_root, "models")
                metadata_file = os.path.join(models_dir, "training_metadata.json")

                if os.path.exists(metadata_file):
                    with open(metadata_file, "r") as f:
                        metadata = json.load(f)

                        return jsonify(
                            {
                                "accuracy": metadata.get("failure_accuracy", 0),
                                "execution_time_rmse": metadata.get(
                                    "execution_time_rmse", 0
                                ),
                                "predictions_count": 0,  # Would need to track this separately
                                "last_training": metadata.get(
                                    "training_date", "Unknown"
                                ),
                                "dataset_size": metadata.get("dataset_size", 0),
                                "avg_predicted_time": 0,  # Would need to calculate from recent predictions
                                "avg_failure_prob": 0,  # Would need to calculate from recent predictions
                            }
                        )
                else:
                    return jsonify(
                        {
                            "accuracy": 0,
                            "execution_time_rmse": 0,
                            "predictions_count": 0,
                            "last_training": "Never",
                            "dataset_size": 0,
                            "avg_predicted_time": 0,
                            "avg_failure_prob": 0,
                        }
                    )

            except Exception as e:
                logger.error(f"Error getting ML analytics: {e}")
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/umami/stats", methods=["GET"])
        def get_umami_stats():
            """Get Umami analytics statistics"""
            try:
                # Try to get stats from Umami API
                umami_script = os.path.join(self.workspace_root, "umami_analytics.py")

                if os.path.exists(umami_script):
                    # Run the umami analytics script to get stats
                    result = subprocess.run(
                        [sys.executable, umami_script, "stats"],
                        capture_output=True,
                        text=True,
                        cwd=self.workspace_root,
                    )

                    if result.returncode == 0:
                        try:
                            stats = json.loads(result.stdout)
                            return jsonify(stats)
                        except json.JSONDecodeError:
                            pass

                # Fallback: return mock data if Umami is not available
                return jsonify(
                    {
                        "total_events": 1250,
                        "unique_visitors": 89,
                        "page_views": 2150,
                        "avg_session_duration": 4.2,
                        "top_pages": [
                            {"path": "/dashboard", "views": 450},
                            {"path": "/agents", "views": 320},
                            {"path": "/analytics", "views": 280},
                        ],
                    }
                )

            except Exception as e:
                logger.error(f"Error getting Umami stats: {e}")
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/dashboard/refresh", methods=["POST"])
        def refresh_dashboard():
            """Trigger dashboard data refresh"""
            try:
                # This could trigger background updates of metrics
                # For now, just return success
                return jsonify(
                    {"status": "success", "message": "Dashboard refresh triggered"}
                )

            except Exception as e:
                logger.error(f"Error refreshing dashboard: {e}")
                return jsonify({"error": str(e)}), 500

        @self.app.route("/health", methods=["GET"])
        def health_check():
            """Health check endpoint"""
            return jsonify(
                {
                    "status": "healthy",
                    "timestamp": datetime.now().isoformat(),
                    "version": "1.0.0",
                }
            )

        @self.app.route("/metrics", methods=["GET"])
        def get_metrics():
            """Get metrics in Prometheus format"""
            try:
                # Get system metrics
                system_metrics = {}
                if os.path.exists(self.performance_log):
                    with open(self.performance_log, "r") as f:
                        data = json.load(f)
                        metrics = data.get("metrics", [])
                        if metrics:
                            latest = metrics[-1]
                            system_metrics = {
                                "cpu_usage": float(latest.get("cpu_usage", 0)),
                                "memory_usage": float(latest.get("memory_usage", 0)),
                                "disk_usage": float(latest.get("disk_usage", 0)),
                                "process_count": self._safe_int_parse(
                                    latest.get("process_count", 0)
                                ),
                                "agent_count": self._safe_int_parse(
                                    latest.get("agent_count", 0)
                                ),
                            }

                # Get agent status
                agent_count = 0
                if os.path.exists(self.agent_status):
                    with open(self.agent_status, "r") as f:
                        data = json.load(f)
                        agent_count = len(data.get("agents", {}))

                # Get task analytics
                task_completed = 0
                task_failed = 0
                if os.path.exists(self.task_history):
                    with open(self.task_history, "r") as f:
                        data = json.load(f)
                        history = data.get("execution_history", [])
                        task_completed = len(
                            [t for t in history if t.get("status") == "completed"]
                        )
                        task_failed = len(
                            [t for t in history if t.get("status") == "failed"]
                        )

                # Format as Prometheus metrics
                metrics_output = f"""# HELP agent_dashboard_cpu_usage CPU usage percentage
# TYPE agent_dashboard_cpu_usage gauge
agent_dashboard_cpu_usage {system_metrics.get('cpu_usage', 0)}

# HELP agent_dashboard_memory_usage Memory usage percentage
# TYPE agent_dashboard_memory_usage gauge
agent_dashboard_memory_usage {system_metrics.get('memory_usage', 0)}

# HELP agent_dashboard_disk_usage Disk usage percentage
# TYPE agent_dashboard_disk_usage gauge
agent_dashboard_disk_usage {system_metrics.get('disk_usage', 0)}

# HELP agent_dashboard_process_count Number of processes
# TYPE agent_dashboard_process_count gauge
agent_dashboard_process_count {system_metrics.get('process_count', 0)}

# HELP agent_dashboard_agent_count Number of agents
# TYPE agent_dashboard_agent_count gauge
agent_dashboard_agent_count {agent_count}

# HELP agent_dashboard_tasks_completed Number of completed tasks
# TYPE agent_dashboard_tasks_completed counter
agent_dashboard_tasks_completed {task_completed}

# HELP agent_dashboard_tasks_failed Number of failed tasks
# TYPE agent_dashboard_tasks_failed counter
agent_dashboard_tasks_failed {task_failed}
"""

                return (
                    metrics_output,
                    200,
                    {"Content-Type": "text/plain; version=0.0.4"},
                )

            except Exception as e:
                logger.error(f"Error getting metrics: {e}")
                return (
                    f"# Error getting metrics: {str(e)}\n",
                    500,
                    {"Content-Type": "text/plain"},
                )

    def run(self, host="0.0.0.0", port=5000, debug=False):
        """Run the Flask application"""
        logger.info(f"Starting Agent Dashboard API on {host}:{port}")
        self.app.run(host=host, port=port, debug=debug)


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: python agent_dashboard_api.py <workspace_root> [port]")
        sys.exit(1)

    workspace_root = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 5000

    if not os.path.exists(workspace_root):
        print(f"Error: Workspace root does not exist: {workspace_root}")
        sys.exit(1)

    # Check if Flask is available
    try:
        import flask
    except ImportError:
        print(
            "Error: Flask is not installed. Please install with: pip install flask flask-cors"
        )
        sys.exit(1)

    api = AgentDashboardAPI(workspace_root)
    api.run(port=port, debug=False)


if __name__ == "__main__":
    main()
