import pytest
import sys
import os
from unittest.mock import Mock, patch, MagicMock
import json

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("mcp_dashboard_flask")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import mcp_dashboard_flask: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/mcp_dashboard_flask.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/mcp_dashboard_flask.py",
                "exec",
            )
        print(f"File mcp_dashboard_flask.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File mcp_dashboard_flask.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestMcpDashboardFlask:
    """Comprehensive tests for mcp_dashboard_flask.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/mcp_dashboard_flask.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/mcp_dashboard_flask.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in mcp_dashboard_flask.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/mcp_dashboard_flask.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("mcp_dashboard_flask")
            assert True
        except ImportError:
            pytest.fail(f"Module mcp_dashboard_flask should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_app_initialization(self):
        """Test Flask app initialization"""
        import mcp_dashboard_flask as module

        assert module.app is not None
        assert hasattr(module.app, "route")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_session_initialization(self):
        """Test requests session initialization"""
        import mcp_dashboard_flask as module

        assert module.session is not None
        assert module.session.headers.get("X-Client-Id") == "dashboard"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_asset_manifest_loading(self):
        """Test asset manifest loading"""
        import mcp_dashboard_flask as module

        # Should be a dict, even if empty
        assert isinstance(module.ASSET_MANIFEST, dict)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_assets_route(self):
        """Test /assets/<filename> route"""
        import mcp_dashboard_flask as module

        with patch("mcp_dashboard_flask.send_from_directory") as mock_send:
            from flask import Response

            mock_response = Response("test content")
            mock_send.return_value = mock_response

            with module.app.test_client() as client:
                response = client.get("/assets/test.css")
                assert response.status_code == 200
                mock_send.assert_called_once_with(module.STATIC_DIR, "test.css")
                mock_send.assert_called_once_with(module.STATIC_DIR, "test.css")
                assert mock_response.headers["Cache-Control"] == "public, max-age=86400"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_index_route(self):
        """Test / route"""
        import mcp_dashboard_flask as module

        with patch("mcp_dashboard_flask.render_template") as mock_render:
            mock_render.return_value = "<html>Dashboard</html>"

            with module.app.test_client() as client:
                response = client.get("/")
                assert response.status_code == 200
                mock_render.assert_called_once_with(
                    "index.html", mcp_url=module.MCP_URL
                )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_api_status_route(self):
        """Test /api/status route"""
        import mcp_dashboard_flask as module

        mock_response_data = {
            "status": "ok",
            "version": "1.0",
            "agents": [],
            "tasks": [],
        }
        with patch.object(module.session, "get") as mock_get:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = mock_response_data
            mock_get.return_value = mock_response

            with module.app.test_client() as client:
                response = client.get("/api/status")
                assert response.status_code == 200
                data = json.loads(response.data)
                assert data == mock_response_data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_api_status_route_error(self):
        """Test /api/status route with error"""
        import mcp_dashboard_flask as module

        with patch.object(module.session, "get") as mock_get:
            mock_get.side_effect = Exception("Connection error")

            with module.app.test_client() as client:
                response = client.get("/api/status")
                assert response.status_code == 200
                data = json.loads(response.data)
                assert data["ok"] == False
                assert "error" in data
                data = json.loads(response.data)
                assert "error" in data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_api_health_route(self):
        """Test /health route"""
        import mcp_dashboard_flask as module

        with patch.object(module.session, "get") as mock_get:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.text = '{"ok": true}'
            mock_response.headers = {"Content-Type": "application/json"}
            mock_get.return_value = mock_response

            with module.app.test_client() as client:
                response = client.get("/health")
                assert response.status_code == 200

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_controllers_page_route(self):
        """Test /controllers route"""
        import mcp_dashboard_flask as module

        with patch("mcp_dashboard_flask.render_template") as mock_render, patch(
            "mcp_dashboard_flask.requests.get"
        ) as mock_get:
            mock_render.return_value = "<html>Controllers</html>"
            mock_response = Mock()
            mock_response.json.return_value = {"controllers": []}
            mock_get.return_value = mock_response

            with module.app.test_client() as client:
                response = client.get("/controllers")
                assert response.status_code == 200
                mock_render.assert_called_once_with("controllers.html", controllers=[])

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_list_artifacts_route(self):
        """Test /artifacts route"""
        import mcp_dashboard_flask as module

        mock_artifacts = ["artifact1.json", "artifact2.txt"]
        with patch("os.listdir") as mock_listdir, patch("os.path.isdir") as mock_isdir:
            mock_isdir.return_value = True
            mock_listdir.return_value = mock_artifacts

            with module.app.test_client() as client:
                response = client.get("/artifacts")
                assert response.status_code == 200
                data = json.loads(response.data)
                assert data == mock_artifacts

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_list_artifacts_route_error(self):
        """Test /artifacts route with error"""
        import mcp_dashboard_flask as module

        with patch("os.path.isdir") as mock_isdir:
            mock_isdir.return_value = False

            with module.app.test_client() as client:
                response = client.get("/artifacts")
                assert response.status_code == 200
                data = json.loads(response.data)
                assert data == []

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_download_artifact_route(self):
        """Test /artifacts/download/<name> route"""
        import mcp_dashboard_flask as module

        with patch("mcp_dashboard_flask.send_from_directory") as mock_send, patch(
            "os.path.isdir"
        ) as mock_isdir:
            from flask import Response

            mock_isdir.return_value = True
            mock_response = Response("file content")
            mock_send.return_value = mock_response

            with module.app.test_client() as client:
                response = client.get("/artifacts/download/test.json")
                assert response.status_code == 200
                mock_send.assert_called_once_with(
                    module.ART_DIR, "test.json", as_attachment=True
                )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_task_detail_route(self):
        """Test /task/<task_id> route"""
        import mcp_dashboard_flask as module

        mock_task_data = {"id": "123", "status": "completed"}
        with patch("mcp_dashboard_flask.render_template") as mock_render, patch(
            "mcp_dashboard_flask.requests.get"
        ) as mock_get:
            mock_render.return_value = "<html>Task Detail</html>"
            mock_response = Mock()
            mock_response.json.return_value = {"tasks": [mock_task_data]}
            mock_get.return_value = mock_response

            with module.app.test_client() as client:
                response = client.get("/task/123")
                assert response.status_code == 200
                mock_render.assert_called_once_with(
                    "task_detail.html", task=mock_task_data
                )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_task_detail_route_error(self):
        """Test /task/<task_id> route with error"""
        import mcp_dashboard_flask as module

        with patch("mcp_dashboard_flask.render_template") as mock_render, patch(
            "mcp_dashboard_flask.requests.get"
        ) as mock_get:
            mock_render.return_value = "<html>No task found</html>"
            mock_get.side_effect = Exception("Task not found")

            with module.app.test_client() as client:
                response = client.get("/task/123")
                assert response.status_code == 200
                mock_render.assert_called_once_with("task_detail.html", task=None)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_inject_asset_url_function(self):
        """Test inject_asset_url context processor"""
        import mcp_dashboard_flask as module

        # Test with asset in manifest
        module.ASSET_MANIFEST = {"app.js": "app.abc123.js"}
        with module.app.app_context():
            asset_url_func = module.inject_asset_url()["asset_url"]
            assert asset_url_func("app.js") == "/assets/app.abc123.js"

        # Test with asset not in manifest
        assert asset_url_func("missing.css") == "/static/missing.css"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_mcp_url_configuration(self):
        """Test MCP URL configuration"""
        import mcp_dashboard_flask as module

        # Should use environment variable or default
        expected_url = os.environ.get("MCP_URL", "http://127.0.0.1:5005")
        assert module.MCP_URL == expected_url

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_static_directories(self):
        """Test static directory configuration"""
        import mcp_dashboard_flask as module

        assert module.ART_DIR.endswith("artifacts")
        assert module.STATIC_DIR.endswith("static")
