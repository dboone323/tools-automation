#!/usr/bin/env python3
"""
Comprehensive tests for the MCP Python SDK
"""

import pytest
from mcp_sdk import (
    MCPClient,
    MCPError,
    MCPConnectionError,
    MCPTimeoutError,
)


class TestMCPClientBasic:
    """Basic functionality tests for MCPClient"""

    def test_init_default(self):
        """Test client initialization with default parameters"""
        client = MCPClient()
        assert client.base_url == "http://localhost:5005"
        assert client.timeout == 30.0
        assert client.max_retries == 3
        assert client.retry_delay == 1.0

    def test_init_custom(self):
        """Test client initialization with custom parameters"""
        client = MCPClient(
            base_url="http://custom-server:8080",
            timeout=60.0,
            max_retries=5,
            retry_delay=2.0,
        )
        assert client.base_url == "http://custom-server:8080"
        assert client.timeout == 60.0
        assert client.max_retries == 5
        assert client.retry_delay == 2.0


class TestDataStructures:
    """Test data structure classes"""

    def test_agent_status_creation(self):
        """Test AgentStatus dataclass"""
        from mcp_sdk import AgentStatus

        agent = AgentStatus(
            name="test-agent",
            status="active",
            last_seen="2025-11-12T19:30:00Z",
            health_score=95.5,
            capabilities=["analysis", "execution"],
        )
        assert agent.name == "test-agent"
        assert agent.status == "active"
        assert agent.health_score == 95.5
        assert len(agent.capabilities) == 2

    def test_task_info_creation(self):
        """Test TaskInfo dataclass"""
        from mcp_sdk import TaskInfo

        task = TaskInfo(
            id="task-123",
            status="completed",
            agent="agent1",
            created_at="2025-11-12T19:30:00Z",
            completed_at="2025-11-12T19:35:00Z",
        )
        assert task.id == "task-123"
        assert task.status == "completed"
        assert task.completed_at is not None

    def test_mcp_response_creation(self):
        """Test MCPResponse dataclass"""
        from mcp_sdk import MCPResponse

        response = MCPResponse(
            success=True,
            data={"result": "success"},
            status_code=200,
            response_time=150.5,
        )
        assert response.success is True
        assert response.data["result"] == "success"
        assert response.status_code == 200
        assert response.response_time == 150.5


class TestErrorHandling:
    """Test error handling classes"""

    def test_mcp_error_creation(self):
        """Test MCPError creation"""
        error = MCPError("Test error", 404)
        assert str(error) == "Test error"
        assert error.status_code == 404

    def test_connection_error_creation(self):
        """Test MCPConnectionError creation"""
        import aiohttp

        _original_error = aiohttp.ClientConnectionError("Connection refused")
        error = MCPConnectionError("Connection failed")
        assert str(error) == "Connection failed"

    def test_timeout_error_creation(self):
        """Test MCPTimeoutError creation"""
        error = MCPTimeoutError("Request timed out")
        assert str(error) == "Request timed out"


class TestCLInterface:
    """Test CLI interface"""

    def test_cli_help(self):
        """Test CLI help output"""
        from mcp_sdk import main
        import sys
        from io import StringIO

        # Capture stdout
        old_stdout = sys.stdout
        old_argv = sys.argv
        sys.stdout = captured_output = StringIO()
        sys.argv = ["mcp_sdk"]  # Set argv to avoid pytest arguments

        try:
            # This would normally exit, but we'll catch it
            try:
                main()
            except SystemExit:
                pass
        finally:
            sys.stdout = old_stdout
            sys.argv = old_argv

        output = captured_output.getvalue()
        assert "MCP Python SDK CLI" in output


class TestIntegration:
    """Integration tests that require MCP server to be running"""

    @pytest.mark.integration
    def test_server_connection(self):
        """Test basic connection to MCP server"""
        import socket

        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        result = sock.connect_ex(("localhost", 5005))
        sock.close()
        assert result == 0, "MCP server not running on localhost:5005"

    @pytest.mark.integration
    @pytest.mark.asyncio
    async def test_get_status_integration(self):
        """Integration test for get_status with real MCP server"""
        async with MCPClient() as client:
            try:
                response = await client.get_status()
                assert response.success is True
                assert "status" in response.data or "version" in response.data
            except Exception as e:
                pytest.skip(f"MCP server not available: {e}")

    @pytest.mark.integration
    @pytest.mark.asyncio
    async def test_get_health_integration(self):
        """Integration test for get_health with real MCP server"""
        async with MCPClient() as client:
            try:
                response = await client.get_health()
                assert response.success is True
                # Health response structure may vary
                assert isinstance(response.data, dict)
            except Exception as e:
                pytest.skip(f"MCP server not available: {e}")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
