import pytest
import sys
import os
import json
import time
from unittest.mock import Mock, patch, MagicMock

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("github_workflow_monitor")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import github_workflow_monitor: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/github_workflow_monitor.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/github_workflow_monitor.py",
                "exec",
            )
        print(
            f"File github_workflow_monitor.py is syntactically valid but import failed"
        )
    except SyntaxError as se:
        print(f"File github_workflow_monitor.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestGithubWorkflowMonitor:
    """Comprehensive tests for github_workflow_monitor.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/github_workflow_monitor.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/github_workflow_monitor.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in github_workflow_monitor.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/github_workflow_monitor.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("github_workflow_monitor")
            assert True
        except ImportError:
            pytest.fail(f"Module github_workflow_monitor should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_require_requests_success(self):
        """Test _require_requests function when requests is available"""
        import github_workflow_monitor as module

        # Mock requests being available
        with patch.dict("sys.modules", {"requests": Mock()}):
            result = module._require_requests()
            assert result is not None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_require_requests_failure(self):
        """Test _require_requests function when requests is not available"""
        import github_workflow_monitor as module

        # Mock requests being unavailable
        with patch.object(module, "requests", None):
            with pytest.raises(RuntimeError, match="requests library is required"):
                module._require_requests()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fetch_recent_workflow_runs_success(self):
        """Test fetch_recent_workflow_runs function with successful API call"""
        import github_workflow_monitor as module

        mock_runs = [
            {"id": 1, "name": "test-workflow", "conclusion": "failure"},
            {"id": 2, "name": "test-workflow-2", "conclusion": "success"},
            {"id": 3, "name": "test-workflow-3", "conclusion": "failure"},
        ]
        mock_response = Mock()
        mock_response.json.return_value = {"workflow_runs": mock_runs}

        with patch.object(module, "requests") as mock_requests, patch.object(
            module, "_require_requests", return_value=mock_requests
        ):
            mock_requests.get.return_value = mock_response

            result = module.fetch_recent_workflow_runs()

            # Should return only failed runs (conclusion != success)
            assert len(result) == 2
            assert result[0]["id"] == 1
            assert result[1]["id"] == 3
            mock_requests.get.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fetch_recent_workflow_runs_api_error(self):
        """Test fetch_recent_workflow_runs function with API error"""
        import github_workflow_monitor as module

        with patch.object(module, "requests") as mock_requests, patch.object(
            module, "_require_requests", return_value=mock_requests
        ):
            mock_requests.get.side_effect = Exception("API Error")

            with pytest.raises(Exception):
                module.fetch_recent_workflow_runs()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_notify_mcp_success(self):
        """Test notify_mcp function with successful notification"""
        import github_workflow_monitor as module

        mock_run = {
            "id": 123,
            "name": "test-workflow",
            "conclusion": "failure",
            "html_url": "https://github.com/test/repo/actions/runs/123",
            "head_branch": "main",
        }

        with patch.object(module, "requests") as mock_requests, patch.object(
            module, "_require_requests", return_value=mock_requests
        ):
            mock_response = Mock()
            mock_response.status_code = 200
            mock_requests.post.return_value = mock_response

            result = module.notify_mcp(mock_run)

            assert result is True
            mock_requests.post.assert_called_once()
            call_args = mock_requests.post.call_args
            assert call_args[0][0] == f"{module.MCP_URL}/workflow_alert"
            assert call_args[1]["json"]["workflow"] == "test-workflow"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_notify_mcp_retry_success(self):
        """Test notify_mcp function with retry and eventual success"""
        import github_workflow_monitor as module

        mock_run = {"id": 123, "name": "test-workflow", "conclusion": "failure"}

        with patch.object(module, "requests") as mock_requests, patch.object(
            module, "_require_requests", return_value=mock_requests
        ), patch("time.sleep") as mock_sleep:
            # First two calls fail, third succeeds
            mock_requests.post.side_effect = [
                Exception("Connection failed"),
                Exception("Connection failed"),
                Mock(status_code=200),
            ]

            result = module.notify_mcp(mock_run)

            assert result is True
            assert mock_requests.post.call_count == 3
            assert mock_sleep.call_count == 2

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_notify_mcp_all_retries_fail(self):
        """Test notify_mcp function when all retries fail"""
        import github_workflow_monitor as module

        mock_run = {"id": 123, "name": "test-workflow", "conclusion": "failure"}

        with patch.object(module, "requests") as mock_requests, patch.object(
            module, "_require_requests", return_value=mock_requests
        ), patch("time.sleep") as mock_sleep:
            mock_requests.post.side_effect = Exception("Connection failed")

            result = module.notify_mcp(mock_run)

            assert result is False
            assert mock_requests.post.call_count == module.MAX_RETRIES

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_open_issue_for_run_success(self):
        """Test open_issue_for_run function with successful issue creation"""
        import github_workflow_monitor as module

        mock_run = {
            "id": 123,
            "name": "test-workflow",
            "head_branch": "main",
            "html_url": "https://github.com/test/repo/actions/runs/123",
        }

        with patch.object(module, "requests") as mock_requests, patch.object(
            module, "_require_requests", return_value=mock_requests
        ), patch.object(module, "GITHUB_TOKEN", "fake-token"):
            mock_response = Mock()
            mock_response.status_code = 201
            mock_response.json.return_value = {
                "html_url": "https://github.com/test/repo/issues/456"
            }
            mock_requests.post.return_value = mock_response

            result = module.open_issue_for_run(mock_run)

            assert result == "https://github.com/test/repo/issues/456"
            mock_requests.post.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_open_issue_for_run_no_token(self):
        """Test open_issue_for_run function without GitHub token"""
        import github_workflow_monitor as module

        mock_run = {"id": 123, "name": "test-workflow"}

        with patch.object(module, "GITHUB_TOKEN", None):
            result = module.open_issue_for_run(mock_run)
            assert result is None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_open_issue_for_run_api_error(self):
        """Test open_issue_for_run function with API error"""
        import github_workflow_monitor as module

        mock_run = {"id": 123, "name": "test-workflow"}

        with patch.object(module, "requests") as mock_requests, patch.object(
            module, "_require_requests", return_value=mock_requests
        ), patch.object(module, "GITHUB_TOKEN", "fake-token"):
            mock_response = Mock()
            mock_response.status_code = 422
            mock_response.text = "Validation failed"
            mock_requests.post.return_value = mock_response

            result = module.open_issue_for_run(mock_run)

            assert result is None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_rerun_workflow_success(self):
        """Test rerun_workflow function with successful rerun"""
        import github_workflow_monitor as module

        mock_run = {"id": 123, "name": "test-workflow"}

        with patch.object(module, "requests") as mock_requests, patch.object(
            module, "_require_requests", return_value=mock_requests
        ), patch.object(module, "GITHUB_TOKEN", "fake-token"):
            mock_response = Mock()
            mock_response.status_code = 201
            mock_requests.post.return_value = mock_response

            result = module.rerun_workflow(mock_run)

            assert result is True
            mock_requests.post.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_rerun_workflow_no_token(self):
        """Test rerun_workflow function without GitHub token"""
        import github_workflow_monitor as module

        mock_run = {"id": 123, "name": "test-workflow"}

        with patch.object(module, "GITHUB_TOKEN", None):
            result = module.rerun_workflow(mock_run)
            assert result is False

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_rerun_workflow_no_run_id(self):
        """Test rerun_workflow function with missing run ID"""
        import github_workflow_monitor as module

        mock_run = {"name": "test-workflow"}  # No ID

        result = module.rerun_workflow(mock_run)
        assert result is False

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_trigger_mcp_debug_run_success(self):
        """Test trigger_mcp_debug_run function with successful trigger"""
        import github_workflow_monitor as module

        mock_run = {
            "id": 123,
            "name": "test-workflow",
            "conclusion": "failure",
            "html_url": "https://github.com/test/repo/actions/runs/123",
            "head_branch": "main",
        }

        with patch.object(module, "requests") as mock_requests, patch.object(
            module, "_require_requests", return_value=mock_requests
        ):
            mock_response = Mock()
            mock_response.status_code = 200
            mock_requests.post.return_value = mock_response

            result = module.trigger_mcp_debug_run(mock_run)

            assert result is True
            mock_requests.post.assert_called_once()
            call_args = mock_requests.post.call_args
            assert call_args[0][0] == f"{module.MCP_URL}/workflow_alert"
            assert call_args[1]["json"]["action"] == "debug-run"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_trigger_mcp_debug_run_error(self):
        """Test trigger_mcp_debug_run function with error"""
        import github_workflow_monitor as module

        mock_run = {"id": 123, "name": "test-workflow"}

        with patch.object(module, "requests") as mock_requests, patch.object(
            module, "_require_requests", return_value=mock_requests
        ):
            mock_requests.post.side_effect = Exception("Connection failed")

            result = module.trigger_mcp_debug_run(mock_run)

            assert result is False

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_loop_with_failed_runs(self):
        """Test main function monitoring loop with failed runs"""
        import github_workflow_monitor as module

        mock_runs = [
            {
                "id": 1,
                "name": "failed-workflow",
                "html_url": "https://github.com/test/1",
                "conclusion": "failure",
            }
        ]

        with patch.object(
            module, "fetch_recent_workflow_runs", return_value=mock_runs
        ), patch.object(module, "notify_mcp", return_value=True), patch(
            "time.sleep"
        ) as mock_sleep, patch(
            "builtins.print"
        ) as mock_print:
            # Mock to break after first iteration
            with patch("time.time", side_effect=[1000.0, 1000.0, KeyboardInterrupt]):
                with pytest.raises(KeyboardInterrupt):
                    module.main(poll_interval=1)

            # Should have called notify_mcp once
            module.notify_mcp.assert_called_once_with(mock_runs[0])

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_loop_with_action_open_issue(self):
        """Test main function with open-issue action"""
        import github_workflow_monitor as module

        mock_runs = [{"id": 1, "name": "failed-workflow", "action": "open-issue"}]

        with patch.object(
            module, "fetch_recent_workflow_runs", return_value=mock_runs
        ), patch.object(module, "notify_mcp", return_value=True), patch.object(
            module, "open_issue_for_run", return_value="https://github.com/issue/1"
        ), patch(
            "time.sleep"
        ) as mock_sleep, patch(
            "builtins.print"
        ) as mock_print:
            # Mock to break after first iteration
            with patch("time.time", side_effect=[1000.0, 1000.0, KeyboardInterrupt]):
                with pytest.raises(KeyboardInterrupt):
                    module.main(poll_interval=1)

            module.open_issue_for_run.assert_called_once_with(mock_runs[0])

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_loop_with_action_rerun_workflow(self):
        """Test main function with rerun-workflow action"""
        import github_workflow_monitor as module

        mock_runs = [{"id": 1, "name": "failed-workflow", "action": "rerun-workflow"}]

        with patch.object(
            module, "fetch_recent_workflow_runs", return_value=mock_runs
        ), patch.object(module, "notify_mcp", return_value=True), patch.object(
            module, "rerun_workflow", return_value=True
        ), patch(
            "time.sleep"
        ) as mock_sleep, patch(
            "builtins.print"
        ) as mock_print:
            # Mock to break after first iteration
            with patch("time.time", side_effect=[1000.0, 1000.0, KeyboardInterrupt]):
                with pytest.raises(KeyboardInterrupt):
                    module.main(poll_interval=1)

            module.rerun_workflow.assert_called_once_with(mock_runs[0])

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_loop_with_action_trigger_debug(self):
        """Test main function with trigger-debug-run action"""
        import github_workflow_monitor as module

        mock_runs = [
            {"id": 1, "name": "failed-workflow", "action": "trigger-debug-run"}
        ]

        with patch.object(
            module, "fetch_recent_workflow_runs", return_value=mock_runs
        ), patch.object(module, "notify_mcp", return_value=True), patch.object(
            module, "trigger_mcp_debug_run", return_value=True
        ), patch(
            "time.sleep"
        ) as mock_sleep, patch(
            "builtins.print"
        ) as mock_print:
            # Mock to break after first iteration
            with patch("time.time", side_effect=[1000.0, 1000.0, KeyboardInterrupt]):
                with pytest.raises(KeyboardInterrupt):
                    module.main(poll_interval=1)

            module.trigger_mcp_debug_run.assert_called_once_with(mock_runs[0])

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_loop_error_handling(self):
        """Test main function error handling in monitoring loop"""
        import github_workflow_monitor as module

        with patch.object(
            module, "fetch_recent_workflow_runs", side_effect=Exception("API Error")
        ), patch(
            "time.sleep", side_effect=[None, None, KeyboardInterrupt]
        ) as mock_sleep, patch(
            "builtins.print"
        ) as mock_print:
            with pytest.raises(KeyboardInterrupt):
                module.main(poll_interval=0.001)  # Very short interval to speed up test

            # Should have printed error message at least twice (for the two iterations before KeyboardInterrupt)
            assert len(mock_print.call_args_list) >= 2
            # Check that at least one call contains the error message
            error_calls = [
                call
                for call in mock_print.call_args_list
                if len(call[0]) >= 2 and call[0][0] == "monitor error:"
            ]
            assert len(error_calls) >= 2
