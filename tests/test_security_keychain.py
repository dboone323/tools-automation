import pytest
import sys
import os
from unittest.mock import Mock, patch, MagicMock

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import security.keychain


class TestSecurityKeychain:
    """Comprehensive tests for security/keychain.py"""

    @patch("security.keychain.subprocess.run")
    def test_get_secret_success(self, mock_run):
        """Test successful secret retrieval"""
        mock_run.return_value = Mock(stdout="secret_value\n", stderr="")

        result = security.keychain.get_secret("test_key")

        assert result == "secret_value"
        mock_run.assert_called_once_with(
            [
                "security",
                "find-generic-password",
                "-a",
                os.environ["USER"],
                "-s",
                "tools-automation-test_key",
                "-w",
            ],
            capture_output=True,
            text=True,
            check=True,
        )

    @patch("security.keychain.subprocess.run")
    def test_get_secret_not_found(self, mock_run):
        """Test secret retrieval when key doesn't exist"""
        mock_run.side_effect = security.keychain.subprocess.CalledProcessError(
            1, "security"
        )

        with pytest.raises(KeyError, match="Secret not found for key: test_key"):
            security.keychain.get_secret("test_key")

    @patch("security.keychain.subprocess.run")
    def test_set_secret_success_first_try(self, mock_run):
        """Test successful secret setting on first attempt"""
        mock_run.return_value = Mock()

        security.keychain.set_secret("test_key", "test_value")

        mock_run.assert_called_once_with(
            [
                "security",
                "add-generic-password",
                "-a",
                os.environ["USER"],
                "-s",
                "tools-automation-test_key",
                "-w",
                "test_value",
                "-U",
            ],
            capture_output=True,
            check=True,
        )

    @patch("security.keychain.subprocess.run")
    def test_set_secret_success_after_delete(self, mock_run):
        """Test successful secret setting after deleting existing"""
        # First call fails (already exists), second deletes, third adds
        mock_run.side_effect = [
            security.keychain.subprocess.CalledProcessError(1, "security"),  # add fails
            Mock(),  # delete succeeds
            Mock(),  # add succeeds
        ]

        security.keychain.set_secret("test_key", "test_value")

        assert mock_run.call_count == 3

    @patch("security.keychain.subprocess.run")
    def test_delete_secret_success(self, mock_run):
        """Test successful secret deletion"""
        mock_run.return_value = Mock()

        security.keychain.delete_secret("test_key")

        mock_run.assert_called_once_with(
            [
                "security",
                "delete-generic-password",
                "-a",
                os.environ["USER"],
                "-s",
                "tools-automation-test_key",
            ],
            capture_output=True,
            check=True,
        )

    @patch("security.keychain.subprocess.run")
    def test_delete_secret_not_found(self, mock_run):
        """Test secret deletion when key doesn't exist"""
        mock_run.side_effect = security.keychain.subprocess.CalledProcessError(
            1, "security"
        )

        with pytest.raises(KeyError, match="Secret not found for key: test_key"):
            security.keychain.delete_secret("test_key")

    @patch("security.keychain.subprocess.run")
    def test_list_secrets_success(self, mock_run):
        """Test successful secret listing"""
        mock_stdout = """
keychain: "/Users/test/Library/Keychains/login.keychain-db"
class: "genp"
attributes:
    "svce"<blob>="tools-automation-token1"
    "acct"<blob>="testuser"
    "svce"<blob>="tools-automation-token2"
    "svce"<blob>="other-service-key"
"""
        mock_run.return_value = Mock(stdout=mock_stdout, stderr="")

        result = security.keychain.list_secrets()

        expected = ["tools-automation-token1", "tools-automation-token2"]
        assert set(result) == set(expected)

    @patch("security.keychain.subprocess.run")
    def test_list_secrets_empty(self, mock_run):
        """Test secret listing when no secrets found"""
        mock_run.return_value = Mock(stdout="", stderr="")

        result = security.keychain.list_secrets()

        assert result == []

    @patch("security.keychain.subprocess.run")
    def test_list_secrets_command_failure(self, mock_run):
        """Test secret listing when command fails"""
        mock_run.side_effect = security.keychain.subprocess.CalledProcessError(
            1, "security"
        )

        result = security.keychain.list_secrets()

        assert result == []

    @patch("security.keychain.get_secret")
    @patch("builtins.print")
    def test_main_get_success(self, mock_print, mock_get):
        """Test main function get command success"""
        mock_get.return_value = "secret_value"

        with patch("sys.argv", ["keychain.py", "get", "test_key"]):
            security.keychain.main()

        mock_get.assert_called_once_with("test_key")
        mock_print.assert_called_once_with("secret_value")

    @patch("security.keychain.set_secret")
    def test_main_set_success(self, mock_set):
        """Test main function set command success"""
        with patch("sys.argv", ["keychain.py", "set", "test_key", "test_value"]):
            security.keychain.main()

        mock_set.assert_called_once_with("test_key", "test_value")

    @patch("security.keychain.delete_secret")
    def test_main_delete_success(self, mock_delete):
        """Test main function delete command success"""
        with patch("sys.argv", ["keychain.py", "delete", "test_key"]):
            security.keychain.main()

        mock_delete.assert_called_once_with("test_key")

    @patch("security.keychain.list_secrets")
    @patch("builtins.print")
    def test_main_list_success(self, mock_print, mock_list):
        """Test main function list command success"""
        mock_list.return_value = ["tools-automation-key1", "tools-automation-key2"]

        with patch("sys.argv", ["keychain.py", "list"]):
            security.keychain.main()

        mock_list.assert_called_once()
        assert mock_print.call_count == 3  # header + 2 items

    @patch("builtins.print")
    def test_main_insufficient_args_get(self, mock_print):
        """Test main function with insufficient args for get"""
        with patch("sys.argv", ["keychain.py", "get"]):
            with pytest.raises(SystemExit, match="1"):
                security.keychain.main()

    @patch("builtins.print")
    def test_main_insufficient_args_set(self, mock_print):
        """Test main function with insufficient args for set"""
        with patch("sys.argv", ["keychain.py", "set", "key"]):
            with pytest.raises(SystemExit, match="1"):
                security.keychain.main()

    @patch("builtins.print")
    def test_main_insufficient_args_delete(self, mock_print):
        """Test main function with insufficient args for delete"""
        with patch("sys.argv", ["keychain.py", "delete"]):
            with pytest.raises(SystemExit, match="1"):
                security.keychain.main()

    @patch("builtins.print")
    def test_main_unknown_command(self, mock_print):
        """Test main function with unknown command"""
        with patch("sys.argv", ["keychain.py", "unknown"]):
            with pytest.raises(SystemExit, match="1"):
                security.keychain.main()

    @patch("security.keychain.get_secret")
    @patch("builtins.print")
    def test_main_get_key_error(self, mock_print, mock_get):
        """Test main function get command with KeyError"""
        mock_get.side_effect = KeyError("Secret not found")

        with patch("sys.argv", ["keychain.py", "get", "test_key"]):
            with pytest.raises(SystemExit, match="1"):
                security.keychain.main()

    @patch("security.keychain.set_secret")
    def test_main_set_exception(self, mock_set):
        """Test main function set command with exception"""
        mock_set.side_effect = Exception("Set failed")

        with patch("sys.argv", ["keychain.py", "set", "test_key", "value"]):
            with pytest.raises(SystemExit, match="1"):
                security.keychain.main()

    # TODO: Add specific tests for functions in security/keychain.py
    # The module import now works correctly, so you can add real test functions here
    # Examples:
    # def test_specific_function(self):
    #     import security.keychain as module
    #     result = module.function_name(args)
    #     assert result == expected
