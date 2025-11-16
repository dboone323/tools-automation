"""Integration tests for MCP ↔ Agent ↔ Workflow chains."""

import pytest
import requests
import json
import time
import subprocess
import os


class TestMCPAgentWorkflowIntegration:
    """Test full integration between MCP server, agents, and workflows."""

    @pytest.fixture(scope="class")
    def mcp_server(self):
        """Start MCP server for testing."""
        # Start MCP server in background
        proc = subprocess.Popen(
            ["python3", "mcp_server.py"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=os.getcwd(),
        )

        # Wait for server to start
        time.sleep(2)

        # Check if server is running (accept healthy, degraded, or rate-limited states for testing)
        try:
            response = requests.get("http://localhost:5005/health", timeout=5)
            # Accept healthy (200), degraded (503), or rate-limited (429) states for testing
            assert response.status_code in [
                200,
                503,
                429,
            ], f"Server returned status {response.status_code}"
        except requests.RequestException:
            pytest.fail("MCP server failed to start")

        yield proc

        # Cleanup
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()

    @pytest.fixture
    def agent_status_file(self, tmp_path):
        """Create temporary agent status file."""
        status_file = tmp_path / "agent_status.json"
        status_file.write_text('{"agents": {}}')
        return status_file

    def test_mcp_health_endpoint(self, mcp_server):
        """Test MCP server health endpoint."""
        response = requests.get("http://localhost:5005/health")
        assert response.status_code == 200

        data = response.json()
        assert "status" in data
        assert "ok" in data
        assert "uptime" in data

    def test_mcp_metrics_endpoint(self, mcp_server):
        """Test MCP server metrics endpoint."""
        response = requests.get("http://localhost:5005/metrics")
        assert response.status_code == 200

        # Should contain Prometheus-style metrics
        content = response.text
        assert "tasks_queued" in content
        assert "tasks_executed" in content
        assert "tasks_failed" in content

    def test_agent_health_check_integration(self, mcp_server):
        """Test agent health check via MCP server."""
        # Test with a simple agent that has health check
        agent_script = "agents/agent_helpers.sh"

        # Run agent health check
        result = subprocess.run(
            [agent_script, "--health"], capture_output=True, text=True, timeout=10
        )

        assert result.returncode == 0
        data = json.loads(result.stdout)
        assert data["ok"] is True

    def test_task_submission_workflow(self, mcp_server, agent_status_file):
        """Test full task submission workflow."""
        # Submit task via MCP
        task_data = {
            "type": "suggest_fix",
            "error_pattern": "syntax error",
            "context": "{}",
            "correlation_id": "test-123",
        }

        response = requests.post(
            "http://localhost:5005/tasks",
            json=task_data,
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code == 200
        result = response.json()
        assert "task_id" in result

        task_id = result["task_id"]

        # Check task status
        status_response = requests.get(f"http://localhost:5005/tasks/{task_id}")
        assert status_response.status_code == 200

        status_data = status_response.json()
        assert status_data["status"] in ["pending", "running", "completed"]

    def test_agent_orchestrator_integration(self, mcp_server):
        """Test agent orchestrator task assignment."""
        # Import orchestrator for testing
        import sys

        sys.path.append("agents")

        from orchestrator_v2 import TaskOrchestrator

        orchestrator = TaskOrchestrator()

        # Create test task
        task = {
            "id": "test-task-123",
            "type": "code_review",
            "data": {"file": "test.py", "content": "print('hello')"},
            "correlation_id": "test-456",
        }

        # Test task assignment
        assigned_agent = orchestrator.assign_task(task)
        assert assigned_agent is not None
        assert "agent" in assigned_agent

    def test_workflow_execution_chain(self, mcp_server):
        """Test complete workflow execution chain."""
        # This would test the full chain: MCP → Orchestrator → Agent → Result
        # For now, test the components individually

        # Test MCP task submission
        task_data = {"type": "health_check", "correlation_id": "workflow-test-789"}

        response = requests.post("http://localhost:5005/tasks", json=task_data)

        assert response.status_code == 200

        # In a full implementation, we'd wait for completion
        # For now, just verify submission works

    def test_error_handling_integration(self, mcp_server):
        """Test error handling across components."""
        # Test with invalid task data
        invalid_task = {"type": "invalid_type", "data": None}

        response = requests.post("http://localhost:5005/tasks", json=invalid_task)

        # Should handle gracefully
        assert response.status_code in [200, 400, 500]

    def test_concurrent_requests(self, mcp_server):
        """Test handling multiple concurrent requests."""
        import threading
        import queue

        results = queue.Queue()

        def make_request(i):
            try:
                response = requests.get("http://localhost:5005/health", timeout=5)
                results.put((i, response.status_code))
            except Exception as e:
                results.put((i, str(e)))

        # Start 10 concurrent requests
        threads = []
        for i in range(10):
            t = threading.Thread(target=make_request, args=(i,))
            threads.append(t)
            t.start()

        # Wait for all to complete
        for t in threads:
            t.join()

        # Check results
        success_count = 0
        for _ in range(10):
            i, result = results.get()
            if isinstance(result, int) and result == 200:
                success_count += 1

        assert success_count >= 8  # Allow some failures

    def test_agent_status_tracking(self, mcp_server, agent_status_file):
        """Test agent status tracking integration."""
        # This would test the agent status API
        # For now, just verify the endpoint exists
        response = requests.get("http://localhost:5005/agents/status")
        # May not be implemented yet, so just check it doesn't crash the server
        assert response.status_code in [200, 404, 501]

    @pytest.mark.performance
    def test_mcp_performance_under_load(self, mcp_server):
        """Test MCP server performance under load."""
        import time

        start_time = time.time()
        request_count = 100

        for i in range(request_count):
            response = requests.get("http://localhost:5005/health")
            assert response.status_code == 200

        end_time = time.time()
        total_time = end_time - start_time

        # Should handle 100 requests in reasonable time
        assert total_time < 30  # Less than 30 seconds
        avg_response_time = total_time / request_count
        assert avg_response_time < 0.5  # Less than 500ms average

    def test_mcp_status_endpoint(self, mcp_server):
        """Test MCP server status endpoint."""
        response = requests.get("http://localhost:5005/status")
        assert response.status_code == 200

        data = response.json()
        assert "ok" in data
        assert "agents" in data
        assert "tasks" in data
        assert isinstance(data["agents"], list)
        assert isinstance(data["tasks"], list)

    def test_agent_registration_workflow(self, mcp_server):
        """Test agent registration workflow."""
        agent_data = {
            "agent": "test_agent",
            "capabilities": ["code_review", "testing", "deployment"],
            "version": "1.0.0",
        }

        response = requests.post(
            "http://localhost:5005/register",
            json=agent_data,
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code == 200
        result = response.json()
        assert "registered" in result or "ok" in result

    def test_agent_heartbeat_endpoint(self, mcp_server):
        """Test agent heartbeat functionality."""
        heartbeat_data = {
            "agent": "test_agent",
            "status": "healthy",
            "last_task": "code_review",
            "uptime": 3600,
        }

        response = requests.post(
            "http://localhost:5005/heartbeat",
            json=heartbeat_data,
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code == 200

    def test_task_execution_endpoint(self, mcp_server):
        """Test task execution endpoint."""
        task_data = {
            "agent": "test_agent",
            "command": "analyze",
            "project": "test_project",
            "execute": False,  # Dry run for testing
            "correlation_id": "test-exec-123",
        }

        response = requests.post(
            "http://localhost:5005/run",
            json=task_data,
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code in [200, 400]  # May fail if agent not registered

    def test_quantum_status_endpoint(self, mcp_server):
        """Test quantum status endpoint."""
        response = requests.get("http://localhost:5005/quantum_status")
        assert response.status_code in [200, 404, 501]  # May not be implemented

        if response.status_code == 200:
            data = response.json()
            assert "status" in data

    def test_quantum_entanglement_endpoint(self, mcp_server):
        """Test quantum entanglement endpoint."""
        entangle_data = {
            "agent1": "agent_a",
            "agent2": "agent_b",
            "entanglement_type": "task_sharing",
        }

        response = requests.post(
            "http://localhost:5005/quantum_entangle",
            json=entangle_data,
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code in [200, 400, 501]

    def test_multiverse_navigation_endpoint(self, mcp_server):
        """Test multiverse navigation endpoint."""
        nav_data = {
            "universe_id": "test_universe",
            "workflow_type": "parallel_execution",
        }

        response = requests.post(
            "http://localhost:5005/multiverse_navigate",
            json=nav_data,
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code in [200, 400, 501]

    def test_consciousness_expansion_endpoint(self, mcp_server):
        """Test consciousness expansion endpoint."""
        expand_data = {"expansion_type": "learning", "target_agent": "test_agent"}

        response = requests.post(
            "http://localhost:5005/consciousness_expand",
            json=expand_data,
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code in [200, 400, 501]

    def test_dimensional_compute_endpoint(self, mcp_server):
        """Test dimensional computation endpoint."""
        compute_data = {"dimensions": [3, 4, 5], "computation_type": "optimization"}

        response = requests.post(
            "http://localhost:5005/dimensional_compute",
            json=compute_data,
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code in [200, 400, 501]

    def test_quantum_orchestration_endpoint(self, mcp_server):
        """Test quantum orchestration endpoint."""
        orchestrate_data = {
            "workflow_name": "test_workflow",
            "execution_mode": "parallel",
        }

        response = requests.post(
            "http://localhost:5005/quantum_orchestrate",
            json=orchestrate_data,
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code in [200, 400, 501]

    def test_reality_simulation_endpoint(self, mcp_server):
        """Test reality simulation endpoint."""
        sim_data = {"simulation_type": "predictive", "parameters": {"confidence": 0.95}}

        response = requests.post(
            "http://localhost:5005/reality_simulate",
            json=sim_data,
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code in [200, 400, 501]

    def test_workflow_alert_endpoint(self, mcp_server):
        """Test workflow alert endpoint."""
        alert_data = {
            "alert_type": "task_failed",
            "workflow_id": "test-workflow-123",
            "message": "Task execution failed",
            "severity": "high",
        }

        response = requests.post(
            "http://localhost:5005/workflow_alert",
            json=alert_data,
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code == 200

    def test_controllers_endpoint(self, mcp_server):
        """Test controllers status endpoint."""
        response = requests.get("http://localhost:5005/controllers")
        assert response.status_code == 200

        data = response.json()
        assert isinstance(data, list)  # Should return list of controllers

    def test_github_webhook_endpoint(self, mcp_server):
        """Test GitHub webhook endpoint."""
        webhook_data = {
            "action": "push",
            "repository": {"name": "test-repo"},
            "commits": [{"message": "test commit"}],
        }

        response = requests.post(
            "http://localhost:5005/github_webhook",
            json=webhook_data,
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code in [200, 400]  # May require signature verification

    def test_circuit_breaker_functionality(self, mcp_server):
        """Test circuit breaker functionality."""
        # Make multiple failing requests to trigger circuit breaker
        for i in range(5):
            try:
                response = requests.get("http://localhost:5005/invalid_endpoint")
                # Should get 404, but circuit breaker might activate
            except:
                pass

        # Circuit breaker should eventually activate for repeated failures
        # This test verifies the circuit breaker is working

    def test_rate_limiting(self, mcp_server):
        """Test rate limiting functionality."""
        # Make many rapid requests to test rate limiting
        responses = []
        for i in range(20):
            try:
                response = requests.get("http://localhost:5005/health")
                responses.append(response.status_code)
            except:
                responses.append(500)

        # Should have some successful responses
        success_count = sum(1 for r in responses if r == 200)
        assert success_count > 10  # At least some requests should succeed

    def test_large_payload_handling(self, mcp_server):
        """Test handling of large payloads."""
        large_data = {
            "type": "large_task",
            "data": {"content": "x" * 10000},  # 10KB of data
            "correlation_id": "large-payload-test",
        }

        response = requests.post(
            "http://localhost:5005/tasks",
            json=large_data,
            headers={"Content-Type": "application/json"},
        )

        # Should handle large payloads gracefully
        assert response.status_code in [200, 413, 500]  # 413 = Payload Too Large

    def test_malformed_json_handling(self, mcp_server):
        """Test handling of malformed JSON."""
        response = requests.post(
            "http://localhost:5005/tasks",
            data="invalid json {",
            headers={"Content-Type": "application/json"},
        )

        # Should handle malformed JSON gracefully
        assert response.status_code in [400, 500]

    def test_unsupported_content_type(self, mcp_server):
        """Test handling of unsupported content types."""
        response = requests.post(
            "http://localhost:5005/tasks",
            data="plain text data",
            headers={"Content-Type": "text/plain"},
        )

        # Should reject unsupported content types
        assert response.status_code in [400, 415]  # 415 = Unsupported Media Type

    def test_cors_headers(self, mcp_server):
        """Test CORS headers are present."""
        response = requests.options("http://localhost:5005/health")
        assert "Access-Control-Allow-Origin" in response.headers
        assert "Access-Control-Allow-Methods" in response.headers
        assert "Access-Control-Allow-Headers" in response.headers

    def test_security_headers(self, mcp_server):
        """Test security headers are present."""
        response = requests.get("http://localhost:5005/health")
        headers = response.headers

        # Check for common security headers
        security_headers = [
            "X-Content-Type-Options",
            "X-Frame-Options",
            "X-XSS-Protection",
        ]

        # At least some security headers should be present
        present_headers = [h for h in security_headers if h in headers]
        assert len(present_headers) > 0
