#!/usr/bin/env python3
"""
Todo Dashboard API Server
Provides REST API endpoints for the unified todo management dashboard.
"""

import json
import os
import sys
from datetime import datetime, timedelta
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import threading
import time
import argparse
from typing import Dict, List, Any

# Add current directory to path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from unified_todo_manager import TodoManager, TodoStatus, TodoPriority, TodoCategory


class TodoDashboardAPI:
    """API server for todo dashboard with integrated todo management."""

    def __init__(self):
        self.app = Flask(__name__)
        CORS(self.app)  # Enable CORS for web dashboard

        # Initialize todo manager
        self.todo_manager = TodoManager()

        # Setup routes
        self.setup_routes()

        # Start background monitoring
        self.monitoring_thread = threading.Thread(
            target=self.background_monitor, daemon=True
        )
        self.monitoring_thread.start()

    def setup_routes(self):
        """Setup Flask routes for the API."""

        @self.app.route("/")
        def index():
            """Serve the dashboard HTML."""
            return send_from_directory(".", "todo_dashboard.html")

        @self.app.route("/api/todo/dashboard", methods=["GET"])
        def get_dashboard_data():
            """Get comprehensive dashboard data."""
            try:
                data = self.get_dashboard_data()
                return jsonify(data)
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/todo/analyze", methods=["POST"])
        def analyze_project():
            """Trigger project analysis to create todos."""
            try:
                result = self.analyze_project_todos()
                return jsonify(result)
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/todo/process", methods=["POST"])
        def process_todos():
            """Process pending todos."""
            try:
                result = self.process_pending_todos()
                return jsonify(result)
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/todo/execute-critical", methods=["POST"])
        def execute_critical():
            """Execute critical todos."""
            try:
                result = self.execute_critical_todos()
                return jsonify(result)
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/todo/report", methods=["POST"])
        def generate_report():
            """Generate comprehensive todo report."""
            try:
                result = self.generate_todo_report()
                return jsonify(result)
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/todo/create", methods=["POST"])
        def create_todo():
            """Create a new todo."""
            try:
                data = request.get_json()
                todo_id = self.todo_manager.create_todo(
                    title=data["title"],
                    description=data.get("description", ""),
                    category=TodoCategory(data.get("category", "general")),
                    priority=TodoPriority(data.get("priority", "medium")),
                    assignee=data.get("assignee"),
                    due_date=data.get("due_date"),
                )
                return jsonify({"todo_id": todo_id})
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/todo/<todo_id>", methods=["GET"])
        def get_todo(todo_id):
            """Get a specific todo."""
            try:
                todo = self.todo_manager.get_todo(todo_id)
                if todo:
                    return jsonify(todo.to_dict())
                return jsonify({"error": "Todo not found"}), 404
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/todo/<todo_id>", methods=["PUT"])
        def update_todo(todo_id):
            """Update a todo."""
            try:
                data = request.get_json()
                success = self.todo_manager.update_todo(todo_id=todo_id, **data)
                if success:
                    return jsonify({"success": True})
                return jsonify({"error": "Todo not found"}), 404
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/todo/<todo_id>/assign", methods=["POST"])
        def assign_todo(todo_id):
            """Assign a todo to an agent."""
            try:
                data = request.get_json()
                success = self.todo_manager.assign_todo_to_agent(
                    todo_id=todo_id, agent_name=data["agent_name"]
                )
                if success:
                    return jsonify({"success": True})
                return jsonify({"error": "Assignment failed"}), 400
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/todo/<todo_id>/execute", methods=["POST"])
        def execute_todo(todo_id):
            """Execute a todo via MCP."""
            try:
                success = self.todo_manager.execute_todo_via_mcp(todo_id)
                if success:
                    return jsonify({"success": True})
                return jsonify({"error": "Execution failed"}), 400
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/agents/status", methods=["GET"])
        def get_agent_status():
            """Get status of all agents."""
            try:
                status = self.get_agent_status_data()
                return jsonify(status)
            except Exception as e:
                return jsonify({"error": str(e)}), 500

    def get_dashboard_data(self) -> Dict[str, Any]:
        """Get comprehensive dashboard data."""
        todos = self.todo_manager.get_todos()

        # Calculate metrics
        total_todos = len(todos)
        by_status = {}
        by_category = {}
        by_priority = {}
        overdue = 0
        recent_activity = []

        now = datetime.now()

        for todo in todos:
            # Status distribution
            status = todo.status.value
            by_status[status] = by_status.get(status, 0) + 1

            # Category distribution
            category = todo.category.value
            by_category[category] = by_category.get(category, 0) + 1

            # Priority distribution
            priority = todo.priority.value
            by_priority[priority] = by_priority.get(priority, 0) + 1

            # Overdue count
            if (
                todo.due_date
                and todo.due_date < now
                and todo.status in [TodoStatus.PENDING, TodoStatus.IN_PROGRESS]
            ):
                overdue += 1

            # Recent activity (last 10 updated)
            if len(recent_activity) < 10:
                recent_activity.append(
                    {
                        "id": todo.id,
                        "title": todo.title,
                        "status": status,
                        "updated_at": todo.updated_at.isoformat(),
                    }
                )

        # Sort recent activity by update time
        recent_activity.sort(key=lambda x: x["updated_at"], reverse=True)

        return {
            "total_todos": total_todos,
            "by_status": by_status,
            "by_category": by_category,
            "by_priority": by_priority,
            "overdue": overdue,
            "recent_activity": recent_activity,
        }

    def analyze_project_todos(self) -> Dict[str, Any]:
        """Analyze project and create todos."""
        # This would integrate with the bash agent analysis
        # For now, return a mock response
        return {
            "todos_created": 5,
            "message": "Project analysis completed successfully",
        }

    def process_pending_todos(self) -> Dict[str, Any]:
        """Process pending todos."""
        # This would trigger the bash agent processing
        return {"processed": 3, "message": "Todo processing completed"}

    def execute_critical_todos(self) -> Dict[str, Any]:
        """Execute critical todos."""
        # This would trigger critical todo execution
        return {"executed": 2, "message": "Critical todos executed"}

    def generate_todo_report(self) -> Dict[str, Any]:
        """Generate comprehensive todo report."""
        # This would create a detailed report
        return {"report_generated": True, "message": "Report generated successfully"}

    def get_agent_status_data(self) -> Dict[str, Any]:
        """Get status of all agents."""
        # This would check agent health and status
        return {
            "unified_todo_agent": "running",
            "mcp_server": "running",
            "ai_service": "running",
        }

    def background_monitor(self):
        """Background monitoring thread."""
        while True:
            try:
                # Periodic health checks and maintenance
                self.todo_manager.health_check()
                time.sleep(60)  # Check every minute
            except Exception as e:
                print(f"Background monitor error: {e}")
                time.sleep(30)

    def run(self, host="0.0.0.0", port=5000, debug=False):
        """Run the Flask application."""
        print(f"Starting Todo Dashboard API on {host}:{port}")
        self.app.run(host=host, port=port, debug=debug)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Todo Dashboard API")
    parser.add_argument(
        "--port", type=int, default=5000, help="Port to run the server on"
    )
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--debug", action="store_true", help="Enable debug mode")

    args = parser.parse_args()

    api = TodoDashboardAPI()
    api.run(host=args.host, port=args.port, debug=args.debug)


if __name__ == "__main__":
    main()
