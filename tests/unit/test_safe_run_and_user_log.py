import os
import subprocess
import logging

import pytest
from unittest.mock import MagicMock

from agents.utils import safe_run, safe_start, user_log


def test_safe_run_blocks_shell_by_default(monkeypatch):
    # string command with pipe should raise unless ALLOW_SHELL is set
    cmd = "echo hi | sed s/h/a/"

    def fake_run(cmd_arg, **kwargs):
        # Should not be called because safe_run should raise first
        raise AssertionError("subprocess.run should not be invoked when shell disallowed")

    monkeypatch.setattr(subprocess, "run", fake_run)

    if "ALLOW_SHELL" in os.environ:
        del os.environ["ALLOW_SHELL"]

    with pytest.raises(RuntimeError):
        safe_run(cmd)


def test_safe_run_allows_shell_when_env_set(monkeypatch):
    cmd = "echo hi | sed s/h/a/"
    captured = {}

    def fake_run(cmd_arg, **kwargs):
        captured["cmd"] = cmd_arg
        captured["kwargs"] = kwargs

        class R:
            returncode = 0
            stdout = "ok"
            stderr = ""

        return R()

    monkeypatch.setattr(subprocess, "run", fake_run)
    os.environ["ALLOW_SHELL"] = "true"

    try:
        res = safe_run(cmd)
        assert captured["kwargs"].get("shell") is True
    finally:
        if "ALLOW_SHELL" in os.environ:
            del os.environ["ALLOW_SHELL"]


def test_safe_run_allows_shell_when_command_in_allowlist(monkeypatch):
    cmd = "shell-allowed | sed s/h/a/"
    captured = {}

    def fake_run(cmd_arg, **kwargs):
        captured["cmd"] = cmd_arg
        captured["kwargs"] = kwargs

        class R:
            returncode = 0
            stdout = "ok"
            stderr = ""

        return R()

    monkeypatch.setattr(subprocess, "run", fake_run)
    os.environ["ALLOWED_SHELL_COMMANDS"] = "shell-allowed"

    try:
        res = safe_run(cmd)
        assert captured["kwargs"].get("shell") is True
    finally:
        if "ALLOWED_SHELL_COMMANDS" in os.environ:
            del os.environ["ALLOWED_SHELL_COMMANDS"]


def test_safe_start_blocks_shell_by_default(monkeypatch):
    cmd = "echo hi | sed s/h/a/"

    def fake_popen(cmd_arg, **kwargs):
        # Should not be called
        raise AssertionError("subprocess.Popen should not be invoked when shell disallowed")

    monkeypatch.setattr(subprocess, "Popen", fake_popen)

    if "ALLOW_SHELL" in os.environ:
        del os.environ["ALLOW_SHELL"]

    with pytest.raises(RuntimeError):
        safe_start(cmd)


def test_safe_start_allows_shell_when_env_set(monkeypatch):
    cmd = "echo hi | sed s/h/a/"
    captured = {}

    def fake_popen(cmd_arg, **kwargs):
        captured["cmd"] = cmd_arg
        captured["kwargs"] = kwargs

        class P:
            pid = 1234

        return P()

    monkeypatch.setattr(subprocess, "Popen", fake_popen)
    os.environ["ALLOW_SHELL"] = "true"

    try:
        p = safe_start(cmd)
        assert captured["kwargs"].get("shell") is True
        assert getattr(p, "pid", None) == 1234
    finally:
        if "ALLOW_SHELL" in os.environ:
            del os.environ["ALLOW_SHELL"]


def test_safe_start_allows_shell_when_command_in_allowlist(monkeypatch):
    cmd = "shell-allowed | sed s/h/a/"
    captured = {}

    def fake_popen(cmd_arg, **kwargs):
        captured["cmd"] = cmd_arg
        captured["kwargs"] = kwargs

        class P:
            pid = 1234

        return P()

    monkeypatch.setattr(subprocess, "Popen", fake_popen)
    os.environ["ALLOWED_SHELL_COMMANDS"] = "shell-allowed"

    try:
        p = safe_start(cmd)
        assert captured["kwargs"].get("shell") is True
        assert getattr(p, "pid", None) == 1234
    finally:
        if "ALLOWED_SHELL_COMMANDS" in os.environ:
            del os.environ["ALLOWED_SHELL_COMMANDS"]


def test_user_log_uses_logger_by_default(monkeypatch):
    # Capture logger calls
    logger = logging.getLogger("agents.utils")
    fake_info = MagicMock()
    monkeypatch.setattr(logger, "info", fake_info)

    user_log("testing logger")
    fake_info.assert_called_with("testing logger")


def test_user_log_prints_when_env_set(capsys, monkeypatch):
    os.environ["LOG_TO_STDOUT"] = "1"
    # Ensure logger not used
    logger = logging.getLogger("agents.utils")
    # Replace logger methods with no-op to ensure fallback to print
    monkeypatch.setattr(logger, "info", lambda msg: None)

    try:
        user_log("test_print")
        captured = capsys.readouterr()
        assert "test_print" in captured.out
    finally:
        if "LOG_TO_STDOUT" in os.environ:
            del os.environ["LOG_TO_STDOUT"]
