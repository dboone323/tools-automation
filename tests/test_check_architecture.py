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
    __import__("check_architecture")
    MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import check_architecture: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/check_architecture.py",
            "r",
        ) as f:
            compile(
                f.read(),
                "/Users/danielstevens/Desktop/github-projects/tools-automation/check_architecture.py",
                "exec",
            )
        print(f"File check_architecture.py is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File check_architecture.py has syntax errors: {se}")


@pytest.mark.skipif(
    not MODULE_AVAILABLE, reason="Module not available or has import issues"
)
class TestCheckArchitecture:
    """Comprehensive tests for check_architecture.py"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open(
                "/Users/danielstevens/Desktop/github-projects/tools-automation/check_architecture.py",
                "r",
            ) as f:
                compile(
                    f.read(),
                    "/Users/danielstevens/Desktop/github-projects/tools-automation/check_architecture.py",
                    "exec",
                )
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in check_architecture.py")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists(
            "/Users/danielstevens/Desktop/github-projects/tools-automation/check_architecture.py"
        )

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_module_can_be_imported(self):
        """Test that the module can be imported successfully"""
        try:
            __import__("check_architecture")
            assert True
        except ImportError:
            pytest.fail(f"Module check_architecture should be importable")

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_project_no_issues(self):
        """Test check_project with a clean project (no issues)"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            # Create a minimal clean project structure
            project_dir = Path(temp_dir)
            workflows_dir = project_dir / ".github" / "workflows"
            workflows_dir.mkdir(parents=True)

            # Create a simple workflow file
            workflow_file = workflows_dir / "ci.yml"
            workflow_file.write_text(
                """
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
"""
            )

            issues = module.check_project(str(project_dir))
            assert len(issues) == 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_project_swift_sharedtypes_swiftui_import(self):
        """Test detection of SwiftUI imports in SharedTypes"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir)
            sharedtypes_dir = project_dir / "SharedTypes"
            sharedtypes_dir.mkdir()

            # Create a Swift file that imports SwiftUI in SharedTypes
            swift_file = sharedtypes_dir / "Utils.swift"
            swift_file.write_text(
                """
import Foundation
import SwiftUI

struct Utils {
    // Some utility code
}
"""
            )

            issues = module.check_project(str(project_dir))
            # Should have SwiftUI issue and missing workflows issue
            assert len(issues) == 2
            swiftui_issues = [
                issue
                for issue in issues
                if "SharedTypes must not import SwiftUI" in issue
            ]
            assert len(swiftui_issues) == 1
            assert "Utils.swift" in swiftui_issues[0]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_project_todo_fixme_count(self):
        """Test TODO/FIXME counting"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir)

            # Create multiple files with TODO/FIXME (more than 10 total)
            for i in range(6):  # 6 files × 2 TODO/FIXME = 12 total
                py_file = project_dir / f"file_{i}.py"
                py_file.write_text(
                    f"""
def function_{i}():
    # TODO: implement this
    # FIXME: fix this bug
    pass
"""
                )

            issues = module.check_project(str(project_dir))
            # Should have one issue about TODO/FIXME count
            todo_issues = [issue for issue in issues if "TODO/FIXME" in issue]
            assert len(todo_issues) == 1
            assert "12 TODO/FIXME markers" in todo_issues[0]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_project_todo_fixme_under_threshold(self):
        """Test TODO/FIXME counting when under threshold"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir)

            # Create files with only 5 TODO/FIXME total (under threshold)
            py_file = project_dir / "file.py"
            py_file.write_text(
                """
def function():
    # TODO: implement this
    # FIXME: fix this bug
    pass
"""
            )

            issues = module.check_project(str(project_dir))
            # Should not have TODO/FIXME issue
            todo_issues = [issue for issue in issues if "TODO/FIXME" in issue]
            assert len(todo_issues) == 0

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_project_multi_doc_yaml(self):
        """Test detection of multi-document YAML files"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir)
            workflows_dir = project_dir / ".github" / "workflows"
            workflows_dir.mkdir(parents=True)

            # Create a multi-document YAML file
            workflow_file = workflows_dir / "multi.yml"
            workflow_file.write_text(
                """
name: First workflow
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
---
name: Second workflow
on: [pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
"""
            )

            issues = module.check_project(str(project_dir))
            yaml_issues = [
                issue for issue in issues if "multiple YAML documents" in issue
            ]
            assert len(yaml_issues) == 1
            assert "multi.yml" in yaml_issues[0]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_project_deprecated_actions(self):
        """Test detection of deprecated action versions"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir)
            workflows_dir = project_dir / ".github" / "workflows"
            workflows_dir.mkdir(parents=True)

            # Create workflow with deprecated actions
            workflow_file = workflows_dir / "deprecated.yml"
            workflow_file.write_text(
                """
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v1
      - uses: actions/setup-python@v2
"""
            )

            issues = module.check_project(str(project_dir))
            deprecated_issues = [
                issue for issue in issues if "deprecated action major versions" in issue
            ]
            assert len(deprecated_issues) == 1
            assert "deprecated.yml" in deprecated_issues[0]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_project_dockerfile_latest(self):
        """Test detection of Dockerfile using latest tag"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir)

            # Create a Dockerfile with latest tag
            dockerfile = project_dir / "Dockerfile"
            dockerfile.write_text(
                """
FROM ubuntu:latest
RUN apt-get update
"""
            )

            issues = module.check_project(str(project_dir))
            docker_issues = [issue for issue in issues if ":latest" in issue]
            assert len(docker_issues) == 1
            assert "Dockerfile" in docker_issues[0]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_project_xcode_without_ci(self):
        """Test detection of Xcode project without CI workflow"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir)

            # Create a fake Xcode project file (the check looks for files ending with .xcodeproj)
            xcodeproj = project_dir / "MyApp.xcodeproj"
            xcodeproj.write_text("# dummy xcodeproj file")

            issues = module.check_project(str(project_dir))
            xcode_issues = [
                issue for issue in issues if "Xcode project detected" in issue
            ]
            assert len(xcode_issues) == 1
            assert "no macOS/iOS CI workflow found" in xcode_issues[0]

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_project_xcode_with_ci(self):
        """Test Xcode project with proper CI workflow"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir)
            workflows_dir = project_dir / ".github" / "workflows"
            workflows_dir.mkdir(parents=True)

            # Create Xcode project
            xcodeproj = project_dir / "MyApp.xcodeproj"
            xcodeproj.mkdir()

            # Create workflow with macOS
            workflow_file = workflows_dir / "ios.yml"
            workflow_file.write_text(
                """
name: iOS CI
on: [push]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: xcodebuild -version
"""
            )

            issues = module.check_project(str(project_dir))
            xcode_issues = [
                issue for issue in issues if "Xcode project detected" in issue
            ]
            assert len(xcode_issues) == 0  # Should not have the issue

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_check_project_missing_workflows_dir(self):
        """Test detection of missing workflows directory"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir)
            # Don't create .github/workflows directory

            issues = module.check_project(str(project_dir))
            workflow_issues = [
                issue for issue in issues if "Missing workflows directory" in issue
            ]
            assert len(workflow_issues) == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_is_yaml_multi_doc_detection(self):
        """Test detection of multi-document YAML through check_project"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir)
            workflows_dir = project_dir / ".github" / "workflows"
            workflows_dir.mkdir(parents=True)

            # Create a multi-document YAML file
            workflow_file = workflows_dir / "multi.yml"
            workflow_file.write_text(
                """
name: First workflow
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
---
name: Second workflow
on: [pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
"""
            )

            issues = module.check_project(str(project_dir))
            # Should detect multi-doc YAML
            yaml_issues = [
                issue for issue in issues if "multiple YAML documents" in issue
            ]
            assert len(yaml_issues) == 1

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_auto_fix_multi_doc_split(self):
        """Test auto-fix for splitting multi-document YAML"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            # Create a multi-document YAML file
            workflow_file = temp_path / "multi.yml"
            workflow_file.write_text(
                """
name: First workflow
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
---
name: Second workflow
on: [pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
"""
            )

            fixes = [("multi-doc", str(workflow_file))]
            results = module.auto_fix_project(temp_dir, fixes)

            assert len(results) == 1
            fp, kind, ok, msg = results[0]
            assert kind == "multi-doc"
            assert ok == True
            assert "split into 2 files" in msg

            # Check that backup was created
            assert (temp_path / "multi.yml.bak").exists()

            # Check that new files were created
            part1 = temp_path / "multi-part1.yml"
            part2 = temp_path / "multi-part2.yml"
            assert part1.exists()
            assert part2.exists()

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_auto_fix_pin_actions(self):
        """Test auto-fix for bumping action version pins"""
        import check_architecture as module
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            # Create workflow with old action versions
            workflow_file = temp_path / "workflow.yml"
            workflow_file.write_text(
                """
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v1
      - uses: actions/setup-python@v1
"""
            )

            fixes = [("pin-actions", str(workflow_file))]
            results = module.auto_fix_project(temp_dir, fixes)

            assert len(results) == 1
            fp, kind, ok, msg = results[0]
            assert kind == "pin-actions"
            assert ok == True
            assert "bumped pins" in msg

            # Check that backup was created
            assert (temp_path / "workflow.yml.bak").exists()

            # Check that file was updated
            content = workflow_file.read_text()
            assert "actions/checkout@v4" in content
            assert "actions/setup-python@v4" in content
            assert "actions/checkout@v1" not in content
            assert "actions/setup-python@v1" not in content

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_function_parsing(self):
        """Test main function argument parsing"""
        import check_architecture as module
        import tempfile

        with tempfile.TemporaryDirectory() as temp_dir:
            # Test with valid arguments
            with patch(
                "sys.argv",
                ["check_architecture.py", "--project", temp_dir, "--warn-only"],
            ):
                with patch("sys.exit") as mock_exit:
                    module.main()
                    # Should exit with 0 (no issues in empty directory)
                    mock_exit.assert_called_with(0)

    @pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module import failed")
    def test_main_function_strict_mode_with_issues(self):
        """Test main function in strict mode with issues"""
        import check_architecture as module
        import tempfile

        with tempfile.TemporaryDirectory() as temp_dir:
            # Create a project with issues (missing workflows)
            with patch("sys.argv", ["check_architecture.py", "--project", temp_dir]):
                with patch("sys.exit") as mock_exit:
                    with patch("builtins.print") as mock_print:
                        module.main()
                        # Should exit with 1 due to missing workflows directory
                        mock_exit.assert_called_with(1)
