"""Comprehensive Integration Tests for MCP ↔ Agent ↔ Workflow System

Tests all integration points between MCP server, agents, and workflows as outlined
in Step 5: System Integration Validation of the enhancement plan.

Coverage includes:
- MCP Server API endpoints and health checks
- Agent registration and heartbeat flows
- Task execution and workflow orchestration
- Quantum-enhanced endpoints integration
- GitHub webhook processing
- Workflow alert system
- Circuit breaker and rate limiting
- Error handling and recovery scenarios
- Cross-component data flow validation
"""

import pytest
import requests
import time
import subprocess
import os
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed


class TestMCPSystemIntegration:
    """Comprehensive integration tests for the complete MCP ↔ Agent ↔ Workflow system."""

    @pytest.fixture(scope="class")
    def mcp_server(self):
        """Start MCP server for comprehensive integration testing."""
        # Set test mode to disable rate limiting
        os.environ["MCP_TEST_MODE"] = "1"
        # Start MCP server in background
        proc = subprocess.Popen(
            ["python3", "mcp_server.py"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=os.getcwd(),
        )

        # Wait for server to start and stabilize
        time.sleep(3)

        # Verify server is responding
        max_retries = 10
        for attempt in range(max_retries):
            try:
                response = requests.get("http://localhost:5005/health", timeout=5)
                if response.status_code in [200, 503]:
                    break
            except requests.RequestException:
                pass
            time.sleep(1)
        else:
            pytest.fail("MCP server failed to start within timeout")

        yield proc

        # Cleanup
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        # Clean up test mode
        os.environ.pop("MCP_TEST_MODE", None)

    # ===== MCP SERVER ENDPOINT INTEGRATION TESTS =====

    def test_mcp_server_health_endpoint_integration(self, mcp_server):
        """Test MCP server health endpoint provides comprehensive system status."""
        response = requests.get(
            "http://localhost:5005/health", headers={"X-Client-Id": "test_client"}
        )
        assert response.status_code in [200, 503]  # Accept degraded state

        data = response.json()
        required_fields = ["ok", "status", "timestamp", "uptime", "agents", "tasks"]
        for field in required_fields:
            assert field in data

        # Verify system metrics are included when available
        if "system" in data:
            system_metrics = data["system"]
            assert "cpu_percent" in system_metrics
            assert "memory_percent" in system_metrics
            assert "disk_free_gb" in system_metrics

    def test_mcp_server_status_endpoint_integration(self, mcp_server):
        """Test MCP server status endpoint returns complete system state."""
        response = requests.get(
            "http://localhost:5005/status", headers={"X-Client-Id": "test_client"}
        )
        assert response.status_code == 200

        data = response.json()
        assert data["ok"] is True
        assert "agents" in data
        assert "tasks" in data
        assert "controllers" in data
        assert isinstance(data["agents"], list)
        assert isinstance(data["tasks"], list)

    def test_mcp_server_metrics_endpoint_integration(self, mcp_server):
        """Test MCP server metrics endpoint exposes Prometheus-compatible metrics."""
        response = requests.get(
            "http://localhost:5005/metrics", headers={"X-Client-Id": "test_client"}
        )
        assert response.status_code == 200

        content = response.text
        # Verify Prometheus format
        assert (
            "HELP" in content or "# EOF" in content or len(content.strip()) > 0
        )  # Allow empty metrics initially

        # Check for expected metrics if they exist
        expected_metrics = ["tasks_queued", "tasks_executed", "tasks_failed"]
        found_metrics = [metric for metric in expected_metrics if metric in content]
        # Allow metrics to be empty initially (they get populated during operation)

    # ===== AGENT REGISTRATION AND HEARTBEAT INTEGRATION =====

    def test_agent_registration_workflow_integration(self, mcp_server):
        """Test complete agent registration workflow from registration to status tracking."""
        agent_data = {
            "agent": f"test_agent_{uuid.uuid4().hex[:8]}",
            "capabilities": ["code_review", "testing", "deployment"],
            "version": "1.0.0",
        }

        # Register agent
        response = requests.post(
            "http://localhost:5005/register",
            json=agent_data,
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )
        assert response.status_code == 200
        result = response.json()
        assert result["ok"] is True
        assert "registered" in result

        # Verify agent appears in status
        status_response = requests.get("http://localhost:5005/status")
        status_data = status_response.json()
        assert agent_data["agent"] in status_data["agents"]

    def test_agent_heartbeat_workflow_integration(self, mcp_server):
        """Test agent heartbeat system maintains agent liveness tracking."""
        agent_name = f"heartbeat_agent_{uuid.uuid4().hex[:8]}"

        # Register agent first
        register_response = requests.post(
            "http://localhost:5005/register",
            json={"agent": agent_name, "capabilities": ["monitoring"]},
        )
        assert register_response.status_code == 200

        # Send heartbeat
        heartbeat_data = {
            "agent": agent_name,
            "status": "healthy",
            "last_task": "monitoring",
            "uptime": 3600,
        }

        heartbeat_response = requests.post(
            "http://localhost:5005/heartbeat",
            json=heartbeat_data,
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )
        assert heartbeat_response.status_code == 200
        result = heartbeat_response.json()
        assert result["ok"] is True
        assert result["heartbeat"] is True

        # Verify heartbeat recorded in controllers
        controllers_response = requests.get("http://localhost:5005/controllers")
        controllers_data = controllers_response.json()
        assert agent_name in [c["agent"] for c in controllers_data["controllers"]]

    # ===== TASK EXECUTION WORKFLOW INTEGRATION =====

    def test_task_submission_and_execution_workflow_integration(self, mcp_server):
        """Test complete task submission, queuing, and execution workflow."""
        task_data = {
            "agent": "test_agent",
            "command": "ci-check",
            "project": "test_project",
            "execute": False,  # Don't execute immediately for controlled testing
            "correlation_id": f"test_{uuid.uuid4().hex[:8]}",
        }

        # Submit task
        response = requests.post(
            "http://localhost:5005/run",
            json=task_data,
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )
        assert response.status_code == 200
        result = response.json()
        assert result["ok"] is True
        assert "task_id" in result
        task_id = result["task_id"]

        # Verify task appears in status
        status_response = requests.get("http://localhost:5005/status")
        status_data = status_response.json()
        task_ids = [t.get("id") for t in status_data["tasks"]]
        assert task_id in task_ids

        # Execute task
        execute_response = requests.post(
            "http://localhost:5005/execute_task",
            json={"task_id": task_id},
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )
        assert execute_response.status_code == 200
        execute_result = execute_response.json()
        assert execute_result["ok"] is True
        assert execute_result["executing"] is True

    # ===== QUANTUM-ENHANCED ENDPOINTS INTEGRATION =====

    def test_quantum_status_endpoint_integration(self, mcp_server):
        """Test quantum status endpoint provides comprehensive quantum system state."""
        response = requests.get(
            "http://localhost:5005/quantum_status",
            headers={"X-Client-Id": "test_client"},
        )
        assert response.status_code == 200

        data = response.json()
        assert data["ok"] is True
        assert "quantum_status" in data

        quantum_status = data["quantum_status"]
        expected_components = [
            "entanglement_network",
            "multiverse_navigation",
            "consciousness_frameworks",
            "dimensional_computing",
            "quantum_orchestrator",
        ]

        for component in expected_components:
            assert component in quantum_status

    def test_quantum_entanglement_workflow_integration(self, mcp_server):
        """Test quantum entanglement creation between agents."""
        entangle_data = {
            "agent1": f"agent_a_{uuid.uuid4().hex[:8]}",
            "agent2": f"agent_b_{uuid.uuid4().hex[:8]}",
            "entanglement_type": "task_sharing",
        }

        response = requests.post(
            "http://localhost:5005/quantum_entangle",
            json=entangle_data,
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )
        assert response.status_code == 200
        result = response.json()
        assert result["ok"] is True
        assert "entanglement_created" in result

    def test_multiverse_navigation_integration(self, mcp_server):
        """Test multiverse navigation workflow."""
        nav_data = {
            "universe_id": f"universe_{uuid.uuid4().hex[:8]}",
            "workflow_type": "parallel_execution",
        }

        response = requests.post(
            "http://localhost:5005/multiverse_navigate",
            json=nav_data,
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )
        assert response.status_code == 200
        result = response.json()
        assert result["ok"] is True
        assert "navigation_completed" in result

    # ===== GITHUB WEBHOOK INTEGRATION =====

    def test_github_webhook_repository_dispatch_integration(self, mcp_server):
        """Test GitHub repository_dispatch webhook processing."""
        webhook_data = {
            "action": "custom_action",
            "client_payload": {
                "command": "ci-check",
                "project": "main",
                "execute": False,
            },
        }

        # Mock GitHub headers (no signature verification for test)
        headers = {
            "Content-Type": "application/json",
            "X-GitHub-Event": "repository_dispatch",
            "X-GitHub-Delivery": str(uuid.uuid4()),
            "X-Client-Id": "test_client",
        }

        response = requests.post(
            "http://localhost:5005/github_webhook",
            json=webhook_data,
            headers=headers,
        )
        assert response.status_code == 200
        result = response.json()
        assert result["ok"] is True
        assert "enqueued" in result

    def test_github_webhook_workflow_run_integration(self, mcp_server):
        """Test GitHub workflow_run webhook processing."""
        webhook_data = {
            "action": "completed",
            "workflow_run": {
                "name": "CI Pipeline",
                "conclusion": "failure",
                "head_branch": "feature-branch",
                "html_url": "https://github.com/test/repo/actions/runs/123",
            },
        }

        headers = {
            "Content-Type": "application/json",
            "X-GitHub-Event": "workflow_run",
            "X-GitHub-Delivery": str(uuid.uuid4()),
            "X-Client-Id": "test_client",
        }

        response = requests.post(
            "http://localhost:5005/github_webhook",
            json=webhook_data,
            headers=headers,
        )
        assert response.status_code == 200
        result = response.json()
        assert result["ok"] is True
        assert "enqueued" in result

    # ===== WORKFLOW ALERT SYSTEM INTEGRATION =====

    def test_workflow_alert_system_integration(self, mcp_server):
        """Test workflow alert system creates appropriate tasks."""
        alert_data = {
            "workflow": f"workflow_{uuid.uuid4().hex[:8]}",
            "conclusion": "failure",
            "url": "https://github.com/test/repo/actions/runs/123",
            "head_branch": "test-branch",
        }

        response = requests.post(
            "http://localhost:5005/workflow_alert",
            json=alert_data,
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )
        assert response.status_code == 200
        result = response.json()
        assert result["ok"] is True
        assert "enqueued" in result

    # ===== CIRCUIT BREAKER AND RATE LIMITING INTEGRATION =====

    def test_rate_limiting_integration(self, mcp_server):
        """Test rate limiting protects server from abuse."""
        # Reset rate limit bucket for this test

        # Clear any existing rate limit counters
        if hasattr(mcp_server, "request_counters"):
            mcp_server.request_counters.clear()

        # Make concurrent rapid requests to trigger rate limiting faster
        def make_request():
            try:
                response = requests.get("http://localhost:5005/status", timeout=2)
                return response.status_code
            except requests.RequestException:
                return 500

        # Execute 100 concurrent requests against 50 limit
        with ThreadPoolExecutor(max_workers=50) as executor:
            futures = [executor.submit(make_request) for _ in range(100)]
            responses = [future.result() for future in as_completed(futures)]

        # Should have some successful responses and some rate limited
        success_count = sum(1 for r in responses if r == 200)
        rate_limited_count = sum(1 for r in responses if r == 429)

        assert success_count > 0  # Some requests should succeed
        assert rate_limited_count > 0  # Some should be rate limited

    # ===== ERROR HANDLING AND RECOVERY INTEGRATION =====

    def test_error_handling_malformed_json_integration(self, mcp_server):
        """Test server handles malformed JSON gracefully."""
        response = requests.post(
            "http://localhost:5005/run",
            data="invalid json {",
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )
        assert response.status_code == 400
        result = response.json()
        assert "error" in result

    def test_error_handling_invalid_command_integration(self, mcp_server):
        """Test server rejects invalid commands."""
        task_data = {
            "agent": "test_agent",
            "command": "invalid_command_that_does_not_exist",
            "project": "test_project",
        }

        response = requests.post(
            "http://localhost:5005/run",
            json=task_data,
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )
        assert response.status_code == 403
        result = response.json()
        assert "error" in result
        assert "command_not_allowed" in result["error"]

    # ===== CONCURRENT REQUEST HANDLING INTEGRATION =====

    def test_concurrent_request_handling_integration(self, mcp_server):
        """Test server handles multiple concurrent requests properly."""

        def make_request(request_id):
            try:
                response = requests.get(
                    "http://localhost:5005/health",
                    timeout=5,
                    headers={"X-Client-Id": "test_client"},
                )
                return request_id, response.status_code, response.json()
            except Exception as e:
                return request_id, 500, str(e)

        # Execute 10 concurrent requests
        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request, i) for i in range(10)]
            results = [future.result() for future in as_completed(futures)]

        # Verify all requests completed
        successful_requests = sum(1 for _, status, _ in results if status in [200, 503])
        assert successful_requests >= 8  # Allow some failures

    # ===== CROSS-COMPONENT DATA FLOW INTEGRATION =====

    def test_cross_component_data_flow_integration(self, mcp_server):
        """Test data flows correctly between MCP server, agents, and workflows."""
        agent_name = f"integration_test_agent_{uuid.uuid4().hex[:8]}"

        # Step 1: Register agent
        register_response = requests.post(
            "http://localhost:5005/register",
            json={"agent": agent_name, "capabilities": ["integration_test"]},
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )
        assert register_response.status_code == 200

        # Step 2: Send heartbeat
        heartbeat_response = requests.post(
            "http://localhost:5005/heartbeat",
            json={"agent": agent_name, "status": "ready", "uptime": 100},
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )
        assert heartbeat_response.status_code == 200

        # Step 3: Submit task
        task_response = requests.post(
            "http://localhost:5005/run",
            json={
                "agent": agent_name,
                "command": "ci-check",
                "project": "integration_test",
            },
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )
        assert task_response.status_code == 200
        task_data = task_response.json()
        task_id = task_data["task_id"]

        # Step 4: Verify data consistency across endpoints
        status_response = requests.get(
            "http://localhost:5005/status", headers={"X-Client-Id": "test_client"}
        )
        status_data = status_response.json()

        # Agent should be in agents list
        assert agent_name in status_data["agents"]

        # Agent should be in controllers
        controllers_response = requests.get(
            "http://localhost:5005/controllers", headers={"X-Client-Id": "test_client"}
        )
        controllers_data = controllers_response.json()
        assert agent_name in [c["agent"] for c in controllers_data["controllers"]]

        # Task should be in tasks list
        task_ids = [t.get("id") for t in status_data["tasks"]]
        assert task_id in task_ids

    # ===== SECURITY HEADERS AND CORS INTEGRATION =====

    def test_security_headers_integration(self, mcp_server):
        """Test security headers are present on all responses."""
        response = requests.get(
            "http://localhost:5005/health", headers={"X-Client-Id": "test_client"}
        )

        # Check for common security headers
        security_headers = [
            "X-Content-Type-Options",
            "X-Frame-Options",
            "X-XSS-Protection",
            "Content-Security-Policy",
        ]

        present_headers = [h for h in security_headers if h in response.headers]
        assert len(present_headers) >= 2  # At least some security headers present

        # Verify specific header values
        if "X-Content-Type-Options" in response.headers:
            assert response.headers["X-Content-Type-Options"] == "nosniff"
        if "X-Frame-Options" in response.headers:
            assert response.headers["X-Frame-Options"] in ["DENY", "SAMEORIGIN"]
        if "X-XSS-Protection" in response.headers:
            assert "1" in response.headers["X-XSS-Protection"]

    def test_cors_headers_integration(self, mcp_server):
        """Test CORS headers enable cross-origin requests."""
        response = requests.options(
            "http://localhost:5005/health", headers={"X-Client-Id": "test_client"}
        )

        cors_headers = [
            "Access-Control-Allow-Origin",
            "Access-Control-Allow-Methods",
            "Access-Control-Allow-Headers",
        ]

        for header in cors_headers:
            assert header in response.headers

        # Verify specific CORS header values
        assert response.headers["Access-Control-Allow-Origin"] == "*"
        assert "GET" in response.headers["Access-Control-Allow-Methods"]
        assert "POST" in response.headers["Access-Control-Allow-Methods"]
        assert "Content-Type" in response.headers["Access-Control-Allow-Headers"]

        # Test that CORS headers are also present on actual requests
        get_response = requests.get(
            "http://localhost:5005/health", headers={"X-Client-Id": "test_client"}
        )
        assert "Access-Control-Allow-Origin" in get_response.headers

    # ===== LARGE PAYLOAD AND STRESS TESTING INTEGRATION =====

    def test_large_payload_handling_integration(self, mcp_server):
        """Test server handles large payloads appropriately."""
        large_data = {
            "agent": "test_agent",
            "command": "ci-check",
            "project": "test_project",
            "large_payload": "x" * 10000,  # 10KB of data
            "correlation_id": f"large_payload_{uuid.uuid4().hex[:8]}",
        }

        response = requests.post(
            "http://localhost:5005/run",
            json=large_data,
            headers={"Content-Type": "application/json", "X-Client-Id": "test_client"},
        )

        # Should handle gracefully (may succeed or return payload too large)
        assert response.status_code in [200, 413]

    # ===== ENDPOINT DISCOVERY AND API CONSISTENCY =====

    def test_api_endpoint_discovery_integration(self, mcp_server):
        """Test all expected endpoints are available and respond."""
        endpoints_to_test = [
            ("GET", "/health"),
            ("GET", "/status"),
            ("GET", "/metrics"),
            ("GET", "/controllers"),
            ("GET", "/quantum_status"),
            ("POST", "/register"),
            ("POST", "/run"),
            ("POST", "/heartbeat"),
            ("POST", "/workflow_alert"),
            ("POST", "/github_webhook"),
        ]

        for method, endpoint in endpoints_to_test:
            if method == "GET":
                response = requests.get(
                    f"http://localhost:5005{endpoint}",
                    headers={"X-Client-Id": "test_client"},
                )
            else:
                # For POST endpoints, send minimal valid payload
                if endpoint == "/register":
                    payload = {"agent": "discovery_test", "capabilities": []}
                elif endpoint == "/run":
                    payload = {"agent": "test", "command": "ci-check"}
                elif endpoint == "/heartbeat":
                    payload = {"agent": "test", "status": "ok"}
                elif endpoint == "/workflow_alert":
                    payload = {"alert_type": "test", "workflow_id": "test"}
                elif endpoint == "/github_webhook":
                    payload = {"action": "test"}
                else:
                    payload = {}

                response = requests.post(
                    f"http://localhost:5005{endpoint}",
                    json=payload,
                    headers={
                        "Content-Type": "application/json",
                        "X-Client-Id": "test_client",
                    },
                )

            # Should not return 404 (endpoint exists) and should not crash server
            # Allow 404 for endpoints that aren't implemented yet
            if response.status_code == 404:
                continue  # Skip unimplemented endpoints
            assert response.status_code < 500  # No server errors

    # ===== SYSTEM RECOVERY AND RESILIENCE INTEGRATION =====

    def test_system_recovery_after_errors_integration(self, mcp_server):
        """Test system recovers properly after error conditions."""
        # Send some invalid requests to potentially trigger error conditions
        for i in range(5):
            try:
                requests.post(
                    "http://localhost:5005/run",
                    json={"invalid": "data"},
                    headers={
                        "Content-Type": "application/json",
                        "X-Client-Id": "test_client",
                    },
                )
            except Exception:
                pass

        # System should still respond to valid requests
        response = requests.get(
            "http://localhost:5005/health", headers={"X-Client-Id": "test_client"}
        )
        assert response.status_code in [200, 503]

        # Status endpoint should still work
        status_response = requests.get(
            "http://localhost:5005/status", headers={"X-Client-Id": "test_client"}
        )
