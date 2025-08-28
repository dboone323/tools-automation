import os
import subprocess
import sys
import time

import requests

MCP_URL = "http://127.0.0.1:5005"
MCP_PY = os.path.join(os.path.dirname(__file__), "..", "mcp_server.py")


def _start_mcp():
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    p = subprocess.Popen([sys.executable, MCP_PY], env=env)
    for _ in range(30):
        try:
            r = requests.get(f"{MCP_URL}/status", timeout=1)
            if r.ok:
                return p
        except Exception:
            time.sleep(0.1)
    p.terminate()
    raise RuntimeError("MCP did not start")


def _stop_mcp(p):
    try:
        p.terminate()
        p.wait(timeout=2)
    except Exception:
        p.kill()


def test_status():
    p = _start_mcp()
    try:
        r = requests.get(f"{MCP_URL}/status", timeout=3)
        assert r.status_code == 200
        data = r.json()
        assert "ok" in data and data["ok"] is True
    finally:
        _stop_mcp(p)


def test_register_and_queue():
    p = _start_mcp()
    try:
        name = f"test-agent-{int(time.time())}"
        r = requests.post(
            f"{MCP_URL}/register",
            json={"agent": name, "capabilities": ["test"]},
            timeout=3,
        )
        assert r.status_code == 200
        j = r.json()
        assert j.get("registered") == name

        r2 = requests.post(
            f"{MCP_URL}/run",
            json={"agent": name, "command": "status", "project": "", "execute": False},
            timeout=3,
        )
        assert r2.status_code == 200
        j2 = r2.json()
        assert j2.get("queued") is True
    finally:
        _stop_mcp(p)
