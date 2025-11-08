import pytest
import sys
import os
import json
import tempfile
from unittest.mock import Mock, patch, MagicMock, mock_open

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import agents.agent_optimizer as agent_optimizer


class TestAgentOptimizer:
    """Comprehensive tests for agents/agent_optimizer.py"""

    def test_init(self):
        """Test AgentOptimizer initialization"""
        optimizer = agent_optimizer.AgentOptimizer("/test/workspace")
        assert optimizer.workspace_root == "/test/workspace"
        assert optimizer.agents_dir == "/test/workspace/Tools/Automation/agents"
        assert (
            optimizer.agent_status_file
            == "/test/workspace/Tools/Automation/agents/agent_status.json"
        )
        assert (
            optimizer.task_queue_file
            == "/test/workspace/Tools/Automation/agents/task_queue.json"
        )

    @patch(
        "builtins.open",
        new_callable=mock_open,
        read_data='{"agents": {"agent1": {"status": "running"}}}',
    )
    def test_load_agent_status_success(self, mock_file):
        """Test loading agent status successfully"""
        optimizer = agent_optimizer.AgentOptimizer()
        result = optimizer.load_agent_status()
        assert result == {"agent1": {"status": "running"}}
        mock_file.assert_called_once_with(optimizer.agent_status_file, "r")

    @patch("builtins.open", side_effect=FileNotFoundError)
    def test_load_agent_status_file_not_found(self, mock_file):
        """Test loading agent status when file doesn't exist"""
        optimizer = agent_optimizer.AgentOptimizer()
        result = optimizer.load_agent_status()
        assert result == {}

    @patch(
        "builtins.open",
        new_callable=mock_open,
        read_data='{"tasks": [{"id": 1, "status": "pending"}]}',
    )
    def test_load_tasks_success(self, mock_file):
        """Test loading tasks successfully"""
        optimizer = agent_optimizer.AgentOptimizer()
        result = optimizer.load_tasks()
        assert result == [{"id": 1, "status": "pending"}]
        mock_file.assert_called_once_with(optimizer.task_queue_file, "r")

    @patch("builtins.open", side_effect=FileNotFoundError)
    def test_load_tasks_file_not_found(self, mock_file):
        """Test loading tasks when file doesn't exist"""
        optimizer = agent_optimizer.AgentOptimizer()
        result = optimizer.load_tasks()
        assert result == []

    @patch("agents.agent_optimizer.AgentOptimizer.load_agent_status")
    @patch("subprocess.run")
    @patch("os.kill")
    @patch("time.sleep")
    def test_optimize_agent_memory_high_usage(
        self, mock_sleep, mock_kill, mock_subprocess, mock_load_status
    ):
        """Test optimizing agent memory with high usage agents"""
        mock_load_status.return_value = {
            "agent1": {"pid": 1234, "status": "running"},
            "agent2": {"pid": 5678, "status": "running"},
        }

        # Mock subprocess to return high memory usage
        mock_process = Mock()
        mock_process.returncode = 0
        mock_process.stdout = "512001\n"  # 512.001MB in KB, with newline
        mock_subprocess.return_value = mock_process

        optimizer = agent_optimizer.AgentOptimizer()
        result = optimizer.optimize_agent_memory()

        assert result == 2  # Both agents should be optimized
        assert mock_kill.call_count == 2
        mock_sleep.assert_called_with(2)

    @patch("agents.agent_optimizer.AgentOptimizer.load_agent_status")
    @patch("subprocess.run")
    def test_optimize_agent_memory_low_usage(self, mock_subprocess, mock_load_status):
        """Test optimizing agent memory with low usage agents"""
        mock_load_status.return_value = {"agent1": {"pid": 1234, "status": "running"}}

        # Mock subprocess to return low memory usage
        mock_process = Mock()
        mock_process.returncode = 0
        mock_process.stdout = "100000"  # 100MB in KB
        mock_subprocess.return_value = mock_process

        optimizer = agent_optimizer.AgentOptimizer()
        result = optimizer.optimize_agent_memory()

        assert result == 0  # No agents should be optimized

    @patch("agents.agent_optimizer.AgentOptimizer.load_agent_status")
    @patch("agents.agent_optimizer.AgentOptimizer.load_tasks")
    @patch("subprocess.run")
    @patch("os.path.exists")
    def test_parallelize_agent_tasks(
        self, mock_exists, mock_subprocess, mock_load_tasks, mock_load_status
    ):
        """Test parallelizing agent tasks"""
        mock_load_status.return_value = {
            "agent1": {"status": "running"},
            "agent2": {"status": "running"},
        }
        mock_load_tasks.return_value = [
            {"id": 1, "status": "in_progress", "assigned_agent": "agent1"},
            {"id": 2, "status": "in_progress", "assigned_agent": "agent1"},
            {"id": 3, "status": "in_progress", "assigned_agent": "agent2"},
        ]
        mock_exists.return_value = True

        optimizer = agent_optimizer.AgentOptimizer()
        result = optimizer.parallelize_agent_tasks()

        assert result == 1  # Only agent1 has multiple tasks
        mock_subprocess.assert_called_once()

    @patch("agents.agent_optimizer.AgentOptimizer.load_agent_status")
    @patch("agents.agent_optimizer.AgentOptimizer.load_tasks")
    @patch("builtins.open", new_callable=mock_open)
    @patch("json.dump")
    def test_optimize_task_distribution(
        self, mock_json_dump, mock_file, mock_load_tasks, mock_load_status
    ):
        """Test optimizing task distribution for load balancing"""
        mock_load_status.return_value = {
            "agent1": {"status": "available"},
            "agent2": {"status": "available"},
            "agent3": {"status": "available"},
        }
        tasks = [
            {"id": 1, "status": "in_progress", "assigned_agent": "agent1"},
            {"id": 2, "status": "in_progress", "assigned_agent": "agent1"},
            {"id": 3, "status": "in_progress", "assigned_agent": "agent1"},
            {
                "id": 4,
                "status": "in_progress",
                "assigned_agent": "agent1",
            },  # Overloaded
            {"id": 5, "status": "in_progress", "assigned_agent": "agent2"},
        ]
        mock_load_tasks.return_value = tasks

        # Mock the file reading for saving
        mock_file.return_value.read.return_value = '{"tasks": []}'

        optimizer = agent_optimizer.AgentOptimizer()
        result = optimizer.optimize_task_distribution()

        assert result == 1  # One task should be redistributed
        mock_json_dump.assert_called_once()

    @patch("agents.agent_optimizer.AgentOptimizer.load_agent_status")
    @patch("agents.agent_optimizer.AgentOptimizer.load_tasks")
    @patch("builtins.open", new_callable=mock_open)
    @patch("json.dump")
    def test_enable_agent_specialization(
        self, mock_json_dump, mock_file, mock_load_tasks, mock_load_status
    ):
        """Test enabling agent specialization"""
        mock_load_status.return_value = {
            "agent1": {"status": "running"},
            "agent2": {"status": "running"},
        }
        tasks = [
            {
                "id": 1,
                "status": "completed",
                "assigned_agent": "agent1",
                "type": "analysis",
            },
            {
                "id": 2,
                "status": "completed",
                "assigned_agent": "agent1",
                "type": "analysis",
            },
            {
                "id": 3,
                "status": "completed",
                "assigned_agent": "agent1",
                "type": "analysis",
            },
            {"id": 4, "status": "queued", "type": "analysis"},
        ]
        mock_load_tasks.return_value = tasks

        # Mock the file reading for saving
        mock_file.return_value.read.return_value = '{"tasks": []}'

        optimizer = agent_optimizer.AgentOptimizer()
        result = optimizer.enable_agent_specialization()

        assert result == 1  # One task should be specialized
        mock_json_dump.assert_called_once()

    @patch("agents.agent_optimizer.AgentOptimizer.optimize_agent_memory")
    @patch("agents.agent_optimizer.AgentOptimizer.parallelize_agent_tasks")
    @patch("agents.agent_optimizer.AgentOptimizer.optimize_task_distribution")
    @patch("agents.agent_optimizer.AgentOptimizer.enable_agent_specialization")
    def test_run_optimization_cycle(
        self, mock_specialize, mock_balance, mock_parallel, mock_memory
    ):
        """Test running complete optimization cycle"""
        optimizer = agent_optimizer.AgentOptimizer()
        optimizer.run_optimization_cycle()

        mock_memory.assert_called_once()
        mock_parallel.assert_called_once()
        mock_balance.assert_called_once()
        mock_specialize.assert_called_once()

    @patch("sys.argv", ["agent_optimizer.py", "memory"])
    @patch("agents.agent_optimizer.AgentOptimizer.optimize_agent_memory")
    def test_main_memory_command(self, mock_memory):
        """Test main function with memory command"""
        agent_optimizer.main()
        mock_memory.assert_called_once()

    @patch("sys.argv", ["agent_optimizer.py", "parallel"])
    @patch("agents.agent_optimizer.AgentOptimizer.parallelize_agent_tasks")
    def test_main_parallel_command(self, mock_parallel):
        """Test main function with parallel command"""
        agent_optimizer.main()
        mock_parallel.assert_called_once()

    @patch("sys.argv", ["agent_optimizer.py", "balance"])
    @patch("agents.agent_optimizer.AgentOptimizer.optimize_task_distribution")
    def test_main_balance_command(self, mock_balance):
        """Test main function with balance command"""
        agent_optimizer.main()
        mock_balance.assert_called_once()

    @patch("sys.argv", ["agent_optimizer.py", "specialize"])
    @patch("agents.agent_optimizer.AgentOptimizer.enable_agent_specialization")
    def test_main_specialize_command(self, mock_specialize):
        """Test main function with specialize command"""
        agent_optimizer.main()
        mock_specialize.assert_called_once()

    @patch("sys.argv", ["agent_optimizer.py", "cycle"])
    @patch("agents.agent_optimizer.AgentOptimizer.run_optimization_cycle")
    def test_main_cycle_command(self, mock_cycle):
        """Test main function with cycle command"""
        agent_optimizer.main()
        mock_cycle.assert_called_once()

    @patch("sys.argv", ["agent_optimizer.py"])
    @patch("agents.agent_optimizer.AgentOptimizer.run_optimization_cycle")
    def test_main_no_args(self, mock_cycle):
        """Test main function with no arguments"""
        agent_optimizer.main()
        mock_cycle.assert_called_once()

    @patch("sys.argv", ["agent_optimizer.py", "invalid"])
    def test_main_invalid_command(self, capsys):
        """Test main function with invalid command"""
        agent_optimizer.main()
        captured = capsys.readouterr()
        assert "Usage: python3 agent_optimizer.py" in captured.out
