#!/usr/bin/env python3
"""
Health check endpoint for the autonomous system container.
This provides a simple HTTP endpoint that ECS can use to check container health.
"""

import http.server
import socketserver
import json
import subprocess
import sys
import os
from datetime import datetime


class HealthCheckHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()

            # Check system health
            health_status = self.check_system_health()

            self.wfile.write(json.dumps(health_status, indent=2).encode())
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found")

    def check_system_health(self):
        """Check the health of various system components."""
        health = {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "checks": {},
        }

        # Check if main processes are running
        processes_to_check = ["supervisord", "nginx", "python3", "node"]

        for process in processes_to_check:
            try:
                result = subprocess.run(
                    ["pgrep", "-f", process], capture_output=True, text=True, timeout=5
                )
                health["checks"][f"{process}_running"] = (
                    len(result.stdout.strip().split("\n")) > 0
                )
            except Exception as e:
                health["checks"][f"{process}_running"] = False
                health["checks"][f"{process}_error"] = str(e)

        # Check disk space
        try:
            result = subprocess.run(
                ["df", "/app"], capture_output=True, text=True, timeout=5
            )
            lines = result.stdout.strip().split("\n")
            if len(lines) > 1:
                # Parse disk usage (assuming format: Filesystem 1K-blocks Used Available Use% Mounted-on)
                parts = lines[1].split()
                if len(parts) >= 5:
                    use_percent = int(parts[4].rstrip("%"))
                    health["checks"]["disk_usage_percent"] = use_percent
                    health["checks"]["disk_space_ok"] = use_percent < 90
        except Exception as e:
            health["checks"]["disk_space_error"] = str(e)

        # Check if web server is responding
        try:
            result = subprocess.run(
                ["curl", "-f", "http://localhost:8000", "--max-time", "5"],
                capture_output=True,
                timeout=10,
            )
            health["checks"]["web_server_responding"] = result.returncode == 0
        except Exception as e:
            health["checks"]["web_server_error"] = str(e)

        # Determine overall status
        critical_checks = [
            "supervisord_running",
            "nginx_running",
            "web_server_responding",
            "disk_space_ok",
        ]

        for check in critical_checks:
            if check in health["checks"] and not health["checks"][check]:
                health["status"] = "unhealthy"
                break

        return health

    def log_message(self, format, *args):
        # Suppress default logging to avoid cluttering logs
        pass


def main():
    port = int(os.environ.get("HEALTH_CHECK_PORT", 8081))
    with socketserver.TCPServer(("", port), HealthCheckHandler) as httpd:
        print(f"Health check server running on port {port}")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
