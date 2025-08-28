import os
import signal
import subprocess
import sys
import tempfile
import time

import requests

MCP_PY = os.path.join(os.path.dirname(__file__), "..", "mcp_server.py")


def start_mcp():
    env = os.environ.copy()
    # ensure logs go somewhere local and deterministic
    env["PYTHONUNBUFFERED"] = "1"
    p = subprocess.Popen([sys.executable, MCP_PY], env=env)
    # wait for server to be up
    for _ in range(20):
        try:
            r = requests.get("http://127.0.0.1:5005/status", timeout=1)
            if r.ok:
                return p
        except Exception:
            time.sleep(0.2)
    # timeout
    p.terminate()
    raise RuntimeError("MCP did not start")


def stop_mcp(p):
    try:
        p.terminate()
        p.wait(timeout=2)
    except Exception:
        p.kill()


def test_register_and_run_execute_flow():
    p = start_mcp()
    try:
        # register agent
        r = requests.post(
            "http://127.0.0.1:5005/register",
            json={"agent": "pytest-agent", "capabilities": ["monitor"]},
            timeout=3,
        )
        assert r.ok and r.json().get("registered") == "pytest-agent"

        # enqueue a non-executable run (should be queued)
        r2 = requests.post(
            "http://127.0.0.1:5005/run",
            json={
                "agent": "pytest-agent",
                "command": "status",
                "project": "",
                "execute": False,
            },
            timeout=3,
        )
        assert r2.ok and r2.json().get("queued")
        task_id = r2.json().get("task_id")

        # execute the task
        r3 = requests.post(
            "http://127.0.0.1:5005/execute_task", json={"task_id": task_id}, timeout=3
        )
        assert r3.ok and r3.json().get("executing")

        # wait for execution to finish and verify task status persisted
        for _ in range(20):
            st = requests.get("http://127.0.0.1:5005/status", timeout=1).json()
            tasks = st.get("tasks", [])
            found = [t for t in tasks if t.get("id") == task_id]
            if found and found[0].get("status") in ("success", "failed", "error"):
                break
            time.sleep(0.2)
        assert found and found[0].get("status") in ("success", "failed", "error")
    finally:
        stop_mcp(p)


def test_modify_fail_and_rollback():
    # start MCP
    p = start_mcp()
    try:
        # ensure target file exists
        target = os.path.join(os.path.dirname(__file__), "..", "test_modify_target.txt")
        target = os.path.abspath(target)
        with open(target, "w") as f:
            f.write("original\n")

        # register a test agent with execute capability
        r = requests.post(
            "http://127.0.0.1:5005/register",
            json={"agent": "pytest-exec", "capabilities": ["execute"]},
            timeout=3,
        )
        assert r.ok

        # enqueue modify-fail and request execute
        r2 = requests.post(
            "http://127.0.0.1:5005/run",
            json={
                "agent": "pytest-exec",
                "command": "modify-fail",
                "project": "",
                "execute": True,
            },
            timeout=3,
        )
        assert r2.ok
        tid = r2.json().get("task_id")

        # wait for persisted task file to appear and for .bak to be created by agent (started earlier)
        bak_found = False
        for _ in range(30):
            # check for task file
            tasks_dir = os.path.join(os.path.dirname(__file__), "..", "tasks")
            if os.path.isdir(tasks_dir):
                for fn in os.listdir(tasks_dir):
                    if fn.endswith(".json") and tid in fn:
                        # only consider true backup files that include the timestamp separator '.bak.'
                        bakfiles = [
                            x
                            for x in os.listdir(os.path.dirname(target))
                            if (
                                x.startswith(os.path.basename(target) + ".bak.")
                                and ".bak." in x
                            )
                        ]
                        if bakfiles:
                            bak_found = True
                            break
            if bak_found:
                break
            time.sleep(0.5)

        assert bak_found, "backup file was not created"

        # simulate rollback by restoring from bak
        bakfiles = [
            x
            for x in os.listdir(os.path.dirname(target))
            if (x.startswith(os.path.basename(target) + ".bak.") and ".bak." in x)
        ]
        assert bakfiles
        bakpath = os.path.join(os.path.dirname(target), bakfiles[-1])
        import shutil

        shutil.copy2(bakpath, target)

        # read back
        with open(target, "r") as f:
            data = f.read()
        assert "original" in data

    finally:
        stop_mcp(p)
