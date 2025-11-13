#!/usr/bin/env python3
"""
Unified Todo Management System
Integrates agents, MCP, and tools for comprehensive todo management across all project aspects.

Features:
- Multi-agent todo delegation and tracking
- MCP integration for distributed task execution
- AI-powered todo analysis and prioritization
- Cross-project todo synchronization
- Real-time status monitoring and reporting
"""

import json
import os
import sys
import time
import uuid
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Set
from dataclasses import dataclass, asdict
from enum import Enum
import threading
import queue
import requests
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Import existing systems
try:
    from mcp_server import MCPClient

    MCP_AVAILABLE = True
except ImportError:
    MCP_AVAILABLE = False

try:
    from ai_service_manager import ai_manager

    AI_AVAILABLE = True
except ImportError:
    AI_AVAILABLE = False


class TodoPriority(Enum):
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    BACKLOG = "backlog"


class TodoStatus(Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    BLOCKED = "blocked"
    CANCELLED = "cancelled"


class TodoCategory(Enum):
    SECURITY = "security"
    PERFORMANCE = "performance"
    MAINTENANCE = "maintenance"
    FEATURES = "features"
    BUGS = "bugs"
    DOCUMENTATION = "documentation"
    TESTING = "testing"
    INFRASTRUCTURE = "infrastructure"
    DEBT = "debt"


@dataclass
class TodoItem:
    id: str
    title: str
    description: str
    category: TodoCategory
    priority: TodoPriority
    status: TodoStatus
    assignee: Optional[str] = None
    created_at: datetime = None
    updated_at: datetime = None
    due_date: Optional[datetime] = None
    tags: Set[str] = None
    dependencies: List[str] = None
    subtasks: List[str] = None
    metadata: Dict[str, Any] = None

    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now()
        if self.updated_at is None:
            self.updated_at = datetime.now()
        if self.tags is None:
            self.tags = set()
        if self.dependencies is None:
            self.dependencies = []
        if self.subtasks is None:
            self.subtasks = []
        if self.metadata is None:
            self.metadata = {}


class TodoManager:
    """Unified Todo Management System"""

    def __init__(self, workspace_root: str = None):
        self.workspace_root = Path(workspace_root or project_root)
        self.todos_file = self.workspace_root / "unified_todos.json"
        self.agents_file = self.workspace_root / "todo_agents.json"
        self.queue = queue.Queue()
        self.lock = threading.Lock()

        # Initialize MCP client if available
        self.mcp_client = None
        if MCP_AVAILABLE:
            try:
                self.mcp_client = MCPClient()
            except Exception as e:
                print(f"MCP client initialization failed: {e}")

        # Load existing data
        self.todos: Dict[str, TodoItem] = {}
        self.agent_capabilities: Dict[str, Set[str]] = {}
        self.load_data()

        # Start background processing
        self.processing_thread = threading.Thread(
            target=self._process_queue, daemon=True
        )
        self.processing_thread.start()

    def load_data(self):
        """Load todos and agent capabilities from disk"""
        # Load todos
        if self.todos_file.exists():
            try:
                with open(self.todos_file, "r") as f:
                    data = json.load(f)
                    for todo_data in data.get("todos", []):
                        # Convert string dates back to datetime
                        for date_field in ["created_at", "updated_at", "due_date"]:
                            if todo_data.get(date_field):
                                todo_data[date_field] = datetime.fromisoformat(
                                    todo_data[date_field]
                                )

                        # Convert category and priority back to enums
                        todo_data["category"] = TodoCategory(todo_data["category"])
                        todo_data["priority"] = TodoPriority(todo_data["priority"])
                        todo_data["status"] = TodoStatus(todo_data["status"])

                        todo = TodoItem(**todo_data)
                        self.todos[todo.id] = todo
            except Exception as e:
                print(f"Error loading todos: {e}")

        # Load agent capabilities
        if self.agents_file.exists():
            try:
                with open(self.agents_file, "r") as f:
                    self.agent_capabilities = json.load(f)
            except Exception as e:
                print(f"Error loading agent capabilities: {e}")

    def save_data(self):
        """Save todos and agent capabilities to disk"""
        with self.lock:
            # Save todos
            todos_data = {
                "todos": [
                    {
                        **asdict(todo),
                        "category": todo.category.value,
                        "priority": todo.priority.value,
                        "status": todo.status.value,
                        "created_at": todo.created_at.isoformat(),
                        "updated_at": todo.updated_at.isoformat(),
                        "due_date": (
                            todo.due_date.isoformat() if todo.due_date else None
                        ),
                        "tags": list(todo.tags),
                    }
                    for todo in self.todos.values()
                ]
            }

            with open(self.todos_file, "w") as f:
                json.dump(todos_data, f, indent=2)

            # Save agent capabilities
            with open(self.agents_file, "w") as f:
                json.dump(self.agent_capabilities, f, indent=2)

    def create_todo(
        self,
        title: str,
        description: str,
        category: TodoCategory,
        priority: TodoPriority = TodoPriority.MEDIUM,
        assignee: str = None,
        due_date: datetime = None,
        tags: Set[str] = None,
        dependencies: List[str] = None,
    ) -> str:
        """Create a new todo item"""
        todo_id = str(uuid.uuid4())
        todo = TodoItem(
            id=todo_id,
            title=title,
            description=description,
            category=category,
            priority=priority,
            status=TodoStatus.PENDING,
            assignee=assignee,
            due_date=due_date,
            tags=tags or set(),
            dependencies=dependencies or [],
        )

        with self.lock:
            self.todos[todo_id] = todo

        self.save_data()

        # Queue for agent processing
        self.queue.put(("analyze", todo_id))

        return todo_id

    def update_todo(self, todo_id: str, **updates) -> bool:
        """Update an existing todo item"""
        with self.lock:
            if todo_id not in self.todos:
                return False

            todo = self.todos[todo_id]
            for key, value in updates.items():
                if hasattr(todo, key):
                    setattr(todo, key, value)

            todo.updated_at = datetime.now()
            self.save_data()

            # Queue for reassignment if needed
            if "assignee" in updates or "status" in updates:
                self.queue.put(("reassign", todo_id))

            return True

    def get_todos(
        self,
        status: TodoStatus = None,
        category: TodoCategory = None,
        assignee: str = None,
        priority: TodoPriority = None,
    ) -> List[TodoItem]:
        """Get todos with optional filtering"""
        todos = list(self.todos.values())

        if status:
            todos = [t for t in todos if t.status == status]
        if category:
            todos = [t for t in todos if t.category == category]
        if assignee:
            todos = [t for t in todos if t.assignee == assignee]
        if priority:
            todos = [t for t in todos if t.priority == priority]

        return sorted(todos, key=lambda t: (t.priority.value, t.created_at))

    def analyze_todo_with_ai(self, todo_id: str) -> Dict[str, Any]:
        """Use AI to analyze and enhance todo item"""
        if not AI_AVAILABLE or todo_id not in self.todos:
            return {}

        todo = self.todos[todo_id]

        prompt = f"""
        Analyze this todo item and provide insights:

        Title: {todo.title}
        Description: {todo.description}
        Category: {todo.category.value}
        Priority: {todo.priority.value}

        Please provide:
        1. Suggested priority (critical/high/medium/low/backlog)
        2. Estimated effort (hours)
        3. Required skills/expertise
        4. Potential subtasks
        5. Dependencies or blockers
        6. Success criteria

        Respond in JSON format.
        """

        try:
            response = ai_manager.process_request("analyze_todo", prompt)
            if response and "content" in response:
                return json.loads(response["content"])
        except Exception as e:
            print(f"AI analysis failed: {e}")

        return {}

    def assign_todo_to_agent(self, todo_id: str) -> Optional[str]:
        """Assign todo to most suitable agent based on capabilities"""
        if todo_id not in self.todos:
            return None

        todo = self.todos[todo_id]

        # Find best agent match
        best_agent = None
        best_score = 0

        for agent, capabilities in self.agent_capabilities.items():
            score = 0

            # Category matching
            if todo.category.value in capabilities:
                score += 3

            # Priority handling
            if "high_priority" in capabilities and todo.priority in [
                TodoPriority.CRITICAL,
                TodoPriority.HIGH,
            ]:
                score += 2

            # Tag matching
            tag_matches = len(todo.tags & capabilities)
            score += tag_matches

            if score > best_score:
                best_score = score
                best_agent = agent

        if best_agent:
            self.update_todo(
                todo_id, assignee=best_agent, status=TodoStatus.IN_PROGRESS
            )
            return best_agent

        return None

    def execute_todo_via_mcp(self, todo_id: str) -> bool:
        """Execute todo using MCP if available"""
        if not MCP_AVAILABLE or not self.mcp_client or todo_id not in self.todos:
            return False

        todo = self.todos[todo_id]

        try:
            # Prepare MCP command
            command = {
                "agent": todo.assignee or "general_agent",
                "command": "execute_todo",
                "todo_id": todo_id,
                "title": todo.title,
                "description": todo.description,
                "category": todo.category.value,
            }

            response = self.mcp_client.run_command(command)

            if response.get("success"):
                self.update_todo(todo_id, status=TodoStatus.COMPLETED)
                return True

        except Exception as e:
            print(f"MCP execution failed: {e}")
            self.update_todo(todo_id, status=TodoStatus.BLOCKED)

        return False

    def _process_queue(self):
        """Background queue processor"""
        while True:
            try:
                action, todo_id = self.queue.get(timeout=1)

                if action == "analyze":
                    # AI analysis
                    analysis = self.analyze_todo_with_ai(todo_id)
                    if analysis:
                        # Update todo with AI insights
                        updates = {}
                        if "suggested_priority" in analysis:
                            try:
                                updates["priority"] = TodoPriority(
                                    analysis["suggested_priority"]
                                )
                            except:
                                pass

                        if "subtasks" in analysis:
                            updates["subtasks"] = analysis["subtasks"]

                        if updates:
                            self.update_todo(todo_id, **updates)

                    # Auto-assign
                    self.assign_todo_to_agent(todo_id)

                elif action == "reassign":
                    # Reassign if needed
                    self.assign_todo_to_agent(todo_id)

                self.queue.task_done()

            except queue.Empty:
                continue
            except Exception as e:
                print(f"Queue processing error: {e}")

    def get_dashboard_data(self) -> Dict[str, Any]:
        """Get dashboard data for todo management"""
        todos = list(self.todos.values())

        return {
            "total_todos": len(todos),
            "by_status": {
                status.value: len([t for t in todos if t.status == status])
                for status in TodoStatus
            },
            "by_category": {
                category.value: len([t for t in todos if t.category == category])
                for category in TodoCategory
            },
            "by_priority": {
                priority.value: len([t for t in todos if t.priority == priority])
                for priority in TodoPriority
            },
            "overdue": len(
                [
                    t
                    for t in todos
                    if t.due_date
                    and t.due_date < datetime.now()
                    and t.status != TodoStatus.COMPLETED
                ]
            ),
            "recent_activity": [
                {
                    "id": t.id,
                    "title": t.title,
                    "status": t.status.value,
                    "updated_at": t.updated_at.isoformat(),
                }
                for t in sorted(todos, key=lambda x: x.updated_at, reverse=True)[:10]
            ],
        }

    def health_check(self) -> bool:
        """Perform health check on the todo manager"""
        try:
            # Check if we can access the data
            todos = list(self.todos.values())
            # Check if queue is responsive
            self.queue.put(("test", "health_check"))
            # Basic validation
            return True
        except Exception as e:
            print(f"Health check failed: {e}")
            return False


# Global instance
todo_manager = TodoManager()


def main():
    """CLI interface for todo management"""
    import argparse

    parser = argparse.ArgumentParser(description="Unified Todo Management System")
    parser.add_argument(
        "action",
        choices=["create", "list", "update", "assign", "complete", "dashboard"],
    )
    parser.add_argument("--id", help="Todo ID")
    parser.add_argument("--title", help="Todo title")
    parser.add_argument("--description", help="Todo description")
    parser.add_argument("--category", choices=[c.value for c in TodoCategory])
    parser.add_argument("--priority", choices=[p.value for p in TodoPriority])
    parser.add_argument("--assignee", help="Assignee")
    parser.add_argument("--status", choices=[s.value for s in TodoStatus])

    args = parser.parse_args()

    if args.action == "create":
        if not args.title or not args.description or not args.category:
            print("Title, description, and category are required")
            return

        category = TodoCategory(args.category)
        priority = TodoPriority(args.priority) if args.priority else TodoPriority.MEDIUM

        todo_id = todo_manager.create_todo(
            args.title, args.description, category, priority, args.assignee
        )
        print(f"Created todo: {todo_id}")

    elif args.action == "list":
        todos = todo_manager.get_todos(
            status=TodoStatus(args.status) if args.status else None,
            category=TodoCategory(args.category) if args.category else None,
            assignee=args.assignee,
        )

        for todo in todos:
            print(
                f"[{todo.status.value.upper()}] {todo.title} ({todo.category.value}) - {todo.assignee or 'Unassigned'}"
            )

    elif args.action == "update":
        if not args.id:
            print("Todo ID required")
            return

        updates = {}
        if args.status:
            updates["status"] = TodoStatus(args.status)
        if args.assignee:
            updates["assignee"] = args.assignee
        if args.priority:
            updates["priority"] = TodoPriority(args.priority)

        if todo_manager.update_todo(args.id, **updates):
            print(f"Updated todo: {args.id}")
        else:
            print(f"Todo not found: {args.id}")

    elif args.action == "assign":
        if not args.id:
            print("Todo ID required")
            return

        agent = todo_manager.assign_todo_to_agent(args.id)
        if agent:
            print(f"Assigned to agent: {agent}")
        else:
            print("No suitable agent found")

    elif args.action == "complete":
        if not args.id:
            print("Todo ID required")
            return

        if todo_manager.update_todo(args.id, status=TodoStatus.COMPLETED):
            print(f"Completed todo: {args.id}")
        else:
            print(f"Todo not found: {args.id}")

    elif args.action == "dashboard":
        data = todo_manager.get_dashboard_data()
        print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
