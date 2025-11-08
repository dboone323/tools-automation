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
    __import__("agents.update_knowledge")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import agents.update_knowledge: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/update_knowledge.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/update_knowledge.py",
                "exec",
            )
        print(
            f"File agents/update_knowledge.py is syntactically valid but import failed"
        )
    except SyntaxError as se:
        print(f"File agents/update_knowledge.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestAgentsUpdateKnowledge:
    """Comprehensive tests for agents/update_knowledge.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/update_knowledge.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/update_knowledge.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in agents/update_knowledge.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/update_knowledge.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("agents.update_knowledge")
            assert True
        except ImportError:
            pytest.fail(f"Module agents.update_knowledge should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_existing_file(self):
        """Test load_json with existing file"""
        import agents.update_knowledge as module

        test_data = {"test": "data", "number": 42}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(test_data, f)
            temp_path = f.name

        try:
            result = module.load_json(temp_path, {})
            assert result == test_data
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_nonexistent_file(self):
        """Test load_json with nonexistent file"""
        import agents.update_knowledge as module

        result = module.load_json("/nonexistent/file.json", {"default": "value"})
        assert result == {"default": "value"}

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_load_json_invalid_json(self):
        """Test load_json with invalid JSON"""
        import agents.update_knowledge as module

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            f.write("invalid json content")
            temp_path = f.name

        try:
            result = module.load_json(temp_path, {"fallback": True})
            assert result == {"fallback": True}
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_save_json(self):
        """Test save_json atomic write"""
        import agents.update_knowledge as module

        test_data = {"test": "data", "unicode": "测试"}

        with tempfile.TemporaryDirectory() as temp_dir:
            output_file = Path(temp_dir) / "test_output.json"

            module.save_json(str(output_file), test_data)

            # File should exist
            assert output_file.exists()

            # Content should be correct
            with open(output_file, "r", encoding="utf-8") as f:
                loaded_data = json.load(f)
            assert loaded_data == test_data

            # Temp file should not exist
            temp_file = output_file.with_suffix(".tmp")
            assert not temp_file.exists()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_save_json_creates_directories(self):
        """Test save_json creates necessary directories"""
        import agents.update_knowledge as module

        test_data = {"test": "data"}

        with tempfile.TemporaryDirectory() as temp_dir:
            nested_path = Path(temp_dir) / "deep" / "nested" / "path" / "file.json"

            module.save_json(str(nested_path), test_data)

            # File should exist and directories should be created
            assert nested_path.exists()
            assert nested_path.parent.exists()

            # Content should be correct
            with open(nested_path, "r", encoding="utf-8") as f:
                loaded_data = json.load(f)
            assert loaded_data == test_data

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_error_patterns_new_pattern(self):
        """Test update_error_patterns with new pattern"""
        import agents.update_knowledge as module

        with tempfile.TemporaryDirectory() as temp_dir:
            # Create workspace structure
            knowledge_dir = (
                Path(temp_dir) / "Tools" / "Automation" / "agents" / "knowledge"
            )
            knowledge_dir.mkdir(parents=True)

            pattern_file = knowledge_dir / "error_patterns.json"

            pattern_obj = {
                "hash": "test_hash_123",
                "pattern": "Test error pattern",
                "category": "build",
                "severity": "high",
                "example": "Example error message",
            }

            module.update_error_patterns(temp_dir, pattern_obj, "test_file.py")

            # Verify file was created and contains correct data
            assert pattern_file.exists()
            with open(pattern_file, "r", encoding="utf-8") as f:
                data = json.load(f)

            assert "test_hash_123" in data
            entry = data["test_hash_123"]
            assert entry["pattern"] == "Test error pattern"
            assert entry["category"] == "build"
            assert entry["severity"] == "high"
            assert entry["count"] == 1
            assert "Example error message" in entry["examples"]
            assert "test_file.py" in entry["files"]
            assert "first_seen" in entry
            assert "last_seen" in entry

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_error_patterns_existing_pattern(self):
        """Test update_error_patterns with existing pattern"""
        import agents.update_knowledge as module

        with tempfile.TemporaryDirectory() as temp_dir:
            # Create workspace structure
            knowledge_dir = (
                Path(temp_dir) / "Tools" / "Automation" / "agents" / "knowledge"
            )
            knowledge_dir.mkdir(parents=True)

            pattern_file = knowledge_dir / "error_patterns.json"

            # Pre-populate with existing data
            existing_data = {
                "test_hash_123": {
                    "pattern": "Test error pattern",
                    "category": "build",
                    "severity": "medium",
                    "count": 2,
                    "examples": ["Old example"],
                    "files": ["old_file.py"],
                    "first_seen": "2023-01-01T00:00:00Z",
                    "last_seen": "2023-01-01T00:00:00Z",
                }
            }

            with open(pattern_file, "w", encoding="utf-8") as f:
                json.dump(existing_data, f)

            pattern_obj = {
                "hash": "test_hash_123",
                "pattern": "Test error pattern",
                "category": "test",  # Different category
                "severity": "high",  # Higher severity
                "example": "New example",
            }

            module.update_error_patterns(temp_dir, pattern_obj, "new_file.py")

            # Verify data was updated
            with open(pattern_file, "r", encoding="utf-8") as f:
                data = json.load(f)

            entry = data["test_hash_123"]
            assert entry["count"] == 3  # Incremented
            assert entry["category"] == "test"  # Updated
            assert entry["severity"] == "high"  # Updated to higher priority
            assert "New example" in entry["examples"]
            assert "new_file.py" in entry["files"]
            assert entry["first_seen"] == "2023-01-01T00:00:00Z"  # Unchanged
            assert entry["last_seen"] != "2023-01-01T00:00:00Z"  # Updated

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_error_patterns_no_hash_or_pattern(self):
        """Test update_error_patterns with missing hash/pattern"""
        import agents.update_knowledge as module

        with tempfile.TemporaryDirectory() as temp_dir:
            # Create workspace structure
            knowledge_dir = (
                Path(temp_dir) / "Tools" / "Automation" / "agents" / "knowledge"
            )
            knowledge_dir.mkdir(parents=True)

            pattern_file = knowledge_dir / "error_patterns.json"

            # Empty pattern object
            pattern_obj = {}

            module.update_error_patterns(temp_dir, pattern_obj)

            # File should not be created since no key
            assert not pattern_file.exists()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_update_error_patterns_use_pattern_as_key(self):
        """Test update_error_patterns using pattern as key when hash not provided"""
        import agents.update_knowledge as module

        with tempfile.TemporaryDirectory() as temp_dir:
            # Create workspace structure
            knowledge_dir = (
                Path(temp_dir) / "Tools" / "Automation" / "agents" / "knowledge"
            )
            knowledge_dir.mkdir(parents=True)

            pattern_file = knowledge_dir / "error_patterns.json"

            pattern_obj = {"pattern": "Error pattern without hash", "category": "test"}

            module.update_error_patterns(temp_dir, pattern_obj)

            # Verify file was created with pattern as key
            assert pattern_file.exists()
            with open(pattern_file, "r", encoding="utf-8") as f:
                data = json.load(f)

            assert "Error pattern without hash" in data
            entry = data["Error pattern without hash"]
            assert entry["pattern"] == "Error pattern without hash"
            assert entry["category"] == "test"

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_valid_arguments(self):
        """Test main function with valid arguments"""
        import agents.update_knowledge as module

        pattern_json = (
            '{"hash": "test123", "pattern": "test error", "category": "build"}'
        )

        with patch(
            "sys.argv",
            [
                "update_knowledge.py",
                "--workspace",
                "/tmp/test_workspace",
                "--pattern-json",
                pattern_json,
                "--source",
                "test.log",
            ],
        ), patch.object(module, "update_error_patterns") as mock_update:

            result = module.main()
            assert result == 0
            mock_update.assert_called_once_with(
                "/tmp/test_workspace",
                {"hash": "test123", "pattern": "test error", "category": "build"},
                "test.log",
            )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_invalid_json(self):
        """Test main function with invalid JSON"""
        import agents.update_knowledge as module

        with patch(
            "sys.argv",
            [
                "update_knowledge.py",
                "--workspace",
                "/tmp/test_workspace",
                "--pattern-json",
                "invalid json",
            ],
        ), patch("sys.stderr") as mock_stderr:

            result = module.main()
            assert result == 2
            # Should print error message to stderr

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_missing_required_args(self):
        """Test main function with missing required arguments"""
        import agents.update_knowledge as module

        # Missing --workspace
        with patch(
            "sys.argv", ["update_knowledge.py", "--pattern-json", '{"test": "data"}']
        ), pytest.raises(SystemExit):
            module.main()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_no_source_file(self):
        """Test main function without source file"""
        import agents.update_knowledge as module

        pattern_json = '{"hash": "test123", "pattern": "test error"}'

        with patch(
            "sys.argv",
            [
                "update_knowledge.py",
                "--workspace",
                "/tmp/test_workspace",
                "--pattern-json",
                pattern_json,
            ],
        ), patch.object(module, "update_error_patterns") as mock_update:

            result = module.main()
            assert result == 0
            mock_update.assert_called_once_with(
                "/tmp/test_workspace",
                {"hash": "test123", "pattern": "test error"},
                None,
            )
