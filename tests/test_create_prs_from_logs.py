import pytest
import sys
import os
import json
from unittest.mock import Mock, patch, MagicMock
from urllib.error import HTTPError

# Add the workspace root to sys.path
if "/Users/danielstevens/Desktop/github-projects/tools-automation" not in sys.path:
    sys.path.insert(0, "/Users/danielstevens/Desktop/github-projects/tools-automation")

import create_prs_from_logs


class TestCreatePrsFromLogs:
    """Comprehensive tests for create_prs_from_logs.py"""

    @patch("glob.glob")
    def test_find_logs(self, mock_glob):
        """Test finding log files"""
        mock_glob.return_value = ["file1_snapshot.log", "file2_snapshot.log"]
        logs = create_prs_from_logs.find_logs("/outdir")
        assert logs == ["file1_snapshot.log", "file2_snapshot.log"]
        mock_glob.assert_called_once_with(os.path.join("/outdir", "*_snapshot.log"))

    def test_extract_repo_and_branch_https(self):
        """Test extracting repo and branch from HTTPS URL"""
        text = "https://github.com/owner/repo.git branch snapshot/2023-01-01T12:00:00"
        repo, branch = create_prs_from_logs.extract_repo_and_branch(text)
        assert repo == "owner/repo"
        assert branch == "snapshot/2023-01-01T12:00:00"

    def test_extract_repo_and_branch_ssh(self):
        """Test extracting repo and branch from SSH URL"""
        text = "git@github.com:owner/repo.git snapshot/branch-name"
        repo, branch = create_prs_from_logs.extract_repo_and_branch(text)
        assert repo == "owner/repo"
        assert branch == "snapshot/branch-name"

    def test_extract_repo_and_branch_no_match(self):
        """Test extracting when no match found"""
        text = "no github url here"
        repo, branch = create_prs_from_logs.extract_repo_and_branch(text)
        assert repo is None
        assert branch is None

    def test_extract_repo_and_branch_no_branch(self):
        """Test extracting repo without branch"""
        text = "https://github.com/owner/repo.git"
        repo, branch = create_prs_from_logs.extract_repo_and_branch(text)
        assert repo == "owner/repo"
        assert branch is None

    @patch("urllib.request.urlopen")
    @patch("urllib.request.Request")
    def test_create_pr_success(self, mock_request, mock_urlopen):
        """Test successful PR creation"""
        mock_resp = Mock()
        mock_resp.read.return_value = (
            b'{"html_url": "https://github.com/owner/repo/pull/1", "number": 1}'
        )
        mock_urlopen.return_value.__enter__.return_value = mock_resp

        result = create_prs_from_logs.create_pr(
            "owner/repo", "snapshot/branch", "token"
        )

        assert result == {
            "html_url": "https://github.com/owner/repo/pull/1",
            "number": 1,
        }
        mock_request.assert_called_once()
        args = mock_request.call_args
        assert args[0][0] == "https://api.github.com/repos/owner/repo/pulls"
        assert (
            json.loads(args[1]["data"])["title"]
            == "[snapshot] commit all local changes before automation run (branch)"
        )
        assert json.loads(args[1]["data"])["draft"] == True

    @patch("urllib.request.urlopen")
    @patch("urllib.request.Request")
    def test_create_pr_http_error(self, mock_request, mock_urlopen):
        """Test PR creation with HTTP error"""
        mock_urlopen.side_effect = HTTPError(
            None, 422, "Unprocessable Entity", None, None
        )
        mock_urlopen.side_effect.read.return_value = b'{"message": "error"}'

        with pytest.raises(HTTPError):
            create_prs_from_logs.create_pr("owner/repo", "snapshot/branch", "token")

    @patch("urllib.request.urlopen")
    @patch("urllib.request.Request")
    def test_request_reviewers_success(self, mock_request, mock_urlopen):
        """Test successful reviewer request"""
        mock_resp = Mock()
        mock_resp.read.return_value = b'{"requested_reviewers": []}'
        mock_urlopen.return_value.__enter__.return_value = mock_resp

        result = create_prs_from_logs.request_reviewers(
            "owner/repo", 1, "token", ["user1", "user2"]
        )

        assert result == {"requested_reviewers": []}
        mock_request.assert_called_once()
        args = mock_request.call_args
        assert (
            args[0][0]
            == "https://api.github.com/repos/owner/repo/pulls/1/requested_reviewers"
        )
        assert json.loads(args[1]["data"])["reviewers"] == ["user1", "user2"]

    @patch("builtins.open", new_callable=MagicMock)
    def test_append_log(self, mock_open):
        """Test appending to log file"""
        mock_file = Mock()
        mock_open.return_value.__enter__.return_value = mock_file

        create_prs_from_logs.append_log("/path/to/log", "new line")

        mock_open.assert_called_once_with("/path/to/log", "a", encoding="utf-8")
        mock_file.write.assert_called_once_with("\nnew line\n")

    @patch("create_prs_from_logs.find_logs")
    @patch("create_prs_from_logs.extract_repo_and_branch")
    @patch("create_prs_from_logs.create_pr")
    @patch("create_prs_from_logs.request_reviewers")
    @patch("create_prs_from_logs.append_log")
    @patch("time.sleep")
    @patch("builtins.open", new_callable=MagicMock)
    @patch.dict(os.environ, {"GITHUB_PAT": "test_token"})
    def test_main_success(
        self,
        mock_open,
        mock_sleep,
        mock_append,
        mock_request_reviewers,
        mock_create_pr,
        mock_extract,
        mock_find_logs,
    ):
        """Test main function successful execution"""
        mock_find_logs.return_value = [
            "/path/log1_snapshot.log",
            "/path/log2_snapshot.log",
        ]
        mock_extract.side_effect = [
            ("owner/repo1", "snapshot/branch1"),
            ("owner/repo2", "snapshot/branch2"),
        ]
        mock_create_pr.side_effect = [
            {"html_url": "https://github.com/owner/repo1/pull/1", "number": 1},
            {"html_url": "https://github.com/owner/repo2/pull/2", "number": 2},
        ]
        mock_file = Mock()
        mock_file.read.return_value = "log content"
        mock_open.return_value.__enter__.return_value = mock_file

        with patch(
            "sys.argv",
            [
                "create_prs_from_logs.py",
                "--outdir",
                "/outdir",
                "--batch",
                "2",
                "--sleep",
                "2",
            ],
        ):
            result = create_prs_from_logs.main()

        assert result == 0
        assert mock_create_pr.call_count == 2
        assert mock_request_reviewers.call_count == 2
        assert mock_append.call_count == 2  # PR created messages
        mock_sleep.assert_called_once_with(2)

    @patch("create_prs_from_logs.find_logs")
    @patch.dict(os.environ, {"GITHUB_PAT": "test_token"})
    def test_main_no_logs(self, mock_find_logs):
        """Test main function with no logs found"""
        mock_find_logs.return_value = []

        with patch("sys.argv", ["create_prs_from_logs.py", "--outdir", "/outdir"]):
            result = create_prs_from_logs.main()

        assert result == 0

    @patch.dict(os.environ, {}, clear=True)
    def test_main_no_pat(self):
        """Test main function without GITHUB_PAT"""
        with patch("sys.argv", ["create_prs_from_logs.py", "--outdir", "/outdir"]):
            result = create_prs_from_logs.main()

        assert result == 1

    @patch("create_prs_from_logs.find_logs")
    @patch("create_prs_from_logs.extract_repo_and_branch")
    @patch("create_prs_from_logs.create_pr")
    @patch("create_prs_from_logs.append_log")
    @patch("builtins.open", new_callable=MagicMock)
    @patch.dict(os.environ, {"GITHUB_PAT": "test_token"})
    def test_main_pr_creation_error(
        self, mock_open, mock_append, mock_create_pr, mock_extract, mock_find_logs
    ):
        """Test main function with PR creation error"""
        mock_find_logs.return_value = ["/path/log_snapshot.log"]
        mock_extract.return_value = ("owner/repo", "snapshot/branch")
        mock_create_pr.side_effect = Exception("API error")
        mock_file = Mock()
        mock_file.read.return_value = "log content"
        mock_open.return_value.__enter__.return_value = mock_file

        with patch("sys.argv", ["create_prs_from_logs.py", "--outdir", "/outdir"]):
            result = create_prs_from_logs.main()

        assert result == 0
        mock_append.assert_called_once_with(
            "/path/log_snapshot.log", "PR_CREATE_ERROR: API error"
        )

    @patch("create_prs_from_logs.find_logs")
    @patch("create_prs_from_logs.extract_repo_and_branch")
    @patch("builtins.open", new_callable=MagicMock)
    @patch.dict(os.environ, {"GITHUB_PAT": "test_token"})
    def test_main_file_read_error(self, mock_open, mock_extract, mock_find_logs):
        """Test main function with file read error"""
        mock_find_logs.return_value = ["/path/log_snapshot.log"]
        mock_open.side_effect = Exception("Read error")

        with patch("sys.argv", ["create_prs_from_logs.py", "--outdir", "/outdir"]):
            result = create_prs_from_logs.main()

        assert result == 0
        # Should skip the file due to read error

    @patch("create_prs_from_logs.find_logs")
    @patch("create_prs_from_logs.extract_repo_and_branch")
    @patch("builtins.open", new_callable=MagicMock)
    @patch.dict(os.environ, {"GITHUB_PAT": "test_token"})
    def test_main_missing_repo_branch(self, mock_open, mock_extract, mock_find_logs):
        """Test main function with missing repo or branch"""
        mock_find_logs.return_value = ["/path/log_snapshot.log"]
        mock_extract.return_value = (None, "snapshot/branch")  # Missing repo
        mock_file = Mock()
        mock_file.read.return_value = "log content"
        mock_open.return_value.__enter__.return_value = mock_file

        with patch("sys.argv", ["create_prs_from_logs.py", "--outdir", "/outdir"]):
            result = create_prs_from_logs.main()

        assert result == 0
        # Should skip the file due to missing repo
