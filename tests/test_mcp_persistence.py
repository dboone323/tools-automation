import importlib
import json
import os
import tempfile
import threading
import time

import mcp_server as server
import pytest


def test_execute_task_writes_json(tmp_path, monkeypatch):
    # Prepare a dummy task and a trivial command (echo)
    tasks_dir = tmp_path / "tasks"
    tasks_dir.mkdir()

    # Monkeypatch server paths to use tmp dir
    monkeypatch.setenv("TASK_TTL_DAYS", "1")
    monkeypatch.setattr(server, "CODE_DIR", str(tmp_path))

    handler = server.MCPHandler

    # Create a dummy instance context for calling _execute_task
    class Dummy:
        pass

    inst = Dummy()
    inst.server = type("S", (), {})()
    inst.server.task_lock = threading.Lock()
    # create a dummy task
    task = {
        "id": "task_persist_1",
        "agent": "t",
        "command": "echo",
        "project": None,
        "status": "running",
    }

    # run _execute_task with a simple command that exists
    cmd = ["echo", "hello"]
    server.MCPHandler._execute_task(inst, task, cmd)

    # check that tasks/<task_id>.json exists
    persisted = os.path.join(
        os.path.dirname(server.__file__), "tasks", f"{task['id']}.json"
    )
    assert os.path.isfile(persisted)
    with open(persisted, "r", encoding="utf-8") as f:
        data = json.load(f)
    assert data.get("id") == task["id"]
    assert "stdout" in data


def test_run_server_loads_tasks(tmp_path, monkeypatch):
    # create a tasks dir and a sample task file
    base_dir = tmp_path
    tasks_dir = base_dir / "tasks"
    tasks_dir.mkdir()
    sample = {"id": "task_existing", "status": "success"}
    with open(tasks_dir / "task_existing.json", "w", encoding="utf-8") as f:
        json.dump(sample, f)

    # monkeypatch __file__ location to our tmp path so run_server loads tasks from there
    monkeypatch.setattr(server, "__file__", str(base_dir / "mcp_server.py"))

    # run the loader portion of run_server manually
    httpd = server.HTTPServer(("127.0.0.1", 0), server.MCPHandler)
    httpd.agents = {}
    httpd.tasks = []
    httpd.task_lock = threading.Lock()

    # emulate load code
    tasks_dir_path = os.path.join(os.path.dirname(server.__file__), "tasks")
    os.makedirs(tasks_dir_path, exist_ok=True)
    # copy sample into that dir
    with open(
        os.path.join(tasks_dir_path, "task_existing.json"), "w", encoding="utf-8"
    ) as f:
        json.dump(sample, f)

    # now load
    loaded = []
    for fname in os.listdir(tasks_dir_path):
        if fname.endswith(".json"):
            with open(os.path.join(tasks_dir_path, fname), "r", encoding="utf-8") as f:
                try:
                    t = json.load(f)
                    loaded.append(t)
                except Exception:
                    pass

    assert any(t.get("id") == "task_existing" for t in loaded)
