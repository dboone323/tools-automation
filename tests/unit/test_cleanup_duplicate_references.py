import subprocess
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
from CodingReviewer.Tools.Automation.cleanup_duplicate_references import verify_project


class DummyCompletedProcess:
    def __init__(self, stdout="", stderr=""):
        self.stdout = stdout
        self.stderr = stderr


def test_verify_project_no_warning(monkeypatch, tmp_path):
    def fake_run(cmd, capture_output=True, text=True, check=False):
        return DummyCompletedProcess(stdout="Some expected output\nAll good")

    monkeypatch.setattr(subprocess, "run", fake_run)
    assert verify_project("/path/to/project.xcodeproj") is True


def test_verify_project_warning(monkeypatch):
    def fake_run(cmd, capture_output=True, text=True, check=False):
        return DummyCompletedProcess(stdout="member of multiple groups\nError details")

    monkeypatch.setattr(subprocess, "run", fake_run)
    assert verify_project("/path/to/project.xcodeproj") is False
