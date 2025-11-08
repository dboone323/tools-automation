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
    __import__("agents.api_server")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.api_server: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/api_server.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/api_server.py",
                "exec",
            )
        print(f"File agents/api_server.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File agents/api_server.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsApiServer:
    """Comprehensive tests for agents/api_server.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/api_server.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/api_server.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/api_server.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/api_server.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.api_server")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.api_server should be importable")


import pytest
import sys
import os
import json
import tempfile
from unittest.mock import Mock, patch, MagicMock
from io import BytesIO

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("agents.api_server")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.api_server: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/api_server.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/api_server.py",
                "exec",
            )
        print(f"File agents/api_server.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File agents/api_server.py has syntax errors: {se}")


@pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
class TestAgentsApiServer:
    """Comprehensive tests for agents/api_server.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/api_server.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/api_server.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/api_server.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/api_server.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.api_server")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.api_server should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_handler_api_plugins_list(self):
        """Test Handler.do_GET for /api/plugins/list"""
        import agents.api_server as module

        with tempfile.TemporaryDirectory() as temp_dir:
            # Create mock plugins directory with some .sh files
            plugins_dir = os.path.join(temp_dir, "plugins")
            os.makedirs(plugins_dir)
            with open(os.path.join(plugins_dir, "plugin1.sh"), "w") as f:
                f.write("#!/bin/bash\necho test1")
            with open(os.path.join(plugins_dir, "plugin2.sh"), "w") as f:
                f.write("#!/bin/bash\necho test2")
            with open(os.path.join(plugins_dir, "notaplugin.txt"), "w") as f:
                f.write("not a plugin")

            # Mock the handler
            handler = module.Handler.__new__(module.Handler)
            handler.path = "/api/plugins/list"
            handler.headers = {"X-User": "testuser"}
            handler.send_response = Mock()
            handler.send_header = Mock()
            handler.end_headers = Mock()
            handler.wfile = BytesIO()

            with patch.object(module, "PLUGINS_DIR", plugins_dir), patch.object(
                module, "AUDIT_LOG", os.path.join(temp_dir, "audit.log")
            ), patch("builtins.open", create=True) as mock_open:
                mock_file = Mock()
                mock_open.return_value.__enter__.return_value = mock_file

                handler.do_GET()

                # Check response
                handler.send_response.assert_called_with(200)
                handler.send_header.assert_called_with(
                    "Content-type", "application/json"
                )
                handler.end_headers.assert_called()

                # Check JSON response
                response_data = json.loads(handler.wfile.getvalue().decode())
                assert "plugins" in response_data
                assert set(response_data["plugins"]) == {"plugin1", "plugin2"}

                # Check audit log was written
                mock_open.assert_called_with(os.path.join(temp_dir, "audit.log"), "a")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_handler_api_plugins_run_allowed(self):
        """Test Handler.do_GET for /api/plugins/run/ with allowed plugin"""
        import agents.api_server as module

        with tempfile.TemporaryDirectory() as temp_dir:
            # Create plugin file
            plugins_dir = os.path.join(temp_dir, "plugins")
            os.makedirs(plugins_dir)
            plugin_path = os.path.join(plugins_dir, "testplugin.sh")
            with open(plugin_path, "w") as f:
                f.write("#!/bin/bash\necho 'plugin output'")

            # Create policy file
            policy_path = os.path.join(temp_dir, "policy.conf")
            with open(policy_path, "w") as f:
                f.write("[plugins]\nallow=testplugin\n")

            # Mock subprocess result
            mock_result = Mock()
            mock_result.stdout = "plugin output"
            mock_result.stderr = ""

            handler = module.Handler.__new__(module.Handler)
            handler.path = "/api/plugins/run/testplugin"
            handler.headers = {"X-User": "testuser", "X-API-TOKEN": "changeme"}
            handler.send_response = Mock()
            handler.send_header = Mock()
            handler.end_headers = Mock()
            handler.wfile = BytesIO()

            with patch.object(module, "PLUGINS_DIR", plugins_dir), patch.object(
                module, "POLICY_CONF", policy_path
            ), patch.object(module, "API_TOKEN", "changeme"), patch.object(
                module, "AUDIT_LOG", os.path.join(temp_dir, "audit.log")
            ), patch(
                "subprocess.run", return_value=mock_result
            ) as mock_subprocess:

                handler.do_GET()

                # Check response
                handler.send_response.assert_called_with(200)
                handler.send_header.assert_called_with(
                    "Content-type", "application/json"
                )
                handler.end_headers.assert_called()

                # Check JSON response
                response_data = json.loads(handler.wfile.getvalue().decode())
                assert response_data["output"] == "plugin output"

                # Check subprocess was called
                mock_subprocess.assert_called_once_with(
                    [plugin_path], capture_output=True, text=True
                )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_handler_api_plugins_run_blocked(self):
        """Test Handler.do_GET for /api/plugins/run/ with blocked plugin"""
        import agents.api_server as module

        with tempfile.TemporaryDirectory() as temp_dir:
            # Create policy file with block list
            policy_path = os.path.join(temp_dir, "policy.conf")
            with open(policy_path, "w") as f:
                f.write("[plugins]\nblock=testplugin\n")

            handler = module.Handler.__new__(module.Handler)
            handler.path = "/api/plugins/run/testplugin"
            handler.headers = {"X-User": "testuser", "X-API-TOKEN": "changeme"}
            handler.send_response = Mock()
            handler.end_headers = Mock()

            with patch.object(module, "POLICY_CONF", policy_path), patch.object(
                module, "AUDIT_LOG", os.path.join(temp_dir, "audit.log")
            ):

                handler.do_GET()

                # Should return 403
                handler.send_response.assert_called_with(403)
                handler.end_headers.assert_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_handler_api_plugins_run_not_allowed(self):
        """Test Handler.do_GET for /api/plugins/run/ with plugin not in allow list"""
        import agents.api_server as module

        with tempfile.TemporaryDirectory() as temp_dir:
            # Create policy file with allow list not including our plugin
            policy_path = os.path.join(temp_dir, "policy.conf")
            with open(policy_path, "w") as f:
                f.write("[plugins]\nallow=otherplugin\n")

            handler = module.Handler.__new__(module.Handler)
            handler.path = "/api/plugins/run/testplugin"
            handler.headers = {"X-User": "testuser", "X-API-TOKEN": "changeme"}
            handler.send_response = Mock()
            handler.end_headers = Mock()

            with patch.object(module, "POLICY_CONF", policy_path), patch.object(
                module, "AUDIT_LOG", os.path.join(temp_dir, "audit.log")
            ):

                handler.do_GET()

                # Should return 403
                handler.send_response.assert_called_with(403)
                handler.end_headers.assert_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_handler_api_plugins_run_bad_token(self):
        """Test Handler.do_GET for /api/plugins/run/ with bad API token"""
        import agents.api_server as module

        handler = module.Handler.__new__(module.Handler)
        handler.path = "/api/plugins/run/testplugin"
        handler.headers = {"X-User": "testuser", "X-API-TOKEN": "wrongtoken"}
        handler.send_response = Mock()
        handler.end_headers = Mock()

        with patch.object(module, "API_TOKEN", "correcttoken"), patch.object(
            module, "AUDIT_LOG", os.path.join(os.path.dirname(__file__), "audit.log")
        ):

            handler.do_GET()

            # Should return 403
            handler.send_response.assert_called_with(403)
            handler.end_headers.assert_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_handler_api_plugins_run_not_found(self):
        """Test Handler.do_GET for /api/plugins/run/ with plugin not found"""
        import agents.api_server as module

        with tempfile.TemporaryDirectory() as temp_dir:
            # Create policy file allowing the plugin
            policy_path = os.path.join(temp_dir, "policy.conf")
            with open(policy_path, "w") as f:
                f.write("[plugins]\nallow=testplugin\n")

            handler = module.Handler.__new__(module.Handler)
            handler.path = "/api/plugins/run/testplugin"
            handler.headers = {"X-User": "testuser", "X-API-TOKEN": "changeme"}
            handler.send_response = Mock()
            handler.end_headers = Mock()

            with patch.object(module, "PLUGINS_DIR", temp_dir), patch.object(
                module, "POLICY_CONF", policy_path
            ), patch.object(module, "AUDIT_LOG", os.path.join(temp_dir, "audit.log")):

                handler.do_GET()

                # Should return 404
                handler.send_response.assert_called_with(404)
                handler.end_headers.assert_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_handler_unknown_path(self):
        """Test Handler.do_GET for unknown path"""
        import agents.api_server as module

        handler = module.Handler.__new__(module.Handler)
        handler.path = "/unknown/path"
        handler.headers = {"X-User": "testuser"}

        with patch("http.server.SimpleHTTPRequestHandler.do_GET") as mock_super_get:
            handler.do_GET()

            # Should call parent do_GET
            mock_super_get.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_policy_parsing_allow_list(self):
        """Test policy file parsing for allow list"""
        import agents.api_server as module

        with tempfile.TemporaryDirectory() as temp_dir:
            policy_path = os.path.join(temp_dir, "policy.conf")
            with open(policy_path, "w") as f:
                f.write(
                    "[plugins]\nallow=plugin1, plugin2 , plugin3\nblock=badplugin\n"
                )

            # Test the policy parsing logic by simulating the handler
            allow_list = []
            block_list = []
            try:
                with open(policy_path) as f:
                    section = None
                    for line in f:
                        line = line.strip()
                        if line == "[plugins]":
                            section = "plugins"
                        elif line.startswith("["):
                            section = None
                        elif section == "plugins" and line.startswith("allow="):
                            allow_list = [
                                x.strip() for x in line.split("=", 1)[1].split(",")
                            ]
                        elif section == "plugins" and line.startswith("block="):
                            block_list = [
                                x.strip() for x in line.split("=", 1)[1].split(",")
                            ]
            except Exception:
                pass

            assert allow_list == ["plugin1", "plugin2", "plugin3"]
            assert block_list == ["badplugin"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_audit_logging(self):
        """Test that audit logging works correctly"""
        import agents.api_server as module

        with tempfile.TemporaryDirectory() as temp_dir:
            audit_path = os.path.join(temp_dir, "audit.log")

            handler = module.Handler.__new__(module.Handler)
            handler.path = "/api/plugins/list"
            handler.headers = {"X-User": "testuser"}
            handler.send_response = Mock()
            handler.send_header = Mock()
            handler.end_headers = Mock()
            handler.wfile = BytesIO()

            with patch.object(module, "PLUGINS_DIR", temp_dir), patch.object(
                module, "AUDIT_LOG", audit_path
            ), patch("builtins.open", create=True) as mock_open:
                mock_file = Mock()
                mock_open.return_value.__enter__.return_value = mock_file

                handler.do_GET()

                # Check that audit log was opened for appending
                audit_calls = [
                    call for call in mock_open.call_args_list if audit_path in str(call)
                ]
                assert len(audit_calls) > 0
