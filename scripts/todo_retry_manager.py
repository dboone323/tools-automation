#!/usr/bin/env python3
"""
TODO Retry Manager
Smart retry logic for failed TODO tasks with analysis and optimization
"""

import os
import json
import time
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
from collections import defaultdict, Counter
import subprocess


class TodoRetryManager:
    """Manages retry logic for failed TODO tasks"""

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.config_dir = workspace_root / "config"
        self.task_queue_file = self.config_dir / "task_queue.json"
        self.agent_status_file = self.config_dir / "agent_status.json"
        self.monitoring_log_file = self.config_dir / "todo_monitoring.json"
        self.retry_log_file = self.config_dir / "todo_retry_log.json"

        # Retry configuration
        self.max_retries = 3
        self.base_delay = 300  # 5 minutes
        self.max_delay = 3600  # 1 hour
        self.backoff_factor = 2.0

        # Failure analysis
        self.failure_patterns = {}
        self.agent_performance = {}

        # Initialize retry log
        self._init_retry_log()

    def _init_retry_log(self):
        """Initialize retry log file"""
        if not self.retry_log_file.exists():
            initial_log = {
                "retry_history": [],
                "failure_analysis": {},
                "retry_statistics": {
                    "total_retries": 0,
                    "successful_retries": 0,
                    "failed_retries": 0,
                    "average_retry_delay": 0,
                },
                "last_updated": datetime.now().isoformat(),
            }
            with open(self.retry_log_file, "w") as f:
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

    def load_retry_log(self) -> Dict[str, Any]:
        """Load retry log"""
        if not self.retry_log_file.exists():
            return {"retry_history": [], "failure_analysis": {}, "retry_statistics": {}}

        try:
            with open(self.retry_log_file, "r") as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {"retry_history": [], "failure_analysis": {}, "retry_statistics": {}}

    def identify_failed_tasks(self) -> List[Dict[str, Any]]:
        """Identify tasks that need retry"""
        tasks = self.load_task_queue().get("tasks", [])
        failed_tasks = []

        for task in tasks:
            if task.get("status") == "failed":
                # Check if task is eligible for retry
                retry_count = task.get("retry_count", 0)
                if retry_count < self.max_retries:
                    failed_tasks.append(task)

        return failed_tasks

    def analyze_failure(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze why a task failed"""
        analysis = {
            "task_id": task.get("id"),
            "failure_reason": "unknown",
            "suggested_action": "retry",
            "agent_reassignment": False,
            "new_agent": None,
            "delay_seconds": self._calculate_retry_delay(task),
            "confidence": 0.5,
        }

        # Analyze failure patterns from monitoring log
        failure_patterns = self._analyze_failure_patterns(task)

        if failure_patterns:
            analysis.update(failure_patterns)

        # Check agent performance
        agent_performance = self._check_agent_performance(task.get("assigned_agent"))
        if agent_performance:
            analysis.update(agent_performance)

        # Task-specific analysis
        task_analysis = self._analyze_task_characteristics(task)
        analysis.update(task_analysis)

        return analysis

    def _analyze_failure_patterns(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze failure patterns from historical data"""
        try:
            with open(self.monitoring_log_file, "r") as f:
                monitoring_data = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

        # Look for similar failed tasks
        task_type = task.get("type", "")
        assigned_agent = task.get("assigned_agent", "")
        source_file = task.get("source_file", "")

        similar_failures = []
        for snapshot in monitoring_data.get("snapshots", []):
            # This is a simplified analysis - in production, you'd want more sophisticated pattern matching
            pass

        # For now, return basic analysis
        if task_type == "todo_processing":
            return {
                "failure_reason": "complexity_overload",
                "suggested_action": "reduce_complexity",
                "confidence": 0.7,
            }

        return {}

    def _check_agent_performance(self, agent_name: str) -> Dict[str, Any]:
        """Check agent performance metrics"""
        try:
            with open(self.monitoring_log_file, "r") as f:
                monitoring_data = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

        # Analyze agent utilization and success rates
        agent_workload = monitoring_data.get("metrics", {}).get("agent_utilization", {})

        if agent_name in agent_workload:
            utilization = agent_workload[agent_name]
            if utilization > 90:
                return {
                    "failure_reason": "agent_overloaded",
                    "suggested_action": "reassign",
                    "agent_reassignment": True,
                    "new_agent": self._find_alternative_agent(agent_name),
                    "confidence": 0.8,
                }

        return {}

    def _find_alternative_agent(self, current_agent: str) -> Optional[str]:
        """Find an alternative agent for reassignment"""
        # Simple agent mapping - in production, this would be more sophisticated
        agent_mapping = {
            "agent_build": ["agent_codegen", "agent_debug"],
            "agent_codegen": ["agent_build", "agent_test"],
            "agent_debug": ["agent_build", "agent_codegen"],
            "agent_test": ["agent_codegen", "agent_performance"],
            "agent_performance": ["agent_test", "agent_security"],
            "agent_security": ["agent_performance", "agent_docs"],
            "agent_docs": ["agent_security", "agent_build"],
        }

        alternatives = agent_mapping.get(current_agent, [])
        if alternatives:
            return alternatives[0]  # Return first alternative

        return None

    def _analyze_task_characteristics(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze task characteristics for retry strategy"""
        priority = task.get("priority", 5)
        retry_count = task.get("retry_count", 0)
        complexity = task.get("metadata", {}).get("estimated_complexity", "medium")

        analysis = {}

        # High priority tasks get more aggressive retry
        if priority >= 8:
            analysis["delay_seconds"] = max(60, self.base_delay // 2)  # Faster retry

        # Complex tasks might need different handling
        if complexity == "high" and retry_count > 1:
            analysis["suggested_action"] = "escalate"
            analysis["confidence"] = 0.9

        # Tasks that keep failing might need human intervention
        if retry_count >= 2:
            analysis["suggested_action"] = "manual_review"
            analysis["confidence"] = 0.95

        return analysis

    def _calculate_retry_delay(self, task: Dict[str, Any]) -> int:
        """Calculate delay before retry"""
        retry_count = task.get("retry_count", 0)
        priority = task.get("priority", 5)

        # Base delay with exponential backoff
        delay = self.base_delay * (self.backoff_factor**retry_count)

        # Cap at maximum delay
        delay = min(delay, self.max_delay)

        # High priority tasks get faster retries
        if priority >= 8:
            delay = delay // 2

        return int(delay)

    def schedule_retry(self, task: Dict[str, Any], analysis: Dict[str, Any]) -> bool:
        """Schedule a task for retry"""
        try:
            # Update task with retry information
            updated_task = task.copy()
            updated_task["retry_count"] = task.get("retry_count", 0) + 1
            updated_task["last_retry"] = datetime.now().isoformat()
            updated_task["retry_analysis"] = analysis
            updated_task["status"] = "pending"  # Reset to pending for retry

            # Apply suggested changes
            if analysis.get("agent_reassignment") and analysis.get("new_agent"):
                updated_task["assigned_agent"] = analysis["new_agent"]
                updated_task["previous_agent"] = task.get("assigned_agent")

            if analysis.get("suggested_action") == "reduce_complexity":
                # Add complexity reduction hints
                updated_task["retry_hints"] = ["break_down_task", "simplify_approach"]

            # Update task queue
            task_queue = self.load_task_queue()
            tasks = task_queue.get("tasks", [])

            # Find and replace the failed task
            for i, t in enumerate(tasks):
                if t.get("id") == task.get("id"):
                    tasks[i] = updated_task
                    break

            task_queue["tasks"] = tasks

            with open(self.task_queue_file, "w") as f:
                json.dump(task_queue, f, indent=2)

            # Log retry
            self._log_retry(updated_task, analysis)

            return True

        except Exception as e:
            print(f"Error scheduling retry for task {task.get('id')}: {e}")
            return False

    def _log_retry(self, task: Dict[str, Any], analysis: Dict[str, Any]):
        """Log retry action"""
        retry_entry = {
            "timestamp": datetime.now().isoformat(),
            "task_id": task.get("id"),
            "retry_count": task.get("retry_count", 0),
            "analysis": analysis,
            "action_taken": "scheduled_retry",
        }

        try:
            retry_log = self.load_retry_log()
            retry_log["retry_history"].append(retry_entry)

            # Update statistics
            stats = retry_log.get("retry_statistics", {})
            stats["total_retries"] = stats.get("total_retries", 0) + 1

            retry_log["retry_statistics"] = stats
            retry_log["last_updated"] = datetime.now().isoformat()

            with open(self.retry_log_file, "w") as f:
                json.dump(retry_log, f, indent=2)

        except Exception as e:
            print(f"Error logging retry: {e}")

    def process_failed_tasks(self) -> Dict[str, Any]:
        """Process all failed tasks and schedule retries"""
        failed_tasks = self.identify_failed_tasks()

        if not failed_tasks:
            return {"processed": 0, "retries_scheduled": 0, "errors": 0}

        results = {
            "processed": len(failed_tasks),
            "retries_scheduled": 0,
            "reassignments": 0,
            "escalations": 0,
            "errors": 0,
        }

        for task in failed_tasks:
            try:
                analysis = self.analyze_failure(task)

                if analysis.get("suggested_action") == "manual_review":
                    # Mark for manual review instead of retry
                    self._mark_for_manual_review(task)
                    continue

                if self.schedule_retry(task, analysis):
                    results["retries_scheduled"] += 1

                    if analysis.get("agent_reassignment"):
                        results["reassignments"] += 1

                    if analysis.get("suggested_action") == "escalate":
                        results["escalations"] += 1
                else:
                    results["errors"] += 1

            except Exception as e:
                print(f"Error processing failed task {task.get('id')}: {e}")
                results["errors"] += 1

        return results

    def _mark_for_manual_review(self, task: Dict[str, Any]):
        """Mark task for manual review"""
        try:
            task_queue = self.load_task_queue()
            tasks = task_queue.get("tasks", [])

            for i, t in enumerate(tasks):
                if t.get("id") == task.get("id"):
                    tasks[i]["status"] = "needs_review"
                    tasks[i]["review_reason"] = "multiple_failures"
                    break

            task_queue["tasks"] = tasks

            with open(self.task_queue_file, "w") as f:
                json.dump(task_queue, f, indent=2)

        except Exception as e:
            print(f"Error marking task for review: {e}")

    def get_retry_statistics(self) -> Dict[str, Any]:
        """Get retry statistics"""
        retry_log = self.load_retry_log()
        return retry_log.get("retry_statistics", {})

    def cleanup_old_retry_data(self, days: int = 30):
        """Clean up old retry data"""
        cutoff_date = datetime.now() - timedelta(days=days)

        try:
            retry_log = self.load_retry_log()
            history = retry_log.get("retry_history", [])

            # Filter out old entries
            filtered_history = []
            for entry in history:
                try:
                    entry_date = datetime.fromisoformat(
                        entry["timestamp"].replace("Z", "+00:00")
                    )
                    if entry_date > cutoff_date:
                        filtered_history.append(entry)
                except (ValueError, KeyError):
                    continue

            retry_log["retry_history"] = filtered_history
            retry_log["last_updated"] = datetime.now().isoformat()

            with open(self.retry_log_file, "w") as f:
                json.dump(retry_log, f, indent=2)

        except Exception as e:
            print(f"Error cleaning up retry data: {e}")


def main():
    """Main entry point for retry manager"""
    import argparse

    parser = argparse.ArgumentParser(description="TODO Retry Manager")
    parser.add_argument(
        "--process-failed",
        action="store_true",
        help="Process failed tasks and schedule retries",
    )
    parser.add_argument(
        "--analyze-task", type=str, help="Analyze a specific failed task"
    )
    parser.add_argument(
        "--statistics", action="store_true", help="Show retry statistics"
    )
    parser.add_argument(
        "--cleanup", type=int, default=30, help="Clean up retry data older than N days"
    )

    args = parser.parse_args()

    workspace_root = Path(__file__).parent.parent
    retry_manager = TodoRetryManager(workspace_root)

    if args.process_failed:
        results = retry_manager.process_failed_tasks()
        print("Retry processing results:")
        print(json.dumps(results, indent=2))

    elif args.analyze_task:
        # Find the task by ID
        tasks = retry_manager.load_task_queue().get("tasks", [])
        task = next((t for t in tasks if t.get("id") == args.analyze_task), None)

        if task:
            analysis = retry_manager.analyze_failure(task)
            print(f"Analysis for task {args.analyze_task}:")
            print(json.dumps(analysis, indent=2))
        else:
            print(f"Task {args.analyze_task} not found")

    elif args.statistics:
        stats = retry_manager.get_retry_statistics()
        print("Retry Statistics:")
        print(json.dumps(stats, indent=2))

    elif args.cleanup:
        retry_manager.cleanup_old_retry_data(args.cleanup)
        print(f"Cleaned up retry data older than {args.cleanup} days")

    else:
        # Default: process failed tasks
        results = retry_manager.process_failed_tasks()
        print("Retry processing results:")
        print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
