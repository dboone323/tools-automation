#!/usr/bin/env python3
"""
Normalize task_queue.json to agent-compatible schema:
- Ensure tasks have assigned_agent (copy from assigned_to if needed)
- Convert status 'assigned' -> 'queued' for pick-up
- Deduplicate tasks by id, keeping the most recent by assigned_at/queued_at
- Ensure completed array exists
"""
from __future__ import annotations
import json
import os
import time
from typing import Any, Dict
from agents.utils import user_log

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
AGENTS_DIR = os.path.join(ROOT, "Tools", "Automation", "agents")
TASK_QUEUE_PATH = os.path.join(AGENTS_DIR, "task_queue.json")


def load_json(path: str, default: Any) -> Any:
    try:
        if not os.path.exists(path):
            return default
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default


def write_json(path: str, data: Any) -> None:
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)


def normalize() -> Dict[str, Any]:
    data = load_json(TASK_QUEUE_PATH, {"tasks": [], "completed": []})
    if isinstance(data, list):
        data = {"tasks": data, "completed": []}
    tasks = data.get("tasks") or []
    completed = data.get("completed") or []

    # Deduplicate and normalize
    by_id: Dict[str, Dict[str, Any]] = {}
    now = int(time.time())
    for t in tasks:
        if not isinstance(t, dict):
            continue
        tid = t.get("id")
        if not tid:
            # generate id if missing
            tid = f"task_{now}"
            t["id"] = tid
        # Normalize fields
        assigned = t.get("assigned_agent") or t.get("assigned_to")
        if assigned:
            t["assigned_agent"] = assigned
            t["assigned_to"] = assigned
        status = t.get("status")
        if status == "assigned":
            t["status"] = "queued"
        # Choose the newest by timestamp
        stamp = t.get("assigned_at") or t.get("queued_at") or 0
        prev = by_id.get(tid)
        if not prev or (
            stamp and stamp >= (prev.get("assigned_at") or prev.get("queued_at") or 0)
        ):
            by_id[tid] = t

    normalized = {
        "tasks": list(by_id.values()),
        "completed": completed,
        "last_updated": int(time.time()),
    }
    write_json(TASK_QUEUE_PATH, normalized)
    return {"before": len(tasks), "after": len(normalized["tasks"])}


if __name__ == "__main__":
    result = normalize()
    user_log(json.dumps({"normalized": result}))
