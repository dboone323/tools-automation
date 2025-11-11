#!/usr/bin/env python3
"""
Tools Automation Metrics Exporter
Provides Prometheus metrics for agent monitoring
"""

import time
import json
import os
from flask import Flask, Response
from prometheus_client import (
    Gauge,
    Counter,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST,
)

app = Flask(__name__)

# Metrics definitions
AGENT_STATUS = Gauge(
    "agent_status", "Agent operational status", ["agent_name", "agent_type"]
)
AGENT_TASKS_COMPLETED = Gauge(
    "agent_tasks_completed_total",
    "Total tasks completed by agent",
    ["agent_name", "task_type"],
)
AGENT_TASKS_FAILED = Gauge(
    "agent_tasks_failed_total",
    "Total tasks failed by agent",
    ["agent_name", "task_type"],
)
AGENT_RESPONSE_TIME = Histogram(
    "agent_response_time_seconds", "Agent response time", ["agent_name", "endpoint"]
)
AGENT_MEMORY_USAGE = Gauge(
    "agent_memory_usage_bytes", "Agent memory usage", ["agent_name"]
)
AGENT_CPU_USAGE = Gauge("agent_cpu_usage_percent", "Agent CPU usage", ["agent_name"])

# System metrics
SYSTEM_AGENTS_TOTAL = Gauge("system_agents_total", "Total number of registered agents")
SYSTEM_TASKS_QUEUED = Gauge("system_tasks_queued", "Number of tasks in queue")
SYSTEM_TASKS_PROCESSING = Gauge(
    "system_tasks_processing", "Number of tasks currently processing"
)


# Load agent status from JSON files
def load_agent_status():
    """Load agent status from monitoring files"""
    agents_dir = os.path.join(os.path.dirname(__file__), "agents")
    agent_status_file = os.path.join(os.path.dirname(__file__), "agent_status.json")

    agents = {}

    # Load from agent_status.json if it exists
    if os.path.exists(agent_status_file):
        try:
            with open(agent_status_file, "r") as f:
                agents = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            pass

    # Load from individual agent files
    if os.path.exists(agents_dir):
        for filename in os.listdir(agents_dir):
            if filename.endswith("_status.json"):
                agent_name = filename.replace("_status.json", "")
                try:
                    with open(os.path.join(agents_dir, filename), "r") as f:
                        agent_data = json.load(f)
                        agents[agent_name] = agent_data
                except (json.JSONDecodeError, FileNotFoundError):
                    continue

    return agents


def update_metrics():
    """Update Prometheus metrics based on current agent status"""
    agents = load_agent_status()

    # Reset counters (in a real implementation, you'd track these persistently)
    # For now, we'll just set current values

    total_agents = len(agents)
    SYSTEM_AGENTS_TOTAL.set(total_agents)

    tasks_queued = 0
    tasks_processing = 0

    for agent_name, agent_data in agents.items():
        # Agent status (1 = running, 0 = stopped)
        status = 1 if agent_data.get("status") == "running" else 0
        agent_type = agent_data.get("type", "unknown")
        AGENT_STATUS.labels(agent_name=agent_name, agent_type=agent_type).set(status)

        # Task counts
        completed = agent_data.get("tasks_completed", 0)
        failed = agent_data.get("tasks_failed", 0)
        AGENT_TASKS_COMPLETED.labels(agent_name=agent_name, task_type="all").set(
            completed
        )
        AGENT_TASKS_FAILED.labels(agent_name=agent_name, task_type="all").set(failed)

        # Queue status
        queued = agent_data.get("tasks_queued", 0)
        processing = agent_data.get("tasks_processing", 0)
        tasks_queued += queued
        tasks_processing += processing

        # Resource usage (mock values for now)
        memory_mb = agent_data.get("memory_usage", 50)  # MB
        cpu_percent = agent_data.get("cpu_usage", 5)  # %
        AGENT_MEMORY_USAGE.labels(agent_name=agent_name).set(memory_mb * 1024 * 1024)
        AGENT_CPU_USAGE.labels(agent_name=agent_name).set(cpu_percent)

    SYSTEM_TASKS_QUEUED.set(tasks_queued)
    SYSTEM_TASKS_PROCESSING.set(tasks_processing)


@app.route("/metrics")
def metrics():
    """Prometheus metrics endpoint"""
    update_metrics()
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


@app.route("/health")
def health():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": time.time()}


@app.route("/")
def index():
    """Basic info page"""
    agents = load_agent_status()
    return {
        "service": "Tools Automation Metrics Exporter",
        "version": "1.0.0",
        "agents_monitored": len(agents),
        "endpoints": {"metrics": "/metrics", "health": "/health"},
    }


if __name__ == "__main__":
    print("🚀 Starting Tools Automation Metrics Exporter...")
    print("📊 Metrics available at: http://localhost:8080/metrics")
    print("💚 Health check at: http://localhost:8080/health")

    app.run(host="0.0.0.0", port=8080, debug=False)
