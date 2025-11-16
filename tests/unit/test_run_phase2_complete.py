import subprocess
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
from run_phase2_complete import Phase2TestOrchestrator


class DummyCompletedProcess:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


def test_run_command_background_no_shell(monkeypatch, tmp_path):
    orchestrator = Phase2TestOrchestrator(workspace_root=str(tmp_path))

    captured = {}

    def fake_run(
        cmd,
        capture_output=True,
        text=True,
        cwd=None,
        timeout=None,
        env=None,
        shell=False,
    ):
        captured["cmd"] = cmd
        captured["shell"] = shell
        captured["env"] = env
        return DummyCompletedProcess(returncode=0, stdout="ok")

    monkeypatch.setattr(subprocess, "run", fake_run)

    # run a simple list-like command that should not need a shell
    r = orchestrator._run_command_background("echo hi", "test")
    assert captured["shell"] is False

    # run a command containing a pipe that requires a shell
    captured.clear()
    r = orchestrator._run_command_background("echo hi | grep hi", "testpipe")
    assert captured["shell"] is True


def test_run_command_background_env_assignment(monkeypatch, tmp_path):
    orchestrator = Phase2TestOrchestrator(workspace_root=str(tmp_path))
    captured = {}

    def fake_run(
        cmd,
        capture_output=True,
        text=True,
        cwd=None,
        timeout=None,
        env=None,
        shell=False,
    ):
        captured["cmd"] = cmd
        captured["env"] = env
        captured["shell"] = shell
        return DummyCompletedProcess(returncode=0, stdout="ok")

    monkeypatch.setattr(subprocess, "run", fake_run)

    r = orchestrator._run_command_background(
        "PORT=5001 ./serve_dashboard.sh start", "dashboard"
    )
    assert captured["shell"] is False
    assert "PORT" in captured["env"]
