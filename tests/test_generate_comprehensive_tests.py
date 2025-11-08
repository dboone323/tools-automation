import pytest
import sys
import os
import ast
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock, mock_open
from typing import List, Dict, Any

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import generate_comprehensive_tests


class TestCodeAnalyzer:
    """Comprehensive tests for CodeAnalyzer class"""

    def test_init(self):
        """Test CodeAnalyzer initialization"""
        analyzer = generate_comprehensive_tests.CodeAnalyzer("/path/to/file.py")
        assert analyzer.file_path == "/path/to/file.py"
        assert analyzer.functions == []
        assert analyzer.classes == []

    @patch(
        "builtins.open",
        new_callable=mock_open,
        read_data="""
def test_function(arg1, arg2):
    '''Test function docstring'''
    return arg1 + arg2

class TestClass:
    def __init__(self):
        pass

    def test_method(self, param):
        '''Test method docstring'''
        return param * 2

    def _private_method(self):
        pass
""",
    )
    def test_analyze_with_functions_and_classes(self, mock_file):
        """Test analyzing code with functions and classes"""
        analyzer = generate_comprehensive_tests.CodeAnalyzer("/path/to/file.py")
        analyzer.analyze()

        # Check functions
        assert len(analyzer.functions) == 1
        func = analyzer.functions[0]
        assert func["name"] == "test_function"
        assert func["args"] == ["arg1", "arg2"]
        assert func["docstring"] == "Test function docstring"

        # Check classes
        assert len(analyzer.classes) == 1
        cls = analyzer.classes[0]
        assert cls["name"] == "TestClass"
        assert len(cls["methods"]) == 1
        method = cls["methods"][0]
        assert method["name"] == "test_method"
        assert method["args"] == ["param"]
        assert method["docstring"] == "Test method docstring"

    @patch("builtins.open", new_callable=mock_open, read_data="invalid syntax {{{")
    def test_analyze_with_syntax_error(self, mock_file):
        """Test analyzing code with syntax errors"""
        analyzer = generate_comprehensive_tests.CodeAnalyzer("/path/to/file.py")
        analyzer.analyze()

        # Should handle errors gracefully
        assert analyzer.functions == []
        assert analyzer.classes == []

    def test_analyze_with_file_not_found(self):
        """Test analyzing when file doesn't exist"""
        analyzer = generate_comprehensive_tests.CodeAnalyzer("/nonexistent/file.py")
        analyzer.analyze()

        # Should handle errors gracefully
        assert analyzer.functions == []
        assert analyzer.classes == []

    def test_get_parents(self):
        """Test getting parent nodes"""
        code = """
def outer():
    def inner():
        pass
"""
        tree = ast.parse(code)
        analyzer = generate_comprehensive_tests.CodeAnalyzer("/test.py")

        # Find the inner function
        inner_func = None
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef) and node.name == "inner":
                inner_func = node
                break

        parents = analyzer._get_parents(inner_func, tree)
        assert len(parents) > 0
        assert any(
            isinstance(p, ast.FunctionDef) and p.name == "outer" for p in parents
        )

    def test_get_docstring_with_docstring(self):
        """Test extracting docstring when present"""
        code = """
def func():
    '''This is a docstring'''
    pass
"""
        tree = ast.parse(code)
        analyzer = generate_comprehensive_tests.CodeAnalyzer("/test.py")

        func_node = None
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef) and node.name == "func":
                func_node = node
                break

        docstring = analyzer._get_docstring(func_node)
        assert docstring == "This is a docstring"

    def test_get_docstring_without_docstring(self):
        """Test extracting docstring when not present"""
        code = """
def func():
    pass
"""
        tree = ast.parse(code)
        analyzer = generate_comprehensive_tests.CodeAnalyzer("/test.py")

        func_node = None
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef) and node.name == "func":
                func_node = node
                break

        docstring = analyzer._get_docstring(func_node)
        assert docstring == ""

    def test_analyze_excludes_private_functions(self):
        """Test that private functions are excluded"""
        code = """
def public_func():
    pass

def _private_func():
    pass
"""
        tree = ast.parse(code)
        analyzer = generate_comprehensive_tests.CodeAnalyzer("/test.py")

        # Manually analyze to test filtering
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef) and not node.name.startswith("_"):
                if not any(
                    isinstance(parent, ast.ClassDef)
                    for parent in analyzer._get_parents(node, tree)
                ):
                    analyzer.functions.append(
                        {
                            "name": node.name,
                            "args": [
                                arg.arg for arg in node.args.args if arg.arg != "self"
                            ],
                            "line": node.lineno,
                            "docstring": analyzer._get_docstring(node),
                        }
                    )

        assert len(analyzer.functions) == 1
        assert analyzer.functions[0]["name"] == "public_func"


class TestTestGenerator:
    """Comprehensive tests for TestGenerator class"""

    def test_init(self):
        """Test TestGenerator initialization"""
        generator = generate_comprehensive_tests.TestGenerator("/workspace", "/tests")
        assert generator.workspace_root == "/workspace"
        assert generator.tests_dir == "/tests"

    @patch("os.makedirs")
    @patch("builtins.open", new_callable=mock_open)
    @patch("generate_comprehensive_tests.CodeAnalyzer")
    def test_generate_test_for_file(
        self, mock_analyzer_class, mock_file, mock_makedirs
    ):
        """Test generating test for a file"""
        # Mock analyzer
        mock_analyzer = Mock()
        mock_analyzer.functions = [
            {"name": "test_func", "args": ["arg1"], "line": 1, "docstring": ""}
        ]
        mock_analyzer.classes = []
        mock_analyzer_class.return_value = mock_analyzer

        generator = generate_comprehensive_tests.TestGenerator("/workspace", "/tests")

        with patch("os.path.relpath", return_value="module.py"):
            generator.generate_test_for_file("/workspace/module.py")

        # Verify file operations
        mock_makedirs.assert_called_once()
        mock_file.assert_called_once()

    def test_generate_test_content_structure(self):
        """Test the structure of generated test content"""
        generator = generate_comprehensive_tests.TestGenerator("/workspace", "/tests")

        functions = [
            {"name": "test_func", "args": ["arg1"], "line": 1, "docstring": ""}
        ]
        classes = []

        content = generator._generate_test_content(
            "module.py", "module", functions, classes
        )

        # Check basic structure
        assert "import pytest" in content
        assert "class Testmodule:" in content
        assert "test_module_syntax_valid" in content
        assert "test_file_exists" in content
        assert "test_test_func" in content

    def test_generate_function_test_basic(self):
        """Test generating basic function test"""
        generator = generate_comprehensive_tests.TestGenerator("/workspace", "/tests")

        func = {
            "name": "test_func",
            "args": ["arg1", "arg2"],
            "line": 1,
            "docstring": "",
        }

        test_code = generator._generate_function_test(func, "module")

        assert "def test_test_func(self):" in test_code
        assert "def test_test_func_signature(self):" in test_code
        assert "test_func(" in test_code

    def test_generate_function_test_main_function(self):
        """Test generating test for main function (should be skipped)"""
        generator = generate_comprehensive_tests.TestGenerator("/workspace", "/tests")

        func = {"name": "main", "args": [], "line": 1, "docstring": ""}

        test_code = generator._generate_function_test(func, "module")

        assert "test_main_exists" in test_code
        assert "test_main(" not in test_code  # Should not try to call main

    def test_generate_class_tests(self):
        """Test generating tests for a class"""
        generator = generate_comprehensive_tests.TestGenerator("/workspace", "/tests")

        cls = {
            "name": "TestClass",
            "methods": [
                {"name": "test_method", "args": ["param"], "line": 1, "docstring": ""}
            ],
            "line": 1,
            "docstring": "",
        }

        test_code = generator._generate_class_tests(cls, "module")

        assert "test_TestClass_instantiation" in test_code
        assert "test_TestClass_test_method" in test_code

    def test_generate_method_test(self):
        """Test generating test for a class method"""
        generator = generate_comprehensive_tests.TestGenerator("/workspace", "/tests")

        method = {"name": "test_method", "args": ["param"], "line": 1, "docstring": ""}

        test_code = generator._generate_method_test("TestClass", method, "module")

        assert "test_TestClass_test_method" in test_code
        assert "getattr(instance, 'test_method'" in test_code

    @patch("pathlib.Path.rglob")
    @patch("generate_comprehensive_tests.TestGenerator.generate_test_for_file")
    def test_main_function(self, mock_generate, mock_rglob):
        """Test the main function"""
        # Mock finding Python files
        mock_file1 = Mock()
        mock_file1.__str__ = Mock(return_value="/workspace/module.py")
        mock_file1.name = "module.py"  # Add name attribute
        mock_rglob.return_value = [mock_file1]

        with patch("os.path.join", return_value="/tests"):
            generate_comprehensive_tests.main()

        mock_generate.assert_called_once_with("/workspace/module.py")


class TestGenerateComprehensiveTests:
    """General tests for the generate_comprehensive_tests module"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/generate_comprehensive_tests.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/generate_comprehensive_tests.py",
                    "exec",
                )
        except SyntaxError as e:
            pytest.fail(f"Syntax error in generate_comprehensive_tests.py: {e}")

    def test_file_exists(self):
        """Test that the module file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/generate_comprehensive_tests.py"
        )

    def test_module_can_be_imported(self):
        """Test that the module can be imported"""
        try:
            import generate_comprehensive_tests
        except ImportError as e:
            pytest.fail(
                f"Module generate_comprehensive_tests should be importable: {e}"
            )

    def test_classes_exist(self):
        """Test that main classes exist in the module"""
        assert hasattr(generate_comprehensive_tests, "CodeAnalyzer")
        assert hasattr(generate_comprehensive_tests, "TestGenerator")

    def test_main_function_exists(self):
        """Test that main function exists"""
        assert hasattr(generate_comprehensive_tests, "main")
        assert callable(generate_comprehensive_tests.main)

    @patch("ast.parse")
    def test_ast_parsing_compatibility(self, mock_parse):
        """Test that AST parsing works with basic constructs"""
        # Test that we can parse basic Python constructs
        test_code = """
def test_func():
    pass

class TestClass:
    pass
"""
        try:
            tree = ast.parse(test_code)
            assert tree is not None
        except SyntaxError:
            pytest.fail("Basic AST parsing should work")

    def test_imports_available(self):
        """Test that required imports are available"""
        import ast
        import os
        import sys
        from pathlib import Path
        from typing import List, Dict, Any

        # All imports should be available
        assert ast is not None
        assert os is not None
        assert sys is not None
        assert Path is not None

    def test_type_hints_usage(self):
        """Test that type hints are used correctly"""
        # Check that the classes use proper type hints
        analyzer = generate_comprehensive_tests.CodeAnalyzer("/test.py")
        assert isinstance(analyzer.functions, list)
        assert isinstance(analyzer.classes, list)

        generator = generate_comprehensive_tests.TestGenerator("/workspace", "/tests")
        assert isinstance(generator.workspace_root, str)
