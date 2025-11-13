"""Performance benchmarks for MCP server and agents using Locust."""

import time
from locust import HttpUser, task, between
import json


class MCPUser(HttpUser):
    """Simulate users interacting with MCP server."""

    wait_time = between(1, 3)  # Wait 1-3 seconds between tasks

    @task(3)  # 30% of tasks
    def health_check(self):
        """Test health endpoint."""
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")

    @task(2)  # 20% of tasks
    def get_metrics(self):
        """Test metrics endpoint."""
        with self.client.get("/metrics", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Metrics failed: {response.status_code}")

    @task(1)  # 10% of tasks
    def submit_task(self):
        """Test task submission."""
        task_data = {
            "type": "health_check",
            "correlation_id": f"perf-test-{time.time()}",
            "data": {"source": "load_test"},
        }

        with self.client.post(
            "/tasks",
            json=task_data,
            headers={"Content-Type": "application/json"},
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Task submission failed: {response.status_code}")

    @task(1)  # 10% of tasks
    def get_task_status(self):
        """Test task status retrieval."""
        # Use a dummy task ID for testing
        task_id = "perf-test-dummy"

        with self.client.get(f"/tasks/{task_id}", catch_response=True) as response:
            # 404 is acceptable for dummy ID
            if response.status_code in [200, 404]:
                response.success()
            else:
                response.failure(f"Task status failed: {response.status_code}")

    @task(1)  # 10% of tasks
    def get_agent_status(self):
        """Test agent status endpoint."""
        with self.client.get("/agents/status", catch_response=True) as response:
            if response.status_code in [200, 404, 501]:  # May not be implemented
                response.success()
            else:
                response.failure(f"Agent status failed: {response.status_code}")


class AgentLoadUser(HttpUser):
    """Simulate load on agent scripts directly."""

    wait_time = between(2, 5)

    @task
    def agent_health_check(self):
        """Test agent health checks."""
        import subprocess
        import os

        start_time = time.time()

        try:
            # Run a sample agent health check
            result = subprocess.run(
                ["bash", "agents/agent_helpers.sh", "--health"],
                capture_output=True,
                text=True,
                timeout=10,
                cwd=os.path.dirname(os.path.dirname(__file__)),
            )

            response_time = time.time() - start_time

            if result.returncode == 0:
                # Simulate success response
                self.environment.events.request.fire(
                    request_type="AGENT",
                    name="agent_health_check",
                    response_time=int(response_time * 1000),
                    response_length=len(result.stdout),
                    exception=None,
                )
            else:
                # Simulate failure
                self.environment.events.request.fire(
                    request_type="AGENT",
                    name="agent_health_check",
                    response_time=int(response_time * 1000),
                    response_length=0,
                    exception=Exception("Agent health check failed"),
                )

        except subprocess.TimeoutExpired:
            self.environment.events.request.fire(
                request_type="AGENT",
                name="agent_health_check",
                response_time=int((time.time() - start_time) * 1000),
                response_length=0,
                exception=Exception("Timeout"),
            )
        except Exception as e:
            self.environment.events.request.fire(
                request_type="AGENT",
                name="agent_health_check",
                response_time=int((time.time() - start_time) * 1000),
                response_length=0,
                exception=e,
            )


# Configuration for load testing
# Run with: locust -f tests/performance/locustfile.py --host=http://localhost:5005
#
# Then access web UI at http://localhost:8089
#
# For headless testing:
# locust -f tests/performance/locustfile.py --host=http://localhost:5005 --no-web -c 10 -r 2 --run-time 1m
#
# Where:
# -c: number of concurrent users
# -r: hatch rate (users spawned per second)
# --run-time: test duration
