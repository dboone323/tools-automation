#!/usr/bin/env python3
"""
Integration Tests for MCP↔Agent↔Workflow System

Tests the complete integration flow between:
- MCP Server (HTTP coordination)
- Agent Orchestrator (task assignment)
- Workflow System (CI/CD orchestration)
- Submodule Integration (.tools-automation/ shims)

Run with: python -m pytest tests/integration/test_system_integration.py -v
"""

import json
import subprocess
import time
import unittest
from pathlib import Path

import requests
from requests.exceptions import ConnectionError, Timeout


class TestSystemIntegration(unittest.TestCase):
    """Test complete system integration"""

    def setUp(self):
        """Set up test environment"""
        self.workspace_root = Path(__file__).parent.parent.parent
        self.mcp_url = "http://127.0.0.1:5005"
        self.test_timeout = 30

        # Test agent configuration
        self.test_agent = {
            "id": "test-integration-agent",
            "name": "test-integration-agent",
            "capabilities": ["test", "integration", "automation"],
        }

        # Test task configuration
        self.test_task = {
            "id": "test-integration-task",
            "type": "integration_test",
            "description": "Test MCP↔Agent↔Workflow integration",
            "priority": 5,
            "status": "pending",
        }

    def tearDown(self):
        """Clean up test environment"""
        # Clean up test agent registration if it exists
        try:
            # This would normally unregister the test agent
            pass
        except Exception:
            pass

    def _check_server_availability(self, url, timeout=5):
        """Check if server is responding"""
        try:
            response = requests.get(f"{url}/health", timeout=timeout)
            return response.status_code in [200, 503]  # Accept degraded state
        except (ConnectionError, Timeout):
            return False

    def test_01_mcp_server_health_check(self):
        """Test 1: MCP Server health endpoint"""
        print("🩺 Testing MCP Server health check...")

        if not self._check_server_availability(self.mcp_url):
            self.skipTest("MCP server not available - start with: python mcp_server.py")

        response = requests.get(f"{self.mcp_url}/health", timeout=self.test_timeout)
        self.assertIn(response.status_code, [200, 503])

        health_data = response.json()
        self.assertIn("ok", health_data)
        self.assertIn("status", health_data)

        if health_data.get("ok"):
            self.assertEqual(health_data["status"], "healthy")
        else:
            self.assertEqual(health_data["status"], "degraded")

        print("✅ MCP Server health check passed")

    def test_02_mcp_server_endpoints(self):
        """Test 2: MCP Server core endpoints"""
        print("🔗 Testing MCP Server endpoints...")

        if not self._check_server_availability(self.mcp_url):
            self.skipTest("MCP server not available")

        # Test /status endpoint
        response = requests.get(f"{self.mcp_url}/status", timeout=self.test_timeout)
        self.assertEqual(response.status_code, 200)
        status_data = response.json()
        self.assertIn("ok", status_data)
        self.assertTrue(status_data["ok"])

        # Test /controllers endpoint
        response = requests.get(
            f"{self.mcp_url}/controllers", timeout=self.test_timeout
        )
        self.assertEqual(response.status_code, 200)
        controllers_data = response.json()
        self.assertIn("ok", controllers_data)
        self.assertTrue(controllers_data["ok"])

        print("✅ MCP Server endpoints test passed")

    def test_03_agent_registration(self):
        """Test 3: Agent registration with MCP server"""
        print("📝 Testing agent registration...")

        if not self._check_server_availability(self.mcp_url):
            self.skipTest("MCP server not available")

        # Register test agent
        register_payload = {
            "agent": self.test_agent["id"],
            "capabilities": self.test_agent["capabilities"],
        }

        response = requests.post(
            f"{self.mcp_url}/register", json=register_payload, timeout=self.test_timeout
        )
        self.assertEqual(response.status_code, 200)

        register_data = response.json()
        self.assertIn("ok", register_data)
        self.assertTrue(register_data["ok"])
        self.assertEqual(register_data["registered"], self.test_agent["id"])

        # Verify agent appears in status
        response = requests.get(f"{self.mcp_url}/status", timeout=self.test_timeout)
        status_data = response.json()
        self.assertIn(self.test_agent["id"], status_data["agents"])

        print("✅ Agent registration test passed")

    def test_04_task_submission_and_execution(self):
        """Test 4: Task submission and execution flow"""
        print("🎯 Testing task submission and execution...")

        if not self._check_server_availability(self.mcp_url):
            self.skipTest("MCP server not available")

        # Submit task
        run_payload = {
            "agent": self.test_agent["id"],
            "command": "status",  # Safe command for testing
            "execute": False,  # Don't execute, just queue
        }

        response = requests.post(
            f"{self.mcp_url}/run", json=run_payload, timeout=self.test_timeout
        )
        self.assertEqual(response.status_code, 200)

        run_data = response.json()
        self.assertIn("ok", run_data)
        self.assertTrue(run_data["ok"])
        self.assertIn("task_id", run_data)
        self.assertTrue(run_data["queued"])

        task_id = run_data["task_id"]

        # Verify task appears in status
        response = requests.get(f"{self.mcp_url}/status", timeout=self.test_timeout)
        status_data = response.json()
        task_ids = [task["id"] for task in status_data["tasks"]]
        self.assertIn(task_id, task_ids)

        print("✅ Task submission test passed")

    def test_05_agent_orchestrator_integration(self):
        """Test 5: Agent orchestrator task assignment"""
        print("🎭 Testing agent orchestrator integration...")

        # Test orchestrator assign command
        orchestrator_cmd = [
            "python3",
            "agents/orchestrator_v2.py",
            "assign",
            "--task",
            json.dumps(self.test_task),
        ]

        result = subprocess.run(
            orchestrator_cmd,
            cwd=self.workspace_root,
            capture_output=True,
            text=True,
            timeout=self.test_timeout,
        )

        # Should succeed even if no agents are available (will queue)
        self.assertIn(result.returncode, [0, 1])  # 0=assigned, 1=queued

        if result.returncode == 0:
            response_data = json.loads(result.stdout)
            self.assertEqual(response_data["result"], "assigned")
        else:
            # Check if task was queued
            task_queue_file = self.workspace_root / "agents" / "task_queue.json"
            if task_queue_file.exists():
                with open(task_queue_file, "r") as f:
                    queue_data = json.load(f)
                if isinstance(queue_data, dict):
                    tasks = queue_data.get("tasks", [])
                else:
                    tasks = queue_data

                task_ids = [task["id"] for task in tasks]
                self.assertIn(self.test_task["id"], task_ids)

        print("✅ Agent orchestrator integration test passed")

    def test_06_workflow_orchestrator_integration(self):
        """Test 6: Workflow orchestrator integration"""
        print("🔄 Testing workflow orchestrator integration...")

        # Test workflow orchestrator status
        workflow_cmd = ["bash", "workflows/ci_orchestrator.sh", "pr-validation"]

        result = subprocess.run(
            workflow_cmd,
            cwd=self.workspace_root,
            capture_output=True,
            text=True,
            timeout=self.test_timeout * 2,  # Longer timeout for workflows
        )

        # Workflow should complete (may fail due to missing dependencies, but should not crash)
        self.assertIn(result.returncode, [0, 1])

        print("✅ Workflow orchestrator integration test passed")

    def test_07_submodule_mcp_integration(self):
        """Test 7: Submodule MCP client integration"""
        print("📦 Testing submodule MCP integration...")

        # Test one of the submodules
        submodule_path = self.workspace_root / "AvoidObstaclesGame"
        mcp_client_path = submodule_path / ".tools-automation" / "mcp_client.sh"

        if not mcp_client_path.exists():
            self.skipTest("Submodule MCP client not found")

        # Test MCP client forwarding
        client_cmd = ["bash", str(mcp_client_path), "status"]

        result = subprocess.run(
            client_cmd,
            cwd=submodule_path,
            capture_output=True,
            text=True,
            timeout=self.test_timeout,
        )

        # Should succeed if MCP server is running
        if self._check_server_availability(self.mcp_url):
            self.assertEqual(result.returncode, 0)
        else:
            # Should fail gracefully if server not available
            self.assertIn(result.returncode, [0, 1])

        print("✅ Submodule MCP integration test passed")

    def test_08_end_to_end_task_flow(self):
        """Test 8: End-to-end task flow simulation"""
        print("🔄 Testing end-to-end task flow...")

        if not self._check_server_availability(self.mcp_url):
            self.skipTest("MCP server not available for end-to-end test")

        # Register agent
        register_payload = {"agent": "e2e-test-agent", "capabilities": ["test"]}
        response = requests.post(f"{self.mcp_url}/register", json=register_payload)
        self.assertEqual(response.status_code, 200)

        # Submit task
        run_payload = {"agent": "e2e-test-agent", "command": "status", "execute": False}
        response = requests.post(f"{self.mcp_url}/run", json=run_payload)
        self.assertEqual(response.status_code, 200)
        task_id = response.json()["task_id"]

        # Execute task
        execute_payload = {"task_id": task_id}
        response = requests.post(f"{self.mcp_url}/execute_task", json=execute_payload)
        self.assertEqual(response.status_code, 200)

        # Wait for completion (with timeout)
        max_wait = 30
        start_time = time.time()
        while time.time() - start_time < max_wait:
            response = requests.get(f"{self.mcp_url}/status")
            tasks = response.json()["tasks"]
            task = next((t for t in tasks if t["id"] == task_id), None)
            if task and task.get("status") in ["success", "failed"]:
                break
            time.sleep(1)

        # Verify task completed
        response = requests.get(f"{self.mcp_url}/status")
        tasks = response.json()["tasks"]
        task = next((t for t in tasks if t["id"] == task_id), None)
        self.assertIsNotNone(task)
        self.assertIn(task["status"], ["success", "failed"])

        print("✅ End-to-end task flow test passed")

    def test_09_error_handling_and_recovery(self):
        """Test 9: Error handling and recovery"""
        print("🛠️ Testing error handling and recovery...")

        # Test invalid agent registration
        invalid_register = {"invalid": "payload"}
        response = requests.post(f"{self.mcp_url}/register", json=invalid_register)
        self.assertEqual(response.status_code, 400)

        # Test invalid task submission
        invalid_run = {"invalid": "command"}
        response = requests.post(f"{self.mcp_url}/run", json=invalid_run)
        self.assertEqual(response.status_code, 400)

        # Test non-existent endpoint
        response = requests.get(f"{self.mcp_url}/nonexistent")
        self.assertEqual(response.status_code, 404)

        print("✅ Error handling test passed")

    def test_10_performance_and_load(self):
        """Test 10: Basic performance and load testing"""
        print("⚡ Testing performance and load...")

        if not self._check_server_availability(self.mcp_url):
            self.skipTest("MCP server not available for performance test")

        # Test response times for health endpoint
        start_time = time.time()
        response = requests.get(f"{self.mcp_url}/health", timeout=10)
        response_time = time.time() - start_time

        self.assertEqual(response.status_code, 200)
        self.assertLess(response_time, 1.0)  # Should respond within 1 second

        # Test concurrent requests (basic load test)
        import concurrent.futures
        import threading

        results = []
        lock = threading.Lock()

        def make_request():
            try:
                start = time.time()
                resp = requests.get(f"{self.mcp_url}/health", timeout=5)
                end = time.time()
                with lock:
                    results.append((resp.status_code, end - start))
            except Exception:
                with lock:
                    results.append((0, 0))

        # Make 10 concurrent requests
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            concurrent.futures.wait(futures, timeout=10)

        # Verify all requests succeeded
        successful_requests = sum(1 for status, _ in results if status == 200)
        self.assertGreaterEqual(successful_requests, 8)  # At least 80% success rate

        # Check average response time
        response_times = [rt for _, rt in results if rt > 0]
        if response_times:
            avg_response_time = sum(response_times) / len(response_times)
            self.assertLess(avg_response_time, 2.0)  # Average under 2 seconds

        print("✅ Performance and load test passed")


if __name__ == "__main__":
    # Set up test environment
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent.parent))

    # Run tests
    unittest.main(verbosity=2)
