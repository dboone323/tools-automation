import os

# ensure Automation directory (Tools/Automation) is on sys.path
import sys
import threading

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
import mcp_controller as controller
import requests


class FakeResponse:
    def __init__(self, data):
        self._data = data
        self.status_code = 200

    def json(self):
        return self._data


def test_execute_task_locking(monkeypatch, tmp_path):
    # Prepare a fake task queue with a single queued task
    task = {
        "id": "task_1",
        "agent": "tester",
        "command": "analyze",
        "project": "ProjA",
        "status": "queued",
    }

    # Monkeypatch poll and execute endpoints
    def fake_poll():
        return [task]

    def fake_post_execute(url, json=None, timeout=5):
        # simulate successful execute_task call
        return FakeResponse({"ok": True, "executing": True, "task_id": task["id"]})

    def fake_status():
        # return success so execute_task exits its poll loop
        t2 = dict(task)
        t2["status"] = "success"
        t2["stdout"] = ""
        t2["stderr"] = ""
        return FakeResponse({"tasks": [t2]})

    monkeypatch.setattr(controller, "poll_tasks", lambda: [task])
    monkeypatch.setattr(requests, "post", lambda *a, **k: fake_post_execute(*a, **k))
    monkeypatch.setattr(requests, "get", lambda *a, **k: fake_status())

    # Ensure ARTIFACT_DIR is a temp dir to avoid writes to home
    controller.ARTIFACT_DIR = str(tmp_path)

    # Start two threads attempting to execute the same task simultaneously
    results = []

    def runner():
        ok = controller.execute_task(task)
        results.append(ok)

    t1 = threading.Thread(target=runner)
    t2 = threading.Thread(target=runner)
    t1.start()
    t2.start()
    t1.join()
    t2.join()

    # Exactly one should have executed (True); the other should have been rejected/returned False
    assert sum(1 for r in results if r) == 1
