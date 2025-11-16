#!/usr/bin/env python3
"""
System Health Monitoring API Server
Provides REST API endpoints for monitoring dashboard and data access
"""

import json
import os
import time
from datetime import datetime
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import glob

app = Flask(__name__)
CORS(app)

# Configuration
MONITORING_DIR = os.path.dirname(os.path.abspath(__file__))
METRICS_DIR = os.path.join(MONITORING_DIR, "metrics")
ALERTS_DIR = os.path.join(MONITORING_DIR, "alerts")
REPORTS_DIR = os.path.join(MONITORING_DIR, "reports")
DASHBOARD_DIR = os.path.join(MONITORING_DIR, "dashboard")

# Ensure directories exist
os.makedirs(METRICS_DIR, exist_ok=True)
os.makedirs(ALERTS_DIR, exist_ok=True)
os.makedirs(REPORTS_DIR, exist_ok=True)
os.makedirs(DASHBOARD_DIR, exist_ok=True)


def load_config():
    """Load monitoring configuration"""
    config_path = os.path.join(MONITORING_DIR, "config.json")
    if os.path.exists(config_path):
        with open(config_path, "r") as f:
            return json.load(f)
    return {}


CONFIG = load_config()


@app.route("/api/health")
def health_check():
    """Health check endpoint"""
    return jsonify(
        {"status": "healthy", "timestamp": int(time.time()), "version": "1.0.0"}
    )


@app.route("/api/metrics")
def get_metrics():
    """Get latest system and performance metrics"""
    try:
        # Get latest system metrics
        system_files = glob.glob(os.path.join(METRICS_DIR, "system_metrics_*.json"))
        system_metrics = {}

        if system_files:
            latest_system = max(system_files, key=os.path.getctime)
            with open(latest_system, "r") as f:
                system_metrics = json.load(f)

        # Get latest performance metrics
        perf_files = glob.glob(os.path.join(METRICS_DIR, "performance_metrics_*.json"))
        perf_metrics = {}

        if perf_files:
            latest_perf = max(perf_files, key=os.path.getctime)
            with open(latest_perf, "r") as f:
                perf_metrics = json.load(f)

        # Combine metrics
        combined = {**system_metrics, **perf_metrics}

        # Add computed fields
        if "cpu_usage_percent" in combined:
            combined["cpu_status"] = (
                "healthy"
                if combined["cpu_usage_percent"] < 80
                else "warning" if combined["cpu_usage_percent"] < 90 else "critical"
            )
        if "memory_usage_percent" in combined:
            combined["memory_status"] = (
                "healthy"
                if combined["memory_usage_percent"] < 85
                else "warning" if combined["memory_usage_percent"] < 95 else "critical"
            )
        if "disk_usage_percent" in combined:
            combined["disk_status"] = (
                "healthy"
                if combined["disk_usage_percent"] < 90
                else "warning" if combined["disk_usage_percent"] < 95 else "critical"
            )

        return jsonify(combined)

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/metrics/history")
def get_metrics_history():
    """Get historical metrics data"""
    try:
        hours = int(request.args.get("hours", 24))
        cutoff_time = time.time() - (hours * 3600)

        # Get system metrics history
        system_files = glob.glob(os.path.join(METRICS_DIR, "system_metrics_*.json"))
        system_data = []

        for file_path in system_files:
            try:
                timestamp = int(os.path.basename(file_path).split("_")[2].split(".")[0])
                if timestamp >= cutoff_time:
                    with open(file_path, "r") as f:
                        data = json.load(f)
                        system_data.append(data)
            except (ValueError, IndexError, json.JSONDecodeError):
                continue

        # Get performance metrics history
        perf_files = glob.glob(os.path.join(METRICS_DIR, "performance_metrics_*.json"))
        perf_data = []

        for file_path in perf_files:
            try:
                timestamp = int(os.path.basename(file_path).split("_")[2].split(".")[0])
                if timestamp >= cutoff_time:
                    with open(file_path, "r") as f:
                        data = json.load(f)
                        perf_data.append(data)
            except (ValueError, IndexError, json.JSONDecodeError):
                continue

        # Sort by timestamp
        system_data.sort(key=lambda x: x.get("timestamp", 0))
        perf_data.sort(key=lambda x: x.get("timestamp", 0))

        return jsonify(
            {
                "system_metrics": system_data,
                "performance_metrics": perf_data,
                "hours": hours,
            }
        )

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/alerts")
def get_alerts():
    """Get active alerts"""
    try:
        hours = int(request.args.get("hours", 24))
        cutoff_time = time.time() - (hours * 3600)

        alert_files = glob.glob(os.path.join(ALERTS_DIR, "alert_*.json"))
        alerts = []

        for file_path in alert_files:
            try:
                timestamp = int(os.path.basename(file_path).split("_")[1].split(".")[0])
                if timestamp >= cutoff_time:
                    with open(file_path, "r") as f:
                        alert_data = json.load(f)
                        alerts.extend(alert_data.get("alerts", []))
            except (ValueError, IndexError, json.JSONDecodeError):
                continue

        return jsonify(alerts)

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/baselines")
def get_baselines():
    """Get performance baselines"""
    try:
        baselines = {}

        # System baseline
        system_baseline_path = os.path.join(METRICS_DIR, "system_baseline.json")
        if os.path.exists(system_baseline_path):
            with open(system_baseline_path, "r") as f:
                baselines["system"] = json.load(f)

        # Performance baseline
        perf_baseline_path = os.path.join(METRICS_DIR, "performance_baseline.json")
        if os.path.exists(perf_baseline_path):
            with open(perf_baseline_path, "r") as f:
                baselines["performance"] = json.load(f)

        return jsonify(baselines)

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/reports")
def get_reports():
    """Get available reports"""
    try:
        days = int(request.args.get("days", 7))
        cutoff_time = time.time() - (days * 86400)

        report_files = glob.glob(os.path.join(REPORTS_DIR, "daily_report_*.md"))
        reports = []

        for file_path in report_files:
            try:
                # Extract date from filename
                date_str = (
                    os.path.basename(file_path)
                    .replace("daily_report_", "")
                    .replace(".md", "")
                )
                report_date = datetime.strptime(date_str, "%Y%m%d")

                if report_date.timestamp() >= cutoff_time:
                    reports.append(
                        {
                            "date": date_str,
                            "path": file_path,
                            "size": os.path.getsize(file_path),
                            "readable_date": report_date.strftime("%Y-%m-%d"),
                        }
                    )
            except (ValueError, OSError):
                continue

        # Sort by date descending
        reports.sort(key=lambda x: x["date"], reverse=True)

        return jsonify(reports)

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/reports/<date>")
def get_report(date):
    """Get specific report content"""
    try:
        report_path = os.path.join(REPORTS_DIR, f"daily_report_{date}.md")

        if not os.path.exists(report_path):
            return jsonify({"error": "Report not found"}), 404

        with open(report_path, "r") as f:
            content = f.read()

        return jsonify({"date": date, "content": content})

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/services")
def get_services_status():
    """Get status of monitored services"""
    try:
        # This would integrate with actual service checks
        # For now, return mock data
        services = [
            {
                "name": "agent_dashboard",
                "status": "healthy",
                "response_time": 145,
                "last_check": int(time.time()),
            },
            {
                "name": "monitoring_api",
                "status": "healthy",
                "response_time": 23,
                "last_check": int(time.time()),
            },
            {
                "name": "github_api",
                "status": "healthy",
                "response_time": 234,
                "last_check": int(time.time()),
            },
        ]

        return jsonify(services)

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/stats")
def get_stats():
    """Get monitoring statistics"""
    try:
        stats = {
            "total_metrics": len(glob.glob(os.path.join(METRICS_DIR, "*.json"))),
            "total_alerts": len(glob.glob(os.path.join(ALERTS_DIR, "*.json"))),
            "total_reports": len(glob.glob(os.path.join(REPORTS_DIR, "*.md"))),
            "uptime": "Monitoring active",  # Would calculate actual uptime
            "last_collection": "Unknown",
        }

        # Get last collection time
        all_metric_files = glob.glob(os.path.join(METRICS_DIR, "*.json"))
        if all_metric_files:
            latest_file = max(all_metric_files, key=os.path.getctime)
            stats["last_collection"] = datetime.fromtimestamp(
                os.path.getctime(latest_file)
            ).isoformat()

        return jsonify(stats)

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/dashboard/<path:filename>")
def dashboard_files(filename):
    """Serve dashboard static files"""
    return send_from_directory(DASHBOARD_DIR, filename)


@app.route("/")
def dashboard():
    """Serve main dashboard"""
    return send_from_directory(DASHBOARD_DIR, "index.html")


@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({"error": "Internal server error"}), 500


def main():
    """Main function to start the API server"""
    port = CONFIG.get("dashboard", {}).get("port", 8081)
    host = CONFIG.get("dashboard", {}).get("host", "localhost")

    print(f"Starting System Health Monitoring API Server on {host}:{port}")
    print(f"Dashboard available at: http://{host}:{port}")
    print(f"API endpoints available at: http://{host}:{port}/api/")

    app.run(host=host, port=port, debug=False)


if __name__ == "__main__":
    main()
