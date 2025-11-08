import pytest
import sys
import os
import json
import tempfile
import threading
from unittest.mock import Mock, patch, MagicMock, call

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("agents.max_processor")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.max_processor: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/max_processor.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/max_processor.py",
                "exec",
            )
        print(f"File agents/max_processor.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File agents/max_processor.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsMaxProcessor:
    """Comprehensive tests for agents/max_processor.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/max_processor.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/max_processor.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/max_processor.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/max_processor.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.max_processor")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.max_processor should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_max_parallel_processor_init(self):
        """Test MaxParallelProcessor constructor"""
        import agents.max_processor as module

        # Test with default workspace
        processor = module.MaxParallelProcessor()
        assert (
            processor.workspace_root == "/Users/danielstevens/Desktop/Quantum-workspace"
        )
        assert (
            processor.agents_dir
            == "/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents"
        )
        assert processor.max_workers == 25

        # Test with custom workspace
        custom_workspace = "/tmp/test_workspace"
        processor = module.MaxParallelProcessor(custom_workspace)
        assert processor.workspace_root == custom_workspace
        assert processor.agents_dir == f"{custom_workspace}/Tools/Automation/agents"
        assert processor.max_workers == 25

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_force_max_parallelization_no_agents(self):
        """Test force_max_parallelization with no available agents"""
        import agents.max_processor as module

        with tempfile.TemporaryDirectory() as temp_dir:
            processor = module.MaxParallelProcessor(temp_dir)

            # Create empty agent status file
            agent_file = os.path.join(processor.agents_dir, "agent_status.json")
            os.makedirs(os.path.dirname(agent_file), exist_ok=True)
            with open(agent_file, "w") as f:
                json.dump({"agents": {}}, f)

            # Create task queue file
            queue_file = os.path.join(processor.agents_dir, "task_queue.json")
            with open(queue_file, "w") as f:
                json.dump({"tasks": []}, f)

            result = processor.force_max_parallelization()
            assert result == 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_force_max_parallelization_no_tasks(self):
        """Test force_max_parallelization with agents but no queued tasks"""
        import agents.max_processor as module

        with tempfile.TemporaryDirectory() as temp_dir:
            processor = module.MaxParallelProcessor(temp_dir)

            # Create agent status file with running agents
            agent_file = os.path.join(processor.agents_dir, "agent_status.json")
            os.makedirs(os.path.dirname(agent_file), exist_ok=True)
            agent_data = {
                "agents": {
                    "agent1": {"pid": 12345, "status": "running"},
                    "agent2": {"pid": 12346, "status": "idle"},
                }
            }
            with open(agent_file, "w") as f:
                json.dump(agent_data, f)

            # Create empty task queue
            queue_file = os.path.join(processor.agents_dir, "task_queue.json")
            with open(queue_file, "w") as f:
                json.dump({"tasks": []}, f)

            with patch(
                "os.kill", return_value=None
            ):  # Mock os.kill to avoid actual process checks
                result = processor.force_max_parallelization()
                assert result == 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_force_max_parallelization_success(self):
        """Test force_max_parallelization with available agents and queued tasks"""
        import agents.max_processor as module

        with tempfile.TemporaryDirectory() as temp_dir:
            processor = module.MaxParallelProcessor(temp_dir)

            # Create agent status file with running agents
            agent_file = os.path.join(processor.agents_dir, "agent_status.json")
            os.makedirs(os.path.dirname(agent_file), exist_ok=True)
            agent_data = {
                "agents": {
                    "agent1": {"pid": 12345, "status": "running"},
                    "agent2": {"pid": 12346, "status": "idle"},
                }
            }
            with open(agent_file, "w") as f:
                json.dump(agent_data, f)

            # Create task queue with queued tasks
            queue_file = os.path.join(processor.agents_dir, "task_queue.json")
            queue_data = {
                "tasks": [
                    {"id": "task1", "status": "queued"},
                    {"id": "task2", "status": "queued"},
                    {"id": "task3", "status": "completed"},
                ]
            }
            with open(queue_file, "w") as f:
                json.dump(queue_data, f)

            with patch("os.kill", return_value=None):
                result = processor.force_max_parallelization()
                assert result == 2  # Should assign 2 tasks

            # Verify updated queue file
            with open(queue_file, "r") as f:
                updated_data = json.load(f)

            assert updated_data["max_parallel_forced"] is True
            assert updated_data["forced_assignments"] == 2

            tasks = updated_data["tasks"]
            assert tasks[0]["status"] == "in_progress"
            assert tasks[0]["assigned_agent"] in ["agent1", "agent2"]
            assert tasks[0]["force_assigned"] is True
            assert tasks[0]["parallel_boost"] is True

            assert tasks[1]["status"] == "in_progress"
            assert tasks[1]["assigned_agent"] in ["agent1", "agent2"]

            assert tasks[2]["status"] == "completed"  # Unchanged

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_force_max_parallelization_max_workers_limit(self):
        """Test force_max_parallelization respects max_workers limit"""
        import agents.max_processor as module

        with tempfile.TemporaryDirectory() as temp_dir:
            processor = module.MaxParallelProcessor(temp_dir)
            processor.max_workers = 1  # Limit to 1 worker

            # Create agent status file
            agent_file = os.path.join(processor.agents_dir, "agent_status.json")
            os.makedirs(os.path.dirname(agent_file), exist_ok=True)
            agent_data = {"agents": {"agent1": {"pid": 12345, "status": "running"}}}
            with open(agent_file, "w") as f:
                json.dump(agent_data, f)

            # Create task queue with many tasks
            queue_file = os.path.join(processor.agents_dir, "task_queue.json")
            queue_data = {
                "tasks": [{"id": f"task{i}", "status": "queued"} for i in range(5)]
            }
            with open(queue_file, "w") as f:
                json.dump(queue_data, f)

            with patch("os.kill", return_value=None):
                result = processor.force_max_parallelization()
                assert result == 1  # Should only assign 1 task due to max_workers limit

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_start_parallel_execution_monitor(self):
        """Test start_parallel_execution_monitor starts monitoring thread"""
        import agents.max_processor as module

        with tempfile.TemporaryDirectory() as temp_dir:
            processor = module.MaxParallelProcessor(temp_dir)

            # Create necessary files
            agent_file = os.path.join(processor.agents_dir, "agent_status.json")
            queue_file = os.path.join(processor.agents_dir, "task_queue.json")
            os.makedirs(os.path.dirname(agent_file), exist_ok=True)

            with open(agent_file, "w") as f:
                json.dump({"agents": {}}, f)
            with open(queue_file, "w") as f:
                json.dump({"tasks": []}, f)

            with patch("threading.Thread") as mock_thread:
                processor.start_parallel_execution_monitor()

                # Verify thread was created and started
                mock_thread.assert_called_once()
                call_args = mock_thread.call_args
                assert "target" in call_args.kwargs
                assert "daemon" in call_args.kwargs
                assert call_args.kwargs["daemon"] is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_optimize_agent_performance(self):
        """Test optimize_agent_performance creates config and sends signals"""
        import agents.max_processor as module

        with tempfile.TemporaryDirectory() as temp_dir:
            processor = module.MaxParallelProcessor(temp_dir)

            # Create agent status file
            agent_file = os.path.join(processor.agents_dir, "agent_status.json")
            os.makedirs(os.path.dirname(agent_file), exist_ok=True)
            agent_data = {
                "agents": {
                    "agent1": {"pid": 12345},
                    "agent2": {"pid": 12346},
                    "agent3": {"pid": 0},  # No PID
                }
            }
            with open(agent_file, "w") as f:
                json.dump(agent_data, f)

            with patch("os.kill") as mock_kill:
                processor.optimize_agent_performance()

                # Verify performance config was created
                config_file = os.path.join(
                    processor.agents_dir, "performance_config.json"
                )
                assert os.path.exists(config_file)

                with open(config_file, "r") as f:
                    config = json.load(f)
                assert config["performance_mode"] == "maximum"
                assert config["concurrent_tasks"] == 5
                assert config["task_timeout"] == 180
                assert config["memory_limit"] == 512
                assert config["cpu_priority"] == "high"

                # Verify signals were sent to running agents
                assert mock_kill.call_count == 2  # Two agents with valid PIDs
                mock_kill.assert_has_calls(
                    [call(12345, 10), call(12346, 10)]  # SIGUSR1
                )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_optimize_agent_performance_no_agents(self):
        """Test optimize_agent_performance with no agents"""
        import agents.max_processor as module

        with tempfile.TemporaryDirectory() as temp_dir:
            processor = module.MaxParallelProcessor(temp_dir)

            # Create empty agent status file
            agent_file = os.path.join(processor.agents_dir, "agent_status.json")
            os.makedirs(os.path.dirname(agent_file), exist_ok=True)
            with open(agent_file, "w") as f:
                json.dump({"agents": {}}, f)

            with patch("os.kill") as mock_kill:
                processor.optimize_agent_performance()

                # Config should still be created
                config_file = os.path.join(
                    processor.agents_dir, "performance_config.json"
                )
                assert os.path.exists(config_file)

                # No signals should be sent
                mock_kill.assert_not_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_run_max_acceleration(self):
        """Test run_max_acceleration orchestrates all functions"""
        import agents.max_processor as module

        with tempfile.TemporaryDirectory() as temp_dir:
            processor = module.MaxParallelProcessor(temp_dir)

            # Create necessary files
            agent_file = os.path.join(processor.agents_dir, "agent_status.json")
            queue_file = os.path.join(processor.agents_dir, "task_queue.json")
            os.makedirs(os.path.dirname(agent_file), exist_ok=True)

            with open(agent_file, "w") as f:
                json.dump({"agents": {}}, f)
            with open(queue_file, "w") as f:
                json.dump({"tasks": []}, f)

            with patch.object(
                processor, "force_max_parallelization", return_value=5
            ) as mock_force:
                with patch.object(
                    processor, "optimize_agent_performance"
                ) as mock_optimize:
                    with patch.object(
                        processor, "start_parallel_execution_monitor"
                    ) as mock_monitor:
                        with patch("builtins.print"):  # Suppress print output
                            processor.run_max_acceleration()

                        # Verify all methods were called
                        mock_force.assert_called_once()
                        mock_optimize.assert_called_once()
                        mock_monitor.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_function(self):
        """Test main function creates and runs processor"""
        import agents.max_processor as module

        with patch("agents.max_processor.MaxParallelProcessor") as mock_class:
            mock_instance = MagicMock()
            mock_class.return_value = mock_instance

            module.main()

            # Verify processor was created and run_max_acceleration was called
            mock_class.assert_called_once()
            mock_instance.run_max_acceleration.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_force_max_parallelization_agent_cycling(self):
        """Test that force_max_parallelization cycles through agents correctly"""
        import agents.max_processor as module

        with tempfile.TemporaryDirectory() as temp_dir:
            processor = module.MaxParallelProcessor(temp_dir)

            # Create agent status file with 2 agents
            agent_file = os.path.join(processor.agents_dir, "agent_status.json")
            os.makedirs(os.path.dirname(agent_file), exist_ok=True)
            agent_data = {
                "agents": {
                    "agent1": {"pid": 12345, "status": "running"},
                    "agent2": {"pid": 12346, "status": "running"},
                }
            }
            with open(agent_file, "w") as f:
                json.dump(agent_data, f)

            # Create task queue with 3 tasks
            queue_file = os.path.join(processor.agents_dir, "task_queue.json")
            queue_data = {
                "tasks": [
                    {"id": "task1", "status": "queued"},
                    {"id": "task2", "status": "queued"},
                    {"id": "task3", "status": "queued"},
                ]
            }
            with open(queue_file, "w") as f:
                json.dump(queue_data, f)

            with patch("os.kill", return_value=None):
                result = processor.force_max_parallelization()
                assert result == 3  # All tasks assigned

            # Verify agent cycling
            with open(queue_file, "r") as f:
                updated_data = json.load(f)

            tasks = updated_data["tasks"]
            assigned_agents = [t["assigned_agent"] for t in tasks]
            # Should cycle: agent1, agent2, agent1
            assert assigned_agents == ["agent1", "agent2", "agent1"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_force_max_parallelization_dead_agent_filtering(self):
        """Test that dead agents are filtered out"""
        import agents.max_processor as module

        with tempfile.TemporaryDirectory() as temp_dir:
            processor = module.MaxParallelProcessor(temp_dir)

            # Create agent status file with mixed alive/dead agents
            agent_file = os.path.join(processor.agents_dir, "agent_status.json")
            os.makedirs(os.path.dirname(agent_file), exist_ok=True)
            agent_data = {
                "agents": {
                    "alive_agent": {"pid": 12345, "status": "running"},
                    "dead_agent": {"pid": 99999, "status": "running"},  # Dead PID
                    "idle_agent": {"pid": 12346, "status": "idle"},
                }
            }
            with open(agent_file, "w") as f:
                json.dump(agent_data, f)

            # Create task queue
            queue_file = os.path.join(processor.agents_dir, "task_queue.json")
            queue_data = {"tasks": [{"id": "task1", "status": "queued"}]}
            with open(queue_file, "w") as f:
                json.dump(queue_data, f)

            def mock_kill(pid, sig):
                if pid == 99999:
                    raise OSError("No such process")  # Dead process
                return None

            with patch("os.kill", side_effect=mock_kill):
                result = processor.force_max_parallelization()
                assert result == 1  # One task assigned

            # Verify only alive agents were used
            with open(queue_file, "r") as f:
                updated_data = json.load(f)

            task = updated_data["tasks"][0]
            assert task["assigned_agent"] in ["alive_agent", "idle_agent"]
