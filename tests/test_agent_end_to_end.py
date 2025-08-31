import importlib.util
import json
import os
import subprocess
import threading
import time
from pathlib import Path

import pytest
import requests

# Load mcp_server module from the Automation directory by file path so tests don't
# depend on PYTHONPATH or the current working directory.
automation_dir = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "mcp_server", str(automation_dir / "mcp_server.py")
)
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


def run_server_in_thread(host="127.0.0.1", port=55124):
    t = threading.Thread(target=server.run_server, args=(host, port), daemon=True)
    t.start()
    time.sleep(0.5)
    return t


def test_agent_executes_artifact_writer(tmp_path, monkeypatch):
    # run server on a test port and use tmp dir as CODE_DIR so artifact path is predictable
    monkeypatch.setattr(server, "CODE_DIR", str(tmp_path))

    # ensure tasks dir exists inside server package
    tasks_dir = os.path.join(os.path.dirname(server.__file__), "tasks")
    os.makedirs(tasks_dir, exist_ok=True)

    # create a small script that writes an artifact file when invoked
    script_path = tmp_path / "write_artifact.sh"
    script_content = """#!/usr/bin/env bash
mkdir -p "$PWD/artifacts"
echo 'artifact-data' > "$PWD/artifacts/test-artifact.txt"
exit 0
"""
    script_path.write_text(script_content)
    script_path.chmod(0o755)

    # monkeypatch allowed command to point to our test script
    monkeypatch.setitem(server.ALLOWED_COMMANDS, "write-artifact", [str(script_path)])

    host = "127.0.0.1"
    port = 55124
    run_server_in_thread(host, port)

    url = f"http://{host}:{port}"

    # register an agent
    r = requests.post(
        f"{url}/register", json={"agent": "e2e-agent", "capabilities": []}, timeout=5
    )
    assert r.status_code == 200

    # enqueue and execute the task
    r = requests.post(
        f"{url}/run",
        json={"agent": "e2e-agent", "command": "write-artifact", "execute": True},
        timeout=5,
    )
    assert r.status_code == 200
    data = r.json()
    task_id = data.get("task_id")
    assert task_id

    # poll the /status until the task finishes
    tobj = None
    for _ in range(50):
        s = requests.get(f"{url}/status", timeout=5).json()
        tlist = s.get("tasks", [])
        tobj = next((x for x in tlist if x.get("id") == task_id), None)
        if tobj and tobj.get("status") in ("success", "failed", "error"):
            break
        time.sleep(0.1)

    assert tobj is not None
    assert tobj.get("status") == "success"

    # verify artifact file exists in the tmp_path/artifacts
    artifact_file = tmp_path / "artifacts" / "test-artifact.txt"
    assert artifact_file.exists()
    content = artifact_file.read_text()
    assert "artifact-data" in content
