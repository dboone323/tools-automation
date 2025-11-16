#!/usr/bin/env python3
"""
Tools Automation Metrics Exporter
Provides comprehensive Prometheus metrics for agent monitoring and SLO tracking
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

# Agent status metrics
AGENT_STATUS = Gauge(
    "agent_status", "Agent operational status", ["agent_name", "agent_type"]
)
AGENT_UPTIME = Gauge("agent_uptime_seconds", "Agent uptime in seconds", ["agent_name"])
AGENT_HEALTH_SCORE = Gauge(
    "agent_health_score", "Agent health score (0-1)", ["agent_name"]
)

# Task metrics
AGENT_TASKS_COMPLETED = Counter(
    "agent_tasks_completed_total",
    "Total tasks completed by agent",
    ["agent_name", "task_type"],
)
AGENT_TASKS_FAILED = Counter(
    "agent_tasks_failed_total",
    "Total tasks failed by agent",
    ["agent_name", "task_type"],
)
AGENT_TASKS_QUEUED = Gauge(
    "agent_tasks_queued", "Number of tasks queued for agent", ["agent_name"]
)
AGENT_TASKS_PROCESSING = Gauge(
    "agent_tasks_processing", "Number of tasks currently processing", ["agent_name"]
)

# Performance metrics
AGENT_RESPONSE_TIME = Histogram(
    "agent_response_time_seconds", "Agent response time", ["agent_name", "endpoint"]
)
AGENT_MEMORY_USAGE = Gauge(
    "agent_memory_usage_bytes", "Agent memory usage", ["agent_name"]
)
AGENT_CPU_USAGE = Gauge("agent_cpu_usage_percent", "Agent CPU usage", ["agent_name"])

# SLO metrics
AGENT_SLO_UPTIME = Gauge(
    "agent_slo_uptime_percent", "Agent SLO uptime percentage", ["agent_name"]
)
AGENT_SLO_LATENCY = Gauge(
    "agent_slo_latency_ms", "Agent SLO latency target", ["agent_name"]
)
AGENT_SLO_ERROR_RATE = Gauge(
    "agent_slo_error_rate_percent", "Agent SLO error rate target", ["agent_name"]
)

# System-wide metrics
SYSTEM_AGENTS_TOTAL = Gauge("system_agents_total", "Total number of registered agents")
SYSTEM_AGENTS_RUNNING = Gauge("system_agents_running", "Number of running agents")
SYSTEM_TASKS_QUEUED = Gauge("system_tasks_queued", "Number of tasks in queue")
SYSTEM_TASKS_PROCESSING = Gauge(
    "system_tasks_processing", "Number of tasks currently processing"
)
SYSTEM_HEALTH_SCORE = Gauge("system_health_score", "Overall system health score (0-1)")

# Alert metrics
ALERTS_ACTIVE = Gauge("alerts_active", "Number of active alerts", ["severity"])
ALERTS_TRIGGERED = Counter(
    "alerts_triggered_total", "Total alerts triggered", ["severity", "source"]
)


# Load alert configuration
def load_alert_config():
    """Load alert configuration for SLO thresholds"""
    config_file = os.path.join(os.path.dirname(__file__), "alert_config.json")
    if os.path.exists(config_file):
        try:
            with open(config_file, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            pass
    return {}


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


def calculate_health_score(agent_data):
    """Calculate health score for an agent based on various metrics"""
    score = 1.0

    # Status penalty
    if agent_data.get("status") != "running":
        score -= 0.5

    # Error rate penalty
    total_tasks = agent_data.get("tasks_completed", 0) + agent_data.get(
        "tasks_failed", 0
    )
    if total_tasks > 0:
        error_rate = agent_data.get("tasks_failed", 0) / total_tasks
        score -= min(error_rate * 2, 0.3)  # Max 30% penalty for errors

    # Resource usage penalty
    cpu_usage = agent_data.get("cpu_usage", 0)
    mem_usage = agent_data.get("memory_usage", 0)
    if cpu_usage > 80:
        score -= 0.1
    if mem_usage > 80:
        score -= 0.1

    return max(0.0, min(1.0, score))


def load_alerts():
    """Load active alerts"""
    alerts_dir = os.path.join(os.path.dirname(__file__), "alerts")
    alerts = {"critical": 0, "high": 0, "medium": 0, "low": 0}

    if os.path.exists(alerts_dir):
        # Count alerts by severity (simplified - in real implementation would parse alert files)
        try:
            alert_files = [f for f in os.listdir(alerts_dir) if f.endswith(".json")]
            alerts["total"] = len(alert_files)
            # For demo purposes, distribute alerts across severities
            alerts["critical"] = max(0, len(alert_files) - 3)
            alerts["high"] = min(2, len(alert_files))
            alerts["medium"] = min(1, len(alert_files))
        except OSError:
            pass

    return alerts


def update_metrics():
    """Update Prometheus metrics based on current agent status"""
    agents = load_agent_status()
    alert_config = load_alert_config()
    alerts = load_alerts()

    # Reset gauges
    SYSTEM_AGENTS_TOTAL.set(len(agents))

    total_running = 0
    total_queued = 0
    total_processing = 0
    total_health_score = 0.0

    current_time = time.time()

    for agent_name, agent_data in agents.items():
        # Agent status (1 = running, 0 = stopped)
        status = 1 if agent_data.get("status") == "running" else 0
        if status == 1:
            total_running += 1

        agent_type = agent_data.get("type", "unknown")
        AGENT_STATUS.labels(agent_name=agent_name, agent_type=agent_type).set(status)

        # Calculate and set uptime
        last_seen = agent_data.get("last_seen")
        if last_seen:
            try:
                # Simple uptime calculation (would be more sophisticated in production)
                uptime = current_time - time.mktime(
                    time.strptime(last_seen, "%Y-%m-%dT%H:%M:%SZ")
                )
                AGENT_UPTIME.labels(agent_name=agent_name).set(uptime)
            except (ValueError, TypeError):
                AGENT_UPTIME.labels(agent_name=agent_name).set(0)

        # Health score
        health_score = calculate_health_score(agent_data)
        AGENT_HEALTH_SCORE.labels(agent_name=agent_name).set(health_score)
        total_health_score += health_score

        # Task metrics
        completed = agent_data.get("tasks_completed", 0)
        failed = agent_data.get("tasks_failed", 0)
        queued = agent_data.get("tasks_queued", 0)
        processing = agent_data.get("tasks_processing", 0)

        AGENT_TASKS_COMPLETED.labels(agent_name=agent_name, task_type="all")._value.set(
            completed
        )
        AGENT_TASKS_FAILED.labels(agent_name=agent_name, task_type="all")._value.set(
            failed
        )
        AGENT_TASKS_QUEUED.labels(agent_name=agent_name).set(queued)
        AGENT_TASKS_PROCESSING.labels(agent_name=agent_name).set(processing)

        total_queued += queued
        total_processing += processing

        # Resource usage
        memory_mb = agent_data.get("memory_usage", 50)
        cpu_percent = agent_data.get("cpu_usage", 5)
        AGENT_MEMORY_USAGE.labels(agent_name=agent_name).set(memory_mb * 1024 * 1024)
        AGENT_CPU_USAGE.labels(agent_name=agent_name).set(cpu_percent)

        # SLO metrics (from alert config)
        env = alert_config.get("custom_thresholds", {}).get(
            "current_environment", "development"
        )
        agent_thresholds = (
            alert_config.get("custom_thresholds", {})
            .get("environments", {})
            .get(env, {})
        )
        tool_thresholds = (
            alert_config.get("custom_thresholds", {})
            .get("tools", {})
            .get(agent_name, {})
        )

        # Use tool-specific thresholds, fall back to environment defaults
        thresholds = {**agent_thresholds, **tool_thresholds}

        slo_uptime = thresholds.get("uptime_percent", 99.5)
        slo_latency = thresholds.get("response_time_ms", 1000)
        slo_error_rate = thresholds.get("error_rate_percent", 5)

        AGENT_SLO_UPTIME.labels(agent_name=agent_name).set(slo_uptime)
        AGENT_SLO_LATENCY.labels(agent_name=agent_name).set(slo_latency)
        AGENT_SLO_ERROR_RATE.labels(agent_name=agent_name).set(slo_error_rate)

    # System-wide metrics
    SYSTEM_AGENTS_RUNNING.set(total_running)
    SYSTEM_TASKS_QUEUED.set(total_queued)
    SYSTEM_TASKS_PROCESSING.set(total_processing)

    # Overall system health score
    if agents:
        avg_health_score = total_health_score / len(agents)
        SYSTEM_HEALTH_SCORE.set(avg_health_score)

    # Alert metrics
    for severity in ["critical", "high", "medium", "low"]:
        ALERTS_ACTIVE.labels(severity=severity).set(alerts.get(severity, 0))


@app.route("/metrics")
def metrics():
    """Prometheus metrics endpoint"""
    update_metrics()
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


@app.route("/health")
def health():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": time.time(), "version": "1.0.0"}


@app.route("/slo")
def slo_status():
    """SLO status endpoint"""
    agents = load_agent_status()
    alert_config = load_alert_config()

    slo_data = {
        "environment": alert_config.get("custom_thresholds", {}).get(
            "current_environment", "development"
        ),
        "agents": {},
    }

    for agent_name, agent_data in agents.items():
        health_score = calculate_health_score(agent_data)
        slo_data["agents"][agent_name] = {
            "health_score": health_score,
            "status": agent_data.get("status"),
            "tasks_completed": agent_data.get("tasks_completed", 0),
            "tasks_failed": agent_data.get("tasks_failed", 0),
        }

    return slo_data


@app.route("/")
def index():
    """Basic info page"""
    agents = load_agent_status()
    alerts = load_alerts()

    return {
        "service": "Tools Automation Metrics Exporter",
        "version": "1.0.0",
        "agents_monitored": len(agents),
        "alerts_active": alerts.get("total", 0),
        "endpoints": {"metrics": "/metrics", "health": "/health", "slo": "/slo"},
        "timestamp": time.time(),
    }


if __name__ == "__main__":
    print("🚀 Starting Tools Automation Metrics Exporter...")
    print("📊 Metrics available at: http://localhost:8080/metrics")
    print("💚 Health check at: http://localhost:8080/health")
    print("🎯 SLO status at: http://localhost:8080/slo")

    app.run(host="0.0.0.0", port=8080, debug=False)
