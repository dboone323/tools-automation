#!/usr/bin/env python3
"""
MCP Todo Integration Server
Provides MCP endpoints for unified todo management across all project aspects.
"""

import json
import sys
from pathlib import Path
from typing import Dict, Any, List
from datetime import datetime

# Add project root to path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from unified_todo_manager import todo_manager, TodoCategory, TodoPriority, TodoStatus


class TodoMCPIntegration:
    """MCP integration for todo management"""

    def __init__(self):
        self.todo_manager = todo_manager

    def handle_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Handle MCP requests for todo operations"""
        action = request.get("action", "")
        params = request.get("params", {})

        try:
            if action == "create_todo":
                return self._create_todo(params)
            elif action == "get_todos":
                return self._get_todos(params)
            elif action == "update_todo":
                return self._update_todo(params)
            elif action == "assign_todo":
                return self._assign_todo(params)
            elif action == "complete_todo":
                return self._complete_todo(params)
            elif action == "get_dashboard":
                return self._get_dashboard(params)
            elif action == "analyze_project_todos":
                return self._analyze_project_todos(params)
            else:
                return {"success": False, "error": f"Unknown action: {action}"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def _create_todo(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new todo item"""
        required = ["title", "description", "category"]
        for field in required:
            if field not in params:
                return {"success": False, "error": f"Missing required field: {field}"}

        try:
            category = TodoCategory(params["category"])
            priority = TodoPriority(params.get("priority", "medium"))

            todo_id = self.todo_manager.create_todo(
                title=params["title"],
                description=params["description"],
                category=category,
                priority=priority,
                assignee=params.get("assignee"),
                tags=set(params.get("tags", [])),
                dependencies=params.get("dependencies", []),
            )

            return {
                "success": True,
                "todo_id": todo_id,
                "message": f'Created todo: {params["title"]}',
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    def _get_todos(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Get todos with filtering"""
        try:
            status = TodoStatus(params["status"]) if "status" in params else None
            category = (
                TodoCategory(params["category"]) if "category" in params else None
            )

            todos = self.todo_manager.get_todos(
                status=status,
                category=category,
                assignee=params.get("assignee"),
                priority=(
                    TodoPriority(params["priority"]) if "priority" in params else None
                ),
            )

            # Convert to serializable format
            todo_list = []
            for todo in todos:
                todo_dict = {
                    "id": todo.id,
                    "title": todo.title,
                    "description": todo.description,
                    "category": todo.category.value,
                    "priority": todo.priority.value,
                    "status": todo.status.value,
                    "assignee": todo.assignee,
                    "created_at": todo.created_at.isoformat(),
                    "updated_at": todo.updated_at.isoformat(),
                    "due_date": todo.due_date.isoformat() if todo.due_date else None,
                    "tags": list(todo.tags),
                    "dependencies": todo.dependencies,
                    "subtasks": todo.subtasks,
                }
                todo_list.append(todo_dict)

            return {"success": True, "todos": todo_list, "count": len(todo_list)}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def _update_todo(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Update an existing todo"""
        if "id" not in params:
            return {"success": False, "error": "Todo ID required"}

        updates = {}
        if "status" in params:
            updates["status"] = TodoStatus(params["status"])
        if "assignee" in params:
            updates["assignee"] = params["assignee"]
        if "priority" in params:
            updates["priority"] = TodoPriority(params["priority"])

        if self.todo_manager.update_todo(params["id"], **updates):
            return {"success": True, "message": f'Updated todo: {params["id"]}'}
        else:
            return {"success": False, "error": "Todo not found"}

    def _assign_todo(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Assign todo to agent"""
        if "id" not in params:
            return {"success": False, "error": "Todo ID required"}

        agent = self.todo_manager.assign_todo_to_agent(params["id"])
        if agent:
            return {
                "success": True,
                "agent": agent,
                "message": f"Assigned to agent: {agent}",
            }
        else:
            return {"success": False, "error": "No suitable agent found"}

    def _complete_todo(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Mark todo as completed"""
        if "id" not in params:
            return {"success": False, "error": "Todo ID required"}

        if self.todo_manager.update_todo(params["id"], status=TodoStatus.COMPLETED):
            return {"success": True, "message": f'Completed todo: {params["id"]}'}
        else:
            return {"success": False, "error": "Todo not found"}

    def _get_dashboard(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Get dashboard data"""
        try:
            data = self.todo_manager.get_dashboard_data()
            return {"success": True, "dashboard": data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def _analyze_project_todos(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze project and create todos for all aspects"""
        try:
            todos_created = []

            # Security todos
            security_todos = self._analyze_security_todos()
            todos_created.extend(security_todos)

            # Performance todos
            performance_todos = self._analyze_performance_todos()
            todos_created.extend(performance_todos)

            # Maintenance todos
            maintenance_todos = self._analyze_maintenance_todos()
            todos_created.extend(maintenance_todos)

            # Feature todos
            feature_todos = self._analyze_feature_todos()
            todos_created.extend(feature_todos)

            return {
                "success": True,
                "todos_created": len(todos_created),
                "todos": todos_created,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    def _analyze_security_todos(self) -> List[str]:
        """Analyze project for security-related todos"""
        todos = []

        # Check for security scan results
        security_report = project_root / "SECURITY_ASSESSMENT_REPORT_20251113.md"
        if security_report.exists():
            with open(security_report, "r") as f:
                content = f.read()
                if "HIGH-severity" in content:
                    todo_id = self.todo_manager.create_todo(
                        "Address High-Severity Security Issues",
                        "Review and fix all high-severity security vulnerabilities identified in the security assessment",
                        TodoCategory.SECURITY,
                        TodoPriority.CRITICAL,
                        tags={"security", "vulnerabilities"},
                    )
                    todos.append(todo_id)

        # Check for exposed secrets
        if (project_root / "security_reports").exists():
            todo_id = self.todo_manager.create_todo(
                "Review Security Scan Reports",
                "Analyze recent security scan reports and address any findings",
                TodoCategory.SECURITY,
                TodoPriority.HIGH,
                tags={"security", "scanning"},
            )
            todos.append(todo_id)

        return todos

    def _analyze_performance_todos(self) -> List[str]:
        """Analyze project for performance-related todos"""
        todos = []

        # Check monitoring data
        monitoring_dir = project_root / "monitoring"
        if monitoring_dir.exists():
            todo_id = self.todo_manager.create_todo(
                "Optimize System Performance",
                "Review monitoring data and optimize performance bottlenecks",
                TodoCategory.PERFORMANCE,
                TodoPriority.MEDIUM,
                tags={"performance", "monitoring"},
            )
            todos.append(todo_id)

        return todos

    def _analyze_maintenance_todos(self) -> List[str]:
        """Analyze project for maintenance-related todos"""
        todos = []

        # Check for outdated dependencies
        if (project_root / "requirements.txt").exists():
            todo_id = self.todo_manager.create_todo(
                "Update Outdated Dependencies",
                "Review and update outdated Python packages to latest secure versions",
                TodoCategory.MAINTENANCE,
                TodoPriority.MEDIUM,
                tags={"maintenance", "dependencies"},
            )
            todos.append(todo_id)

        # Check for backup files cleanup
        backup_files = list(project_root.glob("**/*.bak")) + list(
            project_root.glob("**/*.backup")
        )
        if backup_files:
            todo_id = self.todo_manager.create_todo(
                "Clean Up Backup Files",
                f"Remove {len(backup_files)} unnecessary backup files to reduce repository size",
                TodoCategory.MAINTENANCE,
                TodoPriority.LOW,
                tags={"maintenance", "cleanup"},
            )
            todos.append(todo_id)

        return todos

    def _analyze_feature_todos(self) -> List[str]:
        """Analyze project for feature enhancement todos"""
        todos = []

        # Agent system enhancements
        agents_dir = project_root / "agents"
        if agents_dir.exists():
            agent_files = list(agents_dir.glob("*.sh"))
            if len(agent_files) > 20:  # Many agents suggest need for orchestration
                todo_id = self.todo_manager.create_todo(
                    "Implement Advanced Agent Orchestration",
                    "Create sophisticated agent coordination and load balancing system",
                    TodoCategory.FEATURES,
                    TodoPriority.MEDIUM,
                    tags={"agents", "orchestration"},
                )
                todos.append(todo_id)

        # MCP enhancements
        if (project_root / "mcp_server.py").exists():
            todo_id = self.todo_manager.create_todo(
                "Enhance MCP Capabilities",
                "Add advanced MCP features like distributed execution and cross-project coordination",
                TodoCategory.FEATURES,
                TodoPriority.MEDIUM,
                tags={"mcp", "distributed"},
            )
            todos.append(todo_id)

        return todos


# Global instance
todo_mcp = TodoMCPIntegration()


def handle_mcp_todo_request(request_data: Dict[str, Any]) -> Dict[str, Any]:
    """Handle MCP requests for todo operations"""
    return todo_mcp.handle_request(request_data)


if __name__ == "__main__":
    # Test the integration
    test_request = {"action": "analyze_project_todos", "params": {}}

    result = handle_mcp_todo_request(test_request)
    print(json.dumps(result, indent=2))
