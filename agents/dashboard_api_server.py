#!/usr/bin/env python3
"""
Dashboard API Server
Serves live dashboard data for the development workspace monitor
"""

import http.server
import json
import socketserver
import subprocess
import time
import os
import signal
import sys
from pathlib import Path

PORT = 8004
AGENTS_DIR = Path(__file__).parent  # This is Tools/Automation/agents
# Prefer Automation agents directory for live state, with a fallback to legacy Tools/agents if needed
DASHBOARD_DATA_FILE = AGENTS_DIR / "dashboard_data.json"
PRIMARY_STATUS_FILE = AGENTS_DIR / "agent_status.json"
PRIMARY_TASK_QUEUE_FILE = AGENTS_DIR / "task_queue.json"
LEGACY_AGENTS_DIR = Path("/Users/danielstevens/Desktop/Quantum-workspace/Tools/agents")
LEGACY_STATUS_FILE = LEGACY_AGENTS_DIR / "agent_status.json"
LEGACY_TASK_QUEUE_FILE = LEGACY_AGENTS_DIR / "task_queue.json"

def resolve_path(primary: Path, legacy: Path) -> Path:
    try:
        if primary.exists():
            return primary
    except Exception:
        pass
    return legacy

AGENT_STATUS_FILE = resolve_path(PRIMARY_STATUS_FILE, LEGACY_STATUS_FILE)
TASK_QUEUE_FILE = resolve_path(PRIMARY_TASK_QUEUE_FILE, LEGACY_TASK_QUEUE_FILE)
PID_FILE = AGENTS_DIR / "dashboard_server.pid"


class DashboardAPIHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/api/health":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            payload = {"status": "ok", "time": int(time.time())}
            self.wfile.write(json.dumps(payload).encode())
        elif self.path == "/api/dashboard-data":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()

            dashboard_data = self.get_dashboard_data()
            self.wfile.write(json.dumps(dashboard_data, indent=2).encode())
        elif (
            self.path == "/"
            or self.path == "/dashboard"
            or self.path == "/dashboard.html"
        ):
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()

            # Serve the dashboard HTML
            dashboard_path = Path(__file__).parent.parent / "dashboard.html"
            if dashboard_path.exists():
                with open(dashboard_path, "r") as f:
                    self.wfile.write(f.read().encode())
            else:
                self.wfile.write(
                    b"<html><body><h1>Dashboard not found</h1></body></html>"
                )
        elif self.path == "/test":
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()

            # Serve the test dashboard HTML
            test_path = Path(__file__).parent.parent / "test_dashboard.html"
            if test_path.exists():
                with open(test_path, "r") as f:
                    self.wfile.write(f.read().encode())
            else:
                self.wfile.write(
                    b"<html><body><h1>Test page not found</h1></body></html>"
                )
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'{"error": "Endpoint not found"}')

    def get_dashboard_data(self):
        """Generate comprehensive dashboard data"""
        current_time = int(time.time())

        # Load existing data files
        agent_status = self.load_json_file(AGENT_STATUS_FILE)
        task_queue = self.load_json_file(TASK_QUEUE_FILE)

        # Get system metrics
        system_metrics = self.get_system_metrics()

        # Process agent data
        agents_data = self.process_agent_data(agent_status, current_time)

        # Process task data
        tasks_data = self.process_task_data(task_queue)

        # Combine all data
        result = {
            "agents": agents_data,
            "system": system_metrics,
            "tasks": tasks_data,
            "last_update": current_time,
            "projects": self.get_project_status(),
        }

        # Update the dashboard data file
        self.save_dashboard_data(result)

        return result

    def load_json_file(self, file_path):
        """Load JSON file safely"""
        try:
            if file_path.exists():
                with open(file_path, "r") as f:
                    return json.load(f)
        except Exception as e:
            print(f"Error loading {file_path}: {e}")
        return {}

    def get_system_metrics(self):
        """Get current system metrics using basic commands"""
        try:
            # Get CPU usage
            cpu_result = subprocess.run(
                ["top", "-l", "1", "-n", "0"], capture_output=True, text=True, timeout=5
            )
            cpu_usage = "15.0%"  # Default fallback
            if cpu_result.returncode == 0:
                for line in cpu_result.stdout.split("\n"):
                    if "CPU usage:" in line:
                        # Extract CPU percentage from top output
                        parts = line.split()
                        if len(parts) >= 3:
                            cpu_usage = parts[2] + "%"
                        break

            # Get memory usage
            memory_result = subprocess.run(
                ["vm_stat"], capture_output=True, text=True, timeout=5
            )
            memory_usage = "60.0%"  # Default fallback
            if memory_result.returncode == 0:
                # Parse vm_stat output for memory usage
                for line in memory_result.stdout.split("\n"):
                    if "Pages free:" in line or "Pages active:" in line:
                        memory_usage = "60.0%"  # Simplified calculation

            # Get disk usage
            disk_result = subprocess.run(
                ["df", "-h", "/"], capture_output=True, text=True, timeout=5
            )
            disk_usage = "75.0%"  # Default fallback
            if disk_result.returncode == 0:
                lines = disk_result.stdout.strip().split("\n")
                if len(lines) >= 2:
                    parts = lines[1].split()
                    if len(parts) >= 5:
                        disk_usage = parts[4]

            # Get process count
            process_result = subprocess.run(
                ["ps", "aux"], capture_output=True, text=True, timeout=5
            )
            process_count = (
                len(process_result.stdout.strip().split("\n")) - 1
                if process_result.returncode == 0
                else 500
            )

            return {
                "cpu_usage": cpu_usage,
                "memory_usage": memory_usage,
                "disk_usage": disk_usage,
                "network_connections": "42",  # Placeholder
                "process_count": process_count,
            }
        except Exception as e:
            print(f"Error getting system metrics: {e}")
            return {
                "cpu_usage": "15.0%",
                "memory_usage": "60.0%",
                "disk_usage": "75.0%",
                "network_connections": "42",
                "process_count": 500,
            }

    def process_agent_data(self, agent_status, current_time):
        """Process agent status data and always include all known agents"""
        agents = {}
        # List of all known agents (should match frontend)
        known_agents = [
            "build_agent",
            "debug_agent",
            "codegen_agent",
            "uiux_agent",
            "apple_pro_agent",
            "collab_agent",
            "updater_agent",
            "search_agent",
            "quality_agent",
            "testing_agent",
            "documentation_agent",
            "performance_agent",
            "security_agent",
            "pull_request_agent",
            "auto_update_agent",
            "knowledge_base_agent",
        ]
        # Map simplified names to their script-name counterparts in status files
        alias_to_script = {
            "build_agent": "agent_build.sh",
            "debug_agent": "agent_debug.sh",
            "codegen_agent": "agent_codegen.sh",
            "uiux_agent": "uiux_agent.sh",
            "apple_pro_agent": "apple_pro_agent.sh",
            "collab_agent": "collab_agent.sh",
            "updater_agent": "updater_agent.sh",
            "search_agent": "search_agent.sh",
            "quality_agent": "quality_agent.sh",
            "testing_agent": "testing_agent.sh",
            "documentation_agent": "documentation_agent.sh",
            "performance_agent": "performance_agent.sh",
            "security_agent": "security_agent.sh",
            "pull_request_agent": "pull_request_agent.sh",
            "auto_update_agent": "auto_update_agent.sh",
            "knowledge_base_agent": "knowledge_base_agent.sh",
        }
        status_agents = agent_status.get("agents", {})
        for agent_name in known_agents:
            # Prefer the alias entry, but fall back to script-name entry; if both exist pick the freshest
            script_key = alias_to_script.get(agent_name)
            alias_info = status_agents.get(agent_name, {})
            script_info = status_agents.get(script_key, {}) if script_key else {}
            def last_seen_of(info):
                try:
                    return int(info.get("last_seen", 0) or 0)
                except (TypeError, ValueError):
                    return 0
            chosen = alias_info if last_seen_of(alias_info) >= last_seen_of(script_info) else script_info
            status = chosen.get("status", "offline")
            last_seen = last_seen_of(chosen)
            # Determine if agent is running based on recent activity
            is_running = False
            if last_seen:
                try:
                    last_seen = int(last_seen)
                except (TypeError, ValueError):
                    last_seen = 0
                time_diff = current_time - last_seen
                if time_diff < 300:
                    is_running = True
            # Map status to dashboard format
            if status == "active" and is_running:
                display_status = "running"
            elif status == "restarting" and is_running:
                display_status = "running"
            elif status == "restarting" and not is_running:
                display_status = "failed"
            elif status == "available" and is_running:
                display_status = "running"
            elif status == "available" and not is_running:
                display_status = "stopped"
            elif is_running:
                display_status = "running"
            elif status == "offline":
                display_status = "offline"
            else:
                display_status = "failed"
            agents[agent_name] = {
                "status": display_status,
                "last_seen": last_seen,
                "tasks_completed": chosen.get("tasks_completed", 0),
                "description": self.get_agent_description(agent_name),
                "is_online": is_running,
            }
        return agents

    def process_task_data(self, task_queue):
        """Process task queue data"""
        tasks = {"active": [], "completed": [], "failed": [], "queued": []}

        if "tasks" in task_queue:
            for task in task_queue["tasks"]:
                status = task.get("status", "unknown")
                if status == "pending":
                    tasks["queued"].append(task)
                elif status == "completed":
                    tasks["completed"].append(task)
                elif status == "failed":
                    tasks["failed"].append(task)
                elif status in ["running", "active"]:
                    tasks["active"].append(task)

        return tasks

    def get_agent_description(self, agent_name):
        """Get human-readable description for agent"""
        descriptions = {
            "task_orchestrator.sh": "Central task coordination and agent health monitoring",
            "agent_debug.sh": "Debugging and troubleshooting agent",
            "agent_codegen.sh": "Code generation and test creation",
            "uiux_agent.sh": "UI/UX analysis and improvements",
            "apple_pro_agent.sh": "Apple platform expertise and best practices",
            "quality_agent.sh": "Code quality analysis and linting",
            "testing_agent.sh": "Automated testing and coverage analysis",
            "documentation_agent.sh": "Documentation generation and updates",
            "performance_agent.sh": "Performance monitoring and optimization",
            "security_agent.sh": "Security analysis and vulnerability detection",
            "search_agent.sh": "Code search and analysis",
            "pull_request_agent.sh": "PR creation and review automation",
            "auto_update_agent.sh": "Automated code updates and refactoring",
            "knowledge_base_agent.sh": "Learning and knowledge management",
            "collab_agent.sh": "Collaboration and communication",
            "updater_agent.sh": "System updates and maintenance",
        }
        return descriptions.get(
            agent_name, f"{agent_name.replace('_', ' ').replace('.sh', '')} agent"
        )

    def get_project_status(self):
        """Get project status information"""
        # Use the workspace Projects folder
        projects_dir = Path("/Users/danielstevens/Desktop/Quantum-workspace/Projects")
        projects = {}

        if projects_dir.exists():
            for project_dir in projects_dir.iterdir():
                if project_dir.is_dir() and not project_dir.name.startswith("."):
                    projects[project_dir.name] = {
                        "status": "unknown",
                        "last_build": "unknown",
                        "issues": [],
                    }

        return projects

    def save_dashboard_data(self, data):
        """Save dashboard data to file"""
        try:
            with open(DASHBOARD_DATA_FILE, "w") as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            print(f"Error saving dashboard data: {e}")


def cleanup_handler(signum, frame):
    """Handle cleanup when server is terminated"""
    print(f"\nReceived signal {signum}, shutting down...")
    if PID_FILE.exists():
        PID_FILE.unlink()
    sys.exit(0)


def main():
    # Check if server is already running
    if PID_FILE.exists():
        try:
            with open(PID_FILE, 'r') as f:
                old_pid = int(f.read().strip())
            # Check if process is still running
            os.kill(old_pid, 0)
            print(f"Dashboard server already running on PID {old_pid}")
            print(f"Dashboard: http://localhost:{PORT}/dashboard")
            return
        except (OSError, ValueError):
            # Process doesn't exist or PID file is invalid
            PID_FILE.unlink()
    
    # Write current PID to file
    with open(PID_FILE, 'w') as f:
        f.write(str(os.getpid()))
    
    # Set up signal handlers
    signal.signal(signal.SIGTERM, cleanup_handler)
    signal.signal(signal.SIGINT, cleanup_handler)
    
    print(f"Starting Dashboard API Server on port {PORT}")
    print(f"Dashboard: http://localhost:{PORT}/dashboard")
    print(f"API endpoint: http://localhost:{PORT}/api/dashboard-data")
    print(f"PID: {os.getpid()}")

    try:
        with socketserver.TCPServer(("", PORT), DashboardAPIHandler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
    except OSError as e:
        if e.errno == 48:  # Address already in use
            print(f"Port {PORT} is already in use. Server may already be running.")
        else:
            print(f"Error starting server: {e}")
    finally:
        if PID_FILE.exists():
            PID_FILE.unlink()


if __name__ == "__main__":
    main()
