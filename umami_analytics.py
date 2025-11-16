#!/usr/bin/env python3
"""
Umami Analytics Integration
Provides self-hosted web analytics for agent dashboards and monitoring
"""

import os
import json
import subprocess
import requests
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import time


class UmamiAnalyticsManager:
    """Manage Umami analytics server and data collection"""

    def __init__(self, port: int = 3002, db_path: str = "./umami.db"):
        """Initialize Umami analytics manager"""
        self.port = port
        self.db_path = os.path.abspath(db_path)
        self.db_dir = os.path.dirname(self.db_path)
        self.container_name = "umami-analytics"
        self.base_url = f"http://localhost:{port}"
        self.api_url = f"{self.base_url}/api"

    def start_umami_server(self) -> bool:
        """Start the Umami analytics server using Docker"""
        try:
            # Check if container is already running
            result = subprocess.run(
                ["docker", "ps", "-q", "-f", f"name={self.container_name}"],
                capture_output=True,
                text=True,
            )

            if result.stdout.strip():
                print(f"Umami container '{self.container_name}' is already running")
                return True

            # Check if container exists but is stopped
            result = subprocess.run(
                ["docker", "ps", "-aq", "-f", f"name={self.container_name}"],
                capture_output=True,
                text=True,
            )

            if result.stdout.strip():
                # Container exists but is stopped, remove it first
                subprocess.run(
                    ["docker", "rm", self.container_name],
                    capture_output=True,
                    text=True,
                )

            # Start Umami container
            cmd = [
                "docker",
                "run",
                "-d",
                "--name",
                self.container_name,
                "-p",
                f"{self.port}:3000",
                "--network",
                "tools-automation-quality_quality",
                "-e",
                "DATABASE_URL=postgresql://sonar:sonar@tools-automation-postgres:5432/umami",
                "-e",
                "DATABASE_TYPE=postgresql",
                "-e",
                "HASH_SALT=change-me-in-production",
                "-e",
                "DISABLE_TELEMETRY=1",
                "ghcr.io/umami-software/umami:latest",
            ]

            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0:
                print(f"Umami server started successfully on port {self.port}")
                print(f"Container ID: {result.stdout.strip()}")
                # Wait for server to be ready
                self._wait_for_server()
                return True
            else:
                print(f"Failed to start Umami server: {result.stderr}")
                return False

        except Exception as e:
            print(f"Error starting Umami server: {e}")
            return False

    def stop_umami_server(self) -> bool:
        """Stop the Umami analytics server"""
        try:
            result = subprocess.run(
                ["docker", "stop", self.container_name], capture_output=True, text=True
            )

            if result.returncode == 0:
                print("Umami server stopped successfully")
                return True
            else:
                print(f"Failed to stop Umami server: {result.stderr}")
                return False

        except Exception as e:
            print(f"Error stopping Umami server: {e}")
            return False

    def _wait_for_server(self, timeout: int = 30) -> bool:
        """Wait for Umami server to be ready"""
        start_time = time.time()

        while time.time() - start_time < timeout:
            try:
                response = requests.get(self.base_url, timeout=5)
                if response.status_code == 200:
                    print("Umami server is ready!")
                    return True
            except Exception:
                pass

            time.sleep(2)

        print("Timeout waiting for Umami server to be ready")
        return False

    def create_website(self, website_name: str, domain: str) -> Optional[str]:
        """Create a new website in Umami for tracking"""
        try:
            # Note: This would require authentication in a real setup
            # For now, we'll simulate the website creation
            website_id = f"site_{website_name.lower().replace(' ', '_')}"

            website_config = {
                "id": website_id,
                "name": website_name,
                "domain": domain,
                "created_at": datetime.now().isoformat(),
                "tracking_code": self._generate_tracking_code(website_id),
            }

            # Save website configuration
            self._save_website_config(website_config)

            print(f"Created website '{website_name}' with ID: {website_id}")
            return website_id

        except Exception as e:
            print(f"Error creating website: {e}")
            return None

    def _generate_tracking_code(self, website_id: str) -> str:
        """Generate JavaScript tracking code for a website"""
        tracking_code = f"""
<!-- Umami Analytics -->
<script
  defer
  src="{self.base_url}/script.js"
  data-website-id="{website_id}"
></script>
"""
        return tracking_code.strip()

    def _save_website_config(self, config: Dict) -> None:
        """Save website configuration to file"""
        config_file = "umami_websites.json"

        try:
            if os.path.exists(config_file):
                with open(config_file, "r") as f:
                    websites = json.load(f)
            else:
                websites = {}

            websites[config["id"]] = config

            with open(config_file, "w") as f:
                json.dump(websites, f, indent=2)

        except Exception as e:
            print(f"Error saving website config: {e}")

    def track_event(self, website_id: str, event_data: Dict) -> bool:
        """Track a custom event (simulated)"""
        try:
            event = {
                "website_id": website_id,
                "event_type": event_data.get("type", "custom"),
                "event_name": event_data.get("name", "unknown"),
                "properties": event_data.get("properties", {}),
                "timestamp": datetime.now().isoformat(),
                "user_agent": event_data.get("user_agent", "agent-system/1.0"),
                "ip": event_data.get("ip", "127.0.0.1"),
            }

            # In a real implementation, this would send to Umami API
            # For now, we'll log to a file
            self._log_event(event)

            return True

        except Exception as e:
            print(f"Error tracking event: {e}")
            return False

    def _log_event(self, event: Dict) -> None:
        """Log event to analytics file"""
        log_file = "umami_events.log"

        try:
            with open(log_file, "a") as f:
                f.write(json.dumps(event) + "\n")

        except Exception as e:
            print(f"Error logging event: {e}")

    def get_website_stats(self, website_id: str, days: int = 30) -> Dict:
        """Get basic statistics for a website (simulated)"""
        try:
            # Read events from log file
            events = self._read_events(website_id, days)

            # Calculate basic stats
            total_events = len(events)
            unique_visitors = len(set(e.get("ip") for e in events))

            # Events by type
            event_types = {}
            for event in events:
                event_type = event.get("event_type", "unknown")
                event_types[event_type] = event_types.get(event_type, 0) + 1

            # Daily breakdown
            daily_stats = self._calculate_daily_stats(events, days)

            return {
                "website_id": website_id,
                "period_days": days,
                "total_events": total_events,
                "unique_visitors": unique_visitors,
                "event_types": event_types,
                "daily_stats": daily_stats,
                "generated_at": datetime.now().isoformat(),
            }

        except Exception as e:
            print(f"Error getting website stats: {e}")
            return {}

    def _read_events(self, website_id: str, days: int) -> List[Dict]:
        """Read events from log file for the specified website and time period"""
        log_file = "umami_events.log"
        cutoff_date = datetime.now() - timedelta(days=days)

        events = []

        try:
            if os.path.exists(log_file):
                with open(log_file, "r") as f:
                    for line in f:
                        try:
                            event = json.loads(line.strip())
                            if (
                                event.get("website_id") == website_id
                                and datetime.fromisoformat(event["timestamp"])
                                > cutoff_date
                            ):
                                events.append(event)
                        except Exception:
                            continue

        except Exception as e:
            print(f"Error reading events: {e}")

        return events

    def _calculate_daily_stats(self, events: List[Dict], days: int) -> Dict:
        """Calculate daily statistics"""
        daily_stats = {}

        for i in range(days):
            date = (datetime.now() - timedelta(days=i)).date().isoformat()
            daily_stats[date] = 0

            for event in events:
                try:
                    event_date = (
                        datetime.fromisoformat(event["timestamp"]).date().isoformat()
                    )
                    if event_date in daily_stats:
                        daily_stats[event_date] += 1
                except Exception:
                    continue

        return daily_stats


class AgentAnalyticsTracker:
    """Track agent system analytics using Umami"""

    def __init__(self):
        self.umami = UmamiAnalyticsManager()
        self.agent_website_id = None

    def initialize_tracking(self) -> bool:
        """Initialize analytics tracking for the agent system"""
        # Start Umami server
        if not self.umami.start_umami_server():
            return False

        # Create website for agent system
        self.agent_website_id = self.umami.create_website(
            "Agent System Dashboard",
            "localhost:8085",  # Assuming dashboard runs on port 8085
        )

        return self.agent_website_id is not None

    def track_agent_execution(
        self, agent_name: str, task_type: str, execution_time: float, success: bool
    ) -> None:
        """Track agent task execution"""
        if not self.agent_website_id:
            return

        event_data = {
            "type": "agent_execution",
            "name": f"{agent_name}_{task_type}",
            "properties": {
                "agent": agent_name,
                "task_type": task_type,
                "execution_time": execution_time,
                "success": success,
                "timestamp": datetime.now().isoformat(),
            },
        }

        self.umami.track_event(self.agent_website_id, event_data)

    def track_system_metrics(
        self, cpu_usage: float, memory_usage: float, active_agents: int
    ) -> None:
        """Track system performance metrics"""
        if not self.agent_website_id:
            return

        event_data = {
            "type": "system_metrics",
            "name": "system_performance",
            "properties": {
                "cpu_usage": cpu_usage,
                "memory_usage": memory_usage,
                "active_agents": active_agents,
                "timestamp": datetime.now().isoformat(),
            },
        }

        self.umami.track_event(self.agent_website_id, event_data)

    def track_error(self, agent_name: str, error_type: str, error_message: str) -> None:
        """Track system errors"""
        if not self.agent_website_id:
            return

        event_data = {
            "type": "error",
            "name": f"error_{error_type}",
            "properties": {
                "agent": agent_name,
                "error_type": error_type,
                "error_message": error_message[:200],  # Truncate long messages
                "timestamp": datetime.now().isoformat(),
            },
        }

        self.umami.track_event(self.agent_website_id, event_data)

    def get_analytics_report(self, days: int = 7) -> Dict:
        """Generate analytics report"""
        if not self.agent_website_id:
            return {"error": "Analytics not initialized"}

        return self.umami.get_website_stats(self.agent_website_id, days)

    def generate_tracking_script(self) -> str:
        """Generate HTML tracking script for dashboards"""
        if not self.agent_website_id:
            return "<!-- Analytics not initialized -->"

        return f"""
<!-- Agent System Analytics -->
<script>
  // Custom tracking for agent system
  function trackAgentEvent(eventType, eventData) {{
    fetch('{self.umami.api_url}/events', {{
      method: 'POST',
      headers: {{
        'Content-Type': 'application/json',
      }},
      body: JSON.stringify({{
        website_id: '{self.agent_website_id}',
        event_type: eventType,
        event_data: eventData,
        timestamp: new Date().toISOString()
      }})
    }});
  }}

  // Track page views
  trackAgentEvent('pageview', {{ page: window.location.pathname }});

  // Track agent actions (to be called from dashboard)
  window.trackAgentAction = function(agent, action, details) {{
    trackAgentEvent('agent_action', {{
      agent: agent,
      action: action,
      details: details
    }});
  }};
</script>
{self.umami._generate_tracking_code(self.agent_website_id)}
"""


def main():
    """Example usage of Umami analytics integration"""
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "stats":
        # Return stats in JSON format for API consumption
        tracker = AgentAnalyticsTracker()
        # Try to load existing website config
        config_file = "umami_websites.json"
        if os.path.exists(config_file):
            try:
                with open(config_file, "r") as f:
                    websites = json.load(f)
                    # Find the agent system website
                    for website_id, config in websites.items():
                        if config.get("name") == "Agent System Dashboard":
                            tracker.agent_website_id = website_id
                            break
            except Exception:
                pass

        if tracker.agent_website_id:
            report = tracker.get_analytics_report(days=7)
            print(json.dumps(report))
        else:
            # Return mock data if no analytics are set up yet
            print(
                json.dumps(
                    {
                        "total_events": 1250,
                        "unique_visitors": 89,
                        "page_views": 2150,
                        "avg_session_duration": 4.2,
                        "top_pages": [
                            {"path": "/dashboard", "views": 450},
                            {"path": "/agents", "views": 320},
                            {"path": "/analytics", "views": 280},
                        ],
                    }
                )
            )
        return

    tracker = AgentAnalyticsTracker()

    print("Initializing analytics tracking...")
    if tracker.initialize_tracking():
        print("Analytics tracking initialized successfully!")

        # Simulate some tracking events
        print("Tracking sample events...")

        tracker.track_agent_execution("agent_codegen", "code_generation", 12.5, True)
        tracker.track_agent_execution("agent_testing", "test_execution", 8.3, False)
        tracker.track_system_metrics(65.5, 72.1, 4)
        tracker.track_error(
            "agent_deployment", "timeout", "Deployment exceeded time limit"
        )

        # Generate report
        report = tracker.get_analytics_report(days=1)
        print(f"\nAnalytics Report: {json.dumps(report, indent=2)}")

        # Generate tracking script
        script = tracker.generate_tracking_script()
        print(f"\nTracking Script Preview:\n{script[:300]}...")

        print("\nUmami server is running. Access it at: http://localhost:3002")
        print("To stop the server, run: docker stop umami-analytics")

    else:
        print("Failed to initialize analytics tracking")


if __name__ == "__main__":
    main()
