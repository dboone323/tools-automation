#!/usr/bin/env python3
"""
Contract Tests for MCP Server API

Uses Pact framework to test API contracts between MCP server and agents.
Ensures backward compatibility and proper API evolution.

Run with: python -m pytest tests/integration/test_mcp_contracts.py -v
"""

import json
import unittest
from pathlib import Path

import requests
from requests.exceptions import ConnectionError, Timeout


class TestMCPContracts(unittest.TestCase):
    """Test MCP API contracts using Pact-like approach"""

    def setUp(self):
        """Set up contract test environment"""
        self.workspace_root = Path(__file__).parent.parent.parent
        self.mcp_url = "http://127.0.0.1:5005"
        self.contracts_dir = self.workspace_root / "tests" / "contracts"
        self.contracts_dir.mkdir(exist_ok=True)

    def _check_server_available(self):
        """Check if MCP server is available"""
        try:
            response = requests.get(f"{self.mcp_url}/health", timeout=5, headers={"X-Client-Id": "test_client"})
            return response.status_code in [200, 503]
        except (ConnectionError, Timeout):
            return False

    def test_health_endpoint_contract(self):
        """Test /health endpoint contract"""
        print("🏥 Testing /health endpoint contract...")

        if not self._check_server_available():
            self.skipTest("MCP server not available")

        response = requests.get(f"{self.mcp_url}/health", timeout=10, headers={"X-Client-Id": "test_client"})

        # Contract: Must return valid JSON
        self.assertEqual(response.status_code, 200)
        health_data = response.json()

        # Contract: Required fields
        required_fields = ["ok", "status", "timestamp"]
        for field in required_fields:
            self.assertIn(field, health_data, f"Missing required field: {field}")

        # Contract: Status must be valid
        valid_statuses = ["healthy", "degraded", "error"]
        self.assertIn(health_data["status"], valid_statuses)

        # Contract: Timestamp must be numeric
        self.assertIsInstance(health_data["timestamp"], (int, float))

        # Contract: If ok=true, status must be healthy
        if health_data.get("ok"):
            self.assertEqual(health_data["status"], "healthy")

        # Save contract for future compatibility checks
        contract = {
            "endpoint": "/health",
            "method": "GET",
            "response_schema": {
                "type": "object",
                "required": required_fields,
                "properties": {
                    "ok": {"type": "boolean"},
                    "status": {"enum": valid_statuses},
                    "timestamp": {"type": "number"},
                    "uptime": {"type": "boolean"},
                    "agents": {
                        "type": "object",
                        "properties": {
                            "registered": {"type": "integer"},
                            "controllers": {"type": "integer"},
                        },
                    },
                    "tasks": {
                        "type": "object",
                        "properties": {
                            "total": {"type": "integer"},
                            "queued": {"type": "integer"},
                            "running": {"type": "integer"},
                        },
                    },
                },
            },
        }

        contract_file = self.contracts_dir / "health_endpoint_contract.json"
        with open(contract_file, "w") as f:
            json.dump(contract, f, indent=2)

        print("✅ Health endpoint contract test passed")

    def test_register_endpoint_contract(self):
        """Test /register endpoint contract"""
        print("📝 Testing /register endpoint contract...")

        if not self._check_server_available():
            self.skipTest("MCP server not available")

        # Test valid registration
        register_payload = {
            "agent": "contract-test-agent",
            "capabilities": ["test", "contract"],
        }

        response = requests.post(
            f"{self.mcp_url}/register", json=register_payload, timeout=10, headers={"X-Client-Id": "test_client"}
        )

        # Contract: Must return 200 for valid registration
        self.assertEqual(response.status_code, 200)
        register_data = response.json()

        # Contract: Required response fields
        required_fields = ["ok", "registered"]
        for field in required_fields:
            self.assertIn(field, register_data)

        self.assertTrue(register_data["ok"])
        self.assertEqual(register_data["registered"], "contract-test-agent")

        # Test invalid registration (missing agent)
        invalid_payload = {"capabilities": ["test"]}
        response = requests.post(
            f"{self.mcp_url}/register", json=invalid_payload, timeout=10, headers={"X-Client-Id": "test_client"}
        )

        # Contract: Must return 400 for invalid registration
        self.assertEqual(response.status_code, 400)
        error_data = response.json()
        self.assertIn("error", error_data)

        print("✅ Register endpoint contract test passed")

    def test_run_endpoint_contract(self):
        """Test /run endpoint contract"""
        print("🎯 Testing /run endpoint contract...")

        if not self._check_server_available():
            self.skipTest("MCP server not available")

        # Test valid task submission
        run_payload = {
            "agent": "contract-test-agent",
            "command": "status",
            "execute": False,
        }

        response = requests.post(f"{self.mcp_url}/run", json=run_payload, timeout=10, headers={"X-Client-Id": "test_client"})

        # Contract: Must return 200 for valid task submission
        self.assertEqual(response.status_code, 200)
        run_data = response.json()

        # Contract: Required response fields
        required_fields = ["ok", "task_id", "queued"]
        for field in required_fields:
            self.assertIn(field, run_data)

        self.assertTrue(run_data["ok"])
        self.assertTrue(run_data["queued"])
        self.assertIsInstance(run_data["task_id"], str)

        # Test invalid task submission (missing agent)
        invalid_payload = {"command": "status"}
        response = requests.post(
            f"{self.mcp_url}/run", json=invalid_payload, timeout=10, headers={"X-Client-Id": "test_client"}
        )

        # Contract: Must return 400 for invalid task submission
        self.assertEqual(response.status_code, 400)
        error_data = response.json()
        self.assertIn("error", error_data)

        # Test invalid command
        invalid_cmd_payload = {
            "agent": "contract-test-agent",
            "command": "invalid_command",
        }
        response = requests.post(
            f"{self.mcp_url}/run", json=invalid_cmd_payload, timeout=10, headers={"X-Client-Id": "test_client"}
        )

        # Contract: Must return 403 for invalid command
        self.assertEqual(response.status_code, 403)
        error_data = response.json()
        self.assertIn("error", error_data)

        print("✅ Run endpoint contract test passed")

    def test_status_endpoint_contract(self):
        """Test /status endpoint contract"""
        print("📊 Testing /status endpoint contract...")

        if not self._check_server_available():
            self.skipTest("MCP server not available")

        response = requests.get(f"{self.mcp_url}/status", timeout=10, headers={"X-Client-Id": "test_client"})

        # Contract: Must return 200
        self.assertEqual(response.status_code, 200)
        status_data = response.json()

        # Contract: Required response fields
        required_fields = ["ok", "agents", "tasks", "controllers"]
        for field in required_fields:
            self.assertIn(field, status_data)

        self.assertTrue(status_data["ok"])
        self.assertIsInstance(status_data["agents"], list)
        self.assertIsInstance(status_data["tasks"], list)
        self.assertIsInstance(
            status_data["controllers"], list
        )  # Fixed: controllers is a list

        print("✅ Status endpoint contract test passed")

    def test_controllers_endpoint_contract(self):
        """Test /controllers endpoint contract"""
        print("🎮 Testing /controllers endpoint contract...")

        if not self._check_server_available():
            self.skipTest("MCP server not available")

        response = requests.get(f"{self.mcp_url}/controllers", timeout=10, headers={"X-Client-Id": "test_client"})

        # Contract: Must return 200
        self.assertEqual(response.status_code, 200)
        controllers_data = response.json()

        # Contract: Required response fields
        required_fields = ["ok", "controllers"]
        for field in required_fields:
            self.assertIn(field, controllers_data)

        self.assertTrue(controllers_data["ok"])
        self.assertIsInstance(controllers_data["controllers"], list)

        print("✅ Controllers endpoint contract test passed")

    def test_execute_task_endpoint_contract(self):
        """Test /execute_task endpoint contract"""
        print("▶️ Testing /execute_task endpoint contract...")

        if not self._check_server_available():
            self.skipTest("MCP server not available")

        # First create a task
        run_payload = {
            "agent": "contract-test-agent",
            "command": "status",
            "execute": False,
        }
        response = requests.post(f"{self.mcp_url}/run", json=run_payload, headers={"X-Client-Id": "test_client"})
        task_id = response.json()["task_id"]

        # Now execute it
        execute_payload = {"task_id": task_id}
        response = requests.post(
            f"{self.mcp_url}/execute_task", json=execute_payload, timeout=15, headers={"X-Client-Id": "test_client"}
        )

        # Contract: Must return 200 for valid execution
        self.assertEqual(response.status_code, 200)
        execute_data = response.json()

        # Contract: Required response fields
        required_fields = ["ok", "executing", "task_id"]
        for field in required_fields:
            self.assertIn(field, execute_data)

        self.assertTrue(execute_data["ok"])
        self.assertTrue(execute_data["executing"])
        self.assertEqual(execute_data["task_id"], task_id)

        # Test invalid execution (missing task_id)
        invalid_payload = {}
        response = requests.post(
            f"{self.mcp_url}/execute_task", json=invalid_payload, timeout=10, headers={"X-Client-Id": "test_client"}
        )

        # Contract: Must return 400 for invalid execution
        self.assertEqual(response.status_code, 400)
        error_data = response.json()
        self.assertIn("error", error_data)

        print("✅ Execute task endpoint contract test passed")

    def test_error_response_contracts(self):
        """Test error response contracts"""
        print("❌ Testing error response contracts...")

        if not self._check_server_available():
            self.skipTest("MCP server not available")

        # Test 404 for non-existent endpoint
        response = requests.get(f"{self.mcp_url}/nonexistent", timeout=10, headers={"X-Client-Id": "test_client"})
        self.assertEqual(response.status_code, 404)
        error_data = response.json()
        self.assertIn("error", error_data)

        # Test rate limiting (if implemented)
        # This test may be skipped if rate limiting is not enabled
        rate_limited = False
        for i in range(60):  # Try to trigger rate limit
            response = requests.get(f"{self.mcp_url}/health", timeout=1, headers={"X-Client-Id": "test_client"})
            if response.status_code == 429:
                rate_limited = True
                error_data = response.json()
                self.assertIn("error", error_data)
                break

        if rate_limited:
            print("✅ Rate limiting contract verified")
        else:
            print("ℹ️ Rate limiting not triggered (may not be enabled)")

        print("✅ Error response contracts test passed")

    def test_cors_headers_contract(self):
        """Test CORS headers contract"""
        print("🌐 Testing CORS headers contract...")

        # Test preflight request
        try:
            response = requests.options(
            f"{self.mcp_url}/health",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "Content-Type",
            },
            timeout=10,
            )
        except (ConnectionError, Timeout):
            self.skipTest("MCP server not available for CORS contract test")

        # Contract: Must allow CORS
        self.assertIn("Access-Control-Allow-Origin", response.headers)
        self.assertIn("Access-Control-Allow-Methods", response.headers)
        self.assertIn("Access-Control-Allow-Headers", response.headers)

        # Test actual request includes CORS headers
        response = requests.get(f"{self.mcp_url}/health", timeout=10, headers={"X-Client-Id": "test_client"})
        self.assertIn("Access-Control-Allow-Origin", response.headers)

        print("✅ CORS headers contract test passed")

    def test_security_headers_contract(self):
        """Test security headers contract"""
        print("🔒 Testing security headers contract...")

        if not self._check_server_available():
            self.skipTest("MCP server not available")

        response = requests.get(f"{self.mcp_url}/health", timeout=10, headers={"X-Client-Id": "test_client"})

        # Contract: Must include security headers
        required_headers = [
            "X-Content-Type-Options",
            "X-Frame-Options",
            "X-XSS-Protection",
            "Content-Security-Policy",
        ]

        for header in required_headers:
            self.assertIn(
                header, response.headers, f"Missing security header: {header}"
            )

        # Contract: Security header values
        self.assertEqual(response.headers["X-Content-Type-Options"], "nosniff")
        self.assertEqual(response.headers["X-Frame-Options"], "DENY")
        self.assertEqual(response.headers["X-XSS-Protection"], "1; mode=block")

        print("✅ Security headers contract test passed")


if __name__ == "__main__":
    # Set up test environment
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent.parent))

    # Run tests
    unittest.main(verbosity=2)
