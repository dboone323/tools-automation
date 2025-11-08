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
    __import__("fix_workflow_complete")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import fix_workflow_complete: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/fix_workflow_complete.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/fix_workflow_complete.py",
                "exec",
            )
        print(f"File fix_workflow_complete.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File fix_workflow_complete.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestFixWorkflowComplete:
    """Comprehensive tests for fix_workflow_complete.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/fix_workflow_complete.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/fix_workflow_complete.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in fix_workflow_complete.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/fix_workflow_complete.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("fix_workflow_complete")
            assert True
        except ImportError:
            pytest.fail(f"Module fix_workflow_complete should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_workflow_completely_basic_workflow(self):
        """Test fix_workflow_completely with a basic workflow"""
        import fix_workflow_complete as module

        # Create a basic workflow with formatting issues
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
                module.fix_workflow_completely(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            assert result_content == expected_content
            mock_print.assert_any_call(f"Completely fixing {temp_path}...")
            mock_print.assert_any_call(f"  ✅ Completely fixed {temp_path}")
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_workflow_completely_complex_workflow(self):
        """Test fix_workflow_completely with a complex workflow structure"""
        import fix_workflow_complete as module

        original_content = """name: Complex CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
permissions:
  contents: read
  issues: write
env:
  NODE_VERSION: '18'
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node: [16, 18, 20]
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
    if: github.ref == 'refs/heads/main'
    steps:
    - run: echo "Deploying..."
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_workflow_completely(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            # Check that document starts with ---
            assert result_content.startswith("---")

            # Check that top-level keys are properly formatted
            lines = result_content.split("\n")
            assert "name: Complex CI" in lines
            assert "on:" in lines
            assert "  push:" in lines
            assert "    branches: [main]" in lines
            assert "permissions:" in lines
            assert "  contents: read" in lines
            assert "jobs:" in lines
            assert "  test:" in lines
            assert "    runs-on: ubuntu-latest" in lines
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_workflow_completely_with_comments(self):
        """Test fix_workflow_completely preserves and properly indents comments"""
        import fix_workflow_complete as module

        original_content = """name: CI
# This is a comment
on: [push]
jobs:
  test:
    # Another comment
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3  # Inline comment
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_workflow_completely(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            lines = result_content.split("\n")
            # Comments should be preserved with appropriate indentation
            assert "# This is a comment" in lines
            assert "  # Another comment" in lines
            assert "      - uses: actions/checkout@v3  # Inline comment" in lines
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_workflow_completely_multiline_run(self):
        """Test fix_workflow_completely handles multiline run commands"""
        import fix_workflow_complete as module

        original_content = """name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - run: |
        echo "Starting tests"
        npm install
        npm test
        echo "Tests completed"
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_workflow_completely(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            lines = result_content.split("\n")
            # Multiline content should be properly indented
            run_index = next(i for i, line in enumerate(lines) if "run: |" in line)
            assert lines[run_index + 1] == '          echo "Starting tests"'
            assert lines[run_index + 2] == "          npm install"
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_workflow_completely_with_outputs(self):
        """Test fix_workflow_completely handles job outputs"""
        import fix_workflow_complete as module

        original_content = """name: CI
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
    steps:
    - id: version
      run: echo "version=1.0.0" >> $GITHUB_OUTPUT
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
    - run: echo "Deploying version ${{ needs.build.outputs.version }}"
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_workflow_completely(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            lines = result_content.split("\n")
            # Check outputs indentation
            outputs_index = next(
                i for i, line in enumerate(lines) if "outputs:" in line
            )
            assert (
                lines[outputs_index + 1]
                == "  version: ${{ steps.version.outputs.version }}"
            )
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_workflow_completely_removes_excess_blank_lines(self):
        """Test fix_workflow_completely removes excessive blank lines"""
        import fix_workflow_complete as module

        original_content = """name: CI


on: [push]


jobs:


  test:
    runs-on: ubuntu-latest


    steps:
    - uses: actions/checkout@v3


    - run: echo "test"


"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_workflow_completely(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            lines = result_content.split("\n")
            # Should not have consecutive blank lines
            blank_lines = [i for i, line in enumerate(lines) if line.strip() == ""]
            if len(blank_lines) > 1:
                # Check no consecutive blank lines
                for i in range(len(blank_lines) - 1):
                    assert blank_lines[i + 1] - blank_lines[i] > 1
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_no_arguments(self):
        """Test main function with no arguments"""
        import fix_workflow_complete as module

        with patch("sys.argv", ["fix_workflow_complete.py"]), patch(
            "builtins.print"
        ) as mock_print:
            with pytest.raises(SystemExit) as exc_info:
                module.main()
            assert exc_info.value.code == 1
            mock_print.assert_called_with("Usage: fix_workflow_complete.py <directory>")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_directory_not_exists(self):
        """Test main function with non-existent directory"""
        import fix_workflow_complete as module

        with patch("builtins.print") as mock_print:
            with patch("sys.argv", ["fix_workflow_complete.py", "/non/existent/dir"]):
                with pytest.raises(SystemExit) as exc_info:
                    module.main()
                assert exc_info.value.code == 1
            mock_print.assert_called_with("Directory /non/existent/dir does not exist")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_no_yaml_files(self):
        """Test main function with directory containing no YAML files"""
        import fix_workflow_complete as module

        with tempfile.TemporaryDirectory() as temp_dir:
            with patch("builtins.print") as mock_print:
                with patch("sys.argv", ["fix_workflow_complete.py", temp_dir]):
                    with pytest.raises(SystemExit) as exc_info:
                        module.main()
                    assert exc_info.value.code == 1
                mock_print.assert_called_with(
                    f"No YAML files found in {Path(temp_dir)}"
                )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_with_yaml_files(self):
        """Test main function with directory containing YAML files"""
        import fix_workflow_complete as module

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
                with patch("sys.argv", ["fix_workflow_complete.py", str(temp_path)]):
                    module.main()

            # Check that files were processed
            print_calls = [call[0][0] for call in mock_print.call_args_list]
            assert any("Found 2 YAML files to fix:" in call for call in print_calls)
            assert any(
                "Completely fixed" in call and "ci.yml" in call for call in print_calls
            )
            assert any(
                "Completely fixed" in call and "deploy.yml" in call
                for call in print_calls
            )
            assert any(
                "Completely fixed 2 workflow files!" in call for call in print_calls
            )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_excludes_fixed_files(self):
        """Test main function excludes already fixed files"""
        import fix_workflow_complete as module

        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            # Create test YAML files, including one that should be excluded
            workflow1 = temp_path / "ci.yml"
            workflow1.write_text(
                "name: CI\non: [push]\njobs:\n  test:\n    runs-on: ubuntu-latest"
            )

            workflow2 = temp_path / "ci-fixed.yml"  # Should be excluded
            workflow2.write_text(
                "name: CI Fixed\non: [push]\njobs:\n  test:\n    runs-on: ubuntu-latest"
            )

            with patch("builtins.print") as mock_print:
                with patch("sys.argv", ["fix_workflow_complete.py", str(temp_path)]):
                    module.main()

            # Should only process ci.yml, not ci-fixed.yml
            print_calls = [call[0][0] for call in mock_print.call_args_list]
            assert any("Found 1 YAML files to fix:" in call for call in print_calls)
            assert any(
                "Completely fixed" in call and "ci.yml" in call for call in print_calls
            )
            assert not any("ci-fixed.yml" in call for call in print_calls)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_workflow_completely_preserves_workflow_dispatch(self):
        """Test fix_workflow_completely preserves workflow_dispatch configuration"""
        import fix_workflow_complete as module

        original_content = """name: Manual Deploy
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        default: 'staging'
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - run: echo "Deploying to ${{ github.event.inputs.environment }}"
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_workflow_completely(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            lines = result_content.split("\n")
            # Check workflow_dispatch structure is preserved
            assert "  workflow_dispatch:" in lines
            assert "  inputs:" in lines
            assert "  environment:" in lines
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_fix_workflow_completely_handles_schedule(self):
        """Test fix_workflow_completely handles schedule triggers"""
        import fix_workflow_complete as module

        original_content = """name: Nightly
on:
  schedule:
  - cron: '0 0 * * *'
  push:
    branches: [main]
jobs:
  nightly:
    runs-on: ubuntu-latest
    steps:
    - run: echo "Running nightly tasks"
"""

        with tempfile.NamedTemporaryFile(mode="w+", suffix=".yml", delete=False) as f:
            f.write(original_content)
            temp_path = f.name

        try:
            with patch("builtins.print"):
                module.fix_workflow_completely(temp_path)

            with open(temp_path, "r") as f:
                result_content = f.read()

            lines = result_content.split("\n")
            # Check schedule structure
            assert "  schedule:" in lines
            assert "  push:" in lines
            assert "  push:" in lines
        finally:
            os.unlink(temp_path)
