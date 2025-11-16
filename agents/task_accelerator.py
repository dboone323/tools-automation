#!/usr/bin/env python3
"""
Quantum Workspace Task Accelerator
Speeds up automation by optimizing task processing and parallel execution
"""

import json
import time
import os
import sys
from datetime import datetime, timedelta


class TaskAccelerator:
    def __init__(self, workspace_root=None):
        if workspace_root is None:
            workspace_root = os.environ.get(
                "WORKSPACE_ROOT",
                os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            )
        self.workspace_root = workspace_root
        self.agents_dir = f"{workspace_root}/Tools/Automation/agents"
        self.task_queue_file = f"{self.agents_dir}/task_queue.json"
        self.agent_status_file = f"{self.agents_dir}/agent_status.json"

        # Load current data
        self.tasks = []
        self.completed = []
        self.agents = {}
        self.load_data()

    def load_data(self):
        """Load current task queue and agent status"""
        try:
            with open(self.task_queue_file, "r") as f:
                data = json.load(f)
                self.tasks = data.get("tasks", [])
                self.completed = data.get("completed", [])
        except Exception as e:
            print(f"Error loading task queue: {e}")
            self.tasks = []
            self.completed = []

        try:
            with open(self.agent_status_file, "r") as f:
                data = json.load(f)
                self.agents = data.get("agents", {})
        except Exception as e:
            print(f"Error loading agent status: {e}")
            self.agents = {}

    def save_data(self):
        """Save updated task queue"""
        data = {
            "tasks": self.tasks,
            "completed": self.completed,
            "last_updated": int(time.time()),
        }
        with open(self.task_queue_file, "w") as f:
            json.dump(data, f, indent=2)

    def retry_failed_tasks(self):
        """Retry all failed tasks by resetting their status"""
        failed_count = 0
        for task in self.tasks:
            if task.get("status") == "failed":
                task["status"] = "queued"
                task["retry_count"] = task.get("retry_count", 0) + 1
                task["last_retry"] = int(time.time())
                failed_count += 1

        self.save_data()
        print(f"✅ Retried {failed_count} failed tasks")
        return failed_count

    def prioritize_tasks(self):
        """Implement priority queue for critical tasks"""
        priority_order = {
            "security": 1,
            "performance": 2,
            "testing": 3,
            "review": 4,
            "api": 5,
            "ui": 6,
            "codegen": 7,
            "debug": 8,
        }

        def get_priority(task):
            task_type = task.get("type", "unknown")
            return priority_order.get(task_type, 99)

        # Sort queued tasks by priority
        queued_tasks = [t for t in self.tasks if t.get("status") == "queued"]
        queued_tasks.sort(key=get_priority)

        # Update task order in queue
        non_queued = [t for t in self.tasks if t.get("status") != "queued"]
        self.tasks = queued_tasks + non_queued

        self.save_data()
        print(f"✅ Prioritized {len(queued_tasks)} queued tasks")
        return len(queued_tasks)

    def get_available_agents(self):
        """Get list of agents that can take new tasks"""
        available = []
        for agent_name, agent_info in self.agents.items():
            pid = agent_info.get("pid", 0)
            status = agent_info.get("status", "unknown")

            # Check if process is actually running
            is_running = False
            if pid > 0:
                try:
                    os.kill(pid, 0)
                    is_running = True
                except OSError:
                    is_running = False

            if is_running and status in ["available", "idle"]:
                available.append(agent_name)

        return available

    def assign_tasks_to_agents(self, max_concurrent=12):
        """Assign queued tasks to available agents"""
        available_agents = self.get_available_agents()
        queued_tasks = [t for t in self.tasks if t.get("status") == "queued"]

        assignments = 0
        for i, task in enumerate(queued_tasks[:max_concurrent]):
            if i < len(available_agents):
                agent = available_agents[i]
                task["status"] = "in_progress"
                task["assigned_agent"] = agent
                task["assigned_at"] = int(time.time())
                assignments += 1

        self.save_data()
        print(
            f"✅ Assigned {assignments} tasks to {len(available_agents)} available agents"
        )
        return assignments

    def batch_similar_tasks(self):
        """Group similar tasks for batch processing"""
        task_groups = {}
        for task in self.tasks:
            if task.get("status") == "queued":
                task_type = task.get("type", "unknown")
                if task_type not in task_groups:
                    task_groups[task_type] = []
                task_groups[task_type].append(task)

        # Create batch tasks for large groups
        batch_tasks_created = 0
        for task_type, tasks in task_groups.items():
            if len(tasks) > 10:  # Only batch if more than 10 similar tasks
                # Create a batch task
                batch_task = {
                    "id": f"batch_{task_type}_{int(time.time())}",
                    "type": f"batch_{task_type}",
                    "description": f"Batch process {len(tasks)} {task_type} tasks",
                    "status": "queued",
                    "created_at": int(time.time()),
                    "batch_size": len(tasks),
                    "subtasks": [t["id"] for t in tasks],
                }
                self.tasks.append(batch_task)
                batch_tasks_created += 1

                # Mark individual tasks as batched
                for task in tasks:
                    task["status"] = "batched"
                    task["batch_id"] = batch_task["id"]

        self.save_data()
        print(f"✅ Created {batch_tasks_created} batch tasks for large task groups")
        return batch_tasks_created

    def optimize_agent_orchestration(self):
        """Optimize agent coordination and task assignment"""
        # Kill stuck agents (tasks running > 2 hours)
        current_time = time.time()
        stuck_count = 0

        for task in self.tasks:
            if task.get("status") == "in_progress":
                assigned_at = task.get("assigned_at", 0)
                if current_time - assigned_at > 7200:  # 2 hours
                    task["status"] = "queued"
                    task["assigned_agent"] = None
                    task["stuck_retry"] = task.get("stuck_retry", 0) + 1
                    stuck_count += 1

        if stuck_count > 0:
            self.save_data()
            print(f"✅ Reset {stuck_count} stuck tasks (running > 2 hours)")

        return stuck_count

    def run_accelerator_cycle(self):
        """Run one complete optimization cycle"""
        print("🚀 Starting Task Acceleration Cycle...")

        # Step 1: Retry failed tasks
        self.retry_failed_tasks()

        # Step 2: Reset stuck tasks
        self.optimize_agent_orchestration()

        # Step 3: Prioritize tasks
        self.prioritize_tasks()

        # Step 4: Batch similar tasks
        self.batch_similar_tasks()

        # Step 5: Assign tasks to agents
        self.assign_tasks_to_agents()

        print("✅ Acceleration cycle complete!")

    def get_progress_report(self):
        """Generate progress report"""
        total_tasks = len(self.tasks) + len(self.completed)
        completed_count = len(self.completed)
        remaining_count = len(self.tasks)

        progress_pct = (completed_count / total_tasks * 100) if total_tasks > 0 else 0

        in_progress = len([t for t in self.tasks if t.get("status") == "in_progress"])
        queued = len([t for t in self.tasks if t.get("status") == "queued"])
        failed = len([t for t in self.tasks if t.get("status") == "failed"])

        available_agents = len(self.get_available_agents())
        total_agents = len(self.agents)

        print("📊 PROGRESS REPORT")
        print(f"Progress: {completed_count}/{total_tasks} ({progress_pct:.1f}%)")
        print(f"Remaining: {remaining_count} tasks")
        print(f"In Progress: {in_progress} tasks")
        print(f"Queued: {queued} tasks")
        print(f"Failed: {failed} tasks")
        print(f"Available Agents: {available_agents}/{total_agents}")

        # Estimate completion time
        if completed_count > 0 and in_progress > 0:
            # Calculate current rate
            start_time = min(
                [t.get("completed_at", time.time()) for t in self.completed]
            )
            elapsed_hours = (time.time() - start_time) / 3600
            rate_per_hour = completed_count / elapsed_hours if elapsed_hours > 0 else 0

            if rate_per_hour > 0:
                remaining_hours = remaining_count / rate_per_hour
                remaining_days = remaining_hours / 24
                completion_date = datetime.now() + timedelta(hours=remaining_hours)

                print("\\n⏱️  ESTIMATED COMPLETION:")
                print(f"Current rate: {rate_per_hour:.2f} tasks/hour")
                print(f"Time remaining: {remaining_days:.1f} days")
                print(f"Completion date: {completion_date.strftime('%Y-%m-%d %H:%M')}")


def main():
    accelerator = TaskAccelerator()

    if len(sys.argv) > 1:
        command = sys.argv[1]

        if command == "retry":
            accelerator.retry_failed_tasks()
        elif command == "prioritize":
            accelerator.prioritize_tasks()
        elif command == "assign":
            accelerator.assign_tasks_to_agents()
        elif command == "batch":
            accelerator.batch_similar_tasks()
        elif command == "optimize":
            accelerator.optimize_agent_orchestration()
        elif command == "cycle":
            accelerator.run_accelerator_cycle()
        elif command == "report":
            accelerator.get_progress_report()
        else:
            print(
                "Usage: python3 task_accelerator.py [retry|prioritize|assign|batch|optimize|cycle|report]"
            )
    else:
        # Run full cycle by default
        accelerator.run_accelerator_cycle()
        accelerator.get_progress_report()


if __name__ == "__main__":
    main()
