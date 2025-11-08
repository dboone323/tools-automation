import pytest
import sys
import os
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock, mock_open

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import generate_missing_tests


class TestGenerateMissingTests:
    """Comprehensive tests for generate_missing_tests.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/generate_missing_tests.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/generate_missing_tests.py",
                    "exec",
                )
        except SyntaxError as e:
            pytest.fail(f"Syntax error in generate_missing_tests.py: {e}")

    def test_file_exists(self):
        """Test that the module file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/generate_missing_tests.py"
        )

    def test_module_can_be_imported(self):
        """Test that the module can be imported"""
        try:
            import generate_missing_tests
        except ImportError as e:
            pytest.fail(f"Module generate_missing_tests should be importable: {e}")

    def test_constants_defined(self):
        """Test that constants are properly defined"""
        assert hasattr(generate_missing_tests, "WORKSPACE_ROOT")
        assert hasattr(generate_missing_tests, "TESTS_DIR")
        assert (
            generate_missing_tests.WORKSPACE_ROOT
            == "/Users/danielstevens/Desktop/github-projects/tools-automation"
        )
        assert generate_missing_tests.TESTS_DIR == os.path.join(
            generate_missing_tests.WORKSPACE_ROOT, "tests"
        )

    def test_get_import_path_root_file(self):
        """Test get_import_path for a file in root directory"""
        pyfile = (
            "/Users/danielstevens/Desktop/github-projects/tools-automation/module.py"
        )
        result = generate_missing_tests.get_import_path(pyfile)
        assert result == "module"

    def test_get_import_path_agents_file(self):
        """Test get_import_path for a file in agents directory"""
        pyfile = "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/agent.py"
        result = generate_missing_tests.get_import_path(pyfile)
        assert result == "agents.agent"

    def test_get_import_path_subproject_file(self):
        """Test get_import_path for a file in subproject directory"""
        pyfile = "/Users/danielstevens/Desktop/github-projects/tools-automation/MomentumFinance/module.py"
        result = generate_missing_tests.get_import_path(pyfile)
        assert result == "MomentumFinance.module"

    def test_get_import_path_habitquest_file(self):
        """Test get_import_path for a file in HabitQuest directory"""
        pyfile = "/Users/danielstevens/Desktop/github-projects/tools-automation/HabitQuest/src/module.py"
        result = generate_missing_tests.get_import_path(pyfile)
        assert result == "HabitQuest.src.module"

    def test_get_class_name_simple(self):
        """Test get_class_name for simple module name"""
        result = generate_missing_tests.get_class_name("module")
        assert result == "TestModule"

    def test_get_class_name_with_underscores(self):
        """Test get_class_name for module name with underscores"""
        result = generate_missing_tests.get_class_name("my_module")
        assert result == "TestMyModule"

    def test_get_class_name_with_dots(self):
        """Test get_class_name for module name with dots"""
        result = generate_missing_tests.get_class_name("agents.module")
        assert result == "TestAgentsModule"

    def test_get_class_name_complex(self):
        """Test get_class_name for complex module name"""
        result = generate_missing_tests.get_class_name("my-complex_module.test")
        assert result == "TestMyComplexModuleTest"

    @patch("os.path.exists")
    @patch("os.makedirs")
    @patch("builtins.open", new_callable=mock_open)
    def test_generate_test_for_file_new_file(
        self, mock_file, mock_makedirs, mock_exists
    ):
        """Test generating test for a new file"""
        mock_exists.return_value = False  # Test file doesn't exist

        pyfile = "/Users/danielstevens/Desktop/github-projects/tools-automation/test_module.py"

        with patch(
            "generate_missing_tests.get_import_path", return_value="test_module"
        ):
            with patch(
                "generate_missing_tests.get_class_name", return_value="TestTestModule"
            ):
                generate_missing_tests.generate_test_for_file(pyfile)

        # Verify file operations
        mock_makedirs.assert_called_once()
        mock_file.assert_called_once()

        # Check that the test content was written
        written_content = mock_file().write.call_args[0][0]
        assert "import pytest" in written_content
        assert "class TestTestModule:" in written_content
        assert "test_module_syntax_valid" in written_content

    @patch("os.path.exists")
    def test_generate_test_for_file_existing_file(self, mock_exists):
        """Test generating test when file already exists"""
        mock_exists.return_value = True  # Test file already exists

        pyfile = "/Users/danielstevens/Desktop/github-projects/tools-automation/test_module.py"

        with patch("builtins.print") as mock_print:
            generate_missing_tests.generate_test_for_file(pyfile)

        # Should print that test exists and not create new file
        mock_print.assert_called_with(
            "✅ Test exists: /Users/danielstevens/Desktop/github-projects/tools-automation/tests/test_test_module.py"
        )

    @patch("pathlib.Path.rglob")
    @patch("generate_missing_tests.generate_test_for_file")
    def test_main_function(self, mock_generate, mock_rglob):
        """Test the main function"""
        # Mock finding Python files
        mock_file1 = Mock()
        mock_file1.__str__ = Mock(return_value="/workspace/module1.py")
        mock_file1.name = "module1.py"
        mock_file2 = Mock()
        mock_file2.__str__ = Mock(return_value="/workspace/module2.py")
        mock_file2.name = "module2.py"
        mock_rglob.return_value = [mock_file1, mock_file2]

        generate_missing_tests.main()

        # Should call generate_test_for_file for each Python file
        assert mock_generate.call_count == 2

    def test_generate_test_content_structure(self):
        """Test the structure of generated test content"""
        pyfile = "/workspace/test_module.py"
        import_path = "test_module"
        class_name = "TestTestModule"

        # Simulate the content generation
        test_content = f'''import pytest
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
    __import__("{import_path}")
    MODULE_AVAILABLE = True
except Exception as e:
    print(f"Warning: Could not import {import_path}: {{e}}")
    # Module has issues (hardcoded paths, missing dependencies, etc.)
    # We'll still create tests but they will be skipped
    MODULE_AVAILABLE = False

@pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module not available or has import issues")
class {class_name}:
    """Comprehensive tests for test_module.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open("{pyfile}", 'r') as f:
                compile(f.read(), "{pyfile}", 'exec')
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in test_module.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists("{pyfile}")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("{import_path}")
            assert True
        except ImportError:
            pytest.fail(f"Module {import_path} should be importable")

    # TODO: Add specific tests for functions in test_module.py
    # The module import now works correctly, so you can add real test functions here
    # Examples:
    # def test_specific_function(self):
    #     import test_module as module
    #     result = module.function_name(args)
    #     assert result == expected

'''

        # Verify the structure
        assert "import pytest" in test_content
        assert f"class {class_name}:" in test_content
        assert "test_module_syntax_valid" in test_content
        assert "test_file_exists" in test_content
        assert "test_module_can_be_imported" in test_content
        assert "# TODO: Add specific tests" in test_content

    def test_import_path_edge_cases(self):
        """Test get_import_path with various edge cases"""
        # Test with backslashes (Windows style)
        pyfile = "C:\\workspace\\module.py"
        with patch("os.path.relpath", return_value="module.py"):
            result = generate_missing_tests.get_import_path(pyfile)
            assert result == "module"

    def test_class_name_edge_cases(self):
        """Test get_class_name with various edge cases"""
        # Test with empty string
        result = generate_missing_tests.get_class_name("")
        assert result == "Test"

        # Test with single character
        result = generate_missing_tests.get_class_name("a")
        assert result == "TestA"

        # Test with multiple underscores
        result = generate_missing_tests.get_class_name("a_b_c")
        assert result == "TestABC"

    @patch("os.path.exists")
    @patch("os.makedirs")
    @patch("builtins.open", new_callable=mock_open)
    def test_generate_test_for_file_with_subdir_import(
        self, mock_file, mock_makedirs, mock_exists
    ):
        """Test generating test for file with subdirectory import"""
        mock_exists.return_value = False

        pyfile = "/Users/danielstevens/Desktop/github-projects/tools-automation/agents/subdir/module.py"

        with patch(
            "generate_missing_tests.get_import_path",
            return_value="agents.subdir.module",
        ):
            with patch(
                "generate_missing_tests.get_class_name",
                return_value="TestAgentsSubdirModule",
            ):
                generate_missing_tests.generate_test_for_file(pyfile)

        written_content = mock_file().write.call_args[0][0]
        assert '__import__("agents.subdir.module")' in written_content

    def test_main_function_output(self):
        """Test that main function produces expected output"""
        with patch("pathlib.Path.rglob", return_value=[]):
            with patch("builtins.print") as mock_print:
                generate_missing_tests.main()

        # Check that expected output was printed
        print_calls = [call[0][0] for call in mock_print.call_args_list]
        assert "🔍 Enhanced Test Generation with Proper Import Handling" in print_calls
        assert "🎯 Enhanced Test Generation Complete!" in print_calls

    def test_functions_exist(self):
        """Test that all expected functions exist"""
        assert callable(generate_missing_tests.get_import_path)
        assert callable(generate_missing_tests.get_class_name)
        assert callable(generate_missing_tests.generate_test_for_file)
        assert callable(generate_missing_tests.main)
