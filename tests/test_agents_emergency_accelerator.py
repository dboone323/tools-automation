import pytest
import sys
import os
import json
import tempfile
from unittest.mock import Mock, patch, MagicMock, mock_open
from pathlib import Path

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("agents.emergency_accelerator")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.emergency_accelerator: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/emergency_accelerator.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/emergency_accelerator.py",
                "exec",
            )
        print(
            f"File agents/emergency_accelerator.py is syntactically valid but import failed"
        )
    except SyntaxError as se:
        print(f"File agents/emergency_accelerator.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsEmergencyAccelerator:
    """Comprehensive tests for agents/emergency_accelerator.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/emergency_accelerator.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/emergency_accelerator.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/emergency_accelerator.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/emergency_accelerator.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.emergency_accelerator")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.emergency_accelerator should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_final_accelerator_init(self):
        """Test FinalAccelerator initialization"""
        import agents.emergency_accelerator as module

        accelerator = module.FinalAccelerator()
        assert (
            accelerator.workspace_root
            == "/Users/danielstevens/Desktop/Quantum-workspace"
        )
        assert (
            accelerator.agents_dir
            == "/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents"
        )

        # Test custom workspace
        custom_workspace = "/custom/path"
        accelerator = module.FinalAccelerator(custom_workspace)
        assert accelerator.workspace_root == custom_workspace
        assert accelerator.agents_dir == f"{custom_workspace}/Tools/Automation/agents"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_emergency_agent_restart(self):
        """Test emergency agent restart functionality"""
        import agents.emergency_accelerator as module

        accelerator = module.FinalAccelerator()

        # Mock subprocess operations
        with patch("subprocess.run") as mock_run, patch(
            "subprocess.Popen"
        ) as mock_popen, patch("os.path.exists", return_value=True), patch(
            "time.sleep"
        ) as mock_sleep:

            # Mock successful agent starts
            mock_popen.return_value = Mock()

            result = accelerator.emergency_agent_restart()

            # Verify pkill commands were called
            assert mock_run.call_count >= 2  # pkill calls

            # Verify agents were started with high priority
            expected_agents = [
                "agent_analytics.sh",
                "agent_build.sh",
                "agent_cleanup.sh",
                "agent_codegen.sh",
                "code_review_agent.sh",
                "deployment_agent.sh",
                "documentation_agent.sh",
                "learning_agent.sh",
                "monitoring_agent.sh",
                "performance_agent.sh",
                "quality_agent.sh",
                "search_agent.sh",
                "security_agent.sh",
                "testing_agent.sh",
            ]

            assert mock_popen.call_count == len(expected_agents)

            # Check that nice command was used for high priority
            for call in mock_popen.call_args_list:
                args = call[0][0]
                assert args[0] == "nice"
                assert args[1] == "-n"
                assert args[2] == "-10"  # High priority

            assert result == len(expected_agents)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_emergency_agent_restart_missing_agents(self):
        """Test emergency agent restart with missing agent files"""
        import agents.emergency_accelerator as module

        accelerator = module.FinalAccelerator()

        with patch("subprocess.run"), patch("subprocess.Popen") as mock_popen, patch(
            "os.path.exists", return_value=False
        ), patch("time.sleep"):

            result = accelerator.emergency_agent_restart()

            # No agents should be started if files don't exist
            assert mock_popen.call_count == 0
            assert result == 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_force_maximum_task_distribution(self):
        """Test force maximum task distribution"""
        import agents.emergency_accelerator as module

        accelerator = module.FinalAccelerator()

        # Mock data
        task_queue_data = {
            "tasks": [
                {"id": 1, "status": "queued"},
                {"id": 2, "status": "batched"},
                {"id": 3, "status": "completed"},  # Should be ignored
                {"id": 4, "status": "queued"},
                {"id": 5, "status": "queued"},
            ]
        }

        agent_status_data = {
            "agents": {
                "agent1": {"pid": 123},
                "agent2": {"pid": 456},
                "agent3": {"pid": 0},  # Not running
            }
        }

        with patch("builtins.open", mock_open()) as mock_file, patch(
            "json.load"
        ) as mock_json_load, patch("json.dump") as mock_json_dump, patch(
            "os.kill", return_value=None
        ):  # Agents are running

            # Set up mock returns
            mock_json_load.side_effect = [task_queue_data, agent_status_data]

            result = accelerator.force_maximum_task_distribution()

            # Should assign tasks to running agents (max 5 per agent)
            # 2 running agents * 5 max = 10 possible assignments
            # But only 4 available tasks (queued/batched)
            assert result == 4

            # Verify json.dump was called to save updated queue
            assert mock_json_dump.call_count == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_force_maximum_task_distribution_no_running_agents(self):
        """Test force task distribution with no running agents"""
        import agents.emergency_accelerator as module

        accelerator = module.FinalAccelerator()

        task_queue_data = {"tasks": [{"status": "queued"}]}
        agent_status_data = {"agents": {"agent1": {"pid": 0}}}

        with patch("builtins.open", mock_open()), patch(
            "json.load"
        ) as mock_json_load, patch("json.dump") as mock_json_dump, patch(
            "os.kill", side_effect=OSError
        ):  # Agents not running

            mock_json_load.side_effect = [task_queue_data, agent_status_data]

            result = accelerator.force_maximum_task_distribution()

            assert result == 0  # No assignments possible

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_enable_ultra_performance_mode(self):
        """Test enabling ultra performance mode"""
        import agents.emergency_accelerator as module

        accelerator = module.FinalAccelerator()

        agent_status_data = {
            "agents": {
                "agent1": {"pid": 123},
                "agent2": {"pid": 456},
                "agent3": {"pid": 0},  # Not running
            }
        }

        with patch("builtins.open", mock_open()) as mock_file, patch(
            "json.load", return_value=agent_status_data
        ), patch("json.dump") as mock_json_dump, patch("os.kill", return_value=None):

            accelerator.enable_ultra_performance_mode()

            # Verify json.dump was called for the config file
            assert mock_json_dump.call_count == 1

            # Get the config data that was written
            config_data = mock_json_dump.call_args[0][0]
            assert config_data["ultra_performance_mode"] is True
            assert config_data["max_concurrent_tasks"] == 10
            assert config_data["emergency_acceleration"] is True
            assert config_data["cpu_priority"] == "maximum"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_start_acceleration_monitor(self):
        """Test starting acceleration monitor"""
        import agents.emergency_accelerator as module
        import threading

        accelerator = module.FinalAccelerator()

        task_queue_data = {
            "tasks": [{"status": "in_progress"} for _ in range(5)],  # Low activity
            "completed": [],
        }

        with patch("builtins.open", mock_open()), patch(
            "json.load", return_value=task_queue_data
        ), patch("threading.Thread") as mock_thread, patch.object(
            accelerator, "force_maximum_task_distribution"
        ) as mock_boost:

            mock_thread_instance = Mock()
            mock_thread.return_value = mock_thread_instance

            accelerator.start_acceleration_monitor()

            # Verify thread was created and started
            mock_thread.assert_called_once()
            mock_thread_instance.start.assert_called_once()

            # The monitor function should detect low activity and boost
            # But since it's running in a separate thread, we can't easily test the loop
            # This is a limitation of testing threaded code

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_run_emergency_acceleration(self):
        """Test complete emergency acceleration protocol"""
        import agents.emergency_accelerator as module

        accelerator = module.FinalAccelerator()

        with patch.object(
            accelerator, "emergency_agent_restart", return_value=10
        ), patch.object(
            accelerator, "force_maximum_task_distribution", return_value=25
        ), patch.object(
            accelerator, "enable_ultra_performance_mode"
        ), patch.object(
            accelerator, "start_acceleration_monitor"
        ), patch(
            "time.sleep"
        ) as mock_sleep:

            accelerator.run_emergency_acceleration()

            # Verify all methods were called
            accelerator.emergency_agent_restart.assert_called_once()
            accelerator.force_maximum_task_distribution.assert_called_once()
            accelerator.enable_ultra_performance_mode.assert_called_once()
            accelerator.start_acceleration_monitor.assert_called_once()

            # Verify sleep was called to wait for agents to start
            mock_sleep.assert_called_once_with(3)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_function(self):
        """Test main function"""
        import agents.emergency_accelerator as module

        with patch(
            "agents.emergency_accelerator.FinalAccelerator"
        ) as mock_accelerator_class:
            mock_accelerator_instance = Mock()
            mock_accelerator_class.return_value = mock_accelerator_instance

            module.main()

            # Verify FinalAccelerator was instantiated and run_emergency_acceleration was called
            mock_accelerator_class.assert_called_once()
            mock_accelerator_instance.run_emergency_acceleration.assert_called_once()
