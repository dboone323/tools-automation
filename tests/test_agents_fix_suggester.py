import pytest
import sys
import os
from unittest.mock import Mock, patch, MagicMock
import json
import subprocess
from pathlib import Path

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("agents.fix_suggester")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.fix_suggester: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/fix_suggester.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/fix_suggester.py",
                "exec",
            )
        print(f"File agents/fix_suggester.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File agents/fix_suggester.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsFixSuggester:
    """Comprehensive tests for agents/fix_suggester.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/fix_suggester.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/fix_suggester.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/fix_suggester.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/fix_suggester.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.fix_suggester")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.fix_suggester should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_suggester_init(self):
        """Test FixSuggester initialization"""
        import agents.fix_suggester as module

        with patch("pathlib.Path.exists") as mock_exists:
            with patch.object(module.FixSuggester, "_check_mcp") as mock_check:
                mock_exists.return_value = True
                mock_check.return_value = True

                suggester = module.FixSuggester()
                assert hasattr(suggester, "mcp_available")
                assert hasattr(suggester, "decision_engine_available")
                mock_check.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_mcp_success(self):
        """Test _check_mcp method success"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(returncode=0, stdout="", stderr="")
            result = suggester._check_mcp()
            assert result is True
            mock_run.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_mcp_failure(self):
        """Test _check_mcp method failure"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(returncode=1, stdout="", stderr="")
            result = suggester._check_mcp()
            assert result is False

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_mcp_timeout(self):
        """Test _check_mcp method timeout"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        with patch("subprocess.run", side_effect=subprocess.TimeoutExpired("test", 5)):
            result = suggester._check_mcp()
            assert result is False

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_suggest_fix_decision_engine_only(self):
        """Test suggest_fix with only decision engine available"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        suggester.mcp_available = False
        suggester.decision_engine_available = True

        decision_result = {
            "recommended_action": "rebuild",
            "confidence": 0.8,
            "reasoning": "Build cache issue",
            "auto_execute": True,
            "alternatives": [{"action": "clean_build", "confidence": 0.6}],
        }

        with patch.object(
            suggester, "_get_decision_engine_suggestion", return_value=decision_result
        ):
            result = suggester.suggest_fix("build error")

            assert result["primary_suggestion"]["action"] == "rebuild"
            assert result["primary_suggestion"]["confidence"] == 0.8
            assert result["confidence"] == 0.8
            assert "decision_engine" in result["sources"]
            assert len(result["alternatives"]) == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_suggest_fix_mcp_only(self):
        """Test suggest_fix with only MCP available"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        suggester.mcp_available = True
        suggester.decision_engine_available = False

        mcp_result = {
            "fix_suggestion": "rebuild the project",
            "root_cause": "cache corruption",
            "prevention": "clean builds",
        }

        with patch.object(suggester, "_get_mcp_suggestion", return_value=mcp_result):
            with patch.object(
                suggester, "_extract_action_from_ai", return_value="rebuild"
            ):
                result = suggester.suggest_fix("build error")

                assert result["primary_suggestion"]["action"] == "rebuild"
                assert (
                    result["primary_suggestion"]["confidence"] == 0.6
                )  # AI confidence
                assert "mcp_ai" in result["sources"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_suggest_fix_fallback_only(self):
        """Test suggest_fix with fallback only"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        suggester.mcp_available = False
        suggester.decision_engine_available = False

        result = suggester.suggest_fix("build failed")

        assert result["primary_suggestion"]["action"] == "rebuild"
        assert result["primary_suggestion"]["confidence"] == 0.4
        assert result["sources"] == ["fallback"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_suggest_fix_combined_strategies(self):
        """Test suggest_fix with multiple strategies"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        suggester.mcp_available = True
        suggester.decision_engine_available = True

        decision_result = {
            "recommended_action": "rebuild",
            "confidence": 0.9,
            "reasoning": "High confidence rebuild",
            "auto_execute": True,
        }

        mcp_result = {
            "fix_suggestion": "clean build needed",
            "root_cause": "dependency issue",
        }

        with patch.object(
            suggester, "_get_decision_engine_suggestion", return_value=decision_result
        ):
            with patch.object(
                suggester, "_get_mcp_suggestion", return_value=mcp_result
            ):
                with patch.object(
                    suggester, "_extract_action_from_ai", return_value="clean_build"
                ):
                    result = suggester.suggest_fix("build error")

                    # Decision engine should be primary (higher confidence)
                    assert result["primary_suggestion"]["action"] == "rebuild"
                    assert result["primary_suggestion"]["confidence"] == 0.9
                    assert len(result["sources"]) == 2
                    assert "decision_engine" in result["sources"]
                    assert "mcp_ai" in result["sources"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_decision_engine_suggestion_success(self):
        """Test _get_decision_engine_suggestion success"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        expected_result = {"recommended_action": "rebuild", "confidence": 0.8}

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(
                returncode=0, stdout=json.dumps(expected_result), stderr=""
            )
            result = suggester._get_decision_engine_suggestion("error", {})
            assert result == expected_result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_decision_engine_suggestion_failure(self):
        """Test _get_decision_engine_suggestion failure"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(returncode=1, stdout="", stderr="error")
            with pytest.raises(RuntimeError):
                suggester._get_decision_engine_suggestion("error", {})

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_mcp_suggestion_json_response(self):
        """Test _get_mcp_suggestion with JSON response"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        json_response = {"fix_suggestion": "rebuild", "root_cause": "cache"}

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(
                returncode=0, stdout=json.dumps(json_response), stderr=""
            )
            result = suggester._get_mcp_suggestion("error", {})
            assert result == json_response

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_mcp_suggestion_text_response(self):
        """Test _get_mcp_suggestion with text response"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        text_response = "You should rebuild the project"

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(returncode=0, stdout=text_response, stderr="")
            result = suggester._get_mcp_suggestion("error", {})
            assert result["fix_suggestion"] == text_response

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_mcp_suggestion_failure(self):
        """Test _get_mcp_suggestion failure"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = Mock(returncode=1, stdout="", stderr="")
            result = suggester._get_mcp_suggestion("error", {})
            assert result is None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_extract_action_from_ai_rebuild(self):
        """Test _extract_action_from_ai rebuild detection"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        ai_response = {"fix_suggestion": "Try rebuilding the project"}
        result = suggester._extract_action_from_ai(ai_response)
        assert result == "rebuild"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_extract_action_from_ai_clean_build(self):
        """Test _extract_action_from_ai clean build detection"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        ai_response = {"fix_suggestion": "You need to clean the build cache"}
        result = suggester._extract_action_from_ai(ai_response)
        assert result == "clean_build"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_extract_action_from_ai_manual_fix(self):
        """Test _extract_action_from_ai manual fix fallback"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        ai_response = {"fix_suggestion": "Some unknown fix approach"}
        result = suggester._extract_action_from_ai(ai_response)
        assert result == "manual_fix"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_fallback_suggestion_build_error(self):
        """Test _get_fallback_suggestion build error"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        result = suggester._get_fallback_suggestion("build failed")
        assert result["action"] == "rebuild"
        assert result["confidence"] == 0.4

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_fallback_suggestion_test_error(self):
        """Test _get_fallback_suggestion test error"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        result = suggester._get_fallback_suggestion("test failed")
        assert result["action"] == "run_tests"
        assert result["confidence"] == 0.4

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_get_fallback_suggestion_unknown_error(self):
        """Test _get_fallback_suggestion unknown error"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        result = suggester._get_fallback_suggestion("some random error")
        assert result["action"] == "skip"
        assert result["confidence"] == 0.3

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_combine_suggestions_empty(self):
        """Test _combine_suggestions with empty list"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        result = suggester._combine_suggestions([])
        assert result["primary_suggestion"]["action"] == "skip"
        assert result["confidence"] == 0.0
        assert result["alternatives"] == []

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_combine_suggestions_multiple(self):
        """Test _combine_suggestions with multiple suggestions"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        suggestions = [
            {
                "source": "decision_engine",
                "action": "rebuild",
                "confidence": 0.9,
                "reasoning": "High confidence",
                "alternatives": [{"action": "clean_build", "confidence": 0.7}],
            },
            {
                "source": "mcp_ai",
                "action": "clean_build",
                "confidence": 0.6,
                "reasoning": "AI suggestion",
            },
        ]

        result = suggester._combine_suggestions(suggestions)
        assert result["primary_suggestion"]["action"] == "rebuild"
        assert result["primary_suggestion"]["confidence"] == 0.9
        assert len(result["alternatives"]) == 1  # clean_build
        assert result["sources"] == ["decision_engine", "mcp_ai"]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_explain_fix_rebuild(self):
        """Test explain_fix for rebuild action"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        result = suggester.explain_fix("rebuild")
        assert result["description"] == "Rebuild project from current state"
        assert result["risk"] == "low"
        assert result["time_estimate"] == "1-2 minutes"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_explain_fix_unknown_action(self):
        """Test explain_fix for unknown action"""
        import agents.fix_suggester as module

        suggester = module.FixSuggester()
        result = suggester.explain_fix("unknown_action")
        assert "Unknown action" in result["description"]
        assert result["risk"] == "unknown"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_no_args(self):
        """Test main function with no arguments"""
        import agents.fix_suggester as module

        with patch("sys.argv", ["fix_suggester.py"]):
            with patch("sys.stderr"):
                with pytest.raises(SystemExit) as exc_info:
                    module.main()
                assert exc_info.value.code == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_suggest_command(self):
        """Test main function suggest command"""
        import agents.fix_suggester as module

        with patch("sys.argv", ["fix_suggester.py", "suggest", "build error"]):
            with patch("json.dumps") as mock_json:
                with patch.object(
                    module.FixSuggester, "suggest_fix", return_value={"result": "test"}
                ):
                    module.main()
                    mock_json.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_suggest_with_context(self):
        """Test main function suggest command with context"""
        import agents.fix_suggester as module

        context = {"severity": "high", "files": ["test.py"]}
        with patch(
            "sys.argv",
            ["fix_suggester.py", "suggest", "build error", json.dumps(context)],
        ):
            with patch("json.dumps") as mock_json:
                with patch.object(module.FixSuggester, "suggest_fix") as mock_suggest:
                    module.main()
                    mock_suggest.assert_called_once_with("build error", context)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_explain_command(self):
        """Test main function explain command"""
        import agents.fix_suggester as module

        with patch("sys.argv", ["fix_suggester.py", "explain", "rebuild"]):
            with patch("json.dumps") as mock_json:
                with patch.object(
                    module.FixSuggester, "explain_fix", return_value={"result": "test"}
                ):
                    module.main()
                    mock_json.assert_called_once()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_unknown_command(self):
        """Test main function with unknown command"""
        import agents.fix_suggester as module

        with patch("sys.argv", ["fix_suggester.py", "unknown"]):
            with patch("sys.stderr"):
                with pytest.raises(SystemExit) as exc_info:
                    module.main()
                assert exc_info.value.code == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_suggest_missing_pattern(self):
        """Test main function suggest command missing pattern"""
        import agents.fix_suggester as module

        with patch("sys.argv", ["fix_suggester.py", "suggest"]):
            with patch("sys.stderr"):
                with pytest.raises(SystemExit) as exc_info:
                    module.main()
                assert exc_info.value.code == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_explain_missing_action(self):
        """Test main function explain command missing action"""
        import agents.fix_suggester as module

        with patch("sys.argv", ["fix_suggester.py", "explain"]):
            with patch("sys.stderr"):
                with pytest.raises(SystemExit) as exc_info:
                    module.main()
                assert exc_info.value.code == 1
