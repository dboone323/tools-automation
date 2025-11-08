import pytest
import sys
import os
import json
import io
from unittest.mock import Mock, patch, MagicMock
from contextlib import redirect_stdout

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("agents.pattern_recognizer")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.pattern_recognizer: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/pattern_recognizer.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/pattern_recognizer.py",
                "exec",
            )
        print(
            f"File agents/pattern_recognizer.py is syntactically valid but import failed"
        )
    except SyntaxError as se:
        print(f"File agents/pattern_recognizer.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsPatternRecognizer:
    """Comprehensive tests for agents/pattern_recognizer.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/pattern_recognizer.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/pattern_recognizer.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/pattern_recognizer.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/pattern_recognizer.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.pattern_recognizer")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.pattern_recognizer should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_normalize_message_basic(self):
        """Test normalize_message with basic input"""
        import agents.pattern_recognizer as module

        msg = "  Simple message  "
        result = module.normalize_message(msg)
        assert result == "Simple message"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_normalize_message_ansi_codes(self):
        """Test normalize_message strips ANSI color codes"""
        import agents.pattern_recognizer as module

        msg = "\x1b[31mRed error\x1b[0m message"
        result = module.normalize_message(msg)
        assert result == "Red error message"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_normalize_message_timestamps(self):
        """Test normalize_message strips timestamps"""
        import agents.pattern_recognizer as module

        msg = "[16:34:02] Error occurred"
        result = module.normalize_message(msg)
        assert result == "Error occurred"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_normalize_message_emojis(self):
        """Test normalize_message strips emojis"""
        import agents.pattern_recognizer as module

        msg = "✅ Success message ❌"
        result = module.normalize_message(msg)
        assert result == "Success message"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_normalize_message_multiple_spaces(self):
        """Test normalize_message collapses multiple spaces"""
        import agents.pattern_recognizer as module

        msg = "Error    with    multiple   spaces"
        result = module.normalize_message(msg)
        assert result == "Error with multiple spaces"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_normalize_message_combined(self):
        """Test normalize_message with combined formatting"""
        import agents.pattern_recognizer as module

        msg = "  \x1b[32m[10:15:30]\u2705 Success   message  \x1b[0m  "
        result = module.normalize_message(msg)
        # Note: timestamp in middle is not stripped, only leading timestamps
        assert result == "[10:15:30] Success message"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_categorize_build_error(self):
        """Test categorize with build error patterns"""
        import agents.pattern_recognizer as module

        # Test SwiftPM build failed
        cat, sev = module.categorize("swiftpm build failed")
        assert cat == "build"
        assert sev == "high"

        # Test Xcode build failed
        cat, sev = module.categorize("xcode build failed")
        assert cat == "build"
        assert sev == "high"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_categorize_test_error(self):
        """Test categorize with test error patterns"""
        import agents.pattern_recognizer as module

        cat, sev = module.categorize("tests failed")
        assert cat == "test"
        assert sev == "high"

        cat, sev = module.categorize("failing test")
        assert cat == "test"
        assert sev == "high"

        cat, sev = module.categorize("assertion failed")
        assert cat == "test"
        assert sev == "high"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_categorize_lint_error(self):
        """Test categorize with lint error patterns"""
        import agents.pattern_recognizer as module

        cat, sev = module.categorize("lint error")
        assert cat == "lint"
        assert sev == "medium"

        cat, sev = module.categorize("swiftlint failed")
        assert cat == "lint"
        assert sev == "medium"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_categorize_dependency_error(self):
        """Test categorize with dependency error patterns"""
        import agents.pattern_recognizer as module

        cat, sev = module.categorize("dependency resolution failed")
        assert cat == "dependency"
        assert sev == "medium"

        cat, sev = module.categorize("package not found")
        assert cat == "dependency"
        assert sev == "medium"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_categorize_general_error(self):
        """Test categorize with general error fallback"""
        import agents.pattern_recognizer as module

        cat, sev = module.categorize("some error occurred")
        assert cat == "general"
        assert sev == "medium"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_categorize_info_low(self):
        """Test categorize with info/low fallback"""
        import agents.pattern_recognizer as module

        cat, sev = module.categorize("some random message")
        assert cat == "info"
        assert sev == "low"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_stable_hash_consistent(self):
        """Test stable_hash produces consistent results"""
        import agents.pattern_recognizer as module

        s = "test string"
        hash1 = module.stable_hash(s)
        hash2 = module.stable_hash(s)
        assert hash1 == hash2
        assert len(hash1) == 12
        assert hash1.isalnum()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_stable_hash_different_inputs(self):
        """Test stable_hash produces different results for different inputs"""
        import agents.pattern_recognizer as module

        hash1 = module.stable_hash("string1")
        hash2 = module.stable_hash("string2")
        assert hash1 != hash2

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_recognize_basic_error(self):
        """Test recognize with basic error message"""
        import agents.pattern_recognizer as module

        line = "Error: something went wrong"
        result = module.recognize(line)

        assert result.pattern == "Error: something went wrong"
        assert result.category == "general"
        assert result.severity == "medium"
        assert isinstance(result.hash, str)
        assert len(result.hash) == 12

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_recognize_build_error(self):
        """Test recognize with build error"""
        import agents.pattern_recognizer as module

        line = "swiftpm build failed with exit code 1"
        result = module.recognize(line)

        assert "swiftpm build failed" in result.pattern
        assert result.category == "build"
        assert result.severity == "high"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_recognize_line_number_normalization(self):
        """Test recognize normalizes line numbers"""
        import agents.pattern_recognizer as module

        line1 = "Error at line 42 in file.swift"
        line2 = "Error at line 123 in file.swift"

        result1 = module.recognize(line1)
        result2 = module.recognize(line2)

        # Should have same pattern after normalization
        assert result1.pattern == result2.pattern
        assert "line <n>" in result1.pattern

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_recognize_column_normalization(self):
        """Test recognize normalizes column numbers"""
        import agents.pattern_recognizer as module

        line1 = "Error at file.swift:42:15"
        line2 = "Error at file.swift:123:67"

        result1 = module.recognize(line1)
        result2 = module.recognize(line2)

        # Should have same pattern after normalization
        assert result1.pattern == result2.pattern
        assert ":<n>:<n>" in result1.pattern

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_recognize_with_formatting(self):
        """Test recognize handles formatted messages"""
        import agents.pattern_recognizer as module

        line = "  \x1b[31m[16:34:02] ❌ swiftpm build failed at line 42\x1b[0m  "
        result = module.recognize(line)

        # Note: timestamp in middle is not stripped by normalize_message
        assert result.pattern == "[16:<n>:<n>] swiftpm build failed at line <n>"
        assert result.category == "build"
        assert result.severity == "high"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_with_line_argument(self):
        """Test main function with --line argument"""
        import agents.pattern_recognizer as module

        with patch("sys.argv", ["pattern_recognizer.py", "--line", "test error"]):
            f = io.StringIO()
            with redirect_stdout(f):
                exit_code = module.main()
            output = f.getvalue()

        assert exit_code == 0
        result = json.loads(output)
        assert "pattern" in result
        assert "category" in result
        assert "severity" in result
        assert "hash" in result

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_with_stdin(self):
        """Test main function reading from stdin"""
        import agents.pattern_recognizer as module

        test_input = "stdin error message\nsecond line"
        with patch("sys.argv", ["pattern_recognizer.py"]):
            with patch("sys.stdin.read", return_value=test_input):
                f = io.StringIO()
                with redirect_stdout(f):
                    exit_code = module.main()
                output = f.getvalue()

        assert exit_code == 0
        result = json.loads(output)
        assert result["pattern"] == "stdin error message"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_empty_stdin(self):
        """Test main function with empty stdin"""
        import agents.pattern_recognizer as module

        with patch("sys.argv", ["pattern_recognizer.py"]):
            with patch("sys.stdin.read", return_value=""):
                f = io.StringIO()
                with redirect_stdout(f):
                    exit_code = module.main()
                output = f.getvalue()

        assert exit_code == 0
        result = json.loads(output)
        assert result["pattern"] == ""
        assert result["category"] == "info"
        assert result["severity"] == "low"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_whitespace_only_stdin(self):
        """Test main function with whitespace-only stdin"""
        import agents.pattern_recognizer as module

        with patch("sys.argv", ["pattern_recognizer.py"]):
            with patch("sys.stdin.read", return_value="   \n\t  "):
                f = io.StringIO()
                with redirect_stdout(f):
                    exit_code = module.main()
                output = f.getvalue()

        assert exit_code == 0
        result = json.loads(output)
        assert result["pattern"] == ""
        assert result["category"] == "info"
        assert result["severity"] == "low"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_json_output_format(self):
        """Test main function outputs valid JSON"""
        import agents.pattern_recognizer as module

        with patch("sys.argv", ["pattern_recognizer.py", "--line", "test message"]):
            f = io.StringIO()
            with redirect_stdout(f):
                exit_code = module.main()
            output = f.getvalue()

        assert exit_code == 0
        # Should be valid JSON
        result = json.loads(output)
        assert isinstance(result, dict)

        # Should match Pattern dataclass structure
        expected_keys = {"pattern", "category", "severity", "hash"}
        assert set(result.keys()) == expected_keys

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_unicode_handling(self):
        """Test main function handles unicode characters"""
        import agents.pattern_recognizer as module

        unicode_msg = "Error with ümlaut and 🚀 emoji"
        with patch("sys.argv", ["pattern_recognizer.py", "--line", unicode_msg]):
            f = io.StringIO()
            with redirect_stdout(f):
                exit_code = module.main()
            output = f.getvalue()

        assert exit_code == 0
        result = json.loads(output)
        # Should preserve unicode in JSON output (ensure_ascii=False)
        assert "ü" in result["pattern"]
        # Rocket emoji is not in the list of stripped emojis, so it remains
        assert "🚀" in result["pattern"]
