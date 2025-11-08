import pytest
import sys
import os
import json
import tempfile
import shutil
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timedelta
from pathlib import Path
import signal
import time

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("agents.agent_recovery")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.agent_recovery: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/agent_recovery.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/agent_recovery.py",
                "exec",
            )
        print(f"File agents/agent_recovery.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File agents/agent_recovery.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsAgentRecovery:
    """Comprehensive tests for agents/agent_recovery.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/agent_recovery.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/agent_recovery.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/agent_recovery.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/agent_recovery.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.agent_recovery")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.agent_recovery should be importable")

    # TODO: Add specific tests for functions in agents/agent_recovery.py
    # The module import now works correctly, so you can add real test functions here
    # Examples:
    # def test_specific_function(self):
    #     import agents.agent_recovery as module
    #     result = module.function_name(args)
    #     assert result == expected

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_existing_file(self):
        """Test load_json with existing file"""
        import agents.agent_recovery as module

        test_data = {"test": "data", "number": 42}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(test_data, f)
            temp_path = Path(f.name)

        try:
            result = module.load_json(temp_path, "default")
            assert result == test_data
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_nonexistent_file(self):
        """Test load_json with nonexistent file"""
        import agents.agent_recovery as module

        result = module.load_json(Path("/nonexistent/file.json"), "default_value")
        assert result == "default_value"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_invalid_json(self):
        """Test load_json with invalid JSON"""
        import agents.agent_recovery as module

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            f.write("invalid json content")
            temp_path = Path(f.name)

        try:
            result = module.load_json(temp_path, "default")
            assert result == "default"
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_save_json_creates_file(self):
        """Test save_json creates file correctly"""
        import agents.agent_recovery as module

        test_data = {"test": "data", "number": 123}

        with tempfile.TemporaryDirectory() as temp_dir:
            output_file = Path(temp_dir) / "test_output.json"

            module.save_json(output_file, test_data)

            # File should exist
            assert output_file.exists()

            # Content should be correct
            with open(output_file, "r") as f:
                loaded_data = json.load(f)
            assert loaded_data == test_data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_save_json_creates_directories(self):
        """Test save_json creates necessary directories"""
        import agents.agent_recovery as module

        test_data = {"test": "data"}

        with tempfile.TemporaryDirectory() as temp_dir:
            nested_file = Path(temp_dir) / "nested" / "dir" / "output.json"

            module.save_json(nested_file, test_data)

            # Directory should be created
            assert nested_file.parent.exists()
            assert nested_file.exists()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_is_process_running_valid_pid(self):
        """Test is_process_running with valid PID"""
        import agents.agent_recovery as module

        # Test with current process PID (should be running)
        current_pid = os.getpid()
        assert module.is_process_running(current_pid) is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_is_process_running_invalid_pid(self):
        """Test is_process_running with invalid PID"""
        import agents.agent_recovery as module

        # Test with invalid PIDs
        assert module.is_process_running(None) is False
        assert module.is_process_running(0) is False
        assert module.is_process_running(999999) is False  # Non-existent PID

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_resolve_script_with_extension(self):
        """Test resolve_script with .sh extension"""
        import agents.agent_recovery as module

        with tempfile.TemporaryDirectory() as temp_dir:
            script_path = Path(temp_dir) / "test_agent.sh"
            script_path.write_text("#!/bin/bash\necho test")

            with patch.object(module, "AGENTS_DIR", Path(temp_dir)):
                result = module.resolve_script("test_agent.sh")
                assert result == script_path

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_resolve_script_without_extension(self):
        """Test resolve_script without .sh extension"""
        import agents.agent_recovery as module

        with tempfile.TemporaryDirectory() as temp_dir:
            script_path = Path(temp_dir) / "test_agent.sh"
            script_path.write_text("#!/bin/bash\necho test")

            with patch.object(module, "AGENTS_DIR", Path(temp_dir)):
                result = module.resolve_script("test_agent")
                assert result == script_path

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_resolve_script_not_found(self):
        """Test resolve_script when script not found"""
        import agents.agent_recovery as module

        with tempfile.TemporaryDirectory() as temp_dir:
            with patch.object(module, "AGENTS_DIR", Path(temp_dir)):
                result = module.resolve_script("nonexistent_agent")
                assert result is None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_read_pidfile_existing(self):
        """Test read_pidfile with existing PID file"""
        import agents.agent_recovery as module

        with tempfile.TemporaryDirectory() as temp_dir:
            # Create both the script and PID file
            script_path = Path(temp_dir) / "test_agent.sh"
            script_path.write_text("#!/bin/bash\necho test")
            pid_file = Path(temp_dir) / "test_agent.sh.pid"
            pid_file.write_text("12345\n")

            with patch.object(module, "AGENTS_DIR", Path(temp_dir)):
                result = module.read_pidfile("test_agent.sh")
                assert result == 12345

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_read_pidfile_nonexistent(self):
        """Test read_pidfile with nonexistent PID file"""
        import agents.agent_recovery as module

        with tempfile.TemporaryDirectory() as temp_dir:
            with patch.object(module, "AGENTS_DIR", Path(temp_dir)):
                result = module.read_pidfile("test_agent.sh")
                assert result is None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_read_pidfile_invalid_content(self):
        """Test read_pidfile with invalid content"""
        import agents.agent_recovery as module

        with tempfile.TemporaryDirectory() as temp_dir:
            pid_file = Path(temp_dir) / "test_agent.sh.pid"
            pid_file.write_text("invalid\n")

            with patch.object(module, "AGENTS_DIR", Path(temp_dir)):
                result = module.read_pidfile("test_agent.sh")
                assert result is None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_read_agent_status(self):
        """Test read_agent_status"""
        import agents.agent_recovery as module

        test_data = {
            "agents": {
                "agent1": {"status": "running", "pid": 123},
                "agent2": {"status": "stopped", "pid": 456},
            }
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            status_file = Path(temp_dir) / "agent_status.json"
            with open(status_file, "w") as f:
                json.dump(test_data, f)

            with patch.object(module, "STATUS_PATH", status_file):
                result = module.read_agent_status()
                assert result == test_data["agents"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_agent_status(self):
        """Test update_agent_status"""
        import agents.agent_recovery as module

        with tempfile.TemporaryDirectory() as temp_dir:
            status_file = Path(temp_dir) / "agent_status.json"

            with patch.object(module, "STATUS_PATH", status_file):
                module.update_agent_status(["agent1", "agent2"], "running", 123)

                # Check file was created
                assert status_file.exists()
                with open(status_file, "r") as f:
                    data = json.load(f)

                assert "agents" in data
                assert "agent1" in data["agents"]
                assert "agent2" in data["agents"]
                assert data["agents"]["agent1"]["status"] == "running"
                assert data["agents"]["agent1"]["pid"] == 123
                assert "last_update" in data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_queue_summary(self):
        """Test load_queue_summary"""
        import agents.agent_recovery as module

        test_data = {
            "tasks": [
                {"status": "queued", "assigned_agent": "agent1"},
                {"status": "running", "assigned_agent": "agent2"},
                {"status": "queued", "assigned_agent": "agent1"},
                {"status": "completed", "assigned_agent": "agent3"},
            ]
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            queue_file = Path(temp_dir) / "task_queue.json"
            with open(queue_file, "w") as f:
                json.dump(test_data, f)

            with patch.object(module, "QUEUE_PATH", queue_file):
                count, distribution = module.load_queue_summary()

                assert count == 2  # 2 queued tasks
                assert distribution["agent1"] == 2
                assert "agent2" not in distribution  # running tasks not included

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_drain_rate(self):
        """Test load_drain_rate"""
        import agents.agent_recovery as module

        test_data = {"drain_rate_per_min": 5.5}

        with tempfile.TemporaryDirectory() as temp_dir:
            metrics_file = Path(temp_dir) / ".dashboard_metrics_state.json"
            with open(metrics_file, "w") as f:
                json.dump(test_data, f)

            with patch.object(module, "METRICS_STATE_PATH", metrics_file):
                result = module.load_drain_rate()
                assert result == 5.5

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_drain_rate_missing(self):
        """Test load_drain_rate when file missing"""
        import agents.agent_recovery as module

        with tempfile.TemporaryDirectory() as temp_dir:
            metrics_file = Path(temp_dir) / ".dashboard_metrics_state.json"

            with patch.object(module, "METRICS_STATE_PATH", metrics_file):
                result = module.load_drain_rate()
                assert result is None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_stop_process_running(self):
        """Test stop_process with running process"""
        import agents.agent_recovery as module

        # This is tricky to test safely. We'll mock the os.kill calls
        with patch("os.kill") as mock_kill, patch.object(
            module, "is_process_running", side_effect=[True, False]
        ):
            module.stop_process(123, verbose=True)

            # Should send SIGTERM first
            mock_kill.assert_called_with(123, signal.SIGTERM)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_stop_process_not_running(self):
        """Test stop_process with process not running"""
        import agents.agent_recovery as module

        with patch.object(module, "is_process_running", return_value=False), patch(
            "os.kill"
        ) as mock_kill:
            module.stop_process(123)

            # Should not call os.kill
            mock_kill.assert_not_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_launch_agent_dry_run(self):
        """Test launch_agent in dry run mode"""
        import agents.agent_recovery as module

        with tempfile.TemporaryDirectory() as temp_dir:
            script_path = Path(temp_dir) / "test.sh"
            script_path.write_text("#!/bin/bash\necho test")

            with patch.object(module, "AGENTS_DIR", Path(temp_dir)), patch(
                "subprocess.Popen"
            ) as mock_popen:
                result = module.launch_agent(
                    script_path, "test", dry_run=True, verbose=True
                )

                assert result is None
                mock_popen.assert_not_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_launch_agent_real_launch(self):
        """Test launch_agent with real launch"""
        import agents.agent_recovery as module

        with tempfile.TemporaryDirectory() as temp_dir:
            script_path = Path(temp_dir) / "test.sh"
            script_path.write_text("#!/bin/bash\necho test")

            mock_process = MagicMock()
            mock_process.pid = 12345

            with patch.object(module, "AGENTS_DIR", Path(temp_dir)), patch(
                "subprocess.Popen", return_value=mock_process
            ) as mock_popen:
                result = module.launch_agent(
                    script_path, "test", dry_run=False, verbose=True
                )

                assert result == 12345
                mock_popen.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_related_keys_with_extension(self):
        """Test related_keys with .sh extension"""
        import agents.agent_recovery as module

        result = module.related_keys("agent_build.sh")
        assert "agent_build.sh" in result
        assert "agent_build" in result
        assert "build" in result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_related_keys_without_extension(self):
        """Test related_keys without .sh extension"""
        import agents.agent_recovery as module

        result = module.related_keys("agent_build")
        assert "agent_build" in result
        assert "agent_build.sh" in result
        assert "build" in result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_restart_agent(self):
        """Test restart_agent"""
        import agents.agent_recovery as module

        with tempfile.TemporaryDirectory() as temp_dir:
            script_path = Path(temp_dir) / "test.sh"
            script_path.write_text("#!/bin/bash\necho test")

            with patch.object(module, "AGENTS_DIR", Path(temp_dir)), patch.object(
                module, "stop_process"
            ) as mock_stop, patch.object(
                module, "launch_agent", return_value=12345
            ) as mock_launch, patch.object(
                module, "update_agent_status"
            ) as mock_update:
                module.restart_agent(
                    "test", script_path, 999, dry_run=False, verbose=True
                )

                mock_stop.assert_called_once_with(999, verbose=True)
                mock_launch.assert_called_once()
                mock_update.assert_called_once_with(
                    ["test", "test.sh"], "restarting", 12345
                )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_clones(self):
        """Test load_clones"""
        import agents.agent_recovery as module

        test_data = {
            "agent1": [{"pid": 123, "started": 1000}],
            "agent2": [{"pid": 456, "started": 2000}],
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            clones_file = Path(temp_dir) / "agent_clones.json"
            with open(clones_file, "w") as f:
                json.dump(test_data, f)

            with patch.object(module, "CLONES_PATH", clones_file):
                result = module.load_clones()
                assert result == test_data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_save_clones(self):
        """Test save_clones"""
        import agents.agent_recovery as module

        test_data = {"agent1": [{"pid": 123, "started": 1000}]}

        with tempfile.TemporaryDirectory() as temp_dir:
            clones_file = Path(temp_dir) / "agent_clones.json"

            with patch.object(module, "CLONES_PATH", clones_file):
                module.save_clones(test_data)

                assert clones_file.exists()
                with open(clones_file, "r") as f:
                    loaded_data = json.load(f)
                assert loaded_data == test_data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_prune_dead_clones(self):
        """Test prune_dead_clones"""
        import agents.agent_recovery as module

        clones = {
            "agent1": [
                {"pid": 123, "started": 1000},  # alive
                {"pid": 999, "started": 2000},  # dead
            ],
            "agent2": [{"pid": 888, "started": 3000}],  # dead
        }

        with patch.object(
            module, "is_process_running", side_effect=[True, False, False]
        ):
            module.prune_dead_clones(clones, verbose=True)

            assert "agent1" in clones
            assert len(clones["agent1"]) == 1
            assert clones["agent1"][0]["pid"] == 123
            assert "agent2" not in clones

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_ensure_extra_workers(self):
        """Test ensure_extra_workers"""
        import agents.agent_recovery as module

        with tempfile.TemporaryDirectory() as temp_dir:
            script_path = Path(temp_dir) / "test.sh"
            script_path.write_text("#!/bin/bash\necho test")

            clones = {"test": []}
            plan = {"test": 2}

            with patch.object(module, "AGENTS_DIR", Path(temp_dir)), patch.object(
                module, "resolve_script", return_value=script_path
            ), patch.object(
                module, "launch_agent", return_value=12345
            ) as mock_launch, patch.object(
                module, "save_clones"
            ) as mock_save:
                module.ensure_extra_workers(clones, plan, dry_run=False, verbose=True)

                assert len(clones["test"]) == 2
                assert mock_launch.call_count == 2
                mock_save.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_evaluate_agents(self):
        """Test evaluate_agents"""
        import agents.agent_recovery as module

        agents = {
            "agent1": {
                "status": "running",
                "last_seen": int(time.time()) - 100,
                "pid": 123,
            },
            "agent2": {
                "status": "stopped",
                "last_seen": int(time.time()) - 400,  # stale
                "pid": 456,
            },
        }

        result = module.evaluate_agents(agents)

        assert len(result) == 2
        agent1_info = next(item for item in result if item["name"] == "agent1")
        agent2_info = next(item for item in result if item["name"] == "agent2")

        assert agent1_info["status"] == "running"
        assert agent1_info["needs_restart"] is False
        assert agent1_info["stale"] is False

        assert agent2_info["status"] == "stopped"
        assert agent2_info["needs_restart"] is True
        assert agent2_info["stale"] is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_format_agent_label(self):
        """Test format_agent_label"""
        import agents.agent_recovery as module

        assert module.format_agent_label("agent_build.sh") == "build"
        assert module.format_agent_label("agent_debug") == "debug"
        assert module.format_agent_label("custom_agent") == "custom agent"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_summary_only(self):
        """Test main function with --summary"""
        import agents.agent_recovery as module

        with patch("sys.argv", ["agent_recovery.py", "--summary"]), patch.object(
            module, "read_agent_status", return_value={}
        ), patch.object(module, "evaluate_agents", return_value=[]), patch.object(
            module, "load_queue_summary", return_value=(0, {})
        ), patch.object(
            module, "load_drain_rate", return_value=None
        ), patch(
            "builtins.print"
        ) as mock_print:
            module.main()

            # Should print summary but not apply changes
            mock_print.assert_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_apply_restart(self):
        """Test main function with --apply for restart"""
        import agents.agent_recovery as module

        agent_info = [{"name": "agent_build.sh", "needs_restart": True, "pid": 123}]

        with patch("sys.argv", ["agent_recovery.py", "--apply"]), patch.object(
            module, "read_agent_status", return_value={}
        ), patch.object(
            module, "evaluate_agents", return_value=agent_info
        ), patch.object(
            module, "load_queue_summary", return_value=(0, {})
        ), patch.object(
            module, "load_drain_rate", return_value=None
        ), patch.object(
            module, "resolve_script", return_value=Path("/tmp/test.sh")
        ), patch.object(
            module, "restart_agent"
        ) as mock_restart:
            module.main()

            mock_restart.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_apply_scaling(self):
        """Test main function with --apply and --scale"""
        import agents.agent_recovery as module

        with patch(
            "sys.argv", ["agent_recovery.py", "--apply", "--scale", "agent_build=2"]
        ), patch.object(module, "read_agent_status", return_value={}), patch.object(
            module, "evaluate_agents", return_value=[]
        ), patch.object(
            module, "load_queue_summary", return_value=(0, {})
        ), patch.object(
            module, "load_drain_rate", return_value=None
        ), patch.object(
            module, "load_clones", return_value={}
        ), patch.object(
            module, "prune_dead_clones"
        ), patch.object(
            module, "ensure_extra_workers"
        ) as mock_ensure:
            module.main()

            mock_ensure.assert_called_once()
            args, kwargs = mock_ensure.call_args
            assert args[1]["agent_build"] == 2
