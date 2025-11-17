#!/usr/bin/env python3
"""
Agent Efficiency Optimizer
Improves individual agent performance and coordination
"""

import json
import time
import os
from agents.utils import safe_run, user_log
import logging
logger = logging.getLogger(__name__)


class AgentOptimizer:
    def __init__(self, workspace_root=None):
        # Resolve workspace root from env if not passed in
        workspace_root = (
            workspace_root or os.environ.get("WORKSPACE_ROOT") or os.getcwd()
        )
        self.workspace_root = workspace_root
        self.agents_dir = f"{workspace_root}/Tools/Automation/agents"
        self.agent_status_file = f"{self.agents_dir}/agent_status.json"
        self.task_queue_file = f"{self.agents_dir}/task_queue.json"

    def load_agent_status(self):
        """Load current agent status"""
        try:
            with open(self.agent_status_file, "r") as f:
                return json.load(f).get("agents", {})
        except Exception as e:
            logging.getLogger(__name__).warning("Failed to load agent status: %s", e)
            return {}

    def load_tasks(self):
        """Load current tasks"""
        try:
            with open(self.task_queue_file, "r") as f:
                return json.load(f).get("tasks", [])
        except Exception as e:
            logging.getLogger(__name__).warning("Failed to load tasks: %s", e)
            return []

    def optimize_agent_memory(self):
        """Optimize agent memory usage by restarting memory-intensive agents"""
        _agents = self.load_agent_status()
        optimized = 0

        for agent_name, agent_info in _agents.items():
            pid = agent_info.get("pid", 0)
            if pid > 0:
                try:
                    # Check memory usage (simplified - in real implementation use psutil)
                    result = safe_run(
                        ["ps", "-o", "rss=", "-p", str(pid)],
                        capture_output=True,
                        text=True,
                    )
                    if result.returncode == 0:
                        memory_mb = int(result.stdout.strip()) / 1024
                        if memory_mb > 500:  # Restart if > 500MB
                            user_log(f"Restarting high-memory agent: {agent_name} ({memory_mb:.1f}MB)")
                            os.kill(pid, 15)  # SIGTERM
                            time.sleep(2)
                            optimized += 1
                except Exception as e:
                    logger.debug(
                        "agent_optimizer: failed to inspect memory for %s: %s",
                        agent_name,
                        e,
                        exc_info=True,
                    )

        user_log(f"✅ Optimized {optimized} high-memory agents")
        return optimized

    def parallelize_agent_tasks(self):
        """Enable parallel task processing within agents"""
        _agents = self.load_agent_status()
        tasks = self.load_tasks()

        # Group tasks by agent
        agent_tasks = {}
        for task in tasks:
            if task.get("status") == "in_progress":
                agent = task.get("assigned_agent")
                if agent:
                    if agent not in agent_tasks:
                        agent_tasks[agent] = []
                    agent_tasks[agent].append(task)

        # Check for agents with multiple tasks that could be parallelized
        parallelized = 0
        for agent, agent_task_list in agent_tasks.items():
            if len(agent_task_list) > 1:
                # Signal agent to process tasks in parallel if supported
                agent_script = f"{self.agents_dir}/{agent}"
                if os.path.exists(agent_script):
                    try:
                        # Send parallel processing signal (implementation depends on agent)
                        safe_run([agent_script, "parallel", str(len(agent_task_list))], timeout=5, capture_output=True)
                        parallelized += 1
                    except Exception:
                        logger.debug("agent_optimizer: failed to signal agent %s for parallel processing", agent, exc_info=True)

        user_log(f"✅ Enabled parallel processing for {parallelized} agents")
        return parallelized

    def optimize_task_distribution(self):
        """Redistribute tasks for better load balancing"""
        _agents = self.load_agent_status()
        tasks = self.load_tasks()

        # Count tasks per agent
        agent_workload = {}
        for task in tasks:
            if task.get("status") == "in_progress":
                agent = task.get("assigned_agent")
                if agent:
                    agent_workload[agent] = agent_workload.get(agent, 0) + 1

        # Find overloaded agents (> 3 tasks) and underloaded agents (< 1 task)
        overloaded = [a for a, count in agent_workload.items() if count > 3]
        available_agents = [
            a
            for a, info in _agents.items()
            if info.get("status") in ["available", "idle"]
        ]

        redistributed = 0
        for overloaded_agent in overloaded:
            # Find tasks to redistribute
            overloaded_tasks = [
                t
                for t in tasks
                if t.get("assigned_agent") == overloaded_agent
                and t.get("status") == "in_progress"
            ]

            # Redistribute to available agents
            for i, task in enumerate(overloaded_tasks[3:]):  # Keep only 3 tasks
                if i < len(available_agents):
                    new_agent = available_agents[i]
                    task["assigned_agent"] = new_agent
                    redistributed += 1

        if redistributed > 0:
            # Save updated tasks
            with open(self.task_queue_file, "r") as f:
                data = json.load(f)
            data["tasks"] = tasks
            with open(self.task_queue_file, "w") as f:
                json.dump(data, f, indent=2)

        user_log(f"✅ Redistributed {redistributed} tasks for load balancing")
        return redistributed

    def enable_agent_specialization(self):
        """Enable agent specialization for better performance"""
        _agents = self.load_agent_status()
        tasks = self.load_tasks()

        # Analyze task completion patterns
        agent_specialties = {}
        for task in tasks:
            if task.get("status") == "completed":
                agent = task.get("assigned_agent")
                task_type = task.get("type")
                if agent and task_type:
                    if agent not in agent_specialties:
                        agent_specialties[agent] = {}
                    agent_specialties[agent][task_type] = (
                        agent_specialties[agent].get(task_type, 0) + 1
                    )

        # Assign specialized tasks to best agents
        specialized = 0
        for task in tasks:
            if task.get("status") == "queued":
                task_type = task.get("type")
                if task_type:
                    # Find best agent for this task type
                    best_agent = None
                    best_score = 0
                    for agent, specialties in agent_specialties.items():
                        score = specialties.get(task_type, 0)
                        if score > best_score:
                            best_score = score
                            best_agent = agent

                    if (
                        best_agent and best_score > 2
                    ):  # Only specialize if agent has done >2 similar tasks
                        task["assigned_agent"] = best_agent
                        task["specialized"] = True
                        specialized += 1

        if specialized > 0:
            with open(self.task_queue_file, "r") as f:
                data = json.load(f)
            data["tasks"] = tasks
            with open(self.task_queue_file, "w") as f:
                json.dump(data, f, indent=2)

        user_log(f"✅ Specialized {specialized} tasks to best-performing agents")
        return specialized

    def run_optimization_cycle(self):
        """Run complete optimization cycle"""
        user_log("🔧 Running Agent Efficiency Optimization...")

        self.optimize_agent_memory()
        self.parallelize_agent_tasks()
        self.optimize_task_distribution()
        self.enable_agent_specialization()

        user_log("✅ Agent optimization cycle complete!")


def main():
    import sys

    optimizer = AgentOptimizer()

    if len(sys.argv) > 1:
        command = sys.argv[1]

        if command == "memory":
            optimizer.optimize_agent_memory()
        elif command == "parallel":
            optimizer.parallelize_agent_tasks()
        elif command == "balance":
            optimizer.optimize_task_distribution()
        elif command == "specialize":
            optimizer.enable_agent_specialization()
        elif command == "cycle":
            optimizer.run_optimization_cycle()
        else:
            user_log("Usage: python3 agent_optimizer.py [memory|parallel|balance|specialize|cycle]", level="error", stderr=True)
    else:
        optimizer.run_optimization_cycle()


if __name__ == "__main__":
    main()
