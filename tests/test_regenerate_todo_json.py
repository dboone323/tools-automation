import pytest
import sys
import os
import json
from unittest.mock import Mock, patch, MagicMock, mock_open

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import regenerate_todo_json


class TestRegenerateTodoJson:
    """Comprehensive tests for regenerate_todo_json.py"""

    def test_should_exclude_file(self):
        """Test file exclusion logic"""
        # Should exclude
        assert regenerate_todo_json.should_exclude_file(".venv/lib.py") == True
        assert regenerate_todo_json.should_exclude_file("__pycache__/file.pyc") == True
        assert regenerate_todo_json.should_exclude_file("build/main.o") == True
        assert regenerate_todo_json.should_exclude_file(".git/config") == True
        assert regenerate_todo_json.should_exclude_file(".vscode/settings.json") == True
        assert regenerate_todo_json.should_exclude_file("file.zip") == True
        assert regenerate_todo_json.should_exclude_file(".coverage") == True
        assert (
            regenerate_todo_json.should_exclude_file("autofix_backups/file.py") == True
        )

        # Should not exclude
        assert regenerate_todo_json.should_exclude_file("src/main.py") == False
        assert regenerate_todo_json.should_exclude_file("README.md") == False
        assert regenerate_todo_json.should_exclude_file("script.sh") == False

    @patch("os.walk")
    @patch("builtins.open", new_callable=mock_open)
    def test_find_todo_comments_swift_style(self, mock_file, mock_walk):
        """Test finding TODO comments in Swift style"""
        mock_walk.return_value = [
            ("/root", ["subdir"], ["test.swift"]),
        ]

        mock_file.return_value.readlines.return_value = [
            "// TODO: fix this bug\n",
            "// FIXME: another issue\n",
            "normal code\n",
        ]

        todos = regenerate_todo_json.find_todo_comments("/root")

        assert len(todos) == 2
        assert todos[0]["file"] == "test.swift"
        assert todos[0]["line"] == 1
        assert todos[0]["text"] == "TODO: fix this bug"
        assert todos[1]["text"] == "FIXME: another issue"

    @patch("os.walk")
    @patch("builtins.open", new_callable=mock_open)
    def test_find_todo_comments_python_style(self, mock_file, mock_walk):
        """Test finding TODO comments in Python style"""
        mock_walk.return_value = [
            ("/root", [], ["test.py"]),
        ]

        mock_file.return_value.readlines.return_value = [
            "# TODO: implement feature\n",
            "# FIXME: refactor code\n",
        ]

        todos = regenerate_todo_json.find_todo_comments("/root")

        assert len(todos) == 2
        assert todos[0]["text"] == "TODO: implement feature"
        assert todos[1]["text"] == "FIXME: refactor code"

    @patch("os.walk")
    @patch("builtins.open", new_callable=mock_open)
    def test_find_todo_comments_block_style(self, mock_file, mock_walk):
        """Test finding TODO comments in block comment style"""
        mock_walk.return_value = [
            ("/root", [], ["test.js"]),
        ]

        mock_file.return_value.readlines.return_value = [
            "/* TODO: add validation */\n",
            "/* FIXME: update docs */\n",
        ]

        todos = regenerate_todo_json.find_todo_comments("/root")

        assert len(todos) == 2
        assert todos[0]["text"] == "TODO: add validation"
        assert todos[1]["text"] == "FIXME: update docs"

    @patch("os.walk")
    @patch("builtins.open", new_callable=mock_open)
    def test_find_todo_comments_skip_placeholders(self, mock_file, mock_walk):
        """Test skipping placeholder TODOs"""
        mock_walk.return_value = [
            ("/root", [], ["test.py"]),
        ]

        mock_file.return_value.readlines.return_value = [
            "# TODO: placeholder\n",
            "# TODO: implement me\n",
            "# FIXME: coming soon\n",
        ]

        todos = regenerate_todo_json.find_todo_comments("/root")

        assert len(todos) == 0  # All should be skipped

    @patch("os.walk")
    @patch("builtins.open", new_callable=mock_open)
    def test_find_todo_comments_exclude_files(self, mock_file, mock_walk):
        """Test excluding files and directories"""
        mock_walk.return_value = [
            ("/root", [".venv"], [".DS_Store", "test.zip"]),
        ]

        mock_file.return_value.readlines.return_value = ["# TODO: test\n"]

        todos = regenerate_todo_json.find_todo_comments("/root")

        # Should not process excluded files
        assert len(todos) == 0

    @patch("os.walk")
    @patch("builtins.open", new_callable=mock_open)
    def test_find_todo_comments_file_read_error(self, mock_file, mock_walk):
        """Test handling file read errors"""
        mock_walk.return_value = [
            ("/root", [], ["test.py"]),
        ]

        mock_file.side_effect = Exception("Read error")

        todos = regenerate_todo_json.find_todo_comments("/root")

        assert len(todos) == 0

    @patch("os.walk")
    def test_find_todo_comments_multiple_files(self, mock_walk):
        """Test processing multiple files"""
        mock_walk.return_value = [
            ("/root", [], ["file1.py", "file2.swift"]),
        ]

        with patch("builtins.open", new_callable=mock_open) as mock_file:
            mock_file.return_value.readlines.side_effect = [
                ["# TODO: task1\n"],
                ["// FIXME: task2\n"],
            ]

            todos = regenerate_todo_json.find_todo_comments("/root")

        assert len(todos) == 2
        assert todos[0]["file"] == "file1.py"
        assert todos[1]["file"] == "file2.swift"

    @patch("regenerate_todo_json.Path")
    @patch("builtins.open", new_callable=mock_open)
    def test_main_function(self, mock_file, mock_path):
        """Test main function execution"""
        mock_root = Mock()
        mock_projects = Mock()
        mock_path.return_value = mock_root
        mock_root.parent.parent.parent = mock_root
        mock_root.__truediv__ = Mock(return_value=mock_projects)
        mock_projects.__truediv__ = Mock(return_value=Mock())

        with patch(
            "regenerate_todo_json.find_todo_comments",
            return_value=[
                {"file": "test.py", "line": 1, "text": "TODO: test"},
                {"file": "test.py", "line": 1, "text": "TODO: test"},  # duplicate
            ],
        ) as mock_find:
            regenerate_todo_json.main()

        # Should write deduplicated todos
        mock_file.assert_called_once()
        # Check that write was called (deduplication results in 1 item)
        assert mock_file.return_value.write.called

    @patch("regenerate_todo_json.Path")
    @patch("builtins.open", new_callable=mock_open)
    def test_main_function_no_todos(self, mock_file, mock_path):
        """Test main function with no TODOs found"""
        mock_root = Mock()
        mock_projects = Mock()
        mock_path.return_value = mock_root
        mock_root.parent.parent.parent = mock_root
        mock_root.__truediv__ = Mock(return_value=mock_projects)
        mock_projects.__truediv__ = Mock(return_value=Mock())

        with patch("regenerate_todo_json.find_todo_comments", return_value=[]):
            regenerate_todo_json.main()

        mock_file.assert_called_once()
        # Check that write was called with empty list
        assert mock_file.return_value.write.called
