import pytest
import sys
import os
import json
from unittest.mock import Mock, patch, MagicMock, mock_open

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import code_health_dashboard


class TestCodeHealthDashboard:
    """Comprehensive tests for code_health_dashboard.py"""

    def test_count_swift_files_and_lines(self):
        """Test counting Swift files and lines"""
        mock_base = Mock()
        mock_file1 = Mock()
        mock_file2 = Mock()
        mock_base.rglob.return_value = [mock_file1, mock_file2]

        # Mock file opening
        mock_file1.open = mock_open(read_data="line1\nline2\n")
        mock_file2.open = mock_open(read_data="line3\n")

        files, lines = code_health_dashboard.count_swift_files_and_lines(mock_base)
        assert files == 2
        assert lines == 3

    def test_count_swift_files_and_lines_exception(self):
        """Test counting with file read exception"""
        mock_base = Mock()
        mock_file = Mock()
        mock_base.rglob.return_value = [mock_file]

        mock_file.open.side_effect = Exception("Read error")

        files, lines = code_health_dashboard.count_swift_files_and_lines(mock_base)
        assert files == 1  # Still counts the file
        assert lines == 0

    @patch("code_health_dashboard.ROOT")
    def test_count_todos(self, mock_root):
        """Test counting TODOs in files"""
        mock_projects = Mock()
        mock_shared = Mock()
        mock_tools = Mock()
        mock_root.__truediv__ = Mock(
            side_effect=lambda x: {
                "Projects": mock_projects,
                "Shared": mock_shared,
                "Tools": mock_tools,
            }.get(x, Mock())
        )

        # Mock exists
        mock_projects.exists.return_value = True
        mock_shared.exists.return_value = True
        mock_tools.exists.return_value = True  # For Tools dir
        mock_automation = Mock()
        mock_automation.exists.return_value = False  # Tools/Automation doesn't exist
        mock_tools.__truediv__ = Mock(return_value=mock_automation)

        # Mock files
        mock_file1 = Mock()
        mock_file1.suffix.lower.return_value = ".swift"
        mock_file1.stat.return_value.st_size = 100
        mock_file1.read_text.return_value = "TODO: fix this FIXME: and this"

        mock_file2 = Mock()
        mock_file2.suffix.lower.return_value = ".py"
        mock_file2.stat.return_value.st_size = 100
        mock_file2.read_text.return_value = "BUG: issue"

        mock_projects.rglob.return_value = [mock_file1, mock_file2]
        mock_shared.rglob.return_value = []

        count = code_health_dashboard.count_todos()
        assert count == 3  # TODO, FIXME, BUG

    @patch("code_health_dashboard.ROOT")
    def test_count_todos_large_file(self, mock_root):
        """Test skipping large files in TODO count"""
        mock_projects = Mock()
        mock_shared = Mock(exists=lambda: False)
        mock_tools = Mock(__truediv__=Mock(return_value=Mock(exists=lambda: False)))
        mock_root.__truediv__ = Mock(
            side_effect=lambda x: {
                "Projects": mock_projects,
                "Shared": mock_shared,
                "Tools": mock_tools,
            }.get(x, Mock(exists=lambda: False))
        )

        mock_projects.exists.return_value = True

        mock_file = Mock()
        mock_file.suffix.lower.return_value = ".swift"
        mock_file.stat.return_value.st_size = 2_000_000  # Larger than max_bytes
        mock_projects.rglob.return_value = [mock_file]

        count = code_health_dashboard.count_todos()
        assert count == 0

    @patch("code_health_dashboard.Path")
    def test_project_summary(self, mock_path_class):
        """Test project summary generation"""
        mock_project_dir = Mock()
        mock_project_dir.name = "TestProject"

        # Mock Swift files
        mock_swift_file1 = Mock()
        mock_swift_file1.name = "ViewController.swift"
        mock_swift_file2 = Mock()
        mock_swift_file2.name = "ViewControllerTests.swift"
        mock_project_dir.rglob.return_value = [mock_swift_file1, mock_swift_file2]

        # Mock documentation
        mock_root = Mock()
        mock_path_class.return_value = mock_root
        mock_docs_api = Mock()
        mock_api = Mock()
        mock_file = Mock()
        mock_docs_api.__truediv__ = Mock(
            side_effect=lambda x: mock_api if x == "API" else Mock()
        )
        mock_api.__truediv__ = Mock(return_value=mock_file)
        mock_file.exists.return_value = False
        mock_readme = Mock()
        mock_readme.exists.return_value = True
        mock_root.__truediv__ = Mock(
            side_effect=lambda x: mock_docs_api if x == "Documentation" else Mock()
        )
        mock_project_dir.__truediv__ = Mock(return_value=mock_readme)

        summary = code_health_dashboard.project_summary(mock_project_dir)
        assert summary == {
            "name": "TestProject",
            "swift_files": 2,
            "has_tests": True,  # Has Tests.swift
            "has_docs": True,  # Has README.md
        }

    @patch("code_health_dashboard.time.time", return_value=1234567890)
    @patch("code_health_dashboard.json.dumps")
    @patch("code_health_dashboard.OUTPUT_PATH")
    @patch("code_health_dashboard.count_swift_files_and_lines", return_value=(10, 1000))
    @patch("code_health_dashboard.count_todos", return_value=5)
    @patch("code_health_dashboard.PROJECTS")
    def test_main(
        self,
        mock_projects,
        mock_count_todos,
        mock_count_files,
        mock_output_path,
        mock_json_dumps,
        mock_time,
    ):
        """Test main function execution"""
        mock_project_dir = Mock()
        mock_project_dir.is_dir.return_value = True
        mock_projects.iterdir.return_value = [mock_project_dir]

        with patch(
            "code_health_dashboard.project_summary",
            return_value={
                "name": "TestProj",
                "swift_files": 5,
                "has_tests": True,
                "has_docs": False,
            },
        ):
            code_health_dashboard.main()

        mock_json_dumps.assert_called_once_with(
            {
                "swift_files": 10,
                "swift_lines": 1000,
                "todos": 5,
                "projects": [
                    {
                        "name": "TestProj",
                        "swift_files": 5,
                        "has_tests": True,
                        "has_docs": False,
                    }
                ],
                "last_update": 1234567890,
            },
            indent=2,
        )
        mock_output_path.write_text.assert_called_once()

    @patch("code_health_dashboard.Path")
    def test_project_summary_no_tests_no_docs(self, mock_path_class):
        """Test project summary with no tests or docs"""
        mock_project_dir = Mock()
        mock_project_dir.name = "TestProject"

        mock_swift_file = Mock()
        mock_swift_file.name = "ViewController.swift"
        mock_project_dir.rglob.return_value = [mock_swift_file]

        mock_root = Mock()
        mock_path_class.return_value = mock_root
        mock_docs_api = Mock()
        mock_api = Mock()
        mock_file = Mock()
        mock_docs_api.__truediv__ = Mock(
            side_effect=lambda x: mock_api if x == "API" else Mock()
        )
        mock_api.__truediv__ = Mock(return_value=mock_file)
        mock_file.exists.return_value = False
        mock_readme = Mock()
        mock_readme.exists.return_value = False
        mock_root.__truediv__ = Mock(
            side_effect=lambda x: mock_docs_api if x == "Documentation" else Mock()
        )
        mock_project_dir.__truediv__ = Mock(return_value=mock_readme)

        summary = code_health_dashboard.project_summary(mock_project_dir)
        assert summary == {
            "name": "TestProject",
            "swift_files": 1,
            "has_tests": False,
            "has_docs": False,
        }
