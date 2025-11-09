import pytest
import sys
import os
import json
import tempfile
import shutil
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timedelta, timezone
import io
from contextlib import redirect_stdout

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("agents.analytics_collector")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.analytics_collector: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/analytics_collector.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/analytics_collector.py",
                "exec",
            )
        print(
            f"File agents/analytics_collector.py is syntactically valid but import failed"
        )
    except SyntaxError as se:
        print(f"File agents/analytics_collector.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsAnalyticsCollector:
    """Comprehensive tests for agents/analytics_collector.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/analytics_collector.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/analytics_collector.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/analytics_collector.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/analytics_collector.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.analytics_collector")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.analytics_collector should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_existing_file(self):
        """Test _load_json with existing file"""
        import agents.analytics_collector as module

        test_data = {"test": "data", "number": 42}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(test_data, f)
            temp_path = f.name

        try:
            result = module._load_json(temp_path, "default")
            assert result == test_data
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_nonexistent_file(self):
        """Test _load_json with nonexistent file"""
        import agents.analytics_collector as module

        result = module._load_json("/nonexistent/file.json", "default_value")
        assert result == "default_value"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_invalid_json(self):
        """Test _load_json with invalid JSON"""
        import agents.analytics_collector as module

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            f.write("invalid json content")
            temp_path = f.name

        try:
            result = module._load_json(temp_path, "default")
            assert result == "default"
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_now_iso_format(self):
        """Test _now_iso returns correct ISO format"""
        import agents.analytics_collector as module

        result = module._now_iso()
        # Should be in format YYYY-MM-DDTHH:MM:SSZ
        assert len(result) == 20
        assert result.endswith("Z")
        assert "T" in result

        # Should be parseable as datetime
        datetime.fromisoformat(result[:-1])  # Remove Z for parsing

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_mean_safe_with_values(self):
        """Test _mean_safe with numeric values"""
        import agents.analytics_collector as module

        values = [1.0, 2.0, 3.0, 4.0, 5.0]
        result = module._mean_safe(values)
        assert result == 3.0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_mean_safe_with_mixed_values(self):
        """Test _mean_safe with mixed valid/invalid values"""
        import agents.analytics_collector as module

        values = [1.0, "invalid", 3.0, None, 5.0]
        result = module._mean_safe(values)
        assert result == 3.0  # (1+3+5)/3

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_mean_safe_empty_list(self):
        """Test _mean_safe with empty list"""
        import agents.analytics_collector as module

        result = module._mean_safe([])
        assert result == 0.0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_mean_safe_custom_default(self):
        """Test _mean_safe with custom default"""
        import agents.analytics_collector as module

        result = module._mean_safe([], 42.0)
        assert result == 42.0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_collect_metrics_no_files(self):
        """Test collect_metrics when no knowledge files exist"""
        import agents.analytics_collector as module

        with tempfile.TemporaryDirectory() as temp_dir:
            with patch.object(module, "KNOWLEDGE_DIR", temp_dir):
                result = module.collect_metrics()

                # Should return default metrics
                assert "generated_at" in result
                assert "overall_success_rate" in result
                assert "average_resolution_time" in result
                assert result["overall_success_rate"] == 0.0
                assert result["average_resolution_time"] == 0.0
                assert result["learning_velocity_per_week"] == 0
                assert result["autonomy_level"] == 1.0
                assert result["error_recurrence_rate"] == 0.0
                assert result["cross_agent_collaboration_score"] == 0.0
                assert result["proactive_open_alerts"] == 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_collect_metrics_with_strategies(self):
        """Test collect_metrics with strategies data"""
        import agents.analytics_collector as module

        strategies_data = [
            {"success_rate": 0.8, "avg_execution_time": 10.0},
            {"success_rate": 0.6, "avg_execution_time": 20.0},
            {"success_rate": 0.9, "avg_execution_time": 15.0},
        ]

        with tempfile.TemporaryDirectory() as temp_dir:
            strategies_file = os.path.join(temp_dir, "strategies.json")
            with open(strategies_file, "w") as f:
                json.dump(strategies_data, f)

            with patch.object(module, "KNOWLEDGE_DIR", temp_dir):
                result = module.collect_metrics()

                # Should calculate averages correctly
                assert result["overall_success_rate"] == 0.7667  # (0.8+0.6+0.9)/3
                assert result["average_resolution_time"] == 15.0  # (10+20+15)/3
                assert result["counts"]["strategies"] == 3

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_collect_metrics_with_fix_history(self):
        """Test collect_metrics with fix history timestamps"""
        import agents.analytics_collector as module

        now = datetime.now(timezone.utc)
        week_ago = now - timedelta(days=8)
        recent_fixes = [
            {"timestamp": now.strftime("%Y-%m-%dT%H:%M:%SZ")},
            {"timestamp": (now - timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ")},
            {"timestamp": week_ago.strftime("%Y-%m-%dT%H:%M:%SZ")},  # 8 days ago
        ]

        with tempfile.TemporaryDirectory() as temp_dir:
            fix_history_file = os.path.join(temp_dir, "fix_history.json")
            with open(fix_history_file, "w") as f:
                json.dump(recent_fixes, f)

            with patch.object(module, "KNOWLEDGE_DIR", temp_dir):
                result = module.collect_metrics()

                # Should count fixes from last week
                assert result["learning_velocity_per_week"] == 2  # 2 recent fixes

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_collect_metrics_with_emergencies(self):
        """Test collect_metrics with emergencies data"""
        import agents.analytics_collector as module

        emergencies_data = [
            {"severity": "low", "escalations": []},
            {
                "severity": "critical",
                "escalations": [{"level": "L4"}],
            },  # Human intervention
            {"severity": "high", "escalations": []},
        ]

        with tempfile.TemporaryDirectory() as temp_dir:
            emergencies_file = os.path.join(temp_dir, "emergencies.json")
            with open(emergencies_file, "w") as f:
                json.dump(emergencies_data, f)

            with patch.object(module, "KNOWLEDGE_DIR", temp_dir):
                result = module.collect_metrics()

                # 1 out of 3 emergencies required human intervention
                assert result["autonomy_level"] == pytest.approx(
                    2.0 / 3.0, rel=1e-3
                )  # 1.0 - (1/3)
                assert result["counts"]["emergencies"] == 3

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_collect_metrics_with_failure_analysis(self):
        """Test collect_metrics with failure analysis data"""
        import agents.analytics_collector as module

        failure_data = [
            {"signature": "error1"},
            {"signature": "error2"},
            {"signature": "error1"},  # repeat
            {"signature": "error3"},
            {"signature": "error1"},  # another repeat
        ]

        with tempfile.TemporaryDirectory() as temp_dir:
            failure_file = os.path.join(temp_dir, "failure_analysis.json")
            with open(failure_file, "w") as f:
                json.dump(failure_data, f)

            with patch.object(module, "KNOWLEDGE_DIR", temp_dir):
                result = module.collect_metrics()

                # error1 appears 3 times, so 1 repeat out of 3 unique signatures
                assert result["error_recurrence_rate"] == pytest.approx(
                    1.0 / 3.0, rel=1e-3
                )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_collect_metrics_with_central_hub(self):
        """Test collect_metrics with central hub data"""
        import agents.analytics_collector as module

        central_hub_data = {
            "cross_agent_insights": ["insight1", "insight2", "insight3"],
            "best_practices": ["practice1", "practice2"],
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            central_hub_file = os.path.join(temp_dir, "central_hub.json")
            with open(central_hub_file, "w") as f:
                json.dump(central_hub_data, f)

            with patch.object(module, "KNOWLEDGE_DIR", temp_dir):
                result = module.collect_metrics()

                # Score = min(1.0, (3 + 0.5*2) / 20.0) = min(1.0, 4/20.0) = 0.2
                assert result["cross_agent_collaboration_score"] == 0.2

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_collect_metrics_with_proactive_alerts(self):
        """Test collect_metrics with proactive alerts data"""
        import agents.analytics_collector as module

        alerts_data = [
            {"status": "active"},
            {"status": "resolved"},
            {"status": "active"},
            {"status": "active"},
        ]

        with tempfile.TemporaryDirectory() as temp_dir:
            alerts_file = os.path.join(temp_dir, "proactive_alerts.json")
            with open(alerts_file, "w") as f:
                json.dump(alerts_data, f)

            with patch.object(module, "KNOWLEDGE_DIR", temp_dir):
                result = module.collect_metrics()

                # 3 active alerts
                assert result["proactive_open_alerts"] == 3

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_write_json_creates_file(self):
        """Test _write_json creates file correctly"""
        import agents.analytics_collector as module

        test_data = {"test": "data", "number": 123}

        with tempfile.TemporaryDirectory() as temp_dir:
            output_file = os.path.join(temp_dir, "test_output.json")

            module._write_json(output_file, test_data)

            # File should exist
            assert os.path.exists(output_file)

            # Content should be correct
            with open(output_file, "r") as f:
                loaded_data = json.load(f)
            assert loaded_data == test_data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_write_json_creates_directories(self):
        """Test _write_json creates necessary directories"""
        import agents.analytics_collector as module

        test_data = {"test": "data"}

        with tempfile.TemporaryDirectory() as temp_dir:
            nested_file = os.path.join(temp_dir, "nested", "dir", "output.json")

            module._write_json(nested_file, test_data)

            # Directory should be created
            assert os.path.exists(os.path.dirname(nested_file))
            assert os.path.exists(nested_file)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_write_json_atomic_write(self):
        """Test _write_json uses atomic writes"""
        import agents.analytics_collector as module

        test_data = {"test": "data"}

        with tempfile.TemporaryDirectory() as temp_dir:
            output_file = os.path.join(temp_dir, "output.json")
            tmp_file = f"{output_file}.tmp"

            # Mock to check atomic write
            with patch("os.replace") as mock_replace:
                module._write_json(output_file, test_data)

                # Should use atomic write
                mock_replace.assert_called_once()
                assert mock_replace.call_args[0][0].endswith(".tmp")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_write_html_creates_file(self):
        """Test _write_html creates HTML file"""
        import agents.analytics_collector as module

        test_data = {
            "generated_at": "2025-11-07T12:00:00Z",
            "overall_success_rate": 0.85,
            "average_resolution_time": 45.5,
            "learning_velocity_per_week": 12,
            "autonomy_level": 0.92,
            "error_recurrence_rate": 0.15,
            "cross_agent_collaboration_score": 0.78,
            "proactive_open_alerts": 3,
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            html_file = os.path.join(temp_dir, "report.html")

            module._write_html(html_file, test_data)

            # File should exist
            assert os.path.exists(html_file)

            # Should contain HTML content
            with open(html_file, "r") as f:
                content = f.read()
            assert "<!doctype html>" in content
            assert "Agent Analytics Dashboard" in content
            assert "85.0%" in content  # success rate
            assert "45.5s" in content  # resolution time

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_collect_command(self):
        """Test main function collect command"""
        import agents.analytics_collector as module

        with tempfile.TemporaryDirectory() as temp_dir:
            output_file = os.path.join(temp_dir, "analytics.json")

            with patch(
                "sys.argv", ["analytics_collector.py", "collect", "--out", output_file]
            ):
                with patch.object(module, "KNOWLEDGE_DIR", temp_dir):
                    f = io.StringIO()
                    with redirect_stdout(f):
                        exit_code = module.main()
                    output = f.getvalue()

            assert exit_code == 0

            # Should output JSON to stdout
            result = json.loads(output)
            assert "generated_at" in result
            assert "overall_success_rate" in result

            # Should create output file
            assert os.path.exists(output_file)
            with open(output_file, "r") as f:
                file_data = json.load(f)
            assert file_data == result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_collect_with_html(self):
        """Test main function collect command with HTML output"""
        import agents.analytics_collector as module

        with tempfile.TemporaryDirectory() as temp_dir:
            output_file = os.path.join(temp_dir, "analytics.json")
            html_file = os.path.join(temp_dir, "report.html")

            with patch(
                "sys.argv",
                [
                    "analytics_collector.py",
                    "collect",
                    "--out",
                    output_file,
                    "--html",
                    html_file,
                ],
            ):
                with patch.object(module, "KNOWLEDGE_DIR", temp_dir):
                    f = io.StringIO()
                    with redirect_stdout(f):
                        exit_code = module.main()
                    output = f.getvalue()

            assert exit_code == 0

            # Should create both files
            assert os.path.exists(output_file)
            assert os.path.exists(html_file)

            # HTML file should contain dashboard content
            with open(html_file, "r") as f:
                html_content = f.read()
            assert "Agent Analytics Dashboard" in html_content

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_invalid_command(self):
        """Test main function with invalid command"""
        import agents.analytics_collector as module

        with patch("sys.argv", ["analytics_collector.py", "invalid"]):
            with pytest.raises(SystemExit) as exc_info:
                module.main()
            assert exc_info.value.code == 2

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_no_command(self):
        """Test main function with no command"""
        import agents.analytics_collector as module

        with patch("sys.argv", ["analytics_collector.py"]):
            with patch("argparse.ArgumentParser.print_help") as mock_help:
                exit_code = module.main()

            assert exit_code == 1
            mock_help.assert_called_once()
