import os
import sys
from pathlib import Path
import subprocess
from types import SimpleNamespace
import importlib


sys.path.append(str(Path(__file__).parents[2]))
from run_48hour_validation import ValidationOrchestrator
from run_phase2_complete import Phase2TestOrchestrator


def test_run_48hour_validation_shell_not_allowed(monkeypatch):
    # Command with a pipe requires shell usage; ALLOW_SHELL not set by default
    vo = ValidationOrchestrator(
        config_file="validation_config.json", results_dir="validation_results_test"
    )
    suite = {
        "name": "test_shell",
        "command": "echo hi | sed s/h/a/",
        "timeout_seconds": 5,
    }

    captured = {}

    def fake_run(cmd, **kwargs):
        captured["cmd"] = cmd
        captured["kwargs"] = kwargs

        class R:
            returncode = 0
            stdout = "ok"
            stderr = ""

        return R()

    monkeypatch.setattr(subprocess, "run", fake_run)

    _result = vo.run_test_suite(suite)
    # Because allow_shell is False, subprocess.run should NOT be invoked with shell=True
    assert "shell" not in captured["kwargs"] or not captured["kwargs"].get("shell")


def test_run_48hour_validation_shell_allowed_by_suite(monkeypatch):
    vo = ValidationOrchestrator(
        config_file="validation_config.json", results_dir="validation_results_test"
    )
    suite = {
        "name": "test_shell",
        "command": "echo hi | sed s/h/a/",
        "timeout_seconds": 5,
        "allow_shell": True,
    }

    captured = {}

    def fake_run(cmd, **kwargs):
        captured["cmd"] = cmd
        captured["kwargs"] = kwargs

        class R:
            returncode = 0
            stdout = "ok"
            stderr = ""

        return R()

    monkeypatch.setattr(subprocess, "run", fake_run)

    _result = vo.run_test_suite(suite)
    assert captured["kwargs"].get("shell") is True


def test_phase2_run_test_command_shell_policy(monkeypatch):
    orchestrator = Phase2TestOrchestrator()
    cmd = "echo hi | sed s/h/a/"

    captured = {}

    def fake_run(cmd, **kwargs):
        captured["cmd"] = cmd
        captured["kwargs"] = kwargs

        class R:
            returncode = 0
            stdout = "ok"
            stderr = ""

        return R()

    monkeypatch.setattr(subprocess, "run", fake_run)

    # By default ALLOW_SHELL is not set; ensure background and test commands avoid shell=True
    _r = orchestrator._run_test_command(cmd, "unit_test")
    assert not captured["kwargs"].get("shell", False)

    # Now set ALLOW_SHELL via env var and ensure shell=True is used
    os.environ["ALLOW_SHELL"] = "true"
    orchestrator = Phase2TestOrchestrator()
    captured = {}
    monkeypatch.setattr(subprocess, "run", fake_run)
    _r = orchestrator._run_test_command(cmd, "unit_test")
    assert captured["kwargs"].get("shell") is True
    if "ALLOW_SHELL" in os.environ:
        del os.environ["ALLOW_SHELL"]


def test_mcp_execute_task_shell_usage(monkeypatch, tmp_path):
    mcp = importlib.import_module("mcp_server")
    MCPHandler = getattr(mcp, "MCPHandler")
    # build a minimal self-like object
    fake_server = SimpleNamespace(metrics={"tasks_executed": 0, "tasks_failed": 0})
    self_obj = SimpleNamespace(server=fake_server)
    # Provide CODE_DIR used in mcp_server
    setattr(mcp, "CODE_DIR", str(tmp_path))
    task = {"id": "1234", "command": "echo hi | sed s/h/a/"}

    captured = {}

    def fake_run(cmd, **kwargs):
        captured["cmd"] = cmd
        captured["kwargs"] = kwargs

        class R:
            returncode = 0
            stdout = "out"
            stderr = ""

        return R()

    monkeypatch.setattr(subprocess, "run", fake_run)

    # Call the function unbound: MCPHandler._execute_task(self_obj, task, task["command"]) without ALLOW_SHELL
    func = getattr(MCPHandler, "_execute_task")
    func(self_obj, task, task["command"])
    # Without ALLOW_SHELL, subprocess.run should not be invoked for shell commands
    assert "kwargs" not in captured

    # Now enable ALLOW_SHELL via env var and re-run
    os.environ["ALLOW_SHELL"] = "true"
    captured = {}
    monkeypatch.setattr(subprocess, "run", fake_run)
    func(self_obj, task, task["command"])
    assert captured["kwargs"].get("shell") is True
    if "ALLOW_SHELL" in os.environ:
        del os.environ["ALLOW_SHELL"]


def test_mcp_execute_task_shell_allowed_by_command_name(monkeypatch, tmp_path):
    mcp = importlib.import_module("mcp_server")
    MCPHandler = getattr(mcp, "MCPHandler")
    fake_server = SimpleNamespace(metrics={"tasks_executed": 0, "tasks_failed": 0})
    self_obj = SimpleNamespace(server=fake_server)
    setattr(mcp, "CODE_DIR", str(tmp_path))
    task = {"id": "1234", "command": "shell-allowed"}
    cmd = "echo hi | sed s/h/a/"

    captured = {}

    def fake_run(cmd, **kwargs):
        captured["cmd"] = cmd
        captured["kwargs"] = kwargs

        class R:
            returncode = 0
            stdout = "out"
            stderr = ""

        return R()

    monkeypatch.setattr(subprocess, "run", fake_run)

    # When ALLOWED_SHELL_COMMANDS contains the command, shell should be allowed
    os.environ["ALLOWED_SHELL_COMMANDS"] = "shell-allowed"
    func = getattr(MCPHandler, "_execute_task")
    func(self_obj, task, cmd)
    assert captured["kwargs"].get("shell") is True
    if "ALLOWED_SHELL_COMMANDS" in os.environ:
        del os.environ["ALLOWED_SHELL_COMMANDS"]
