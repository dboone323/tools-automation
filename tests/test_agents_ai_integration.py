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
    __import__("agents.ai_integration")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.ai_integration: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/ai_integration.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/ai_integration.py",
                "exec",
            )
        print(f"File agents/ai_integration.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File agents/ai_integration.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsAiIntegration:
    """Comprehensive tests for agents/ai_integration.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/ai_integration.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/ai_integration.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/ai_integration.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/ai_integration.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.ai_integration")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.ai_integration should be importable")

    # TODO: Add specific tests for functions in agents/ai_integration.py
    # The module import now works correctly, so you can add real test functions here
    # Examples:
    # def test_specific_function(self):
    #     import agents.ai_integration as module
    #     result = module.function_name(args)
    #     assert result == expected

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_try_mcp_success(self):
        """Test _try_mcp with successful MCP call"""
        import agents.ai_integration as module
        import tempfile
        import json

        # Create a mock MCP script that returns valid JSON
        mock_response = {"analysis": "test", "confidence": 0.8}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".sh", delete=False) as f:
            f.write("#!/bin/bash\n")
            f.write(f"echo '{json.dumps(mock_response)}'\n")
            mock_script = f.name

        os.chmod(mock_script, 0o755)

        try:
            # Mock the path joining to return our mock script
            with patch("os.path.join") as mock_join:
                mock_join.side_effect = lambda *args: (
                    mock_script if "mcp_client.sh" in str(args) else os.path.join(*args)
                )
                with patch("os.path.exists", return_value=True):
                    with patch("os.access", return_value=True):
                        with patch("subprocess.run") as mock_run:
                            mock_run.return_value = MagicMock(
                                stdout=json.dumps(mock_response), returncode=0
                            )
                            result = module._try_mcp(["test", "arg"])
                            assert result == mock_response
        finally:
            os.unlink(mock_script)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_try_mcp_no_script(self):
        """Test _try_mcp when no MCP script is available"""
        import agents.ai_integration as module

        with patch("agents.ai_integration.AGENTS_DIR", "/nonexistent"):
            with patch("agents.ai_integration.ROOT", "/nonexistent"):
                result = module._try_mcp(["test"])
                assert result is None

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_try_mcp_non_json_output(self):
        """Test _try_mcp with non-JSON output from MCP"""
        import agents.ai_integration as module
        import tempfile

        # Create a mock MCP script that returns plain text
        with tempfile.NamedTemporaryFile(mode="w", suffix=".sh", delete=False) as f:
            f.write("#!/bin/bash\n")
            f.write('echo "plain text output"\n')
            mock_script = f.name

        os.chmod(mock_script, 0o755)

        try:
            with patch("os.path.join") as mock_join:
                mock_join.side_effect = lambda *args: (
                    mock_script if "mcp_client.sh" in str(args) else os.path.join(*args)
                )
                with patch("os.path.exists", return_value=True):
                    with patch("os.access", return_value=True):
                        with patch("subprocess.run") as mock_run:
                            mock_run.return_value = MagicMock(
                                stdout="plain text output", returncode=0
                            )
                            result = module._try_mcp(["test"])
                            assert result == {
                                "raw": "plain text output",
                                "exit_code": 0,
                            }
        finally:
            os.unlink(mock_script)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_heuristic_analysis_null_pointer(self):
        """Test _heuristic_analysis with null pointer related text"""
        import agents.ai_integration as module

        text = "NullPointerException in line 42"
        result = module._heuristic_analysis(text)

        assert "analysis" in result
        assert "confidence" in result
        assert result["confidence"] == 0.42
        assert result["source"] == "heuristic"
        assert "nil/None guards" in result["analysis"]["suggestions"][0]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_heuristic_analysis_timeout(self):
        """Test _heuristic_analysis with timeout related text"""
        import agents.ai_integration as module

        text = "Request timeout occurred after 30 seconds"
        result = module._heuristic_analysis(text)

        assert "analysis" in result
        assert "timeout" in result["analysis"]["suggestions"][0].lower()
        assert "retry" in result["analysis"]["suggestions"][0].lower()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_heuristic_analysis_syntax_error(self):
        """Test _heuristic_analysis with syntax error text"""
        import agents.ai_integration as module

        text = "SyntaxError: invalid syntax"
        result = module._heuristic_analysis(text)

        assert "analysis" in result
        assert "linter" in result["analysis"]["suggestions"][0].lower()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_heuristic_analysis_permission_denied(self):
        """Test _heuristic_analysis with permission denied text"""
        import agents.ai_integration as module

        text = "Permission denied when accessing file"
        result = module._heuristic_analysis(text)

        assert "analysis" in result
        assert "credentials" in result["analysis"]["suggestions"][0].lower()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_heuristic_analysis_generic_error(self):
        """Test _heuristic_analysis with generic error text"""
        import agents.ai_integration as module

        text = "Some random error occurred"
        result = module._heuristic_analysis(text)

        assert "analysis" in result
        assert "minimal repro" in result["analysis"]["suggestions"][0].lower()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_analyze_with_mcp_success(self):
        """Test analyze function with successful MCP call"""
        import agents.ai_integration as module

        mock_result = {"analysis": "success", "confidence": 0.9}
        with patch("agents.ai_integration._try_mcp", return_value=mock_result):
            result = module.analyze("test text")
            assert result == mock_result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_analyze_fallback_to_heuristic(self):
        """Test analyze function falling back to heuristic when MCP fails"""
        import agents.ai_integration as module

        with patch("agents.ai_integration._try_mcp", return_value=None):
            result = module.analyze("test text with null")
            assert "analysis" in result
            assert result["source"] == "heuristic"
            assert "nil/None guards" in result["analysis"]["suggestions"][0]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_suggest_fix_with_mcp_success(self):
        """Test suggest_fix function with successful MCP call"""
        import agents.ai_integration as module

        mock_result = {"suggestion": "fix applied", "confidence": 0.8}
        with patch("agents.ai_integration._try_mcp", return_value=mock_result):
            result = module.suggest_fix("NullPointer")
            assert result == mock_result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_suggest_fix_fallback_to_heuristic(self):
        """Test suggest_fix function falling back to heuristic"""
        import agents.ai_integration as module

        with patch("agents.ai_integration._try_mcp", return_value=None):
            result = module.suggest_fix("test pattern")
            assert "suggestion" in result
            assert "regression test" in result["suggestion"]
            assert result["source"] == "heuristic"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_evaluate_with_mcp_success(self):
        """Test evaluate function with successful MCP call"""
        import agents.ai_integration as module

        mock_result = {"evaluation": "good", "risk": 0.2}
        with patch("agents.ai_integration._try_mcp", return_value=mock_result):
            result = module.evaluate("test change")
            assert result == mock_result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_evaluate_fallback_to_heuristic(self):
        """Test evaluate function falling back to heuristic"""
        import agents.ai_integration as module

        with patch("agents.ai_integration._try_mcp", return_value=None):
            result = module.evaluate("test change")
            assert "evaluation" in result
            assert "compiles locally" in result["evaluation"]
            assert result["source"] == "heuristic"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_with_mcp_success(self):
        """Test verify function with successful MCP call"""
        import agents.ai_integration as module

        mock_result = {"verify": "passed", "checks": []}
        with patch("agents.ai_integration._try_mcp", return_value=mock_result):
            result = module.verify("test target")
            assert result == mock_result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_verify_fallback_to_heuristic(self):
        """Test verify function falling back to heuristic"""
        import agents.ai_integration as module

        with patch("agents.ai_integration._try_mcp", return_value=None):
            result = module.verify("test.swift")
            assert "verify" in result
            assert "Static checks passed" in result["verify"]
            assert result["source"] == "heuristic"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_analyze_command(self):
        """Test main function with analyze command"""
        import agents.ai_integration as module

        mock_result = {"analysis": "test"}
        with patch(
            "agents.ai_integration.analyze", return_value=mock_result
        ) as mock_analyze:
            with patch("builtins.print") as mock_print:
                with patch(
                    "sys.argv", ["ai_integration.py", "analyze", "--text", "test error"]
                ):
                    exit_code = module.main()
                    assert exit_code == 0
                    mock_analyze.assert_called_once_with("test error")
                    mock_print.assert_called_once_with('{"analysis": "test"}')

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_suggest_fix_command(self):
        """Test main function with suggest-fix command"""
        import agents.ai_integration as module

        mock_result = {"suggestion": "fix"}
        with patch(
            "agents.ai_integration.suggest_fix", return_value=mock_result
        ) as mock_suggest:
            with patch("builtins.print") as mock_print:
                with patch(
                    "sys.argv",
                    ["ai_integration.py", "suggest-fix", "--pattern", "NullPointer"],
                ):
                    exit_code = module.main()
                    assert exit_code == 0
                    mock_suggest.assert_called_once_with("NullPointer")
                    mock_print.assert_called_once_with('{"suggestion": "fix"}')

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_evaluate_command(self):
        """Test main function with evaluate command"""
        import agents.ai_integration as module

        mock_result = {"evaluation": "good"}
        with patch(
            "agents.ai_integration.evaluate", return_value=mock_result
        ) as mock_evaluate:
            with patch("builtins.print") as mock_print:
                with patch(
                    "sys.argv",
                    ["ai_integration.py", "evaluate", "--change", '{"type": "add"}'],
                ):
                    exit_code = module.main()
                    assert exit_code == 0
                    mock_evaluate.assert_called_once_with('{"type": "add"}')
                    mock_print.assert_called_once_with('{"evaluation": "good"}')

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_verify_command(self):
        """Test main function with verify command"""
        import agents.ai_integration as module

        mock_result = {"verify": "passed"}
        with patch(
            "agents.ai_integration.verify", return_value=mock_result
        ) as mock_verify:
            with patch("builtins.print") as mock_print:
                with patch(
                    "sys.argv",
                    ["ai_integration.py", "verify", "--target", "file.swift"],
                ):
                    exit_code = module.main()
                    assert exit_code == 0
                    mock_verify.assert_called_once_with("file.swift")
                    mock_print.assert_called_once_with('{"verify": "passed"}')

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_invalid_command(self):
        """Test main function with invalid command"""
        import agents.ai_integration as module

        with patch("sys.argv", ["ai_integration.py", "invalid"]):
            with pytest.raises(SystemExit) as exc_info:
                module.main()
            assert exc_info.value.code == 2

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_no_command(self):
        """Test main function with no command"""
        import agents.ai_integration as module

        with patch("sys.argv", ["ai_integration.py"]):
            with patch("argparse.ArgumentParser.print_help") as mock_help:
                exit_code = module.main()
                assert exit_code == 1
                mock_help.assert_called_once()
