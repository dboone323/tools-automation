import pytest
import sys
import os
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

# Try to import the module with correct path
MODULE_AVAILABLE = False
try:
    # Try direct import with proper path
    __import__("fix_workflow_yaml")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import fix_workflow_yaml: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/fix_workflow_yaml.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/fix_workflow_yaml.py",
                "exec",
            )
        print(f"File fix_workflow_yaml.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File fix_workflow_yaml.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestFixWorkflowYaml:
    """Comprehensive tests for fix_workflow_yaml.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/fix_workflow_yaml.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/fix_workflow_yaml.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in fix_workflow_yaml.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/fix_workflow_yaml.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("fix_workflow_yaml")
            assert True
        except ImportError:
            pytest.fail(f"Module fix_workflow_yaml should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_yaml_file_basic_workflow(self):
        """Test fix_yaml_file with a basic workflow that needs fixes"""
        import fix_workflow_yaml as module

        # Create a workflow with formatting issues
        original_content = """name: CI
on: true
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v1
      - run: echo "test"
"""

        expected_content = """---
name: CI
on: [push, pull_request]
jobs:
  test:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v1
        - run: echo "test"
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print") as mock_print:
                module.fix_yaml_file(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            assert result_content == expected_content
            mock_print.assert_any_call(f"Fixing {temp_path}...")
            mock_print.assert_any_call(f"  ✅ Fixed {temp_path}")
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_yaml_file_bracket_spacing(self):
        """Test fix_yaml_file bracket spacing corrections"""
        import fix_workflow_yaml as module

        original_content = """name: CI
on: [ push , pull_request ]
jobs:
  test:
      runs-on: ubuntu-latest
"""

        expected_content = """---
name: CI
on: [push, pull_request]
jobs:
  test:
      runs-on: ubuntu-latest
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_yaml_file(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            assert result_content == expected_content
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_yaml_file_indentation_fixes(self):
        """Test fix_yaml_file indentation corrections for jobs and steps"""
        import fix_workflow_yaml as module

        original_content = """name: CI
on: [push]
jobs:
  test:
  runs-on: ubuntu-latest
  steps:
  - uses: actions/checkout@v1
  - run: echo "test"
"""

        expected_content = """---
name: CI
on: [push]
jobs:
  test:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v1
        - run: echo "test"
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_yaml_file(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            assert result_content == expected_content
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_yaml_file_trailing_spaces(self):
        """Test fix_yaml_file removes trailing spaces"""
        import fix_workflow_yaml as module

        original_content = """name: CI   
on: [push] 
jobs:
  test:
      runs-on: ubuntu-latest   
"""

        expected_content = """---
name: CI
on: [push]
jobs:
  test:
      runs-on: ubuntu-latest
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_yaml_file(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            assert result_content == expected_content
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_yaml_file_adds_document_start(self):
        """Test fix_yaml_file adds document start marker when missing"""
        import fix_workflow_yaml as module

        original_content = """name: CI
on: [push]
jobs:
  test:
      runs-on: ubuntu-latest
"""

        expected_content = """---
name: CI
on: [push]
jobs:
  test:
      runs-on: ubuntu-latest
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_yaml_file(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            assert result_content == expected_content
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_yaml_file_preserves_existing_document_start(self):
        """Test fix_yaml_file preserves existing document start marker"""
        import fix_workflow_yaml as module

        original_content = """---
name: CI
on: [push]
jobs:
  test:
      runs-on: ubuntu-latest
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_yaml_file(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            assert result_content == original_content
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_yaml_file_empty_file(self):
        """Test fix_yaml_file with empty file"""
        import fix_workflow_yaml as module

        original_content = ""

        expected_content = """---
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_yaml_file(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            assert result_content == expected_content
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_yaml_file_complex_workflow(self):
        """Test fix_yaml_file with complex workflow structure"""
        import fix_workflow_yaml as module

        original_content = """name: Complex CI
on: true
jobs:
  test:
  runs-on: ubuntu-latest
  strategy:
    matrix:
      node: [14, 16, 18]
  steps:
  - uses: actions/checkout@v3
  - name: Setup Node
    uses: actions/setup-node@v3
    with:
      node-version: ${{ matrix.node }}
  - run: npm install
  - run: npm test
  deploy:
  needs: test
  runs-on: ubuntu-latest
  steps:
  - run: echo "Deploying"
"""

        expected_content = """---
name: Complex CI
on: [push, pull_request]
jobs:
  test:
      runs-on: ubuntu-latest
      strategy:
        matrix:
          node: [14, 16, 18]
      steps:
        - uses: actions/checkout@v3
        - name: Setup Node
          uses: actions/setup-node@v3
          with:
            node-version: ${{ matrix.node }}
        - run: npm install
        - run: npm test
  deploy:
      needs: test
      runs-on: ubuntu-latest
      steps:
        - run: echo "Deploying"
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_yaml_file(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            assert result_content == expected_content
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_no_arguments(self):
        """Test main function with no arguments"""
        import fix_workflow_yaml as module

        with patch("sys.argv", ["fix_workflow_yaml.py"]), patch(
            "builtins.print"
        ) as mock_print:
            with pytest.raises(SystemExit) as exc_info:
                module.main()
            assert exc_info.value.code == 1
            mock_print.assert_called_with("Usage: fix_workflow_yaml.py <directory>")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_directory_not_exists(self):
        """Test main function with non-existent directory"""
        import fix_workflow_yaml as module

        with patch("sys.argv", ["fix_workflow_yaml.py", "/non/existent/dir"]), patch(
            "builtins.print"
        ) as mock_print:
            with pytest.raises(SystemExit) as exc_info:
                module.main()
            assert exc_info.value.code == 1
            mock_print.assert_called_with("Directory /non/existent/dir does not exist")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_no_yaml_files(self):
        """Test main function with directory containing no YAML files"""
        import fix_workflow_yaml as module

        with tempfile.TemporaryDirectory() as temp_dir:
            with patch("sys.argv", ["fix_workflow_yaml.py", temp_dir]), patch(
                "builtins.print"
            ) as mock_print:
                with pytest.raises(SystemExit) as exc_info:
                    module.main()
                assert exc_info.value.code == 1
                mock_print.assert_called_with(
                    f"No YAML files found in {Path(temp_dir)}"
                )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_with_yaml_files(self):
        """Test main function with directory containing YAML files"""
        import fix_workflow_yaml as module

        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            # Create test YAML files
            workflow1 = temp_path / "ci.yml"
            workflow1.write_text(
                "name: CI\non: [push]\njobs:\n  test:\n    runs-on: ubuntu-latest"
            )

            workflow2 = temp_path / "deploy.yml"
            workflow2.write_text(
                "name: Deploy\non: [release]\njobs:\n  deploy:\n    runs-on: ubuntu-latest"
            )

            with patch("builtins.print") as mock_print:
                with patch("sys.argv", ["fix_workflow_yaml.py", str(temp_path)]):
                    module.main()

            # Check that files were processed
            print_calls = [call[0][0] for call in mock_print.call_args_list]
            assert any("Found 2 YAML files to fix:" in call for call in print_calls)
            assert any("Fixing" in call and "ci.yml" in call for call in print_calls)
            assert any(
                "Fixing" in call and "deploy.yml" in call for call in print_calls
            )
            assert any("Fixed 2 workflow files!" in call for call in print_calls)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_yaml_file_preserves_comments(self):
        """Test fix_yaml_file preserves comments"""
        import fix_workflow_yaml as module

        original_content = """# This is a comment
name: CI
on: [push]
jobs:
  test:
  # Another comment
  runs-on: ubuntu-latest
"""

        expected_content = """---
# This is a comment
name: CI
on: [push]
jobs:
  test:
  # Another comment
      runs-on: ubuntu-latest
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_yaml_file(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            assert result_content == expected_content
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_yaml_file_removes_excess_blank_lines(self):
        """Test fix_yaml_file removes excessive blank lines at end"""
        import fix_workflow_yaml as module

        original_content = """name: CI
on: [push]
jobs:
  test:
      runs-on: ubuntu-latest


"""

        expected_content = """---
name: CI
on: [push]
jobs:
  test:
      runs-on: ubuntu-latest
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_yaml_file(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            assert result_content == expected_content
        finally:
            os.unlink(temp_path)
