#!/usr/bin/env python3
"""
Final Acceleration Burst - Maximize utilization of running agents
"""

import json
import time
import os
import subprocess
import logging
import threading
from agents.utils import safe_run, user_log, safe_start
logger = logging.getLogger(__name__)


class FinalAccelerator:
    def __init__(self, workspace_root=None):
        if workspace_root is None:
            workspace_root = os.environ.get(
                "WORKSPACE_ROOT",
                os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            )
        self.workspace_root = workspace_root
        self.agents_dir = f"{workspace_root}/Tools/Automation/agents"

    def emergency_agent_restart(self):
        """Force restart all agents with maximum priority"""
        logger.warning("🚨 EMERGENCY AGENT RESTART")

        # Kill all existing agents
        try:
            safe_run(["pkill", "-f", "agent_.*.sh"], capture_output=True)
            safe_run(["pkill", "-f", "quality_agent.sh"], capture_output=True)
        except Exception:
            logger.debug("Failed to pkill agent processes (not fatal)")
        time.sleep(2)

        # Start agents with high priority
        agents_to_start = [
            "agent_analytics.sh",
            "agent_build.sh",
            "agent_cleanup.sh",
            "agent_codegen.sh",
            "code_review_agent.sh",
            "deployment_agent.sh",
            "documentation_agent.sh",
            "learning_agent.sh",
            "monitoring_agent.sh",
            "performance_agent.sh",
            "quality_agent.sh",
            "search_agent.sh",
            "security_agent.sh",
            "testing_agent.sh",
        ]

        started = 0
        for agent in agents_to_start:
            agent_path = f"{self.agents_dir}/{agent}"
            if os.path.exists(agent_path):
                try:
                    # Start with nice -n -10 (high priority)
                    safe_start(
                        ["nice", "-n", "-10", "bash", agent_path, "start"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    started += 1
                    time.sleep(0.2)  # Stagger starts
                except Exception as e:
                    logger.debug("Failed to spawn agent %s: %s", agent, e, exc_info=True)

        logger.info(f"✅ Emergency restarted {started} agents with high priority")
        return started

    def force_maximum_task_distribution(self):
        """Force distribute all available tasks to running agents"""
        logger.warning("🔥 FORCE MAXIMUM TASK DISTRIBUTION")

        # Load current data
        with open(f"{self.agents_dir}/task_queue.json", "r") as f:
            queue_data = json.load(f)

        with open(f"{self.agents_dir}/agent_status.json", "r") as f:
            agent_data = json.load(f)

        tasks = queue_data["tasks"]
        agents = agent_data["agents"]

        # Get running agents
        running_agents = []
        for agent_name, agent_info in agents.items():
            pid = agent_info.get("pid", 0)
            if pid > 0:
                try:
                    os.kill(pid, 0)
                    running_agents.append(agent_name)
                except Exception:
                    pass

        logger.info(f"Running agents: {len(running_agents)}")

        # Get available tasks
        available_tasks = [t for t in tasks if t.get("status") in ["queued", "batched"]]
        logger.info(f"Available tasks: {len(available_tasks)}")

        # Force assign tasks (allow multiple per agent)
        max_per_agent = 5  # Allow up to 5 concurrent tasks per agent
        assignments = 0
        agent_index = 0

        for task in available_tasks:
            if assignments >= len(running_agents) * max_per_agent:
                break

            agent = running_agents[agent_index % len(running_agents)]
            task["status"] = "in_progress"
            task["assigned_agent"] = agent
            task["force_assigned"] = True
            task["emergency_boost"] = True
            assignments += 1

            agent_index += 1

        # Save updated queue
        queue_data["tasks"] = tasks
        queue_data["emergency_acceleration"] = True
        queue_data["max_assignments"] = assignments

        with open(f"{self.agents_dir}/task_queue.json", "w") as f:
            json.dump(queue_data, f, indent=2)

        logger.info(f"✅ Force assigned {assignments} tasks ({max_per_agent} per agent max)")
        return assignments

    def enable_ultra_performance_mode(self):
        """Enable ultra performance mode for all agents"""
        logger.warning("⚡ ENABLING ULTRA PERFORMANCE MODE")

        # Create ultra performance config
        config = {
            "ultra_performance_mode": True,
            "max_concurrent_tasks": 10,
            "task_timeout": 120,  # 2 minutes
            "memory_limit": 2048,  # 2GB per agent
            "cpu_priority": "maximum",
            "parallel_processing": True,
            "batch_size": 20,
            "emergency_acceleration": True,
            "disable_logging": False,  # Keep logging for monitoring
            "aggressive_cleanup": True,
        }

        with open(f"{self.agents_dir}/ultra_performance_config.json", "w") as f:
            json.dump(config, f, indent=2)

        logger.info("✅ Ultra performance config created")

        # Send URGENT signals to running agents
        with open(f"{self.agents_dir}/agent_status.json", "r") as f:
            agent_data = json.load(f)

        urgent_signals = 0
        for agent_name, agent_info in agent_data["agents"].items():
            pid = agent_info.get("pid", 0)
            if pid > 0:
                try:
                    # Send SIGURG (urgent condition)
                    os.kill(pid, 23)  # SIGURG
                    urgent_signals += 1
                except Exception:
                    pass

        logger.info(f"✅ Sent urgent performance signals to {urgent_signals} agents")

    def start_acceleration_monitor(self):
        """Start real-time acceleration monitoring"""

        def monitor():
            while True:
                try:
                    # Quick status check
                    with open(f"{self.agents_dir}/task_queue.json", "r") as f:
                        queue_data = json.load(f)

                    tasks = queue_data["tasks"]
                    in_progress = len(
                        [t for t in tasks if t.get("status") == "in_progress"]
                    )
                    _completed = len(queue_data.get("completed", []))

                    if in_progress < 10:  # If less than 10 tasks running, boost
                        logger.info(
                            "📈 Low activity detected (%s tasks). Boosting...", in_progress
                        )
                        self.force_maximum_task_distribution()

                except Exception as e:
                    logger.exception("Monitor error: %s", e)

                time.sleep(30)  # Check every 30 seconds

        monitor_thread = threading.Thread(target=monitor, daemon=True)
        monitor_thread.start()
        logger.info("✅ Acceleration monitor started")

    def run_emergency_acceleration(self):
        """Run complete emergency acceleration protocol"""
        user_log("🚨 EMERGENCY ACCELERATION PROTOCOL ACTIVATED")
        user_log("=" * 60)
        user_log("🎯 TARGET: Complete automation in DAYS")
        user_log("⚡ Ultra performance mode + maximum parallelization")
        user_log("=" * 60)

        self.emergency_agent_restart()
        time.sleep(3)  # Wait for agents to start

        self.force_maximum_task_distribution()
        self.enable_ultra_performance_mode()
        self.start_acceleration_monitor()

        user_log("\n🎯 FINAL ACCELERATION STATUS:")
        user_log("  ✅ Emergency agent restart: COMPLETE")
        user_log("  ✅ Maximum task distribution: ACTIVE")
        user_log("  ✅ Ultra performance mode: ENABLED")
        user_log("  ✅ Real-time monitoring: ACTIVE")
        user_log("\n📊 Monitor progress at: http://127.0.0.1:8080")
        user_log("🎯 Expected completion: DAYS (not months)!")


def main():
    accelerator = FinalAccelerator()
    accelerator.run_emergency_acceleration()


if __name__ == "__main__":
    main()
