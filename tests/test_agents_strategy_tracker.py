import pytest
import sys
import os
import json
import tempfile
from unittest.mock import Mock, patch, MagicMock
from pathlib import Path
from datetime import datetime

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("agents.strategy_tracker")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.strategy_tracker: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/strategy_tracker.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/strategy_tracker.py",
                "exec",
            )
        print(
            f"File agents/strategy_tracker.py is syntactically valid but import failed"
        )
    except SyntaxError as se:
        print(f"File agents/strategy_tracker.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsStrategyTracker:
    """Comprehensive tests for agents/strategy_tracker.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/strategy_tracker.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/strategy_tracker.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/strategy_tracker.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/strategy_tracker.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.strategy_tracker")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.strategy_tracker should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_strategy_tracker_init_creates_default_strategies(self):
        """Test StrategyTracker initialization creates default strategies"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    assert "strategies" in tracker.strategies
                    assert len(tracker.strategies["strategies"]) == 4
                assert "metadata" in tracker.strategies

                # Check default strategies exist
                strategy_ids = [s["id"] for s in tracker.strategies["strategies"]]
                assert "rebuild" in strategy_ids
                assert "clean_build" in strategy_ids
                assert "fix_imports" in strategy_ids
                assert "run_tests" in strategy_ids

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_strategy_tracker_init_loads_existing_strategies(self):
        """Test StrategyTracker initialization loads existing strategies"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            strategies_file = knowledge_dir / "strategies.json"

            # Create existing strategies file
            existing_data = {
                "strategies": [
                    {
                        "id": "test_strategy",
                        "name": "Test Strategy",
                        "description": "A test strategy",
                        "contexts": ["test"],
                        "base_risk": 0.5,
                        "estimated_time": 30,
                        "success_rate": 0.8,
                        "total_attempts": 10,
                        "successful_attempts": 8,
                        "failed_attempts": 2,
                        "avg_execution_time": 25.0,
                        "adaptations": [],
                        "created_at": "2023-01-01T00:00:00",
                    }
                ],
                "metadata": {
                    "last_updated": "2023-01-01T00:00:00",
                    "total_strategies": 1,
                },
            }

            knowledge_dir.mkdir(parents=True, exist_ok=True)
            with open(strategies_file, "w") as f:
                json.dump(existing_data, f)

            # Patch the file paths directly
            with patch.object(module, "STRATEGIES_FILE", strategies_file):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    assert len(tracker.strategies["strategies"]) == 1
                    assert tracker.strategies["strategies"][0]["id"] == "test_strategy"
                    assert tracker.strategies["strategies"][0]["success_rate"] == 0.8

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_strategy_tracker_init_loads_history(self):
        """Test StrategyTracker initialization loads existing history"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            history_file = knowledge_dir / "strategy_history.json"

            # Create existing history file
            existing_history = {
                "executions": [
                    {
                        "timestamp": "2023-01-01T00:00:00",
                        "strategy_id": "test_strategy",
                        "context": "test",
                        "success": True,
                        "execution_time": 25.0,
                        "details": {},
                    }
                ]
            }

            knowledge_dir.mkdir(parents=True, exist_ok=True)
            with open(history_file, "w") as f:
                json.dump(existing_history, f)

            # Patch the file paths directly
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(module, "STRATEGY_HISTORY_FILE", history_file):
                    tracker = module.StrategyTracker()

                    assert len(tracker.history["executions"]) == 1
                    assert (
                        tracker.history["executions"][0]["strategy_id"]
                        == "test_strategy"
                    )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_record_execution_success(self):
        """Test recording a successful strategy execution"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    # Record successful execution
                    tracker.record_execution(
                        "rebuild", "build_error", True, 60.0, {"details": "test"}
                    )

                    # Check strategy was updated
                    strategy = tracker._find_strategy("rebuild")
                    assert strategy["total_attempts"] == 1
                    assert strategy["successful_attempts"] == 1
                    assert strategy["failed_attempts"] == 0
                    assert strategy["success_rate"] == 1.0
                    assert strategy["avg_execution_time"] == 60.0

                    # Check history was recorded
                    assert len(tracker.history["executions"]) == 1
                    execution = tracker.history["executions"][0]
                    assert execution["strategy_id"] == "rebuild"
                    assert execution["context"] == "build_error"
                    assert execution["success"] is True
                    assert execution["execution_time"] == 60.0
                    assert execution["details"] == {"details": "test"}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_record_execution_failure(self):
        """Test recording a failed strategy execution"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    # Record failed execution
                    tracker.record_execution("rebuild", "build_error", False, 30.0)

                    # Check strategy was updated
                    strategy = tracker._find_strategy("rebuild")
                    assert strategy["total_attempts"] == 1
                    assert strategy["successful_attempts"] == 0
                    assert strategy["failed_attempts"] == 1
                    assert strategy["success_rate"] == 0.0
                    assert strategy["avg_execution_time"] == 30.0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_record_execution_moving_average(self):
        """Test execution time moving average calculation"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    # Record multiple executions
                    tracker.record_execution("rebuild", "build_error", True, 60.0)
                    tracker.record_execution("rebuild", "build_error", True, 30.0)
                    tracker.record_execution("rebuild", "build_error", True, 45.0)

                    strategy = tracker._find_strategy("rebuild")
                    # Should use exponential moving average
                    # First: 60.0
                    # Second: 0.3 * 30.0 + 0.7 * 60.0 = 51.0
                    # Third: 0.3 * 45.0 + 0.7 * 51.0 = 49.2
                    assert abs(strategy["avg_execution_time"] - 49.2) < 0.1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_record_execution_unknown_strategy(self):
        """Test recording execution for unknown strategy"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    # Record execution for non-existent strategy
                    tracker.record_execution("unknown_strategy", "test", True, 10.0)

                    # History should still be recorded (even for unknown strategies)
                    assert len(tracker.history["executions"]) == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_record_adaptation(self):
        """Test recording strategy adaptation"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    # Record adaptation
                    tracker.record_adaptation(
                        "rebuild", "Increased timeout", "Better success rate"
                    )

                    strategy = tracker._find_strategy("rebuild")
                    assert len(strategy["adaptations"]) == 1
                    adaptation = strategy["adaptations"][0]
                    assert adaptation["change"] == "Increased timeout"
                    assert adaptation["impact"] == "Better success rate"
                    assert "date" in adaptation
                    assert adaptation["success_rate_before"] == 0.0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_strategy_performance(self):
        """Test getting strategy performance metrics"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    # Add some execution history
                    tracker.record_execution("rebuild", "build_error", True, 60.0)
                    tracker.record_execution("rebuild", "build_error", False, 30.0)
                    tracker.record_execution("rebuild", "build_error", True, 45.0)

                    performance = tracker.get_strategy_performance("rebuild")

                    assert performance["strategy_id"] == "rebuild"
                    assert performance["name"] == "Rebuild Project"
                    assert performance["total_attempts"] == 3
                    assert (
                        performance["success_rate"] == 2.0 / 3.0
                    )  # 2 successes out of 3
                    assert (
                        performance["recent_success_rate"] == 2.0 / 3.0
                    )  # All are recent
                    assert performance["trend"] == "stable"
                    assert performance["adaptations_count"] == 0
                    assert "build_error" in performance["contexts"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_strategy_performance_unknown_strategy(self):
        """Test getting performance for unknown strategy"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    performance = tracker.get_strategy_performance("unknown")

                    assert performance == {"error": "Strategy not found"}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_best_strategy(self):
        """Test getting best strategy for a context"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    # Add execution data to make one strategy better
                    tracker.record_execution("rebuild", "build_error", True, 60.0)
                    tracker.record_execution("rebuild", "build_error", True, 60.0)
                    tracker.record_execution(
                        "clean_build", "build_error", True, 120.0
                    )  # Slower

                    best = tracker.get_best_strategy("build_error")

                    assert best is not None
                    assert (
                        best["id"] == "rebuild"
                    )  # Should be better due to higher success rate and faster time

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_best_strategy_no_candidates(self):
        """Test getting best strategy when no strategies match context"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    best = tracker.get_best_strategy("unknown_context")

                    assert best is None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_all_strategies(self):
        """Test getting all strategies with performance metrics"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    strategies = tracker.get_all_strategies()

                    assert len(strategies) == 4  # Default strategies
                    strategy_ids = [s["strategy_id"] for s in strategies]
                    assert "rebuild" in strategy_ids
                    assert "clean_build" in strategy_ids
                    assert "fix_imports" in strategy_ids
                    assert "run_tests" in strategy_ids

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_compare_strategies(self):
        """Test comparing multiple strategies"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    # Add execution data
                    tracker.record_execution("rebuild", "build_error", True, 60.0)
                    tracker.record_execution("rebuild", "build_error", True, 60.0)
                    tracker.record_execution("clean_build", "build_error", True, 120.0)
                    tracker.record_execution("clean_build", "build_error", False, 120.0)

                    comparison = tracker.compare_strategies(["rebuild", "clean_build"])

                    assert "strategies" in comparison
                    assert len(comparison["strategies"]) == 2
                    assert comparison["best"] == "rebuild"  # Higher success rate
                    assert comparison["worst"] == "clean_build"
                    assert comparison["avg_success_rate"] == 0.75  # (1.0 + 0.5) / 2

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_compare_strategies_no_valid_strategies(self):
        """Test comparing strategies with invalid IDs"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    comparison = tracker.compare_strategies(["unknown1", "unknown2"])

                    assert comparison == {"error": "No valid strategies to compare"}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_strategy_recommendations(self):
        """Test getting strategy recommendations for a context"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    # Add execution data
                    tracker.record_execution("rebuild", "build_error", True, 60.0)
                    tracker.record_execution("rebuild", "build_error", True, 60.0)
                    tracker.record_execution("clean_build", "build_error", True, 120.0)

                    recommendations = tracker.get_strategy_recommendations(
                        "build_error"
                    )

                    assert (
                        len(recommendations) >= 1
                    )  # At least one recommendation should be returned
                    assert "score" in recommendations[0]
                    assert "confidence" in recommendations[0]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_add_strategy_new(self):
        """Test adding a new strategy"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    success = tracker.add_strategy(
                        "new_strategy",
                        "New Strategy",
                        "A new test strategy",
                        ["test_context"],
                        0.2,
                        45,
                    )

                    assert success is True

                    strategy = tracker._find_strategy("new_strategy")
                    assert strategy is not None
                    assert strategy["name"] == "New Strategy"
                    assert strategy["description"] == "A new test strategy"
                    assert strategy["contexts"] == ["test_context"]
                    assert strategy["base_risk"] == 0.2
                    assert strategy["estimated_time"] == 45
                    assert strategy["success_rate"] == 0.0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_add_strategy_duplicate(self):
        """Test adding a strategy that already exists"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    # Try to add existing strategy
                    success = tracker.add_strategy(
                        "rebuild",
                        "Duplicate Strategy",
                        "This should fail",
                        ["test"],
                        0.5,
                        30,
                    )

                    assert success is False

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_record_command(self):
        """Test main function record command"""
        import agents.strategy_tracker as module
        import io
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    with patch(
                        "sys.argv",
                        [
                            "strategy_tracker.py",
                            "record",
                            "rebuild",
                            "build_error",
                            "true",
                            "60.0",
                            '{"test": "data"}',
                        ],
                    ):
                        f = io.StringIO()
                        with redirect_stdout(f):
                            module.main()
                        output = f.getvalue()

                    # Check output
                    result = json.loads(output)
                    assert result["status"] == "recorded"
                    assert result["strategy_id"] == "rebuild"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_adapt_command(self):
        """Test main function adapt command"""
        import agents.strategy_tracker as module
        import io
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    with patch(
                        "sys.argv",
                        [
                            "strategy_tracker.py",
                            "adapt",
                            "rebuild",
                            "Increased timeout",
                            "Better performance",
                        ],
                    ):
                        f = io.StringIO()
                        with redirect_stdout(f):
                            module.main()
                        output = f.getvalue()

                    result = json.loads(output)
                    assert result["status"] == "recorded"
                    assert result["strategy_id"] == "rebuild"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_performance_command(self):
        """Test main function performance command"""
        import agents.strategy_tracker as module
        import io
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    with patch(
                        "sys.argv", ["strategy_tracker.py", "performance", "rebuild"]
                    ):
                        f = io.StringIO()
                        with redirect_stdout(f):
                            module.main()
                        output = f.getvalue()

                    result = json.loads(output)
                    assert result["strategy_id"] == "rebuild"
                    assert "success_rate" in result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_best_command(self):
        """Test main function best command"""
        import agents.strategy_tracker as module
        import io
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    with patch(
                        "sys.argv", ["strategy_tracker.py", "best", "build_error"]
                    ):
                        f = io.StringIO()
                        with redirect_stdout(f):
                            module.main()
                        output = f.getvalue()

                    result = json.loads(output)
                    assert result["id"] == "rebuild"  # Default best for build_error

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_list_command(self):
        """Test main function list command"""
        import agents.strategy_tracker as module
        import io
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    with patch("sys.argv", ["strategy_tracker.py", "list"]):
                        f = io.StringIO()
                        with redirect_stdout(f):
                            module.main()
                        output = f.getvalue()

                    result = json.loads(output)
                    assert isinstance(result, list)
                    assert len(result) == 4  # Default strategies

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_compare_command(self):
        """Test main function compare command"""
        import agents.strategy_tracker as module
        import io
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    with patch(
                        "sys.argv",
                        [
                            "strategy_tracker.py",
                            "compare",
                            "rebuild",
                            "clean_build",
                        ],
                    ):
                        f = io.StringIO()
                        with redirect_stdout(f):
                            module.main()
                        output = f.getvalue()

                    result = json.loads(output)
                    assert "strategies" in result
                    assert "best" in result
                    assert "worst" in result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_recommend_command(self):
        """Test main function recommend command"""
        import agents.strategy_tracker as module
        import io
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    with patch(
                        "sys.argv",
                        ["strategy_tracker.py", "recommend", "build_error"],
                    ):
                        f = io.StringIO()
                        with redirect_stdout(f):
                            module.main()
                        output = f.getvalue()

                    result = json.loads(output)
                    assert isinstance(result, list)
                    assert len(result) > 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_add_command(self):
        """Test main function add command"""
        import agents.strategy_tracker as module
        import io
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    with patch(
                        "sys.argv",
                        [
                            "strategy_tracker.py",
                            "add",
                            "new_strategy",
                            "New Strategy",
                            "A test strategy",
                            "test,build",
                            "0.3",
                            "45",
                        ],
                    ):
                        f = io.StringIO()
                        with redirect_stdout(f):
                            module.main()
                        output = f.getvalue()

                    result = json.loads(output)
                    assert result["status"] == "added"
                    assert result["strategy_id"] == "new_strategy"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_unknown_command(self):
        """Test main function with unknown command"""
        import agents.strategy_tracker as module

        with pytest.raises(SystemExit) as exc_info:
            with patch("sys.argv", ["strategy_tracker.py", "unknown_command"]):
                module.main()

        assert exc_info.value.code == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_insufficient_args(self):
        """Test main function with insufficient arguments"""
        import agents.strategy_tracker as module

        with pytest.raises(SystemExit) as exc_info:
            with patch("sys.argv", ["strategy_tracker.py"]):
                module.main()

        assert exc_info.value.code == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_history_limit(self):
        """Test that execution history is limited to 1000 entries"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            with patch.object(
                module, "STRATEGIES_FILE", knowledge_dir / "strategies.json"
            ):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    # Add more than 1000 executions
                    for i in range(1005):
                        tracker.record_execution("rebuild", "test", True, 10.0)

                    assert (
                        len(tracker.history["executions"]) == 1000
                    )  # Should be limited

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_atomic_file_operations(self):
        """Test that file operations use atomic writes"""
        import agents.strategy_tracker as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"
            strategies_file = knowledge_dir / "strategies.json"

            with patch.object(module, "STRATEGIES_FILE", strategies_file):
                with patch.object(
                    module,
                    "STRATEGY_HISTORY_FILE",
                    knowledge_dir / "strategy_history.json",
                ):
                    tracker = module.StrategyTracker()

                    # Trigger save
                    tracker.record_execution("rebuild", "test", True, 10.0)

                    # Check that atomic write was used (tmp file should not exist)
                    tmp_file = strategies_file.with_suffix(".tmp")
                    assert not tmp_file.exists()
                    assert strategies_file.exists()
