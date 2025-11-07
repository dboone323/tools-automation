import pytest
import sys
import os
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock, mock_open

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import cleanup_duplicate_references


class TestCleanupDuplicateReferences:
    """Comprehensive tests for cleanup_duplicate_references.py"""

    @patch("cleanup_duplicate_references.Path")
    def test_xcodeproj_cleaner_init_success(self, mock_path_class):
        """Test successful XcodeprojCleaner initialization"""
        mock_path_instance = Mock()
        mock_pbxproj = Mock()
        mock_pbxproj.exists.return_value = True
        mock_path_instance.__truediv__ = Mock(return_value=mock_pbxproj)
        mock_path_class.return_value = mock_path_instance

        with patch("builtins.open", mock_open(read_data="test content")):
            cleaner = cleanup_duplicate_references.XcodeprojCleaner(
                "/path/to/project.xcodeproj"
            )

        assert cleaner.xcodeproj_path == mock_path_instance
        assert cleaner.content == "test content"
        assert cleaner.lines == ["test content"]

    @patch("cleanup_duplicate_references.Path")
    def test_xcodeproj_cleaner_init_no_pbxproj(self, mock_path_class):
        """Test XcodeprojCleaner initialization with missing pbxproj"""
        mock_path_instance = Mock()
        mock_pbxproj = Mock()
        mock_pbxproj.exists.return_value = False
        mock_path_instance.__truediv__ = Mock(return_value=mock_pbxproj)
        mock_path_class.return_value = mock_path_instance

        with pytest.raises(FileNotFoundError):
            cleanup_duplicate_references.XcodeprojCleaner("/path/to/project.xcodeproj")

    @patch("cleanup_duplicate_references.Path")
    @patch("builtins.open", new_callable=mock_open)
    def test_backup(self, mock_file, mock_path_class):
        """Test backup creation"""
        mock_path_instance = Mock()
        mock_backup = Mock()
        mock_path_instance.with_suffix.return_value = mock_backup
        mock_path_class.return_value = mock_path_instance

        cleaner = cleanup_duplicate_references.XcodeprojCleaner.__new__(
            cleanup_duplicate_references.XcodeprojCleaner
        )
        cleaner.pbxproj_path = mock_path_instance
        cleaner.content = "test content"

        result = cleaner.backup()

        assert result == mock_backup
        mock_file.assert_called_once_with(mock_backup, "w", encoding="utf-8")
        mock_file.return_value.write.assert_called_once_with("test content")

    def test_find_duplicate_build_files(self):
        """Test finding duplicate build files"""
        lines = [
            "    ABC123 /* file1.m in Sources */ = {isa = PBXBuildFile; fileRef = DEF456 /* file1.m */; };",
            "    GHI789 /* file1.m in Sources */ = {isa = PBXBuildFile; fileRef = DEF456 /* file1.m */; };",
            "    JKL012 /* file2.m in Sources */ = {isa = PBXBuildFile; fileRef = MNO345 /* file2.m */; };",
        ]

        cleaner = cleanup_duplicate_references.XcodeprojCleaner.__new__(
            cleanup_duplicate_references.XcodeprojCleaner
        )
        cleaner.lines = lines

        duplicates = cleaner.find_duplicate_build_files()

        assert "DEF456" in duplicates
        assert len(duplicates["DEF456"]) == 2

    def test_find_duplicate_file_references(self):
        """Test finding duplicate file references in groups"""
        lines = [
            "/* Begin PBXGroup section */",
            "    GROUP1 /* Group1 */ = {",
            "        children = (",
            "            FILE1 /* file1.m */ ,",
            "            FILE1 /* file1.m */ ,",  # duplicate in same group
            "        );",
            "    };",
            "    GROUP2 /* Group2 */ = {",
            "        children = (",
            "            FILE1 /* file1.m */ ,",  # duplicate across groups
            "        );",
            "    };",
            "/* End PBXGroup section */",
        ]

        cleaner = cleanup_duplicate_references.XcodeprojCleaner.__new__(
            cleanup_duplicate_references.XcodeprojCleaner
        )
        cleaner.lines = lines

        occurrences = cleaner.find_duplicate_file_references()

        assert "FILE1" in occurrences
        assert len(occurrences["FILE1"]) == 3

    def test_remove_duplicate_build_files(self):
        """Test removing duplicate build files"""
        lines = ["line1", "line2", "line3", "line4"]
        cleaner = cleanup_duplicate_references.XcodeprojCleaner.__new__(
            cleanup_duplicate_references.XcodeprojCleaner
        )
        cleaner.lines = lines

        duplicates = {
            "file1": [
                {"line": 1, "uuid": "uuid1", "filename": "file1.m"},
                {"line": 2, "uuid": "uuid2", "filename": "file1.m"},
            ]
        }

        removed = cleaner.remove_duplicate_build_files(duplicates)

        assert removed == 1
        assert len(cleaner.lines) == 3
        assert "line3" not in cleaner.lines  # line 2 (0-indexed) removed

    def test_remove_duplicate_file_references_from_groups(self):
        """Test removing duplicate file references from groups"""
        lines = ["line1", "line2", "line3", "line4", "line5"]
        cleaner = cleanup_duplicate_references.XcodeprojCleaner.__new__(
            cleanup_duplicate_references.XcodeprojCleaner
        )
        cleaner.lines = lines

        occurrences = {
            "file1": [
                {"line": 1, "group": "group1", "filename": "file1.m"},
                {
                    "line": 2,
                    "group": "group1",
                    "filename": "file1.m",
                },  # in-group duplicate
                {
                    "line": 3,
                    "group": "group2",
                    "filename": "file1.m",
                },  # cross-group duplicate
            ]
        }

        removed = cleaner.remove_duplicate_file_references_from_groups(occurrences)

        assert removed == 2
        assert len(cleaner.lines) == 3

    @patch("builtins.open", new_callable=mock_open)
    def test_save(self, mock_file):
        """Test saving cleaned project"""
        cleaner = cleanup_duplicate_references.XcodeprojCleaner.__new__(
            cleanup_duplicate_references.XcodeprojCleaner
        )
        cleaner.lines = ["line1", "line2"]
        cleaner.pbxproj_path = Mock()

        cleaner.save()

        mock_file.assert_called_once_with(cleaner.pbxproj_path, "w", encoding="utf-8")
        mock_file.return_value.write.assert_called_once_with("line1\nline2")

    @patch("cleanup_duplicate_references.XcodeprojCleaner")
    @patch("os.path.exists", return_value=True)
    def test_main_success(self, mock_exists, mock_cleaner_class):
        """Test main function successful execution"""
        mock_cleaner = Mock()
        mock_cleaner_class.return_value = mock_cleaner

        with patch(
            "sys.argv",
            ["cleanup_duplicate_references.py", "/path/to/project.xcodeproj"],
        ):
            with patch("os.system") as mock_system:
                cleanup_duplicate_references.main()

        mock_cleaner_class.assert_called_once_with("/path/to/project.xcodeproj")
        mock_cleaner.clean.assert_called_once()
        assert mock_system.call_count == 1  # verification call

    @patch("os.path.exists", return_value=False)
    def test_main_project_not_found(self, mock_exists):
        """Test main function with non-existent project"""
        with patch(
            "sys.argv",
            ["cleanup_duplicate_references.py", "/path/to/project.xcodeproj"],
        ):
            with patch("sys.stdout", new_callable=MagicMock) as mock_stdout:
                with pytest.raises(SystemExit, match="1"):
                    cleanup_duplicate_references.main()

        mock_stdout.write.assert_called()

    def test_main_insufficient_args(self):
        """Test main function with insufficient arguments"""
        with patch("sys.argv", ["cleanup_duplicate_references.py"]):
            with patch("sys.stdout", new_callable=MagicMock) as mock_stdout:
                with pytest.raises(SystemExit, match="1"):
                    cleanup_duplicate_references.main()

        mock_stdout.write.assert_called()

    @patch("cleanup_duplicate_references.XcodeprojCleaner")
    @patch("os.path.exists", return_value=True)
    def test_main_cleanup_error(self, mock_exists, mock_cleaner_class):
        """Test main function with cleanup error"""
        mock_cleaner = Mock()
        mock_cleaner.clean.side_effect = Exception("cleanup error")
        mock_cleaner_class.return_value = mock_cleaner

        with patch(
            "sys.argv",
            ["cleanup_duplicate_references.py", "/path/to/project.xcodeproj"],
        ):
            with patch("sys.stdout", new_callable=MagicMock) as mock_stdout:
                with pytest.raises(SystemExit, match="1"):
                    cleanup_duplicate_references.main()

        mock_stdout.write.assert_called()

    @patch("os.system")
    def test_verify_project(self, mock_system):
        """Test project verification"""
        mock_system.return_value = 0  # No "member of multiple groups" errors

        result = cleanup_duplicate_references.verify_project(
            "/path/to/project.xcodeproj"
        )

        assert result is True
        mock_system.assert_called_once()

    def test_clean_no_duplicates(self):
        """Test clean method when no duplicates found"""
        cleaner = cleanup_duplicate_references.XcodeprojCleaner.__new__(
            cleanup_duplicate_references.XcodeprojCleaner
        )
        cleaner.xcodeproj_path = Mock()
        cleaner.xcodeproj_path.name = "TestProject.xcodeproj"
        cleaner.pbxproj_path = Mock()
        cleaner.lines = ["line1", "line2"]
        cleaner.backup = Mock()
        cleaner.save = Mock()
        cleaner.find_duplicate_build_files = Mock(return_value={})
        cleaner.find_duplicate_file_references = Mock(return_value={})

        with patch("builtins.print") as mock_print:
            cleaner.clean()

        mock_print.assert_called()
        cleaner.save.assert_called_once()
