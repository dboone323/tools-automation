#!/usr/bin/env python3
"""
TODO Task Converter
Converts TODO/FIXME comments from codebase scan into agent tasks
"""

import json
import subprocess
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional
import hashlib

# Import the new Phase 2 components
from todo_prioritizer import TodoPrioritizer
from agent_matcher import AgentMatcher
from dependency_analyzer import DependencyAnalyzer


class TodoTaskConverter:
    """Converts TODO comments into agent tasks"""

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.config_dir = workspace_root / "config"
        self.task_queue_file = (
            workspace_root / "agents" / "task_queue.json"
        )  # Use agents task queue
        self.todo_output_file = workspace_root / "config" / "todo-tree-output.json"
        self.agent_capabilities_file = self.config_dir / "agent_capabilities.json"

        # Ensure config directory exists
        self.config_dir.mkdir(exist_ok=True)

        # Initialize Phase 2 components
        self.prioritizer = TodoPrioritizer(workspace_root)
        self.agent_matcher = AgentMatcher(workspace_root)
        self.dependency_analyzer = DependencyAnalyzer(workspace_root)

        # Initialize agent capabilities if not exists
        self._init_agent_capabilities()

    def _init_agent_capabilities(self):
        """Initialize agent capabilities mapping"""
        if not self.agent_capabilities_file.exists():
            capabilities = {
                "agent_codegen.sh": {
                    "file_types": [
                        ".swift",
                        ".py",
                        ".js",
                        ".ts",
                        ".java",
                        ".cpp",
                        ".c",
                        ".h",
                    ],
                    "task_types": ["code_generation", "code_fix", "implementation"],
                    "priority": 8,
                },
                "agent_build.sh": {
                    "file_types": [".json", ".yml", ".yaml", ".xml", ".gradle", ".pom"],
                    "task_types": ["build", "configuration", "deployment"],
                    "priority": 7,
                },
                "agent_test.sh": {
                    "file_types": [".py", ".js", ".ts", ".java", ".swift"],
                    "task_types": ["testing", "validation", "quality_assurance"],
                    "priority": 9,
                },
                "agent_documentation.sh": {
                    "file_types": [".md", ".txt", ".rst", ".adoc"],
                    "task_types": ["documentation", "readme", "comments"],
                    "priority": 5,
                },
                "agent_debug.sh": {
                    "file_types": ["*"],  # All file types
                    "task_types": ["debugging", "troubleshooting", "analysis"],
                    "priority": 9,
                },
                "agent_security.sh": {
                    "file_types": [
                        ".py",
                        ".js",
                        ".ts",
                        ".java",
                        ".swift",
                        ".json",
                        ".yml",
                    ],
                    "task_types": [
                        "security",
                        "auth",
                        "encryption",
                        "vulnerability_fix",
                    ],
                    "priority": 10,
                },
                "agent_performance_monitor.sh": {
                    "file_types": [".py", ".js", ".ts", ".swift", ".sh"],
                    "task_types": ["performance", "optimization", "monitoring"],
                    "priority": 8,
                },
                "pull_request_agent.sh": {
                    "file_types": ["*"],
                    "task_types": ["pull_request", "code_review", "merge"],
                    "priority": 6,
                },
            }

            with open(self.agent_capabilities_file, "w") as f:
                json.dump(capabilities, f, indent=2)

    def load_agent_capabilities(self) -> Dict[str, Any]:
        """Load agent capabilities mapping"""
        try:
            with open(self.agent_capabilities_file, "r") as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

    def scan_todos(self) -> List[Dict[str, Any]]:
        """Scan for TODO comments using existing scanner"""
        print("🔍 Scanning for TODO/FIXME comments...")

        # Run the existing TODO scanner
        scanner_script = self.workspace_root / "scripts" / "regenerate_todo_json.py"
        if scanner_script.exists():
            try:
                result = subprocess.run(
                    ["python3", str(scanner_script)],
                    capture_output=True,
                    text=True,
                    cwd=self.workspace_root,
                )

                if result.returncode == 0:
                    print("✅ TODO scan completed successfully")
                else:
                    print(f"⚠️  TODO scan completed with warnings: {result.stderr}")
            except Exception as e:
                print(f"❌ Error running TODO scanner: {e}")
                return []
        else:
            print("⚠️  TODO scanner script not found, using existing data")

        # Load TODO data
        if self.todo_output_file.exists():
            try:
                with open(self.todo_output_file, "r") as f:
                    todos = json.load(f)
                print(f"📊 Found {len(todos)} TODO items")
                return todos
            except (FileNotFoundError, json.JSONDecodeError) as e:
                print(f"❌ Error loading TODO data: {e}")
                return []
        else:
            print("⚠️  No TODO data file found")
            return []

    def calculate_priority(self, todo: Dict[str, Any]) -> int:
        """Calculate priority score for a TODO item using advanced prioritizer"""
        return self.prioritizer.calculate_priority(todo)

    def match_agent(self, todo: Dict[str, Any]) -> str:
        """Match TODO to appropriate agent using advanced matcher"""
        agent, _ = self.agent_matcher.match_agent(todo)
        # Agent matcher now returns agents with .sh extensions
        return agent

    def convert_todo_to_task(
        self, todo: Dict[str, Any], dependency_info: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Convert a TODO item into an agent task with enhanced metadata"""
        # Generate unique task ID
        # Use sha256 for a stronger unique hash (non-security usage)
        content_hash = hashlib.sha256(
            f"{todo.get('file', '')}:{todo.get('line', 0)}:{todo.get('text', '')}".encode()
        ).hexdigest()[:8]

        task_id = f"todo_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{content_hash}"

        # Get priority and agent assignment using Phase 2 components
        priority = self.calculate_priority(todo)
        assigned_agent = self.match_agent(todo)

        # Determine task type from content
        text = todo.get("text", "").lower()
        if "fixme" in text or "bug" in text:
            task_type = "bug_fix"
        elif "implement" in text or "add" in text:
            task_type = "feature_implementation"
        elif "test" in text:
            task_type = "testing"
        elif "docs" in text or "readme" in text:
            task_type = "documentation"
        elif "security" in text or "auth" in text:
            task_type = "security"
        elif "performance" in text or "optimize" in text:
            task_type = "performance"
        else:
            task_type = "code_improvement"

        # Get priority breakdown for metadata
        priority_breakdown = self.prioritizer.get_priority_breakdown(todo)

        # Get agent matching breakdown
        _, agent_breakdown = self.agent_matcher.match_agent(todo)

        # Extract dependencies if available
        dependencies = []
        if dependency_info:
            # Look for this TODO in dependency info
            for dep_item in dependency_info.get("explicit_dependencies", []):
                if dep_item["todo"].get("file") == todo.get("file") and dep_item[
                    "todo"
                ].get("line") == todo.get("line"):
                    dependencies.extend(dep_item["dependencies"])
                    break

        task = {
            "id": task_id,
            "type": task_type,
            "priority": priority,
            "status": "pending",
            "description": todo.get("text", ""),
            "assigned_agent": assigned_agent,
            "source_file": todo.get("file", ""),
            "line_number": todo.get("line", 0),
            "created_at": datetime.now().isoformat(),
            "dependencies": dependencies,
            "metadata": {
                "source": "todo_scan",
                "file_type": Path(todo.get("file", "")).suffix,
                "estimated_complexity": self._estimate_complexity(todo),
                "tags": ["todo", "automated"],
                "priority_breakdown": priority_breakdown,
                "agent_matching": agent_breakdown,
                "phase": "intelligent_prioritization",
            },
        }

        return task

    def _estimate_complexity(self, todo: Dict[str, Any]) -> str:
        """Estimate task complexity based on various factors"""
        text = todo.get("text", "")
        file_path = todo.get("file", "")

        complexity_score = 0

        # Text length indicates complexity
        if len(text) > 100:
            complexity_score += 2
        elif len(text) > 50:
            complexity_score += 1

        # Keywords indicating complexity
        complex_keywords = [
            "refactor",
            "rewrite",
            "architect",
            "design",
            "complex",
            "multiple",
        ]
        if any(keyword in text.lower() for keyword in complex_keywords):
            complexity_score += 2

        # File type complexity
        if any(ext in file_path.lower() for ext in [".swift", ".cpp", ".c"]):
            complexity_score += 1  # Compiled languages are more complex

        # Priority correlation
        priority = self.calculate_priority(todo)
        if priority >= 8:
            complexity_score += 1

        # Map to complexity levels
        if complexity_score >= 4:
            return "high"
        elif complexity_score >= 2:
            return "medium"
        else:
            return "low"

    def load_existing_tasks(self) -> List[Dict[str, Any]]:
        """Load existing tasks from queue"""
        if not self.task_queue_file.exists():
            return []

        try:
            with open(self.task_queue_file, "r") as f:
                data = json.load(f)
                return data.get("tasks", [])
        except (FileNotFoundError, json.JSONDecodeError):
            return []

    def load_existing_queue(self) -> Dict[str, Any]:
        """Load the entire existing queue structure"""
        if not self.task_queue_file.exists():
            return {"tasks": [], "completed": [], "failed": []}

        try:
            with open(self.task_queue_file, "r") as f:
                data = json.load(f)
                # Ensure all required arrays exist
                if "tasks" not in data:
                    data["tasks"] = []
                if "completed" not in data:
                    data["completed"] = []
                if "failed" not in data:
                    data["failed"] = []
                return data
        except (FileNotFoundError, json.JSONDecodeError):
            return {"tasks": [], "completed": [], "failed": []}

    def save_tasks(self, tasks: List[Dict[str, Any]]):
        """Save tasks to queue file while preserving completed/failed arrays"""
        # Ensure directory exists
        self.task_queue_file.parent.mkdir(exist_ok=True)

        # Load existing queue to preserve completed/failed arrays
        existing_data = self.load_existing_queue()
        existing_data["tasks"] = tasks

        # Atomic write with temporary file
        temp_file = self.task_queue_file.with_suffix(".tmp")
        with open(temp_file, "w") as f:
            json.dump(existing_data, f, indent=2)

        temp_file.replace(self.task_queue_file)
        print(
            f"💾 Saved {len(tasks)} tasks to {self.task_queue_file} (preserved {len(existing_data.get('completed', []))} completed, {len(existing_data.get('failed', []))} failed)"
        )

    def add_todo_tasks(self, todos: List[Dict[str, Any]]) -> int:
        """Add TODO-derived tasks to the queue with intelligent analysis"""
        existing_queue = self.load_existing_queue()
        existing_tasks = existing_queue["tasks"]
        completed_tasks = existing_queue.get("completed", [])
        failed_tasks = existing_queue.get("failed", [])

        # Don't re-add tasks that are already completed or failed
        completed_task_ids = {task["id"] for task in completed_tasks}
        failed_task_ids = {task["id"] for task in failed_tasks}
        existing_task_ids = {task["id"] for task in existing_tasks}
        all_processed_ids = completed_task_ids | failed_task_ids | existing_task_ids

        # Analyze dependencies across all TODOs
        print("🔍 Analyzing TODO dependencies and relationships...")
        dependency_info = self.dependency_analyzer.analyze_todo_dependencies(todos)

        new_tasks = []
        analysis_summary = {
            "total_todos": len(todos),
            "priority_distribution": {},
            "agent_distribution": {},
            "complexity_distribution": {},
            "dependency_insights": dependency_info,
        }

        for todo in todos:
            task = self.convert_todo_to_task(todo, dependency_info)

            # Skip if task already exists (in tasks, completed, or failed)
            if task["id"] not in all_processed_ids:
                new_tasks.append(task)
                existing_tasks.append(task)

                # Update analysis summary
                priority = task["priority"]
                agent = task["assigned_agent"]
                complexity = task["metadata"]["estimated_complexity"]

                analysis_summary["priority_distribution"][priority] = (
                    analysis_summary["priority_distribution"].get(priority, 0) + 1
                )
                analysis_summary["agent_distribution"][agent] = (
                    analysis_summary["agent_distribution"].get(agent, 0) + 1
                )
                analysis_summary["complexity_distribution"][complexity] = (
                    analysis_summary["complexity_distribution"].get(complexity, 0) + 1
                )

        if new_tasks:
            self.save_tasks(existing_tasks)

            # Display intelligent analysis results
            self._display_analysis_results(analysis_summary, dependency_info)

            return len(new_tasks)
        else:
            print("ℹ️  No new TODO tasks to add")
            return 0

    def _display_analysis_results(
        self, analysis_summary: Dict[str, Any], dependency_info: Dict[str, Any]
    ):
        """Display intelligent analysis results"""
        print("\n🎯 INTELLIGENT ANALYSIS RESULTS")
        print("=" * 50)

        # Priority distribution
        print("🎖️  Priority Distribution:")
        for priority in sorted(
            analysis_summary["priority_distribution"].keys(), reverse=True
        ):
            count = analysis_summary["priority_distribution"][priority]
            bars = "█" * count
            print(f"  {priority}/10: {count} tasks {bars}")

        # Agent distribution
        print("\n🤖 Agent Assignment Distribution:")
        for agent in sorted(analysis_summary["agent_distribution"].keys()):
            count = analysis_summary["agent_distribution"][agent]
            percentage = (count / analysis_summary["total_todos"]) * 100
            bars = "█" * int(percentage / 5)  # Scale for display
            print(f"  {agent}: {count} tasks ({percentage:.1f}%) {bars}")

        # Complexity distribution
        print("\n🧠 Complexity Assessment:")
        for complexity in ["high", "medium", "low"]:
            count = analysis_summary["complexity_distribution"].get(complexity, 0)
            if count > 0:
                percentage = (count / analysis_summary["total_todos"]) * 100
                bars = "█" * int(percentage / 5)
                print(
                    f"  {complexity.capitalize()}: {count} tasks ({percentage:.1f}%) {bars}"
                )
        # Dependency insights
        dep_info = dependency_info
        print("\n🔗 Dependency Analysis:")
        print(f"  📋 Explicit dependencies: {len(dep_info['explicit_dependencies'])}")
        print(f"  🔄 File relationships: {len(dep_info['file_dependencies'])}")
        print(f"  ⚠️  Circular dependencies: {len(dep_info['circular_dependencies'])}")
        print(f"  ⛓️  Dependency chains: {len(dep_info['dependency_chains'])}")
        print(f"  🎯 Priority adjustments: {len(dep_info['priority_suggestions'])}")

        if dep_info["circular_dependencies"]:
            print("\n⚠️  WARNING: Circular dependencies detected!")
            for cycle in dep_info["circular_dependencies"][:3]:  # Show first 3
                print(f"  🔄 Cycle: {' -> '.join(cycle)}")

        if dep_info["priority_suggestions"]:
            print("\n📈 Priority Adjustments Made:")
            for suggestion in dep_info["priority_suggestions"][:5]:  # Show first 5
                todo = suggestion["todo"]
                print(
                    f"  📄 {Path(todo['file']).name}:{todo['line']} - Priority {suggestion['original_priority']} → {suggestion['suggested_priority']}"
                )

    def process_todos(self) -> int:
        """Main processing function with intelligent analysis"""
        print("🚀 Starting INTELLIGENT TODO to task conversion...")
        print("🎯 Phase 2: Advanced Prioritization & Agent Matching")
        print("=" * 60)

        # Scan for TODOs
        todos = self.scan_todos()
        if not todos:
            print("⚠️  No TODOs found to process")
            return 0

        # Convert and add tasks with intelligent analysis
        new_task_count = self.add_todo_tasks(todos)

        # Summary
        existing_queue = self.load_existing_queue()
        total_tasks = len(existing_queue["tasks"])
        completed_tasks = len(existing_queue["completed"])
        failed_tasks = len(existing_queue["failed"])
        print("\n📊 Task Queue Status:")
        print(f"  📋 Total tasks in queue: {total_tasks}")
        print(f"  ✅ Completed tasks: {completed_tasks}")
        print(f"  ❌ Failed tasks: {failed_tasks}")
        print(f"  ✨ New TODO tasks added: {new_task_count}")
        print(
            "  🎯 Intelligence features: ✅ Priority scoring, ✅ Agent matching, ✅ Dependency analysis"
        )

        return new_task_count


def main():
    """Main entry point with Phase 2 intelligence"""
    workspace_root = Path(__file__).parent.parent

    converter = TodoTaskConverter(workspace_root)
    new_tasks = converter.process_todos()

    if new_tasks > 0:
        print(
            f"\n🎉 Successfully converted {new_tasks} TODOs into intelligent agent tasks!"
        )
        print(
            "🤖 Agents can now automatically work on these intelligently prioritized tasks"
        )
        print(
            "🎯 Phase 2 features activated: Advanced prioritization, Smart agent matching, Dependency analysis"
        )
    else:
        print("✨ No new TODOs to process at this time")


if __name__ == "__main__":
    main()
