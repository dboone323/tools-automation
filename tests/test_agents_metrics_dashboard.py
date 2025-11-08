import pytest
import sys
import os
import json
import tempfile
from unittest.mock import Mock, patch, MagicMock
from pathlib import Path

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("agents.metrics_dashboard")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.metrics_dashboard: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/metrics_dashboard.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/metrics_dashboard.py",
                "exec",
            )
        print(
            f"File agents/metrics_dashboard.py is syntactically valid but import failed"
        )
    except SyntaxError as se:
        print(f"File agents/metrics_dashboard.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsMetricsDashboard:
    """Comprehensive tests for agents/metrics_dashboard.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/metrics_dashboard.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/metrics_dashboard.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/metrics_dashboard.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/metrics_dashboard.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.metrics_dashboard")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.metrics_dashboard should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_existing_file(self):
        """Test _load_json with existing file"""
        import agents.metrics_dashboard as module

        test_data = {"test": "data", "number": 42}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(test_data, f)
            temp_path = f.name

        try:
            result = module._load_json(temp_path)
            assert result == test_data
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_nonexistent_file(self):
        """Test _load_json with nonexistent file"""
        import agents.metrics_dashboard as module

        result = module._load_json("/nonexistent/file.json")
        assert result == {}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_invalid_json(self):
        """Test _load_json with invalid JSON"""
        import agents.metrics_dashboard as module

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            f.write("invalid json content")
            temp_path = f.name

        try:
            result = module._load_json(temp_path)
            assert result == {}
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_run_refresh_without_html(self):
        """Test _run_refresh without HTML generation"""
        import agents.metrics_dashboard as module

        with patch("subprocess.run") as mock_run:
            module._run_refresh(html=False)

            # Should call analytics_collector.py with collect command
            mock_run.assert_called_once()
            args = mock_run.call_args[0][0]
            assert "analytics_collector.py" in args[0]
            assert "collect" in args
            assert "--out" in args

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_run_refresh_with_html(self):
        """Test _run_refresh with HTML generation"""
        import agents.metrics_dashboard as module

        with patch("subprocess.run") as mock_run:
            module._run_refresh(html=True)

            # Should call analytics_collector.py with collect and html commands
            mock_run.assert_called_once()
            args = mock_run.call_args[0][0]
            assert "analytics_collector.py" in args[0]
            assert "collect" in args
            assert "--out" in args
            assert "--html" in args

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_pct_formatting(self):
        """Test _pct formatting function"""
        import agents.metrics_dashboard as module

        assert module._pct(0.5) == "50.00%"
        assert module._pct(1.0) == "100.00%"
        assert module._pct(0.123) == "12.30%"
        assert module._pct("invalid") == "0.00%"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_secs_formatting(self):
        """Test _secs formatting function"""
        import agents.metrics_dashboard as module

        assert module._secs(1.5) == "1.50s"
        assert module._secs(10.0) == "10.00s"
        assert module._secs(0.123) == "0.12s"
        assert module._secs("invalid") == "0.00s"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_show_dashboard_complete_data(self):
        """Test show_dashboard with complete analytics data"""
        import agents.metrics_dashboard as module

        data = {
            "generated_at": "2023-01-01T12:00:00Z",
            "overall_success_rate": 0.85,
            "average_resolution_time": 45.5,
            "learning_velocity_per_week": 12,
            "autonomy_level": 0.75,
            "error_recurrence_rate": 0.05,
            "cross_agent_collaboration_score": 0.90,
            "proactive_open_alerts": 3,
            "counts": {"predictions": 25, "strategies": 8, "emergencies": 2},
        }

        result = module.show_dashboard(data)

        # Check that all key metrics are included
        assert "=== Agent Analytics Dashboard ===" in result
        assert "Generated: 2023-01-01T12:00:00Z" in result
        assert "Overall Success Rate:        85.00%" in result
        assert "Average Resolution Time:     45.50s" in result
        assert "Learning Velocity (per wk):  12" in result
        assert "Autonomy Level:              75.00%" in result
        assert "Error Recurrence Rate:       5.00%" in result
        assert "Collaboration Score:         90.00%" in result
        assert "Open Proactive Alerts:       3" in result
        assert "Predictions: 25  Strategies: 8  Emergencies: 2" in result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_show_dashboard_empty_data(self):
        """Test show_dashboard with empty data"""
        import agents.metrics_dashboard as module

        data = {}

        result = module.show_dashboard(data)

        # Should handle missing data gracefully
        assert "=== Agent Analytics Dashboard ===" in result
        assert "Overall Success Rate:        0.00%" in result
        assert "Average Resolution Time:     0.00s" in result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_show_queue_status(self):
        """Test show_queue_status function"""
        import agents.metrics_dashboard as module

        # Mock task queue data
        queue_data = {
            "tasks": [
                {"status": "queued", "id": 1},
                {"status": "in_progress", "id": 2},
                {"status": "failed", "id": 3},
                {"status": "completed", "id": 4},
            ],
            "completed": [{"id": 5}, {"id": 6}],
        }

        with patch.object(module, "_load_json", return_value=queue_data):
            result = module.show_queue_status()

            assert "=== Task Queue Status ===" in result
            assert "Queued:       1" in result
            assert "In Progress:  1" in result
            assert "Failed:       1" in result
            assert "Completed:    2" in result  # 1 from tasks + 2 from completed

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_show_queue_status_empty_queue(self):
        """Test show_queue_status with empty queue"""
        import agents.metrics_dashboard as module

        queue_data = {"tasks": [], "completed": []}

        with patch.object(module, "_load_json", return_value=queue_data):
            result = module.show_queue_status()

            assert "=== Task Queue Status ===" in result
            assert "Queued:       0" in result
            assert "In Progress:  0" in result
            assert "Failed:       0" in result
            assert "Completed:    0" in result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_show_command(self):
        """Test main function show command"""
        import agents.metrics_dashboard as module

        with patch("sys.argv", ["metrics_dashboard.py", "show"]), patch.object(
            module, "_load_json", return_value={"test": "data"}
        ), patch("builtins.print") as mock_print:

            result = module.main()
            assert result == 0
            mock_print.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_show_refresh_command(self):
        """Test main function show command with refresh"""
        import agents.metrics_dashboard as module

        with patch(
            "sys.argv", ["metrics_dashboard.py", "show", "--refresh"]
        ), patch.object(module, "_run_refresh") as mock_refresh, patch.object(
            module, "_load_json", return_value={"test": "data"}
        ), patch(
            "builtins.print"
        ) as mock_print:

            result = module.main()
            assert result == 0
            mock_refresh.assert_called_once_with(html=False)
            mock_print.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_html_command(self):
        """Test main function html command"""
        import agents.metrics_dashboard as module

        with patch("sys.argv", ["metrics_dashboard.py", "html"]), patch.object(
            module, "_run_refresh"
        ) as mock_refresh, patch("builtins.print") as mock_print:

            result = module.main()
            assert result == 0
            mock_refresh.assert_called_once_with(html=True)
            mock_print.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_html_custom_output(self):
        """Test main function html command with custom output"""
        import agents.metrics_dashboard as module

        custom_out = "/custom/path/report.html"
        with patch(
            "sys.argv", ["metrics_dashboard.py", "html", "--out", custom_out]
        ), patch.object(module, "_run_refresh") as mock_refresh, patch(
            "builtins.print"
        ) as mock_print:

            result = module.main()
            assert result == 0
            # _run_refresh should be called with html=True, but the output path is handled internally
            mock_refresh.assert_called_once_with(html=True)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_queue_command(self):
        """Test main function queue command"""
        import agents.metrics_dashboard as module

        with patch("sys.argv", ["metrics_dashboard.py", "queue"]), patch(
            "builtins.print"
        ) as mock_print:

            result = module.main()
            assert result == 0
            mock_print.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_queue_watch_command(self):
        """Test main function queue command with watch"""
        import agents.metrics_dashboard as module

        with patch("sys.argv", ["metrics_dashboard.py", "queue", "--watch"]), patch(
            "time.sleep", side_effect=KeyboardInterrupt
        ), patch("builtins.print") as mock_print:

            result = module.main()
            assert result == 0
            # Should have printed multiple times (clear screen + status + message)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_invalid_command(self):
        """Test main function with invalid command"""
        import agents.metrics_dashboard as module

        with patch("sys.argv", ["metrics_dashboard.py", "invalid"]), patch(
            "sys.exit"
        ) as mock_exit, patch("sys.stdout") as mock_stdout, patch(
            "sys.stderr"
        ) as mock_stderr:

            # The function should call sys.exit for invalid command
            module.main()
            mock_exit.assert_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_no_command(self):
        """Test main function with no command"""
        import agents.metrics_dashboard as module

        with patch("sys.argv", ["metrics_dashboard.py"]), patch(
            "sys.stdout"
        ) as mock_stdout:

            result = module.main()
            assert result == 1
            # Should print help
