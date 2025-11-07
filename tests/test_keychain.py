import pytest
import sys
import os
import subprocess
from unittest.mock import Mock, patch, MagicMock

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import keychain


class TestKeychain:
    """Comprehensive tests for keychain.py"""

    @patch("subprocess.run")
    def test_get_secret_success(self, mock_run):
        """Test successful secret retrieval"""
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = "secret_value\n"

        result = keychain.get_secret("test_service")

        assert result == "secret_value"
        mock_run.assert_called_once_with(
            ["security", "find-generic-password", "-s", "test_service", "-w"],
            capture_output=True,
            text=True,
            timeout=10,
        )

    @patch("subprocess.run")
    def test_get_secret_not_found(self, mock_run):
        """Test secret not found"""
        mock_run.return_value.returncode = 44  # Not found error code

        result = keychain.get_secret("test_service")

        assert result == ""

    @patch("subprocess.run")
    def test_get_secret_timeout(self, mock_run):
        """Test subprocess timeout"""
        mock_run.side_effect = subprocess.TimeoutExpired("security", 10)

        result = keychain.get_secret("test_service")

        assert result == ""

    @patch("subprocess.run")
    def test_get_secret_file_not_found(self, mock_run):
        """Test security command not found"""
        mock_run.side_effect = FileNotFoundError()

        result = keychain.get_secret("test_service")

        assert result == ""

    @patch("subprocess.run")
    def test_set_secret_success(self, mock_run):
        """Test successful secret setting"""
        mock_run.return_value.returncode = 0

        keychain.set_secret("test_service", "secret_value")

        # Should call add-generic-password twice (add then update)
        assert mock_run.call_count == 2
        calls = mock_run.call_args_list
        assert calls[0][0][0] == [
            "security",
            "add-generic-password",
            "-s",
            "test_service",
            "-w",
            "secret_value",
        ]
        assert calls[1][0][0] == [
            "security",
            "add-generic-password",
            "-U",
            "-s",
            "test_service",
            "-w",
            "secret_value",
        ]

    @patch("subprocess.run")
    def test_set_secret_timeout(self, mock_run):
        """Test subprocess timeout during set"""
        mock_run.side_effect = subprocess.TimeoutExpired("security", 10)

        # Should not raise exception
        keychain.set_secret("test_service", "secret_value")

    @patch("keychain.get_secret", return_value="retrieved_secret")
    def test_main_get(self, mock_get_secret):
        """Test main function get action"""
        with patch("sys.argv", ["keychain.py", "get", "test_service"]):
            with patch("builtins.print") as mock_print:
                result = keychain.main()

        assert result == 0
        mock_get_secret.assert_called_once_with("test_service")
        mock_print.assert_called_once_with("retrieved_secret")

    @patch("keychain.set_secret")
    def test_main_set(self, mock_set_secret):
        """Test main function set action"""
        with patch("sys.argv", ["keychain.py", "set", "test_service", "secret_value"]):
            result = keychain.main()

        assert result == 0
        mock_set_secret.assert_called_once_with("test_service", "secret_value")

    def test_main_insufficient_args(self):
        """Test main function with insufficient arguments"""
        with patch("sys.argv", ["keychain.py"]):
            with patch("builtins.print") as mock_print:
                result = keychain.main()

        assert result == 1
        # Check that error message was printed
        assert any("Usage:" in str(call) for call in mock_print.call_args_list)

    def test_main_invalid_action(self):
        """Test main function with invalid action"""
        with patch("sys.argv", ["keychain.py", "invalid", "service"]):
            with patch("builtins.print") as mock_print:
                result = keychain.main()

        assert result == 1
        assert any("Invalid action" in str(call) for call in mock_print.call_args_list)

    def test_main_set_missing_value(self):
        """Test main function set action with missing value"""
        with patch("sys.argv", ["keychain.py", "set", "test_service"]):
            with patch("builtins.print") as mock_print:
                result = keychain.main()

        assert result == 1
        assert any("Invalid action" in str(call) for call in mock_print.call_args_list)
