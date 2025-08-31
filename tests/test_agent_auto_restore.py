import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import requests

MCP_PY = os.path.join(os.path.dirname(__file__), "..", "mcp_server.py")
AGENT_PY = os.path.join(os.path.dirname(__file__), "..", "agents", "run_agent.py")


def start_mcp(port=5005):
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    p = subprocess.Popen([sys.executable, MCP_PY, "127.0.0.1", str(port)], env=env)
    for _ in range(20):
        try:
            r = requests.get(f"http://127.0.0.1:{port}/status", timeout=1)
            if r.ok:
                return p
        except Exception:
            time.sleep(0.2)
    p.terminate()
    raise RuntimeError("MCP did not start")


def stop_mcp(p):
    try:
        p.terminate()
        p.wait(timeout=2)
    except Exception:
        p.kill()


def test_agent_auto_restore(tmp_path):
    # prepare target file
    target = os.path.join(os.path.dirname(__file__), "..", "test_modify_target.txt")
    target = os.path.abspath(target)
    with open(target, "w") as f:
        f.write("original")

    # choose a free port for this test to avoid conflicts with any running MCP
    import socket

    s = socket.socket()
    s.bind(("", 0))
    port = s.getsockname()[1]
    s.close()

    # start mcp on chosen port
    p = start_mcp(port=port)
    try:
        # start agent using venv/python same as test
        venv_python = sys.executable
        env = os.environ.copy()
        env["MCP_URL"] = f"http://127.0.0.1:{port}"
        agent_proc = subprocess.Popen(
            [
                venv_python,
                AGENT_PY,
                "--name",
                "pytest-auto",
                "--capabilities",
                "execute",
                "--interval",
                "1",
            ],
            env=env,
        )
        time.sleep(0.5)

        # register and enqueue modify-fail execute against the test MCP URL
        base = f"http://127.0.0.1:{port}"
        r = requests.post(
            f"{base}/register",
            json={"agent": "pytest-auto", "capabilities": ["execute"]},
            timeout=3,
        )
        assert r.ok
        r2 = requests.post(
            f"{base}/run",
            json={
                "agent": "pytest-auto",
                "command": "modify-fail",
                "project": "",
                "execute": True,
            },
            timeout=3,
        )
        assert r2.ok
        tid = r2.json().get("task_id")

        # wait until a backup marker appears (written by agent)
        marker = f"{target}.bak_marker"
        found = False
        for _ in range(40):
            if os.path.exists(marker):
                found = True
                break
            time.sleep(0.2)
        assert found, "backup marker not created"

        # wait for restore to happen (agent polls and will restore on failure)
        restored = False
        for _ in range(60):
            with open(target, "r") as f:
                data = f.read()
            if "original" in data:
                restored = True
                break
            time.sleep(0.2)
        assert restored, "original content not restored"

    finally:
        try:
            agent_proc.send_signal(signal.SIGINT)
            agent_proc.wait(timeout=2)
        except Exception:
            agent_proc.kill()
        stop_mcp(p)
