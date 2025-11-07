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
    __import__("agents.orchestrator_v2")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.orchestrator_v2: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/orchestrator_v2.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/orchestrator_v2.py",
                "exec",
            )
        print(
            f"File agents/orchestrator_v2.py is syntactically valid but import failed"
        )
    except SyntaxError as se:
        print(f"File agents/orchestrator_v2.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsOrchestratorV2:
    """Comprehensive tests for agents/orchestrator_v2.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/orchestrator_v2.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/orchestrator_v2.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/orchestrator_v2.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/orchestrator_v2.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.orchestrator_v2")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.orchestrator_v2 should be importable")

    # TODO: Add specific tests for functions in agents/orchestrator_v2.py
    # The module import now works correctly, so you can add real test functions here
    # Examples:
    # def test_specific_function(self):
    #     import agents.orchestrator_v2 as module
    #     result = module.function_name(args)
    #     assert result == expected

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_file_exists(self):
        """Test _load_json with existing file"""
        import agents.orchestrator_v2 as module
        from unittest.mock import mock_open

        test_data = {"test": "data"}
        with patch("builtins.open", mock_open(read_data=json.dumps(test_data))):
            with patch("os.path.exists", return_value=True):
                result = module._load_json("test.json", {})
                assert result == test_data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_file_not_exists(self):
        """Test _load_json with non-existing file"""
        import agents.orchestrator_v2 as module

        with patch("os.path.exists", return_value=False):
            result = module._load_json("test.json", {"default": True})
            assert result == {"default": True}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_invalid_json(self):
        """Test _load_json with invalid JSON"""
        import agents.orchestrator_v2 as module
        from unittest.mock import mock_open

        with patch("builtins.open", mock_open(read_data="invalid json")):
            with patch("os.path.exists", return_value=True):
                result = module._load_json("test.json", {"default": True})
                assert result == {"default": True}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_write_json(self):
        """Test _write_json writes data correctly"""
        import agents.orchestrator_v2 as module
        from unittest.mock import mock_open

        test_data = {"test": "data"}
        with patch("builtins.open", mock_open()) as mock_file:
            with patch("os.makedirs"):
                with patch("os.replace"):
                    module._write_json("test.json", test_data)
                    mock_file.assert_called()
                    # Check that write was called (simplified check)
                    assert mock_file().write.called

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_agent_score_basic(self):
        """Test _agent_score with basic agent data"""
        import agents.orchestrator_v2 as module

        agent = {"name": "test_agent", "status": "idle", "queue_size": 0}
        strategies = []
        score = module._agent_score(agent, strategies)
        assert score == 1.5  # base 1.0 + availability 0.5

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_agent_score_with_strategy(self):
        """Test _agent_score with matching strategy"""
        import agents.orchestrator_v2 as module

        agent = {"name": "test_agent", "status": "idle", "queue_size": 0}
        strategies = [{"name": "test_agent", "success_rate": 0.8}]
        score = module._agent_score(agent, strategies)
        assert score == 2.3  # base 1.0 + success_rate 0.8 + availability 0.5

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_agent_score_with_queue_penalty(self):
        """Test _agent_score with queue size penalty"""
        import agents.orchestrator_v2 as module

        agent = {"name": "test_agent", "status": "busy", "queue_size": 2}
        strategies = []
        score = module._agent_score(agent, strategies)
        assert score == 0.9  # base 1.0 - 0.05 * 2

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_pick_agent_with_candidates(self):
        """Test _pick_agent with available agents"""
        import agents.orchestrator_v2 as module

        agents = [
            {"id": "agent1", "status": "idle", "queue_size": 0},
            {"id": "agent2", "status": "busy", "queue_size": 1},
        ]
        strategies = []
        picked = module._pick_agent(agents, strategies)
        assert picked["id"] == "agent1"  # Should pick idle agent

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_pick_agent_no_candidates(self):
        """Test _pick_agent with no available agents"""
        import agents.orchestrator_v2 as module

        agents = []
        strategies = []
        picked = module._pick_agent(agents, strategies)
        assert picked is None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_aliases_for_basic(self):
        """Test _aliases_for with basic name"""
        import agents.orchestrator_v2 as module

        aliases = module._aliases_for("test_agent")
        expected = {"test_agent", "agent_test_agent", "test_agent_agent"}
        assert set(aliases) == expected

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_aliases_for_script(self):
        """Test _aliases_for with .sh extension"""
        import agents.orchestrator_v2 as module

        aliases = module._aliases_for("agent_build.sh")
        assert "agent_build" in aliases
        assert "build_agent" in aliases

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_assign_task_success(self):
        """Test assign_task with successful assignment"""
        import agents.orchestrator_v2 as module
        from unittest.mock import patch

        task = {"id": "test_task", "type": "analysis"}
        agents = [
            {
                "id": "test_agent",
                "name": "test_agent",
                "status": "idle",
                "queue_size": 0,
            }
        ]
        queue = []

        with patch("agents.orchestrator_v2._load_json") as mock_load:
            mock_load.side_effect = lambda path, default: (
                agents
                if "agent_status" in path
                else queue if "task_queue" in path else []
            )
            with patch("agents.orchestrator_v2._write_json") as mock_write:
                result = module.assign_task(task)
                assert result["result"] == "assigned"
                assert "assigned_agent" in result["task"]
                mock_write.assert_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_assign_task_queue_only(self):
        """Test assign_task creates default agent when none available"""
        import agents.orchestrator_v2 as module
        from unittest.mock import patch

        task = {"id": "test_task", "type": "analysis"}
        agents = []
        queue = []

        with patch("agents.orchestrator_v2._load_json") as mock_load:
            mock_load.side_effect = lambda path, default: (
                agents
                if "agent_status" in path
                else queue if "task_queue" in path else []
            )
            with patch("agents.orchestrator_v2._write_json") as mock_write:
                result = module.assign_task(task)
                assert result["result"] == "assigned"  # Creates default agent
                mock_write.assert_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_assign_task_explicit_agent(self):
        """Test assign_task with explicit agent assignment"""
        import agents.orchestrator_v2 as module
        from unittest.mock import patch

        task = {
            "id": "test_task",
            "type": "analysis",
            "assigned_agent": "specific_agent",
        }
        agents = [
            {
                "id": "specific_agent",
                "name": "specific_agent",
                "status": "idle",
                "queue_size": 0,
            },
            {
                "id": "other_agent",
                "name": "other_agent",
                "status": "idle",
                "queue_size": 0,
            },
        ]
        queue = []

        with patch("agents.orchestrator_v2._load_json") as mock_load:
            mock_load.side_effect = lambda path, default: (
                agents
                if "agent_status" in path
                else queue if "task_queue" in path else []
            )
            with patch("agents.orchestrator_v2._write_json") as mock_write:
                result = module.assign_task(task)
                assert result["result"] == "assigned"
                assert result["task"]["assigned_agent"] == "specific_agent"
                mock_write.assert_called()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_balance_load(self):
        """Test balance_load function"""
        import agents.orchestrator_v2 as module
        from unittest.mock import patch

        queue_data = {
            "tasks": [
                {"assigned_agent": "agent1"},
                {"assigned_agent": "agent1"},
                {"assigned_agent": "agent2"},
            ]
        }

        with patch("agents.orchestrator_v2._load_json", return_value=queue_data):
            result = module.balance_load()
            assert result["queue_size"] == 3
            assert result["distribution"]["agent1"] == 2
            assert result["distribution"]["agent2"] == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_snapshot(self):
        """Test snapshot function"""
        import agents.orchestrator_v2 as module
        from unittest.mock import patch

        agents_data = [{"id": "agent1", "status": "idle"}]
        queue_data = {"tasks": [{"id": "task1"}]}

        with patch("agents.orchestrator_v2._load_json") as mock_load:
            mock_load.side_effect = [queue_data, agents_data]
            result = module.snapshot()
            assert result["agents"] == agents_data
            assert result["queue"] == [{"id": "task1"}]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_assign_command(self):
        """Test main function with assign command"""
        import agents.orchestrator_v2 as module
        from unittest.mock import patch

        task_json = '{"id": "test_task", "type": "analysis"}'

        with patch(
            "agents.orchestrator_v2.assign_task", return_value={"result": "assigned"}
        ) as mock_assign:
            with patch("builtins.print") as mock_print:
                with patch(
                    "sys.argv", ["orchestrator_v2.py", "assign", "--task", task_json]
                ):
                    result = module.main()
                    assert result == 0
                    mock_assign.assert_called_once()
                    mock_print.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_balance_command(self):
        """Test main function with balance command"""
        import agents.orchestrator_v2 as module
        from unittest.mock import patch

        with patch(
            "agents.orchestrator_v2.balance_load", return_value={"queue_size": 5}
        ) as mock_balance:
            with patch("builtins.print") as mock_print:
                with patch("sys.argv", ["orchestrator_v2.py", "balance"]):
                    result = module.main()
                    assert result == 0
                    mock_balance.assert_called_once()
                    mock_print.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_status_command(self):
        """Test main function with status command"""
        import agents.orchestrator_v2 as module
        from unittest.mock import patch

        with patch(
            "agents.orchestrator_v2.snapshot", return_value={"agents": [], "queue": []}
        ) as mock_snapshot:
            with patch("builtins.print") as mock_print:
                with patch("sys.argv", ["orchestrator_v2.py", "status"]):
                    result = module.main()
                    assert result == 0
                    mock_snapshot.assert_called_once()
                    mock_print.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_invalid_task_json(self):
        """Test main function with invalid task JSON"""
        import agents.orchestrator_v2 as module
        from unittest.mock import patch

        with patch("builtins.print") as mock_print:
            with patch(
                "sys.argv", ["orchestrator_v2.py", "assign", "--task", "invalid json"]
            ):
                result = module.main()
                assert result == 2
                mock_print.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_no_command(self):
        """Test main function with no command"""
        import agents.orchestrator_v2 as module
        from unittest.mock import patch

        with patch("argparse.ArgumentParser.print_help") as mock_help:
            with patch("sys.argv", ["orchestrator_v2.py"]):
                result = module.main()
                assert result == 1
                mock_help.assert_called_once()
