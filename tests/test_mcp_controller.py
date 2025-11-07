import pytest
import sys
import os
import tempfile
import time
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock, mock_open

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import mcp_controller


class TestMcpController:
    """Comprehensive tests for mcp_controller.py"""

    @patch("mcp_controller.requests.Session")
    @patch("mcp_controller.time.sleep")
    def test_register_success(self, mock_sleep, mock_session_class):
        """Test successful registration with MCP server"""
        mock_session = Mock()
        mock_session_class.return_value = mock_session
        mock_response = Mock()
        mock_response.status_code = 200
        mock_session.post.return_value = mock_response

        with patch.dict(os.environ, {"PROJECT_NAME": "test_project"}):
            result = mcp_controller.register()
            assert result is True
            mock_session.post.assert_called_once_with(
                "http://127.0.0.1:5005/register",
                json={"agent": "controller-agent", "capabilities": ["controller"]},
                timeout=5,
            )

    @patch("mcp_controller.requests.Session")
    @patch("mcp_controller.time.sleep")
    def test_register_failure_retries(self, mock_sleep, mock_session_class):
        """Test registration failure with retries"""
        mock_session = Mock()
        mock_session_class.return_value = mock_session
        mock_session.post.side_effect = Exception("Connection failed")

        result = mcp_controller.register()
        assert result is False
        assert mock_session.post.call_count == 6  # 6 attempts

    @patch("mcp_controller._session")
    def test_send_heartbeat_success(self, mock_session):
        """Test successful heartbeat send"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_session.post.return_value = mock_response

        mcp_controller.send_heartbeat("test_project")
        mock_session.post.assert_called_once_with(
            "http://127.0.0.1:5005/heartbeat",
            json={"agent": "controller-agent", "project": "test_project"},
            timeout=4,
        )

    @patch("mcp_controller._session")
    def test_send_heartbeat_failure(self, mock_session):
        """Test heartbeat failure (should not raise)"""
        mock_session.post.side_effect = Exception("Network error")

        # Should not raise exception
        mcp_controller.send_heartbeat()

    @patch("mcp_controller._session")
    @patch("mcp_controller.time.sleep")
    def test_poll_tasks_success(self, mock_sleep, mock_session):
        """Test successful task polling"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "tasks": [{"id": "task1", "status": "queued"}]
        }
        mock_session.get.return_value = mock_response

        tasks = mcp_controller.poll_tasks()
        assert tasks == [{"id": "task1", "status": "queued"}]
        mock_session.get.assert_called_once_with(
            "http://127.0.0.1:5005/status", timeout=6
        )

    @patch("mcp_controller._session")
    @patch("mcp_controller.time.sleep")
    def test_poll_tasks_failure_retries(self, mock_sleep, mock_session):
        """Test task polling with failures and retries"""
        mock_session.get.side_effect = Exception("Connection failed")

        tasks = mcp_controller.poll_tasks()
        assert tasks == []
        assert mock_session.get.call_count == 3  # 3 attempts

    @patch("mcp_controller.requests.post")
    @patch("mcp_controller.requests.get")
    @patch("mcp_controller.save_artifacts")
    @patch("mcp_controller.upload_artifacts")
    @patch("mcp_controller.time.sleep")
    @patch("mcp_controller.lock")
    def test_execute_task_success(
        self, mock_lock, mock_sleep, mock_upload, mock_save, mock_get, mock_post
    ):
        """Test successful task execution"""
        mock_lock.__enter__ = Mock()
        mock_lock.__exit__ = Mock()

        # Mock execute_task POST
        mock_exec_response = Mock()
        mock_exec_response.status_code = 200
        mock_post.return_value = mock_exec_response

        # Mock status GET
        mock_status_response = Mock()
        mock_status_response.json.return_value = {
            "tasks": [
                {
                    "id": "task1",
                    "status": "success",
                    "stdout": "output",
                    "stderr": "error",
                }
            ]
        }
        mock_get.return_value = mock_status_response

        task = {"id": "task1", "project": "test_proj"}

        with patch("mcp_controller.running_projects", set()):
            result = mcp_controller.execute_task(task)
            assert result is True
            mock_save.assert_called_once()
            mock_upload.assert_called_once()

    @patch("mcp_controller.lock")
    def test_execute_task_already_running(self, mock_lock):
        """Test task execution when project already running"""
        mock_lock.__enter__ = Mock()
        mock_lock.__exit__ = Mock()

        task = {"id": "task1", "project": "test_proj"}

        with patch("mcp_controller.running_projects", {"test_proj"}):
            result = mcp_controller.execute_task(task)
            assert result is False

    @patch("mcp_controller.Path")
    @patch("mcp_controller.time.time", return_value=1234567890)
    def test_save_artifacts(self, mock_time, mock_path_class):
        """Test artifact saving"""
        mock_path_instance = Mock()
        mock_base = Mock()
        mock_stdout = Mock()
        mock_stderr = Mock()

        mock_path_instance.__truediv__ = Mock(return_value=mock_base)
        mock_base.__truediv__ = Mock(side_effect=[mock_stdout, mock_stderr])
        mock_base.mkdir = Mock()

        mock_path_class.return_value = mock_path_instance

        task = {
            "id": "task1",
            "project": "test_proj",
            "stdout": "test output",
            "stderr": "test error",
        }

        mcp_controller.save_artifacts(task)
        mock_stdout.write_text.assert_called_with("test output")
        mock_stderr.write_text.assert_called_with("test error")

    @patch("mcp_controller.Path")
    @patch("mcp_controller.os.access", return_value=True)
    @patch("mcp_controller.threading.Thread")
    @patch("mcp_controller.requests.get")
    def test_upload_artifacts_uploader_exists(
        self, mock_get, mock_thread, mock_access, mock_path_class
    ):
        """Test artifact upload when uploader script exists"""
        mock_uploader = Mock()
        mock_uploader.exists.return_value = True
        mock_parent = Mock()
        mock_parent.__truediv__ = Mock(return_value=mock_uploader)
        mock_path_instance = Mock()
        mock_path_instance.parent = mock_parent
        mock_base = Mock()
        mock_base.__truediv__ = Mock(return_value=Mock())
        mock_path_class.side_effect = lambda path: (
            mock_path_instance if path == mcp_controller.__file__ else mock_base
        )

        task = {"id": "task1", "project": "test_proj"}

        mcp_controller.upload_artifacts(task)
        mock_thread.assert_called_once()

    @patch("mcp_controller.Path")
    @patch("mcp_controller.os.access", return_value=False)
    def test_upload_artifacts_no_uploader(self, mock_access, mock_path_class):
        """Test artifact upload when uploader script doesn't exist"""
        mock_uploader = Mock()
        mock_uploader.exists.return_value = False
        mock_parent = Mock()
        mock_parent.__truediv__ = Mock(return_value=mock_uploader)
        mock_path_instance = Mock()
        mock_path_instance.parent = mock_parent
        mock_base = Mock()
        mock_base.__truediv__ = Mock(return_value=Mock())
        mock_path_class.side_effect = lambda path: (
            mock_path_instance if path == mcp_controller.__file__ else mock_base
        )

        task = {"id": "task1", "project": "test_proj"}

        # Should not raise exception
        mcp_controller.upload_artifacts(task)

    @patch("mcp_controller.register")
    @patch("mcp_controller.threading.Thread")
    @patch("mcp_controller.poll_tasks")
    @patch("mcp_controller.time.sleep")
    @patch("mcp_controller.execute_task")
    def test_main_loop(
        self, mock_execute, mock_sleep, mock_poll, mock_thread_class, mock_register
    ):
        """Test main function execution loop"""
        mock_register.return_value = True
        mock_poll.return_value = [{"id": "task1", "status": "queued"}]

        # Mock KeyboardInterrupt after first iteration
        mock_sleep.side_effect = KeyboardInterrupt()

        mcp_controller.main()  # Should catch KeyboardInterrupt and return

        mock_register.assert_called_once()
        mock_poll.assert_called_once()

    @patch("mcp_controller._safe_request")
    def test_safe_request_success(self, mock_safe_request):
        """Test _safe_request with successful call"""
        mock_response = Mock()
        mock_safe_request.return_value = mock_response

        result = mcp_controller._safe_request(
            Mock(), "http://test.com", headers={"test": "header"}
        )
        assert result == mock_response

    def test_safe_request_retry_without_headers(self):
        """Test _safe_request retry without headers on TypeError"""
        mock_func = Mock()
        mock_response = Mock()
        mock_func.side_effect = [TypeError(), mock_response]

        result = mcp_controller._safe_request(
            mock_func, "http://test.com", headers={"test": "header"}
        )
        assert result == mock_response
        assert mock_func.call_count == 2
        # First call with headers, second without
        mock_func.assert_any_call("http://test.com", headers={"test": "header"})
        mock_func.assert_any_call("http://test.com")
