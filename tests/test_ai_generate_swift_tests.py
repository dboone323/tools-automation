import pytest
import sys
import os
import json
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock, mock_open
from datetime import datetime

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import ai_generate_swift_tests


class TestAiGenerateSwiftTests:
    """Comprehensive tests for ai_generate_swift_tests.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/ai_generate_swift_tests.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/ai_generate_swift_tests.py",
                    "exec",
                )
        except SyntaxError as e:
            pytest.fail(f"Syntax error in ai_generate_swift_tests.py: {e}")

    def test_file_exists(self):
        """Test that the module file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/ai_generate_swift_tests.py"
        )

    def test_module_can_be_imported(self):
        """Test that the module can be imported"""
        try:
            import ai_generate_swift_tests
        except ImportError as e:
            pytest.fail(f"Module ai_generate_swift_tests should be importable: {e}")

    def test_is_excluded(self):
        """Test directory exclusion logic"""
        # Should exclude
        assert ai_generate_swift_tests.is_excluded(Path("Tests/file.swift")) == True
        assert ai_generate_swift_tests.is_excluded(Path("UnitTests/file.swift")) == True
        assert ai_generate_swift_tests.is_excluded(Path("AutoTests/file.swift")) == True
        assert ai_generate_swift_tests.is_excluded(Path(".build/file.swift")) == True
        assert ai_generate_swift_tests.is_excluded(Path("Pods/file.swift")) == True

        # Should not exclude
        assert ai_generate_swift_tests.is_excluded(Path("Sources/file.swift")) == False
        assert ai_generate_swift_tests.is_excluded(Path("Models/file.swift")) == False

    @patch("os.walk")
    def test_find_swift_files(self, mock_walk):
        """Test finding Swift files in project directory"""
        mock_walk.return_value = [
            ("/project", ["Tests", "Sources"], ["file1.txt", "file2.swift"]),
            ("/project/Sources", [], ["class.swift", "util.swift"]),
            ("/project/Tests", [], ["test.swift"]),  # Should be excluded
        ]

        files = list(ai_generate_swift_tests.find_swift_files(Path("/project")))
        expected = [
            Path("/project/file2.swift"),
            Path("/project/Sources/class.swift"),
            Path("/project/Sources/util.swift"),
        ]
        assert files == expected

    def test_extract_types_and_methods(self):
        """Test extracting types and methods from Swift code"""
        swift_code = """
        public class MyClass: NSObject {
            public func doSomething(param: String) -> Bool {
                return true
            }

            private func _privateMethod() {
            }

            public static func createInstance() -> MyClass {
                return MyClass()
            }
        }

        struct MyStruct {
            func process() {
            }
        }

        enum MyEnum {
            case one, two
        }
        """

        types, methods = ai_generate_swift_tests.extract_types_and_methods(swift_code)
        assert "MyClass" in types
        assert "MyStruct" in types
        assert "MyEnum" in types
        assert "doSomething" in methods
        assert "createInstance" in methods
        assert "_privateMethod" not in methods
        assert "process" in methods

    def test_extract_types_and_methods_limits_methods(self):
        """Test that methods are limited to 6 per file"""
        swift_code = """
        class TestClass {
            func method1() {}
            func method2() {}
            func method3() {}
            func method4() {}
            func method5() {}
            func method6() {}
            func method7() {}
        }
        """

        types, methods = ai_generate_swift_tests.extract_types_and_methods(swift_code)
        assert len(methods) <= 6  # Should be capped at 6

    @patch("ai_generate_swift_tests.datetime")
    def test_unique_output_path_no_conflict(self, mock_datetime):
        """Test unique output path when no conflict exists"""
        mock_datetime.now.return_value.timestamp.return_value = 1234567890

        base_dir = Path("/tmp")
        base_name = "GeneratedTests_20231201.swift"
        result = ai_generate_swift_tests.unique_output_path(base_dir, base_name)

        expected = base_dir / base_name
        assert result == expected

    @patch("ai_generate_swift_tests.datetime")
    @patch("pathlib.Path.exists")
    def test_unique_output_path_with_conflict(self, mock_exists, mock_datetime):
        """Test unique output path when conflict exists"""
        mock_exists.return_value = True
        mock_now = Mock()
        mock_now.timestamp.return_value = 1234567890
        mock_datetime.now.return_value = mock_now

        base_dir = Path("/tmp")
        base_name = "GeneratedTests_20231201.swift"
        result = ai_generate_swift_tests.unique_output_path(base_dir, base_name)

        # Should have suffix added
        assert result.name.startswith("GeneratedTests_2023120_")
        assert result.name.endswith(".swift")
        assert len(result.name) > len("GeneratedTests_20231201.swift")

    @patch("ai_generate_swift_tests.find_swift_files")
    @patch("ai_generate_swift_tests.unique_output_path")
    @patch("pathlib.Path.mkdir")
    @patch("pathlib.Path.write_text")
    def test_generate_tests_for_project_with_types(
        self, mock_write, mock_mkdir, mock_unique_path, mock_find_files
    ):
        """Test generating tests for project with discovered types"""
        # Mock file discovery
        mock_file1 = Mock()
        mock_file1.read_text.return_value = """
        public class TestClass {
            public func doSomething() {}
        }
        """
        mock_find_files.return_value = [mock_file1]

        # Mock output path
        mock_output_path = Path("/mock/path/GeneratedTests_20231201.swift")
        mock_unique_path.return_value = mock_output_path

        with patch("ai_generate_swift_tests.datetime") as mock_datetime:
            mock_datetime.now.return_value.strftime.return_value = "20231201"
            mock_datetime.now.return_value.isoformat.return_value = (
                "2023-12-01T10:00:00"
            )

            project_dir = Path("/Projects/TestProject")
            result = ai_generate_swift_tests.generate_tests_for_project(project_dir)

        assert result["project"] == "TestProject"
        assert result["status"] == "ok"
        assert result["output"] == str(mock_output_path)
        mock_write.assert_called_once()
        mock_mkdir.assert_called_once_with(parents=True, exist_ok=True)

    @patch("ai_generate_swift_tests.find_swift_files")
    @patch("pathlib.Path.mkdir")
    def test_generate_tests_for_project_no_types(self, mock_mkdir, mock_find_files):
        """Test generating tests for project with no types found"""
        mock_find_files.return_value = []

        project_dir = Path("/Projects/EmptyProject")
        result = ai_generate_swift_tests.generate_tests_for_project(project_dir)

        assert result["project"] == "EmptyProject"
        assert result["status"] == "no_types_found"
        mock_mkdir.assert_called_once_with(parents=True, exist_ok=True)

    @patch("ai_generate_swift_tests.generate_tests_for_project")
    @patch("pathlib.Path.exists")
    @patch("pathlib.Path.is_dir")
    @patch("pathlib.Path.iterdir")
    @patch("pathlib.Path.mkdir")
    @patch("pathlib.Path.write_text")
    def test_main_all_projects(
        self,
        mock_write,
        mock_mkdir,
        mock_iterdir,
        mock_is_dir,
        mock_exists,
        mock_generate,
    ):
        """Test main function processing all projects"""
        # Mock project directories
        mock_proj1 = Mock()
        mock_proj1.name = "Project1"
        mock_proj1.is_dir.return_value = True
        mock_proj2 = Mock()
        mock_proj2.name = "Project2"
        mock_proj2.is_dir.return_value = True
        mock_iterdir.return_value = [mock_proj1, mock_proj2]

        mock_generate.side_effect = [
            {"project": "Project1", "status": "ok", "output": "/path1"},
            {"project": "Project2", "status": "ok", "output": "/path2"},
        ]

        with patch("sys.argv", ["ai_generate_swift_tests.py"]):
            result = ai_generate_swift_tests.main([])

        assert result == 0
        assert mock_generate.call_count == 2

    @patch("ai_generate_swift_tests.generate_tests_for_project")
    @patch("pathlib.Path.exists")
    @patch("pathlib.Path.is_dir")
    def test_main_specific_project_not_found(
        self, mock_is_dir, mock_exists, mock_generate
    ):
        """Test main function with non-existent specific project"""
        mock_exists.return_value = False

        with patch(
            "sys.argv", ["ai_generate_swift_tests.py", "--project", "NonExistent"]
        ):
            result = ai_generate_swift_tests.main(["--project", "NonExistent"])

        assert result == 2

    @patch("ai_generate_swift_tests.generate_tests_for_project")
    @patch("pathlib.Path.exists")
    @patch("pathlib.Path.is_dir")
    def test_main_specific_project(self, mock_is_dir, mock_exists, mock_generate):
        """Test main function with specific project"""
        mock_exists.return_value = True
        mock_is_dir.return_value = True
        mock_generate.return_value = {"project": "TestProject", "status": "ok"}

        with patch(
            "sys.argv", ["ai_generate_swift_tests.py", "--project", "TestProject"]
        ):
            result = ai_generate_swift_tests.main(["--project", "TestProject"])

        assert result == 0
        mock_generate.assert_called_once()

    def test_extract_types_and_methods_edge_cases(self):
        """Test extract_types_and_methods with various edge cases"""
        # Test with empty code
        types, methods = ai_generate_swift_tests.extract_types_and_methods("")
        assert types == []
        assert methods == []

        # Test with code that has no matches
        types, methods = ai_generate_swift_tests.extract_types_and_methods("let x = 5")
        assert types == []
        assert methods == []

    def test_constants_and_regex(self):
        """Test that constants and regex patterns are properly defined"""
        assert hasattr(ai_generate_swift_tests, "TYPE_REGEX")
        assert hasattr(ai_generate_swift_tests, "METHOD_REGEX")
        assert hasattr(ai_generate_swift_tests, "EXCLUDE_DIR_NAMES")
        assert hasattr(ai_generate_swift_tests, "HEADER")
        assert hasattr(ai_generate_swift_tests, "TEST_TEMPLATE")
        assert hasattr(ai_generate_swift_tests, "METHOD_TEST_TEMPLATE")

        # Test exclude dir names
        assert "Tests" in ai_generate_swift_tests.EXCLUDE_DIR_NAMES
        assert "AutoTests" in ai_generate_swift_tests.EXCLUDE_DIR_NAMES

    @patch("ai_generate_swift_tests.datetime")
    def test_template_formatting(self, mock_datetime):
        """Test that templates contain proper placeholders"""
        mock_datetime.now.return_value.isoformat.return_value = "2023-12-01T10:00:00"

        header = ai_generate_swift_tests.HEADER.format(
            date="2023-12-01T10:00:00", project="TestProject", module="TestModule"
        )

        assert "2023-12-01T10:00:00" in header
        assert "TestProject" in header
        assert "TestModule" in header
        assert "import XCTest" in header

    def test_method_test_template(self):
        """Test method test template formatting"""
        template = ai_generate_swift_tests.METHOD_TEST_TEMPLATE.format(
            type_name="MyClass", method_name="doSomething"
        )

        assert "test_doSomething_behaviour" in template
        assert "MyClass.doSomething" in template
        assert "XCTFail" in template

    def test_test_template(self):
        """Test test class template formatting"""
        template = ai_generate_swift_tests.TEST_TEMPLATE.format(
            type_name="MyClass", method_tests="\n    func test_example() {}"
        )

        assert "final class MyClassTests: XCTestCase" in template
        assert "setUp()" in template
        assert "tearDown()" in template
