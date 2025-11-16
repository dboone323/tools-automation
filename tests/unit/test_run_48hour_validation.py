import subprocess
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
from run_48hour_validation import ValidationOrchestrator


class DummyCompletedProcess:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


def test_run_test_suite_no_shell(monkeypatch, tmp_path):
    v = ValidationOrchestrator(
        config_file=str(tmp_path / "v.json"), results_dir=str(tmp_path / "results")
    )

    captured = {}

    def fake_run(
        cmd,
        capture_output=True,
        text=True,
        timeout=None,
        cwd=None,
        env=None,
        shell=False,
    ):
        captured["cmd"] = cmd
        captured["shell"] = shell
        captured["env"] = env
        return DummyCompletedProcess(returncode=0, stdout="PASS")

    monkeypatch.setattr(subprocess, "run", fake_run)

    suite = {"name": "unit_tests", "command": "pytest tests/unit/ -v"}
    res = v.run_test_suite(suite)
    assert captured["shell"] is False
    assert res["success"]


def test_run_test_suite_with_pipe(monkeypatch, tmp_path):
    v = ValidationOrchestrator(
        config_file=str(tmp_path / "v.json"), results_dir=str(tmp_path / "results")
    )

    captured = {}

    def fake_run(
        cmd,
        capture_output=True,
        text=True,
        timeout=None,
        cwd=None,
        env=None,
        shell=True,
    ):
        captured["cmd"] = cmd
        captured["shell"] = shell
        return DummyCompletedProcess(returncode=0, stdout="PASS")

    monkeypatch.setattr(subprocess, "run", fake_run)

    suite = {
        "name": "check",
        "command": "curl -s http://localhost:5005/health | head -1",
    }
    res = v.run_test_suite(suite)
    assert captured["shell"] is True
    assert res["success"]
