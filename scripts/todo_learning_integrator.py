#!/usr/bin/env python3
"""
TODO Learning Integrator
Learning system integration for TODO task processing optimization
"""

import json
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional
from collections import defaultdict
import statistics


class TodoLearningIntegrator:
    """Integrates learning from TODO task completions to improve future assignments"""

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.config_dir = workspace_root / "config"
        self.task_queue_file = self.config_dir / "task_queue.json"
        self.monitoring_log_file = self.config_dir / "todo_monitoring.json"
        self.learning_log_file = self.config_dir / "todo_learning.json"
        self.agent_capabilities_file = self.config_dir / "agent_capabilities.json"

        # Learning data
        self.success_patterns = {}
        self.failure_patterns = {}
        self.agent_performance_history = defaultdict(list)
        self.task_completion_times = defaultdict(list)

        # Initialize learning log
        self._init_learning_log()

    def _init_learning_log(self):
        """Initialize learning log file"""
        if not self.learning_log_file.exists():
            initial_log = {
                "learning_patterns": {
                    "success_patterns": {},
                    "failure_patterns": {},
                    "agent_performance": {},
                    "task_completion_times": {},
                },
                "optimization_rules": [],
                "last_updated": datetime.now().isoformat(),
                "learning_statistics": {
                    "patterns_learned": 0,
                    "optimizations_applied": 0,
                    "performance_improvements": 0,
                },
            }
            with open(self.learning_log_file, "w") as f:
                json.dump(initial_log, f, indent=2)

    def load_learning_data(self) -> Dict[str, Any]:
        """Load learning data"""
        if not self.learning_log_file.exists():
            return {"learning_patterns": {}, "optimization_rules": []}

        try:
            with open(self.learning_log_file, "r") as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {"learning_patterns": {}, "optimization_rules": []}

    def load_monitoring_data(self) -> Dict[str, Any]:
        """Load monitoring data for learning"""
        if not self.monitoring_log_file.exists():
            return {"snapshots": [], "alerts": []}

        try:
            with open(self.monitoring_log_file, "r") as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {"snapshots": [], "alerts": []}

    def analyze_completed_tasks(self) -> Dict[str, Any]:
        """Analyze completed tasks to learn patterns"""
        monitoring_data = self.load_monitoring_data()
        snapshots = monitoring_data.get("snapshots", [])

        if not snapshots:
            return {"analyzed": 0, "patterns_found": 0}

        # Find task completion patterns
        completion_patterns = self._extract_completion_patterns(snapshots)
        agent_performance = self._analyze_agent_performance(snapshots)
        task_characteristics = self._analyze_task_characteristics(snapshots)

        # Update learning data
        learning_data = self.load_learning_data()
        learning_patterns = learning_data.get("learning_patterns", {})

        learning_patterns["success_patterns"] = completion_patterns
        learning_patterns["agent_performance"] = agent_performance
        learning_patterns["task_completion_times"] = task_characteristics

        learning_data["learning_patterns"] = learning_patterns
        learning_data["last_updated"] = datetime.now().isoformat()

        # Save updated learning data
        with open(self.learning_log_file, "w") as f:
            json.dump(learning_data, f, indent=2)

        return {
            "analyzed": len(snapshots),
            "patterns_found": len(completion_patterns),
            "performance_insights": len(agent_performance),
        }

    def _extract_completion_patterns(
        self, snapshots: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Extract successful completion patterns"""
        patterns = {}

        # Analyze task status changes over time
        for snapshot in snapshots[-100:]:  # Last 100 snapshots
            tasks_by_status = snapshot.get("tasks_by_status", {})

            # Look for patterns in completed tasks
            completed_count = tasks_by_status.get("completed", 0)
            if completed_count > 0:
                # Extract patterns from task assignments
                tasks_by_agent = snapshot.get("tasks_by_agent", {})

                for agent, count in tasks_by_agent.items():
                    if agent not in patterns:
                        patterns[agent] = {"total_assigned": 0, "completion_rate": 0}

                    patterns[agent]["total_assigned"] += count

        # Calculate completion rates
        total_completed = sum(
            snapshot.get("tasks_by_status", {}).get("completed", 0)
            for snapshot in snapshots[-50:]
        )  # Last 50 snapshots

        for agent, data in patterns.items():
            if data["total_assigned"] > 0:
                # Estimate completion rate (simplified)
                data["completion_rate"] = min(
                    0.95, total_completed / max(1, data["total_assigned"] * 0.1)
                )

        return patterns

    def _analyze_agent_performance(
        self, snapshots: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Analyze agent performance over time"""
        performance = {}

        for snapshot in snapshots[-50:]:  # Last 50 snapshots
            agent_workload = snapshot.get("agent_workload", {})

            for agent, workload in agent_workload.items():
                if agent not in performance:
                    performance[agent] = {
                        "utilization_samples": [],
                        "avg_utilization": 0,
                        "performance_score": 0,
                    }

                utilization = workload.get("utilization_percent", 0)
                performance[agent]["utilization_samples"].append(utilization)

        # Calculate averages and performance scores
        for agent, data in performance.items():
            samples = data["utilization_samples"]
            if samples:
                avg_utilization = statistics.mean(samples)
                data["avg_utilization"] = round(avg_utilization, 1)

                # Performance score based on utilization (70-85% is optimal)
                if 70 <= avg_utilization <= 85:
                    data["performance_score"] = 1.0
                elif 50 <= avg_utilization <= 95:
                    data["performance_score"] = 0.8
                else:
                    data["performance_score"] = 0.5

            # Clean up samples to keep only recent data
            data["utilization_samples"] = data["utilization_samples"][-20:]

        return performance

    def _analyze_task_characteristics(
        self, snapshots: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Analyze task completion characteristics"""
        characteristics = {}

        # This would analyze completion times, complexity correlations, etc.
        # For now, return basic structure
        characteristics["avg_completion_time"] = "estimated"
        characteristics["complexity_correlations"] = {}
        characteristics["priority_patterns"] = {}

        return characteristics

    def generate_optimization_rules(self) -> List[Dict[str, Any]]:
        """Generate optimization rules based on learned patterns"""
        learning_data = self.load_learning_data()
        patterns = learning_data.get("learning_patterns", {})

        rules = []

        # Rule 1: Agent assignment optimization
        agent_performance = patterns.get("agent_performance", {})
        if agent_performance:
            best_agents = sorted(
                agent_performance.items(),
                key=lambda x: x[1].get("performance_score", 0),
                reverse=True,
            )

            if best_agents:
                top_agent = best_agents[0][0]
                rules.append(
                    {
                        "rule_id": "agent_assignment_optimization",
                        "type": "assignment",
                        "condition": "high_priority_task",
                        "action": f"prefer_agent_{top_agent}",
                        "reason": f"{top_agent} shows highest performance score",
                        "confidence": 0.8,
                    }
                )

        # Rule 2: Workload balancing
        overloaded_agents = [
            agent
            for agent, perf in agent_performance.items()
            if perf.get("avg_utilization", 0) > 90
        ]

        if overloaded_agents:
            rules.append(
                {
                    "rule_id": "workload_balancing",
                    "type": "balancing",
                    "condition": f"agent_in_{overloaded_agents}",
                    "action": "redistribute_tasks",
                    "reason": "Prevent agent overload",
                    "confidence": 0.9,
                }
            )

        # Rule 3: Success pattern application
        success_patterns = patterns.get("success_patterns", {})
        if success_patterns:
            # Find most successful agent patterns
            successful_agents = [
                agent
                for agent, pattern in success_patterns.items()
                if pattern.get("completion_rate", 0) > 0.8
            ]

            if successful_agents:
                rules.append(
                    {
                        "rule_id": "success_pattern_application",
                        "type": "pattern",
                        "condition": "similar_task_type",
                        "action": f"apply_{successful_agents[0]}_approach",
                        "reason": "Historical success pattern",
                        "confidence": 0.7,
                    }
                )

        # Save rules
        learning_data["optimization_rules"] = rules
        with open(self.learning_log_file, "w") as f:
            json.dump(learning_data, f, indent=2)

        return rules

    def apply_learning_optimizations(self) -> Dict[str, Any]:
        """Apply learned optimizations to current task assignments"""
        learning_data = self.load_learning_data()
        rules = learning_data.get("optimization_rules", [])

        if not rules:
            return {"applied": 0, "reason": "no_rules_available"}

        # Load current task queue
        try:
            with open(self.task_queue_file, "r") as f:
                task_queue = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {"applied": 0, "error": "cannot_load_task_queue"}

        tasks = task_queue.get("tasks", [])
        optimizations_applied = 0

        for rule in rules:
            rule_type = rule.get("type")

            if rule_type == "assignment":
                # Apply agent assignment optimization
                optimizations_applied += self._apply_assignment_optimization(
                    tasks, rule
                )
            elif rule_type == "balancing":
                # Apply workload balancing
                optimizations_applied += self._apply_workload_balancing(tasks, rule)

        # Save updated task queue if optimizations were applied
        if optimizations_applied > 0:
            task_queue["tasks"] = tasks
            with open(self.task_queue_file, "w") as f:
                json.dump(task_queue, f, indent=2)

        # Update statistics
        stats = learning_data.get("learning_statistics", {})
        stats["optimizations_applied"] = (
            stats.get("optimizations_applied", 0) + optimizations_applied
        )
        learning_data["learning_statistics"] = stats

        with open(self.learning_log_file, "w") as f:
            json.dump(learning_data, f, indent=2)

        return {
            "applied": optimizations_applied,
            "rules_processed": len(rules),
        }

    def _apply_assignment_optimization(
        self, tasks: List[Dict[str, Any]], rule: Dict[str, Any]
    ) -> int:
        """Apply agent assignment optimization"""
        action = rule.get("action", "")
        if not action.startswith("prefer_agent_"):
            return 0

        preferred_agent = action.replace("prefer_agent_", "")
        optimizations = 0

        for task in tasks:
            if (
                task.get("status") == "pending"
                and task.get("priority", 0) >= 8  # High priority tasks
                and task.get("assigned_agent") != preferred_agent
            ):

                task["assigned_agent"] = preferred_agent
                task["optimization_applied"] = rule.get("rule_id")
                optimizations += 1

        return optimizations

    def _apply_workload_balancing(
        self, tasks: List[Dict[str, Any]], rule: Dict[str, Any]
    ) -> int:
        """Apply workload balancing optimization"""
        condition = rule.get("condition", "")
        if not condition.startswith("agent_in_"):
            return 0

        # Parse overloaded agents from condition
        # This is a simplified implementation
        overloaded_agents = ["agent_build", "agent_debug"]  # Would parse from rule

        optimizations = 0

        for task in tasks:
            if (
                task.get("status") == "pending"
                and task.get("assigned_agent") in overloaded_agents
            ):

                # Find alternative agent
                alternative = self._find_balancing_alternative(
                    task.get("assigned_agent")
                )
                if alternative:
                    task["assigned_agent"] = alternative
                    task["previous_agent"] = task.get("assigned_agent")
                    task["optimization_applied"] = rule.get("rule_id")
                    optimizations += 1

        return optimizations

    def _find_balancing_alternative(self, current_agent: str) -> Optional[str]:
        """Find alternative agent for workload balancing"""
        # Simple mapping - in production, this would be more sophisticated
        alternatives = {
            "agent_build": "agent_codegen",
            "agent_debug": "agent_build",
            "agent_codegen": "agent_test",
            "agent_test": "agent_performance",
        }

        return alternatives.get(current_agent)

    def get_learning_insights(self) -> Dict[str, Any]:
        """Get learning insights and recommendations"""
        learning_data = self.load_learning_data()

        insights = {
            "patterns_learned": len(learning_data.get("learning_patterns", {})),
            "rules_generated": len(learning_data.get("optimization_rules", [])),
            "statistics": learning_data.get("learning_statistics", {}),
            "recommendations": [],
        }

        # Generate recommendations based on learning
        patterns = learning_data.get("learning_patterns", {})

        # Agent performance recommendations
        agent_perf = patterns.get("agent_performance", {})
        if agent_perf:
            underperforming = [
                agent
                for agent, perf in agent_perf.items()
                if perf.get("performance_score", 0) < 0.7
            ]

            if underperforming:
                insights["recommendations"].append(
                    {
                        "type": "agent_optimization",
                        "message": f"Consider optimizing agents: {', '.join(underperforming)}",
                        "priority": "medium",
                    }
                )

        # Success pattern recommendations
        success_patterns = patterns.get("success_patterns", {})
        if success_patterns:
            top_performers = sorted(
                success_patterns.items(),
                key=lambda x: x[1].get("completion_rate", 0),
                reverse=True,
            )[:3]

            if top_performers:
                insights["recommendations"].append(
                    {
                        "type": "assignment_optimization",
                        "message": f"Prioritize tasks to top agents: {', '.join([agent for agent, _ in top_performers])}",
                        "priority": "high",
                    }
                )

        return insights

    def run_learning_cycle(self) -> Dict[str, Any]:
        """Run a complete learning cycle"""
        results = {
            "phase": "learning_cycle",
            "timestamp": datetime.now().isoformat(),
            "steps": {},
        }

        # Step 1: Analyze completed tasks
        analysis_results = self.analyze_completed_tasks()
        results["steps"]["analysis"] = analysis_results

        # Step 2: Generate optimization rules
        rules = self.generate_optimization_rules()
        results["steps"]["rule_generation"] = {"rules_created": len(rules)}

        # Step 3: Apply optimizations
        optimization_results = self.apply_learning_optimizations()
        results["steps"]["optimization"] = optimization_results

        # Step 4: Get insights
        insights = self.get_learning_insights()
        results["steps"]["insights"] = insights

        return results


def main():
    """Main entry point for learning integrator"""
    import argparse

    parser = argparse.ArgumentParser(description="TODO Learning Integrator")
    parser.add_argument(
        "--analyze",
        action="store_true",
        help="Analyze completed tasks and learn patterns",
    )
    parser.add_argument(
        "--optimize", action="store_true", help="Apply learned optimizations"
    )
    parser.add_argument(
        "--insights", action="store_true", help="Show learning insights"
    )
    parser.add_argument(
        "--cycle", action="store_true", help="Run complete learning cycle"
    )

    args = parser.parse_args()

    workspace_root = Path(__file__).parent.parent
    learning_integrator = TodoLearningIntegrator(workspace_root)

    if args.analyze:
        results = learning_integrator.analyze_completed_tasks()
        print("Analysis Results:")
        print(json.dumps(results, indent=2))

    elif args.optimize:
        results = learning_integrator.apply_learning_optimizations()
        print("Optimization Results:")
        print(json.dumps(results, indent=2))

    elif args.insights:
        insights = learning_integrator.get_learning_insights()
        print("Learning Insights:")
        print(json.dumps(insights, indent=2))

    elif args.cycle:
        results = learning_integrator.run_learning_cycle()
        print("Learning Cycle Results:")
        print(json.dumps(results, indent=2))

    else:
        # Default: run learning cycle
        results = learning_integrator.run_learning_cycle()
        print("Learning Cycle Results:")
        print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
