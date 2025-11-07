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

import generate_test_report


class TestTestReportGenerator:
    """Comprehensive tests for generate_test_report.py"""

    @patch("subprocess.run")
    def test_run_all_tests_python_tests_success(self, mock_subprocess):
        """Test running Python tests successfully"""
        mock_result = Mock()
        mock_result.stdout = "passed"
        mock_result.stderr = ""
        mock_result.returncode = 0
        mock_subprocess.return_value = mock_result

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = Path("/fake/workspace")
        results = generator._run_all_tests()

        assert "python_tests" in results
        assert results["python_tests"]["passed"] is True
        assert results["python_tests"]["return_code"] == 0

        mock_subprocess.assert_called()

    @patch("subprocess.run")
    def test_run_all_tests_python_tests_failure(self, mock_subprocess):
        """Test running Python tests with failure"""
        mock_result = Mock()
        mock_result.stdout = "failed"
        mock_result.stderr = "error details"
        mock_result.returncode = 1
        mock_subprocess.return_value = mock_result

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = Path("/fake/workspace")
        results = generator._run_all_tests()

        assert results["python_tests"]["passed"] is False
        assert results["python_tests"]["return_code"] == 1

    @patch("subprocess.run")
    def test_run_all_tests_swift_builds_success(self, mock_subprocess):
        """Test running Swift builds successfully"""
        mock_result = Mock()
        mock_result.stdout = "build successful" * 100  # Long output
        mock_result.stderr = ""
        mock_result.returncode = 0
        mock_subprocess.return_value = mock_result

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = Path("/fake/workspace")
        results = generator._run_all_tests()

        assert results["swift_builds"]["completed"] is True
        assert results["swift_builds"]["return_code"] == 0
        assert len(results["swift_builds"]["output"]) <= 2000  # Should be truncated

    @patch("subprocess.run")
    def test_run_all_tests_exception_handling(self, mock_subprocess):
        """Test exception handling in test running"""
        mock_subprocess.side_effect = Exception("Command failed")

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = Path("/fake/workspace")
        results = generator._run_all_tests()

        assert "python_tests" in results
        assert "error" in results["python_tests"]
        assert results["python_tests"]["error"] == "Command failed"

    @patch("generate_test_report.yaml.safe_load")
    @patch("builtins.open", new_callable=mock_open)
    @patch("generate_test_report.Path")
    def test_validate_workflows_valid_workflow(
        self, mock_path_class, mock_open_file, mock_yaml_load
    ):
        """Test validating valid workflows"""
        mock_yaml_load.return_value = {
            "name": "Test Workflow",
            "jobs": {"test": "config"},
            True: True,  # Mock workflow_call trigger
        }

        # Mock the workflows directory structure
        mock_workspace = Mock()
        mock_github_dir = Mock()
        mock_workflows_dir = Mock()
        mock_workflows_dir.exists.return_value = True
        mock_workflow_file = Mock()
        mock_workflow_file.name = "test.yml"
        mock_workflows_dir.glob.return_value = [mock_workflow_file]

        # Set up the path traversal chain
        mock_workspace.__truediv__ = Mock(return_value=mock_github_dir)
        mock_github_dir.__truediv__ = Mock(return_value=mock_workflows_dir)
        mock_path_class.return_value = mock_workspace

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = mock_workspace
        results = generator._validate_workflows()

        assert "test.yml" in results
        assert results["test.yml"]["valid"] is True
        assert results["test.yml"]["name"] == "Test Workflow"
        assert results["test.yml"]["has_jobs"] is True

    @patch("generate_test_report.yaml.safe_load")
    @patch("builtins.open", new_callable=mock_open)
    @patch("generate_test_report.Path")
    def test_validate_workflows_invalid_workflow(
        self, mock_path_class, mock_open_file, mock_yaml_load
    ):
        """Test validating invalid workflows"""
        mock_yaml_load.side_effect = Exception("YAML parse error")

        # Mock the workflows directory structure
        mock_workspace = Mock()
        mock_github_dir = Mock()
        mock_workflows_dir = Mock()
        mock_workflows_dir.exists.return_value = True
        mock_workflow_file = Mock()
        mock_workflow_file.name = "invalid.yml"
        mock_workflows_dir.glob.return_value = [mock_workflow_file]

        # Set up the path traversal chain
        mock_workspace.__truediv__ = Mock(return_value=mock_github_dir)
        mock_github_dir.__truediv__ = Mock(return_value=mock_workflows_dir)
        mock_path_class.return_value = mock_workspace

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = mock_workspace
        results = generator._validate_workflows()

        assert "invalid.yml" in results
        assert results["invalid.yml"]["valid"] is False
        assert "YAML parse error" in results["invalid.yml"]["error"]

    @patch("generate_test_report.Path")
    def test_validate_workflows_no_workflows_dir(self, mock_path_class):
        """Test validating workflows when directory doesn't exist"""
        mock_workflows_dir = Mock()
        mock_workflows_dir.exists.return_value = False
        mock_path_class.return_value.__truediv__.return_value = mock_workflows_dir

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = Path("/fake/workspace")
        results = generator._validate_workflows()

        assert "status" in results
        assert results["status"] == "No workflows directory found"

    @patch("subprocess.run")
    def test_gather_system_status_dev_tools_available(self, mock_subprocess):
        """Test gathering system status with available tools"""
        mock_result = Mock()
        mock_result.returncode = 0
        mock_result.stdout = "version 1.0"
        mock_subprocess.return_value = mock_result

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = Path("/fake/workspace")
        status = generator._gather_system_status()

        assert "development_tools" in status
        tools = status["development_tools"]
        assert "xcodebuild" in tools
        assert tools["xcodebuild"]["available"] is True
        assert tools["xcodebuild"]["version"] == "version 1.0"

    @patch("subprocess.run")
    def test_gather_system_status_dev_tools_unavailable(self, mock_subprocess):
        """Test gathering system status with unavailable tools"""
        mock_subprocess.side_effect = Exception("Tool not found")

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = Path("/fake/workspace")
        status = generator._gather_system_status()

        assert "development_tools" in status
        tools = status["development_tools"]
        assert "xcodebuild" in tools
        assert "error" in tools["xcodebuild"]
        assert tools["xcodebuild"]["error"] == "Tool not found"

    @patch("generate_test_report.Path")
    def test_get_project_status(self, mock_path_class):
        """Test getting project status"""
        # Mock projects directory structure
        mock_workspace = Mock()
        mock_projects_dir = Mock()
        mock_projects_dir.exists.return_value = True

        mock_project_dir = Mock()
        mock_project_dir.is_dir.return_value = True
        mock_project_dir.name = "TestProject"
        mock_project_dir.glob.return_value = [Mock()]  # Has xcodeproj
        mock_project_dir.rglob.return_value = [Mock(), Mock()]  # 2 swift files

        mock_projects_dir.iterdir.return_value = [mock_project_dir]

        # Set up the path traversal chain
        mock_workspace.__truediv__ = Mock(return_value=mock_projects_dir)
        mock_path_class.return_value = mock_workspace

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = mock_workspace
        status = generator._get_project_status()

        assert "TestProject" in status
        assert status["TestProject"]["exists"] is True
        assert status["TestProject"]["has_xcodeproj"] is True
        assert status["TestProject"]["swift_files"] == 2

    @patch("subprocess.run")
    def test_get_git_status_clean(self, mock_subprocess):
        """Test getting clean git status"""
        mock_result = Mock()
        mock_result.stdout = ""
        mock_result.returncode = 0
        mock_subprocess.return_value = mock_result

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = Path("/fake/workspace")
        status = generator._get_git_status()

        assert status["clean"] is True
        assert status["changes"] == 0

    @patch("subprocess.run")
    def test_get_git_status_dirty(self, mock_subprocess):
        """Test getting dirty git status"""
        mock_result = Mock()
        mock_result.stdout = "M file1.txt\nA file2.txt\n"
        mock_result.returncode = 0
        mock_subprocess.return_value = mock_result

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = Path("/fake/workspace")
        status = generator._get_git_status()

        assert status["clean"] is False
        assert status["changes"] == 2

    @patch("subprocess.run")
    def test_get_git_status_error(self, mock_subprocess):
        """Test git status error handling"""
        mock_subprocess.side_effect = Exception("Git not found")

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        # Set required attributes manually since we're bypassing __init__
        generator.workspace_root = Path("/fake/workspace")
        status = generator._get_git_status()

        assert "error" in status
        assert status["error"] == "Git not found"

    def test_generate_recommendations_python_tests_failing(self):
        """Test generating recommendations for failing Python tests"""
        report = {"test_results": {"python_tests": {"passed": False}}}

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        recommendations = generator._generate_recommendations(report)

        assert len(recommendations) > 0
        python_rec = next(
            (r for r in recommendations if "Python tests" in r["issue"]), None
        )
        assert python_rec is not None
        assert python_rec["priority"] == "high"
        assert python_rec["category"] == "testing"

    def test_generate_recommendations_swift_builds_failing(self):
        """Test generating recommendations for failing Swift builds"""
        report = {"test_results": {"swift_builds": {"completed": False}}}

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        recommendations = generator._generate_recommendations(report)

        assert len(recommendations) > 0
        swift_rec = next(
            (r for r in recommendations if "Swift builds" in r["issue"]), None
        )
        assert swift_rec is not None
        assert swift_rec["priority"] == "medium"
        assert swift_rec["category"] == "build"

    def test_generate_recommendations_missing_tools(self):
        """Test generating recommendations for missing development tools"""
        report = {
            "system_status": {
                "development_tools": {
                    "xcodebuild": {"available": False},
                    "swift": {"available": True},
                }
            }
        }

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        recommendations = generator._generate_recommendations(report)

        assert len(recommendations) > 0
        tools_rec = next(
            (r for r in recommendations if "development tools" in r["issue"]), None
        )
        assert tools_rec is not None
        assert tools_rec["priority"] == "high"
        assert tools_rec["category"] == "environment"
        assert "xcodebuild" in tools_rec["issue"]

    def test_generate_recommendations_projects_without_xcodeproj(self):
        """Test generating recommendations for projects without Xcode project files"""
        report = {
            "system_status": {
                "projects": {
                    "Project1": {"exists": True, "has_xcodeproj": True},
                    "Project2": {"exists": True, "has_xcodeproj": False},
                }
            }
        }

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        recommendations = generator._generate_recommendations(report)

        assert len(recommendations) > 0
        project_rec = next(
            (r for r in recommendations if "Xcode project files" in r["issue"]), None
        )
        assert project_rec is not None
        assert project_rec["priority"] == "low"
        assert "Project2" in project_rec["issue"]

    def test_generate_recommendations_git_changes(self):
        """Test generating recommendations for uncommitted git changes"""
        report = {"system_status": {"git_status": {"clean": False, "changes": 3}}}

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        recommendations = generator._generate_recommendations(report)

        assert len(recommendations) > 0
        git_rec = next(
            (r for r in recommendations if "uncommitted changes" in r["issue"]), None
        )
        assert git_rec is not None
        assert git_rec["priority"] == "medium"
        assert git_rec["category"] == "version_control"
        assert "3 files" in git_rec["issue"]

    def test_generate_recommendations_no_issues(self):
        """Test generating recommendations when everything is fine"""
        report = {
            "test_results": {
                "python_tests": {"passed": True},
                "swift_builds": {"completed": True},
            },
            "system_status": {
                "development_tools": {
                    "xcodebuild": {"available": True},
                    "swift": {"available": True},
                },
                "projects": {"Project1": {"exists": True, "has_xcodeproj": True}},
                "git_status": {"clean": True},
            },
        }

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        recommendations = generator._generate_recommendations(report)

        assert len(recommendations) == 0

    @patch("generate_test_report.TestReportGenerator.generate_comprehensive_report")
    @patch("builtins.print")
    @patch("generate_test_report.TestReportGenerator.__init__", return_value=None)
    @patch("generate_test_report.Path")
    def test_main_function(self, mock_path_class, mock_init, mock_print, mock_generate):
        """Test main function execution"""
        # Mock Path operations for constructor
        mock_workspace = Mock()
        mock_reports_dir = Mock()
        mock_reports_dir.mkdir = Mock()
        mock_workspace.__truediv__ = Mock(return_value=mock_reports_dir)
        mock_path_class.return_value = mock_workspace

        # Set up generator instance manually
        generator = generate_test_report.TestReportGenerator()
        generator.workspace_root = mock_workspace
        generator.reports_dir = mock_reports_dir

        mock_report_file = "/path/to/report.json"
        mock_report = {
            "report_metadata": {"generated_at": "2023-01-01T12:00:00"},
            "test_results": {"python_tests": {"passed": True}},
            "system_status": {
                "development_tools": {
                    "xcodebuild": {"available": True, "version": "1.0"}
                },
                "projects": {"Project1": {}},
                "git_status": {"clean": True},
            },
            "recommendations": [],
        }
        mock_generate.return_value = (mock_report_file, mock_report)

        generate_test_report.main()

        # Verify generate_comprehensive_report was called
        mock_generate.assert_called_once()

        # Verify prints were called (we can't easily verify exact output without more complex mocking)
        assert mock_print.call_count > 0

    @patch("generate_test_report.TestReportGenerator.generate_comprehensive_report")
    @patch("builtins.print")
    @patch("generate_test_report.TestReportGenerator.__init__", return_value=None)
    @patch("generate_test_report.Path")
    def test_main_with_recommendations(
        self, mock_path_class, mock_init, mock_print, mock_generate
    ):
        """Test main function with recommendations"""
        # Mock Path operations for constructor
        mock_workspace = Mock()
        mock_reports_dir = Mock()
        mock_reports_dir.mkdir = Mock()
        mock_workspace.__truediv__ = Mock(return_value=mock_reports_dir)
        mock_path_class.return_value = mock_workspace

        # Set up generator instance manually
        generator = generate_test_report.TestReportGenerator()
        generator.workspace_root = mock_workspace
        generator.reports_dir = mock_reports_dir

        mock_report_file = "/path/to/report.json"
        mock_report = {
            "report_metadata": {"generated_at": "2023-01-01T12:00:00"},
            "test_results": {"python_tests": {"passed": False}},
            "system_status": {
                "development_tools": {"xcodebuild": {"available": False}},
                "projects": {},
                "git_status": {"clean": False, "changes": 2},
            },
            "recommendations": [
                {
                    "priority": "high",
                    "category": "testing",
                    "issue": "Python tests failing",
                    "action": "Fix tests",
                }
            ],
        }
        mock_generate.return_value = (mock_report_file, mock_report)

        generate_test_report.main()

        mock_generate.assert_called_once()
        assert mock_print.call_count > 0

    @patch("generate_test_report.TestReportGenerator._run_all_tests")
    @patch("generate_test_report.TestReportGenerator._gather_system_status")
    @patch("generate_test_report.TestReportGenerator._generate_recommendations")
    @patch("generate_test_report.datetime")
    @patch("builtins.open", new_callable=mock_open)
    @patch("generate_test_report.Path")
    def test_generate_comprehensive_report(
        self,
        mock_path_class,
        mock_open_file,
        mock_datetime,
        mock_generate_rec,
        mock_gather_status,
        mock_run_tests,
    ):
        """Test comprehensive report generation"""
        # Setup mocks
        mock_now = Mock()
        mock_now.isoformat.return_value = "2023-01-01T12:00:00"
        mock_datetime.now.return_value = mock_now

        mock_run_tests.return_value = {"test": "results"}
        mock_gather_status.return_value = {"system": "status"}
        mock_generate_rec.return_value = ["recommendation"]

        # Mock Path operations
        mock_workspace = Mock()
        mock_reports_dir = Mock()
        mock_report_file = Mock()
        mock_report_file.__str__ = Mock(return_value="/path/to/report.json")

        mock_workspace.__truediv__ = Mock(return_value=mock_reports_dir)
        mock_reports_dir.__truediv__ = Mock(return_value=mock_report_file)
        mock_path_class.return_value = mock_workspace

        generator = generate_test_report.TestReportGenerator.__new__(
            generate_test_report.TestReportGenerator
        )
        generator.workspace_root = mock_workspace
        generator.reports_dir = mock_reports_dir

        report_file, report = generator.generate_comprehensive_report()

        assert str(report_file) == "/path/to/report.json"
        assert "report_metadata" in report
        assert "test_results" in report
        assert "system_status" in report
        assert "recommendations" in report

        mock_run_tests.assert_called_once()
        mock_gather_status.assert_called_once()
        mock_generate_rec.assert_called_once_with(report)
