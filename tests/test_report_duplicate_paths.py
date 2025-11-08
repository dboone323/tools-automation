import pytest
import sys
import os
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import report_duplicate_paths


class TestReportDuplicatePaths:
    """Comprehensive tests for report_duplicate_paths.py"""

    def test_parse_pbxproj_basic(self):
        """Test basic PBX project parsing"""
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".pbxproj", delete=False
        ) as f:
            f.write(
                """/* Begin PBXFileReference section */
        ABC123 /* file1.m */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.c.objc; name = file1.m; path = "Sources/file1.m"; sourceTree = "<group>"; };
        DEF456 /* file2.m */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.c.objc; path = "Sources/file2.m"; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
        GROUP1 /* Group1 */ = {
            children = (
                ABC123 /* file1.m */,
                DEF456 /* file2.m */,
            );
        };
/* End PBXGroup section */"""
            )
            temp_path = f.name

        try:
            result = report_duplicate_paths.parse_pbxproj(Path(temp_path))

            assert "ABC123" in result["file_refs"]
            assert result["file_refs"]["ABC123"]["name"] == "file1.m"
            assert result["file_refs"]["ABC123"]["path"] == "Sources/file1.m"
            assert "DEF456" in result["file_refs"]
            assert result["file_refs"]["DEF456"]["path"] == "Sources/file2.m"
            assert "GROUP1" in result["group_children"]
            assert "ABC123" in result["group_children"]["GROUP1"]
            assert "DEF456" in result["group_children"]["GROUP1"]
        finally:
            os.unlink(temp_path)

    def test_parse_pbxproj_duplicate_paths(self):
        """Test parsing with duplicate file paths"""
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".pbxproj", delete=False
        ) as f:
            f.write(
                """/* Begin PBXFileReference section */
        ABC123 /* file1.m */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.c.objc; path = "Sources/file1.m"; sourceTree = "<group>"; };
        DEF456 /* file1.m */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.c.objc; path = "Sources/file1.m"; sourceTree = "<group>"; };
        GHI789 /* file2.m */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.c.objc; path = "Sources/file2.m"; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
        GROUP1 /* Group1 */ = {
            children = (
                ABC123 /* file1.m */,
                DEF456 /* file1.m */,
            );
        };
        GROUP2 /* Group2 */ = {
            children = (
                GHI789 /* file2.m */,
            );
        };
/* End PBXGroup section */"""
            )
            temp_path = f.name

        try:
            result = report_duplicate_paths.parse_pbxproj(Path(temp_path))

            assert "Sources/file1.m" in result["duplicates"]
            assert len(result["duplicates"]["Sources/file1.m"]) == 2
            assert "ABC123" in result["duplicates"]["Sources/file1.m"]
            assert "DEF456" in result["duplicates"]["Sources/file1.m"]
            assert "Sources/file2.m" not in result["duplicates"]
        finally:
            os.unlink(temp_path)

    def test_parse_pbxproj_multi_group_refs(self):
        """Test parsing with file references in multiple groups"""
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".pbxproj", delete=False
        ) as f:
            f.write(
                """/* Begin PBXFileReference section */
        ABC123 /* shared.m */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.c.objc; path = "Sources/shared.m"; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
        GROUP1 /* Group1 */ = {
            children = (
                ABC123 /* shared.m */,
            );
        };
        GROUP2 /* Group2 */ = {
            children = (
                ABC123 /* shared.m */,
            );
        };
/* End PBXGroup section */"""
            )
            temp_path = f.name

        try:
            result = report_duplicate_paths.parse_pbxproj(Path(temp_path))

            assert "ABC123" in result["child_to_groups"]
            assert len(result["child_to_groups"]["ABC123"]) == 2
            assert "GROUP1" in result["child_to_groups"]["ABC123"]
            assert "GROUP2" in result["child_to_groups"]["ABC123"]
        finally:
            os.unlink(temp_path)

    @patch("builtins.print")
    def test_generate_report_no_duplicates(self, mock_print):
        """Test report generation with no duplicates"""
        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir) / "TestProject"
            project_dir.mkdir()
            xcodeproj_dir = project_dir / "TestProject.xcodeproj"
            xcodeproj_dir.mkdir()
            pbxproj_path = xcodeproj_dir / "project.pbxproj"
            pbxproj_path.write_text("""/* Empty project */""")

            with patch("report_duplicate_paths.parse_pbxproj") as mock_parse:
                mock_parse.return_value = {
                    "duplicates": {},
                    "child_to_groups": {},
                    "file_refs": {},
                    "group_meta": {},
                }

                report_duplicate_paths.generate_report(project_dir)

                # Check that print was called (for report written message)
                mock_print.assert_called()

    @patch("builtins.print")
    def test_generate_report_with_duplicates(self, mock_print):
        """Test report generation with duplicate paths"""
        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir) / "TestProject"
            project_dir.mkdir()
            xcodeproj_dir = project_dir / "TestProject.xcodeproj"
            xcodeproj_dir.mkdir()
            pbxproj_path = xcodeproj_dir / "project.pbxproj"
            pbxproj_path.write_text("""/* Empty project */""")

            with patch("report_duplicate_paths.parse_pbxproj") as mock_parse:
                mock_parse.return_value = {
                    "duplicates": {"Sources/file1.m": ["ABC123", "DEF456"]},
                    "child_to_groups": {"ABC123": ["GROUP1"], "DEF456": ["GROUP2"]},
                    "file_refs": {
                        "ABC123": {"name": "file1.m", "path": "Sources/file1.m"},
                        "DEF456": {"name": "file1.m", "path": "Sources/file1.m"},
                    },
                    "group_meta": {
                        "GROUP1": {"name": "Group1"},
                        "GROUP2": {"name": "Group2"},
                    },
                }

                report_duplicate_paths.generate_report(project_dir)

                mock_print.assert_called()

    def test_main_no_args(self, capsys):
        """Test main execution with no arguments"""
        with patch("sys.argv", ["report_duplicate_paths.py"]):
            with patch("sys.exit") as mock_exit:
                # We expect sys.exit to be called, but since it's mocked, execution continues
                # So we need to catch the IndexError that happens when it tries to access sys.argv[1]
                try:
                    report_duplicate_paths.main()
                    assert False, "Should have called sys.exit"
                except IndexError:
                    pass  # Expected when sys.exit is mocked

        captured = capsys.readouterr()
        assert "Usage: report_duplicate_paths.py <ProjectDir>" in captured.out
        mock_exit.assert_called_once_with(1)

    @patch("report_duplicate_paths.generate_report")
    def test_main_success(self, mock_generate):
        """Test main execution successful"""
        with patch("sys.argv", ["report_duplicate_paths.py", "/path/to/project"]):
            report_duplicate_paths.main()

        mock_generate.assert_called_once()
        args = mock_generate.call_args[0][0]
        assert str(args) == "/path/to/project"
