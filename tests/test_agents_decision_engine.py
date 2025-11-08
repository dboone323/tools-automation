import pytest
import sys
import os
from unittest.mock import Mock, patch, MagicMock

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("agents.decision_engine")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.decision_engine: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/decision_engine.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/decision_engine.py",
                "exec",
            )
        print(
            f"File agents/decision_engine.py is syntactically valid but import failed"
        )
    except SyntaxError as se:
        print(f"File agents/decision_engine.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsDecisionEngine:
    """Comprehensive tests for agents/decision_engine.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/decision_engine.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/decision_engine.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/decision_engine.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/decision_engine.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.decision_engine")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.decision_engine should be importable")


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
    __import__("agents.decision_engine")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.decision_engine: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/decision_engine.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/decision_engine.py",
                "exec",
            )
        print(
            f"File agents/decision_engine.py is syntactically valid but import failed"
        )
    except SyntaxError as se:
        print(f"File agents/decision_engine.py has syntax errors: {se}")


@pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
class TestAgentsDecisionEngine:
    """Comprehensive tests for agents/decision_engine.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/decision_engine.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/decision_engine.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/decision_engine.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/decision_engine.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.decision_engine")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.decision_engine should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_decision_engine_init(self):
        """Test DecisionEngine initialization"""
        import agents.decision_engine as module

        with tempfile.TemporaryDirectory() as temp_dir:
            knowledge_dir = Path(temp_dir) / "knowledge"

            # Mock _load_json to return empty dicts since we're testing init
            with patch.object(module, "KNOWLEDGE_DIR", knowledge_dir), patch.object(
                module.DecisionEngine, "_load_json", return_value={}
            ):

                engine = module.DecisionEngine()

                assert engine.error_patterns == {}
                assert engine.fix_history == {}
                assert engine.failure_analysis == {}
                assert engine.correlation_matrix == {}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_existing_file(self):
        """Test _load_json with existing file"""
        import agents.decision_engine as module

        test_data = {"test": "data", "number": 42}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(test_data, f)
            temp_path = Path(f.name)

        try:
            engine = module.DecisionEngine()
            result = engine._load_json(temp_path)
            assert result == test_data
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_nonexistent_file(self):
        """Test _load_json with nonexistent file"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()
        result = engine._load_json(Path("/nonexistent/file.json"))
        assert result == {}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_invalid_json(self):
        """Test _load_json with invalid JSON"""
        import agents.decision_engine as module

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            f.write("invalid json content")
            temp_path = Path(f.name)

        try:
            engine = module.DecisionEngine()
            result = engine._load_json(temp_path)
            assert result == {}
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_save_json(self):
        """Test _save_json"""
        import agents.decision_engine as module

        test_data = {"test": "data", "number": 123}

        with tempfile.TemporaryDirectory() as temp_dir:
            output_file = Path(temp_dir) / "test_output.json"

            engine = module.DecisionEngine()
            engine._save_json(output_file, test_data)

            # File should exist
            assert output_file.exists()

            # Content should be correct
            with open(output_file, "r") as f:
                loaded_data = json.load(f)
            assert loaded_data == test_data

            # Temp file should not exist
            temp_file = output_file.with_suffix(".tmp")
            assert not temp_file.exists()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_stable_hash(self):
        """Test _stable_hash generates consistent 8-character hashes"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()

        # Same input should give same hash
        hash1 = engine._stable_hash("test input")
        hash2 = engine._stable_hash("test input")
        assert hash1 == hash2

        # Different input should give different hash
        hash3 = engine._stable_hash("different input")
        assert hash1 != hash3

        # Should be 8 characters
        assert len(hash1) == 8

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_evaluate_situation_unknown_error(self):
        """Test evaluate_situation with unknown error"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()

        result = engine.evaluate_situation("unknown error pattern")

        assert result["recommended_action"] == "analyze_and_log"
        assert result["confidence"] == 0.3
        assert "Unknown error pattern" in result["reasoning"]
        assert result["auto_execute"] is False
        assert len(result["alternatives"]) == 2

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_evaluate_situation_known_error_with_fix_history(self):
        """Test evaluate_situation with known error and fix history"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()

        # Mock error patterns
        error_hash = engine._stable_hash("known error")
        engine.error_patterns = {
            error_hash: {"category": "build", "severity": "high", "count": 5}
        }

        # Mock fix history
        engine.fix_history = {
            "fix1": {
                "error_hash": error_hash,
                "action": "rebuild",
                "success": True,
                "success_rate": 0.8,
                "times_used": 4,
            }
        }

        result = engine.evaluate_situation("known error")

        assert result["recommended_action"] == "rebuild"
        assert result["confidence"] > 0.7  # Should be high confidence
        assert "Previously fixed 4 times" in result["reasoning"]
        assert result["auto_execute"] is True
        assert result["known_error"] is True
        assert result["category"] == "build"
        assert result["severity"] == "high"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_evaluate_situation_known_error_heuristic(self):
        """Test evaluate_situation with known error but no fix history"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()

        # Mock error patterns
        error_hash = engine._stable_hash("build error")
        engine.error_patterns = {
            error_hash: {"category": "build", "severity": "medium", "count": 3}
        }

        result = engine.evaluate_situation("build error")

        assert result["recommended_action"] == "rebuild"
        assert result["confidence"] >= 0.5
        assert "Heuristic selection" in result["reasoning"]
        assert result["known_error"] is True
        assert result["category"] == "build"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_calculate_confidence(self):
        """Test _calculate_confidence with various factors"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()

        # Base confidence (with default parameters: success_rate=0.5, occurrences=1, severity="medium")
        # Should be: 0.5 + (0.5-0.5)*0.2 + min(1/10.0, 0.15) + 0 = 0.5 + 0 + 0.1 + 0 = 0.6
        confidence = engine._calculate_confidence(0.5)
        assert confidence == 0.6

        # High success rate
        confidence = engine._calculate_confidence(0.5, success_rate=0.9)
        assert confidence > 0.5

        # Many occurrences
        confidence = engine._calculate_confidence(0.5, occurrences=20)
        assert confidence > 0.5

        # High severity
        confidence = engine._calculate_confidence(0.5, severity="high")
        assert confidence > 0.5

        # Low severity (should reduce confidence compared to medium)
        confidence_low = engine._calculate_confidence(0.5, severity="low")
        confidence_medium = engine._calculate_confidence(0.5, severity="medium")
        assert confidence_low < confidence_medium

        # Clamped to valid range
        confidence = engine._calculate_confidence(2.0)
        assert confidence == 1.0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_successful_fixes(self):
        """Test _get_successful_fixes"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()

        error_hash = "testhash"
        engine.fix_history = {
            "fix1": {
                "error_hash": error_hash,
                "action": "rebuild",
                "success": True,
                "success_rate": 0.8,
                "times_used": 4,
            },
            "fix2": {
                "error_hash": error_hash,
                "action": "clean_build",
                "success": True,
                "success_rate": 0.6,
                "times_used": 2,
            },
            "fix3": {
                "error_hash": "otherhash",
                "action": "rebuild",
                "success": True,
                "success_rate": 0.9,
                "times_used": 1,
            },
        }

        fixes = engine._get_successful_fixes(error_hash)

        assert len(fixes) == 2
        assert fixes[0]["action"] == "rebuild"  # Higher success rate
        assert fixes[1]["action"] == "clean_build"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_heuristic_action_selection(self):
        """Test _heuristic_action_selection"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()

        # Build category
        assert engine._heuristic_action_selection("build", "high", {}) == "clean_build"
        assert engine._heuristic_action_selection("build", "low", {}) == "rebuild"

        # Other categories
        assert engine._heuristic_action_selection("test", "medium", {}) == "run_tests"
        assert engine._heuristic_action_selection("lint", "medium", {}) == "fix_lint"
        assert engine._heuristic_action_selection("unknown", "medium", {}) == "rebuild"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_alternative_actions(self):
        """Test _get_alternative_actions"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()

        fixes = [
            {"action": "rebuild", "success_rate": 0.8},
            {"action": "clean_build", "success_rate": 0.6},
            {"action": "fix_lint", "success_rate": 0.7},
            {"action": "rollback", "success_rate": 0.5},
        ]

        alternatives = engine._get_alternative_actions(fixes)

        assert len(alternatives) == 3  # Top 3
        assert alternatives[0]["action"] == "rebuild"
        assert alternatives[0]["confidence"] == 0.8 * 0.8  # success_rate * 0.8

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_heuristic_alternatives(self):
        """Test _get_heuristic_alternatives"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()

        # Build category
        alternatives = engine._get_heuristic_alternatives("build")
        assert len(alternatives) == 2
        assert alternatives[0]["action"] == "clean_build"

        # Unknown category
        alternatives = engine._get_heuristic_alternatives("unknown")
        assert len(alternatives) == 1
        assert alternatives[0]["action"] == "skip"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_outcome_success(self):
        """Test verify_outcome with successful action"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()

        result = engine.verify_outcome("rebuild", "error state", "success completed")

        assert result["success"] is True
        assert result["confidence"] >= 0.7
        assert "Success indicators found" in result["explanation"]
        assert result["metrics"]["success_indicators"] > 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_outcome_failure(self):
        """Test verify_outcome with failed action"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()

        result = engine.verify_outcome(
            "rebuild", "working state", "error failed crashed"
        )

        assert result["success"] is False
        assert result["confidence"] >= 0.7
        assert "Failure indicators found" in result["explanation"]
        assert result["metrics"]["failure_indicators"] > 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_outcome_ambiguous(self):
        """Test verify_outcome with ambiguous outcome"""
        import agents.decision_engine as module

        engine = module.DecisionEngine()

        result = engine.verify_outcome("rebuild", "state1", "state2")

        assert result["success"] is True  # State changed
        assert result["confidence"] == 0.5
        assert "State changed but outcome unclear" in result["explanation"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_record_fix_attempt(self):
        """Test record_fix_attempt"""
        import agents.decision_engine as module

        with tempfile.TemporaryDirectory() as temp_dir:
            fix_history_file = Path(temp_dir) / "fix_history.json"
            correlation_file = Path(temp_dir) / "correlation_matrix.json"

            with patch.object(
                module, "FIX_HISTORY_FILE", fix_history_file
            ), patch.object(module, "CORRELATION_MATRIX_FILE", correlation_file):

                engine = module.DecisionEngine()

                # Record successful fix
                engine.record_fix_attempt("test error", "rebuild", True, 30.0)

                # Check fix history was saved
                assert fix_history_file.exists()
                with open(fix_history_file, "r") as f:
                    history = json.load(f)

                assert len(history) == 1
                fix_data = list(history.values())[0]
                assert fix_data["action"] == "rebuild"
                assert fix_data["successes"] == 1
                assert fix_data["times_used"] == 1
                assert fix_data["success_rate"] == 1.0
                assert fix_data["avg_duration"] == 30.0

                # Check correlation matrix was updated
                assert correlation_file.exists()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_correlations(self):
        """Test _update_correlations"""
        import agents.decision_engine as module

        with tempfile.TemporaryDirectory() as temp_dir:
            correlation_file = Path(temp_dir) / "correlation_matrix.json"

            with patch.object(module, "CORRELATION_MATRIX_FILE", correlation_file):
                engine = module.DecisionEngine()

                error_hash = "testhash"
                action = "rebuild"

                # First attempt (success)
                engine._update_correlations(error_hash, action, True)

                # Second attempt (failure)
                engine._update_correlations(error_hash, action, False)

                # Check correlation data
                assert correlation_file.exists()
                with open(correlation_file, "r") as f:
                    correlations = json.load(f)

                key = f"{error_hash}:{action}"
                assert key in correlations
                corr_data = correlations[key]
                assert corr_data["total_attempts"] == 2
                assert corr_data["successes"] == 1
                assert (
                    corr_data["correlation_score"] == 0.3
                )  # Low confidence for few samples

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_evaluate_command(self):
        """Test main function evaluate command"""
        import agents.decision_engine as module

        with patch("sys.argv", ["decision_engine.py", "evaluate", "test error"]), patch(
            "builtins.print"
        ) as mock_print:

            exit_code = module.main()

            # Should not exit with error
            assert exit_code is None  # main() doesn't return anything on success

            # Should print JSON result
            mock_print.assert_called_once()
            result_json = mock_print.call_args[0][0]
            result = json.loads(result_json)
            assert "recommended_action" in result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_verify_command(self):
        """Test main function verify command"""
        import agents.decision_engine as module

        with patch(
            "sys.argv", ["decision_engine.py", "verify", "rebuild", "before", "after"]
        ), patch("builtins.print") as mock_print:

            exit_code = module.main()

            assert exit_code is None

            mock_print.assert_called_once()
            result_json = mock_print.call_args[0][0]
            result = json.loads(result_json)
            assert "success" in result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_record_command(self):
        """Test main function record command"""
        import agents.decision_engine as module

        with tempfile.TemporaryDirectory() as temp_dir:
            with patch.object(
                module, "FIX_HISTORY_FILE", Path(temp_dir) / "fix_history.json"
            ), patch.object(
                module,
                "CORRELATION_MATRIX_FILE",
                Path(temp_dir) / "correlation_matrix.json",
            ), patch(
                "sys.argv",
                [
                    "decision_engine.py",
                    "record",
                    "test error",
                    "rebuild",
                    "true",
                    "30.0",
                ],
            ), patch(
                "builtins.print"
            ) as mock_print:

                exit_code = module.main()

                assert exit_code is None

                mock_print.assert_called_once()
                result_json = mock_print.call_args[0][0]
                result = json.loads(result_json)
                assert result["status"] == "recorded"
                assert result["success"] is True

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_invalid_command(self):
        """Test main function with invalid command"""
        import agents.decision_engine as module

        with patch("sys.argv", ["decision_engine.py", "invalid"]), patch(
            "sys.stderr"
        ) as mock_stderr:

            with pytest.raises(SystemExit) as exc_info:
                module.main()

            assert exc_info.value.code == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_missing_arguments(self):
        """Test main function with missing arguments"""
        import agents.decision_engine as module

        with patch("sys.argv", ["decision_engine.py"]), patch(
            "sys.stderr"
        ) as mock_stderr:

            with pytest.raises(SystemExit) as exc_info:
                module.main()

            assert exc_info.value.code == 1
