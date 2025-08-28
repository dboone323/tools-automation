import json
import os
import threading
import time

import mcp_server as server
import pytest
import requests


def run_server_in_thread(host="127.0.0.1", port=55123):
    t = threading.Thread(target=server.run_server, args=(host, port), daemon=True)
    t.start()
    # give server time to bind
    time.sleep(0.5)
    return t


def test_server_executes_allowed_command(tmp_path, monkeypatch):
    # use a temp tasks dir
    monkeypatch.setattr(server, "CODE_DIR", str(tmp_path))
    # monkeypatch allowed commands to a harmless echo command
    monkeypatch.setitem(server.ALLOWED_COMMANDS, "test-echo", ["echo", "ok"])

    # start server on a non-standard port
    host = "127.0.0.1"
    port = 55123
    t = run_server_in_thread(host, port)

    url = f"http://{host}:{port}"

    # register agent
    r = requests.post(
        f"{url}/register", json={"agent": "int-test", "capabilities": []}, timeout=5
    )
    assert r.status_code == 200

    # request run
    r = requests.post(
        f"{url}/run",
        json={"agent": "int-test", "command": "test-echo", "execute": True},
        timeout=5,
    )
    assert r.status_code == 200
    data = r.json()
    task_id = data.get("task_id")
    assert task_id

    # poll status until done
    for _ in range(30):
        s = requests.get(f"{url}/status", timeout=5).json()
        tlist = s.get("tasks", [])
        tobj = next((x for x in tlist if x.get("id") == task_id), None)
        if tobj and tobj.get("status") in ("success", "failed", "error"):
            break
        time.sleep(0.2)

    assert tobj is not None
    assert tobj.get("status") == "success"
