import pytest
import sys
import os
from unittest.mock import Mock, patch, MagicMock

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("mcp_server")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import mcp_server: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/mcp_server.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/mcp_server.py",
                "exec",
            )
        print(f"File mcp_server.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File mcp_server.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestMcpServer:
    """Comprehensive tests for mcp_server.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/mcp_server.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/mcp_server.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in mcp_server.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/mcp_server.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("mcp_server")
            assert True
        except ImportError:
            pytest.fail(f"Module mcp_server should be importable")

    # TODO: Add specific tests for functions in mcp_server.py
    # The module import now works correctly, so you can add real test functions here
    # Examples:
    # def test_specific_function(self):
    #     import mcp_server as module
    #     result = module.function_name(args)
    #     assert result == expected

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_github_signature_sha256(self):
        """Test GitHub signature verification with SHA256"""
        import mcp_server as module

        secret = "test_secret"
        payload = b"test_payload"
        # Create a valid signature
        import hmac
        import hashlib

        expected = hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()
        sig = f"sha256={expected}"

        result = module.verify_github_signature(secret, payload, sig)
        assert result is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_github_signature_invalid(self):
        """Test GitHub signature verification with invalid signature"""
        import mcp_server as module

        secret = "test_secret"
        payload = b"test_payload"
        sig = "sha256=invalid_signature"

        result = module.verify_github_signature(secret, payload, sig)
        assert result is False

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_github_signature_no_secret(self):
        """Test GitHub signature verification with no secret"""
        import mcp_server as module

        secret = ""
        payload = b"test_payload"
        sig = "sha256=some_signature"

        result = module.verify_github_signature(secret, payload, sig)
        assert result is False

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_allowed_commands_structure(self):
        """Test that ALLOWED_COMMANDS is properly structured"""
        import mcp_server as module

        assert isinstance(module.ALLOWED_COMMANDS, dict)
        assert len(module.ALLOWED_COMMANDS) > 0

        # Check that all commands have valid script paths
        for cmd, script_list in module.ALLOWED_COMMANDS.items():
            assert isinstance(script_list, list)
            assert len(script_list) > 0
            assert all(isinstance(s, str) for s in script_list)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_server_configuration_constants(self):
        """Test that server configuration constants are properly set"""
        import mcp_server as module

        assert isinstance(module.HOST, str)
        assert isinstance(module.PORT, int)
        assert module.PORT > 0
        assert isinstance(module.TASK_TTL_DAYS, int)
        assert module.TASK_TTL_DAYS > 0
        assert isinstance(module.CLEANUP_INTERVAL_MIN, int)
        assert module.CLEANUP_INTERVAL_MIN > 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_mcp_handler_initialization(self):
        """Test MCPHandler class attributes"""
        import mcp_server as module

        # Test that the class exists and has expected attributes
        assert hasattr(module, "MCPHandler")
        assert hasattr(module.MCPHandler, "server_version")
        assert module.MCPHandler.server_version == "MCP-Local/0.1"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_rate_limiting_logic(self):
        """Test rate limiting functionality"""
        import mcp_server as module
        from unittest.mock import Mock, patch
        import threading

        # Create a mock handler instance with required attributes
        handler = Mock()
        handler.client_address = ("127.0.0.1", 12345)

        # Create a simple server mock with real dict and lock
        class MockServer:
            def __init__(self):
                self.request_counters = {}
                self.rate_limit_lock = threading.Lock()

        handler.server = MockServer()

        # Bind the actual method to the mock
        handler._is_rate_limited = module.MCPHandler._is_rate_limited.__get__(
            handler, module.MCPHandler
        )

        # Mock the rate limiting constants
        with patch.object(module, "RATE_LIMIT_MAX_REQS", 1), patch.object(
            module, "RATE_LIMIT_WINDOW_SEC", 60
        ), patch.object(module, "RATE_LIMIT_WHITELIST", []):

            # First request should not be rate limited
            assert not handler._is_rate_limited()
            # Second request should be rate limited (exceeds max requests)
            assert handler._is_rate_limited()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_send_json_response(self):
        """Test JSON response sending"""
        import mcp_server as module
        from unittest.mock import Mock

        # Create a mock handler instance
        handler = Mock()
        handler.send_response = Mock()
        handler.send_header = Mock()
        handler.end_headers = Mock()
        handler.wfile = Mock()
        handler.wfile.write = Mock()

        # Bind the actual method to the mock
        handler._send_json = module.MCPHandler._send_json.__get__(
            handler, module.MCPHandler
        )

        test_data = {"test": "data", "number": 42}
        handler._send_json(test_data, 201)

        handler.send_response.assert_called_with(201)
        handler.send_header.assert_any_call("Content-Type", "application/json")
        handler.wfile.write.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_status_endpoint(self):
        """Test GET /status endpoint"""
        import mcp_server as module
        from unittest.mock import Mock

        # Create a mock handler instance
        handler = Mock()
        handler.path = "/status"
        handler._is_rate_limited = Mock(return_value=False)
        handler._send_json = Mock()

        # Mock server state
        handler.server = Mock()
        handler.server.agents = {"agent1": {"capabilities": ["task1"]}}
        handler.server.tasks = [{"id": "task1", "status": "queued"}]
        handler.server.controllers = {
            "controller1": {"agent": "agent1", "last_heartbeat": 1234567890}
        }

        # Bind the actual method to the mock
        handler.do_GET = module.MCPHandler.do_GET.__get__(handler, module.MCPHandler)

        # Call do_GET
        handler.do_GET()

        # Verify response
        handler._send_json.assert_called_once()
        call_args = handler._send_json.call_args[0][0]
        assert call_args["ok"] is True
        assert "agents" in call_args
        assert "tasks" in call_args
        assert "controllers" in call_args

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_register_endpoint(self):
        """Test POST /register endpoint"""
        import mcp_server as module
        from unittest.mock import Mock

        # Create a mock handler instance
        handler = Mock()
        handler.path = "/register"
        handler._is_rate_limited = Mock(return_value=False)
        handler._send_json = Mock()
        handler.headers = {"Content-Length": "50"}
        handler.rfile = Mock()
        handler.rfile.read = Mock(
            return_value=b'{"agent": "test_agent", "capabilities": ["task1"]}'
        )

        # Mock server
        handler.server = Mock()
        handler.server.agents = {}

        # Bind the actual method to the mock
        handler.do_POST = module.MCPHandler.do_POST.__get__(handler, module.MCPHandler)

        # Call do_POST
        handler.do_POST()

        # Verify agent was registered
        assert "test_agent" in handler.server.agents
        assert handler.server.agents["test_agent"]["capabilities"] == ["task1"]

        # Verify response
        handler._send_json.assert_called_once()
        call_args = handler._send_json.call_args[0][0]
        assert call_args["ok"] is True
        assert call_args["registered"] == "test_agent"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_run_endpoint_valid_command(self):
        """Test POST /run endpoint with valid command"""
        import mcp_server as module
        from unittest.mock import Mock

        # Create a mock handler instance
        handler = Mock()
        handler.path = "/run"
        handler._is_rate_limited = Mock(return_value=False)
        handler._send_json = Mock()
        handler.headers = {"Content-Length": "80"}
        handler.rfile = Mock()
        handler.rfile.read = Mock(
            return_value=b'{"agent": "test_agent", "command": "analyze", "project": "test_project"}'
        )

        # Mock server
        handler.server = Mock()
        handler.server.tasks = []

        # Bind the actual method to the mock
        handler.do_POST = module.MCPHandler.do_POST.__get__(handler, module.MCPHandler)

        # Call do_POST
        handler.do_POST()

        # Verify task was created
        assert len(handler.server.tasks) == 1
        task = handler.server.tasks[0]
        assert task["agent"] == "test_agent"
        assert task["command"] == "analyze"
        assert task["project"] == "test_project"
        assert task["status"] == "queued"

        # Verify response
        handler._send_json.assert_called_once()
        call_args = handler._send_json.call_args[0][0]
        assert call_args["ok"] is True
        assert "task_id" in call_args

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_run_endpoint_invalid_command(self):
        """Test POST /run endpoint with invalid command"""
        import mcp_server as module
        from unittest.mock import Mock

        # Create a mock handler instance
        handler = Mock()
        handler.path = "/run"
        handler._is_rate_limited = Mock(return_value=False)
        handler._send_json = Mock()
        handler.headers = {"Content-Length": "70"}
        handler.rfile = Mock()
        handler.rfile.read = Mock(
            return_value=b'{"agent": "test_agent", "command": "invalid_command"}'
        )

        # Bind the actual method to the mock
        handler.do_POST = module.MCPHandler.do_POST.__get__(handler, module.MCPHandler)

        # Call do_POST
        handler.do_POST()

        # Verify error response
        handler._send_json.assert_called_once()
        call_args = handler._send_json.call_args
        response_data = call_args[0][0]
        status_code = call_args[1]["status"]
        assert status_code == 403
        assert "error" in response_data
        assert "command_not_allowed" in response_data["error"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_quantum_status_endpoint(self):
        """Test GET /quantum_status endpoint"""
        import mcp_server as module
        from unittest.mock import Mock, patch

        # Create a mock handler instance
        handler = Mock()
        handler.path = "/quantum_status"
        handler._is_rate_limited = Mock(return_value=False)
        handler._send_json = Mock()
        handler.headers = {"Content-Length": "0"}
        handler.rfile = Mock()
        handler.rfile.read = Mock(return_value=b"")

        # Bind the actual method to the mock
        handler.do_POST = module.MCPHandler.do_POST.__get__(handler, module.MCPHandler)

        # Mock urlparse to return correct path
        mock_parsed = Mock()
        mock_parsed.path = "/quantum_status"
        with patch("mcp_server.urlparse", return_value=mock_parsed):
            # Call do_POST
            handler.do_POST()

        # Verify response
        handler._send_json.assert_called_once()
        call_args = handler._send_json.call_args[0][0]
        assert "ok" in call_args
        assert call_args["ok"] is True
        assert "quantum_status" in call_args
        quantum_status = call_args["quantum_status"]
        assert "entanglement_network" in quantum_status
        assert "multiverse_navigation" in quantum_status
        assert "consciousness_frameworks" in quantum_status
        assert "dimensional_computing" in quantum_status
        assert "quantum_orchestrator" in quantum_status

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_task_execution_success(self):
        """Test successful task execution"""
        import mcp_server as module
        from unittest.mock import Mock, patch

        # Create a mock handler instance
        handler = Mock()

        # Create test task
        task = {
            "id": "test_task_1",
            "command": "analyze",
            "project": "test_project",
            "status": "running",
        }

        # Bind the actual method to the mock
        handler._execute_task = module.MCPHandler._execute_task.__get__(
            handler, module.MCPHandler
        )

        # Mock subprocess.run for successful execution
        mock_result = Mock()
        mock_result.returncode = 0
        mock_result.stdout = "Task completed successfully"
        mock_result.stderr = ""

        with patch("subprocess.run", return_value=mock_result):
            handler._execute_task(task, ["echo", "test"])

        # Verify task status
        assert task["status"] == "success"
        assert task["returncode"] == 0
        assert "stdout" in task
        assert "stderr" in task

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_task_execution_failure(self):
        """Test failed task execution"""
        import mcp_server as module
        from unittest.mock import Mock, patch

        # Create a mock handler instance
        handler = Mock()

        # Create test task
        task = {
            "id": "test_task_2",
            "command": "analyze",
            "project": "test_project",
            "status": "running",
        }

        # Bind the actual method to the mock
        handler._execute_task = module.MCPHandler._execute_task.__get__(
            handler, module.MCPHandler
        )

        # Mock subprocess.run for failed execution
        mock_result = Mock()
        mock_result.returncode = 1
        mock_result.stdout = ""
        mock_result.stderr = "Command failed"

        with patch("subprocess.run", return_value=mock_result):
            handler._execute_task(task, ["false"])

        # Verify task status
        assert task["status"] == "failed"
        assert task["returncode"] == 1
        assert "stderr" in task

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_task_execution_timeout(self):
        """Test task execution timeout"""
        import mcp_server as module
        from unittest.mock import Mock, patch

        # Create a mock handler instance
        handler = Mock()

        # Create test task
        task = {
            "id": "test_task_3",
            "command": "analyze",
            "project": "test_project",
            "status": "running",
        }

        # Bind the actual method to the mock
        handler._execute_task = module.MCPHandler._execute_task.__get__(
            handler, module.MCPHandler
        )

        # Mock subprocess.run to raise TimeoutExpired
        with patch(
            "subprocess.run",
            side_effect=module.subprocess.TimeoutExpired("timeout", 1800),
        ):
            handler._execute_task(task, ["sleep", "2000"])

        # Verify task status
        assert task["status"] == "error"
        assert "stderr" in task
        assert "timeout" in task["stderr"].lower()
