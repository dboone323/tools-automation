#!/usr/bin/env python3
"""Automatically complete stale todos whose error patterns disappeared.
Criteria: error_pattern has not appeared in last N log analysis runs (tracked via predictive_data.json error_patterns frequency going to 0).
Simplified heuristic: if occurrences <=1 and created_at older than threshold, auto-complete.
"""
import json, os, datetime

ROOT = os.path.dirname(os.path.abspath(__file__))
TODOS_FILE = os.path.join(ROOT, "unified_todos.json")
PRED_FILE = os.path.join(ROOT, "predictive_data.json")
THRESHOLD_HOURS = 12

if not os.path.exists(TODOS_FILE):
    print("No todos file; skipping.")
    exit(0)

todos_data = json.load(open(TODOS_FILE))
now = datetime.datetime.utcnow()
completed = 0

for t in todos_data.get("todos", []):
    if t.get("status") == "pending":
        created_at = t.get("created_at")
        ep = (t.get("metadata") or {}).get("error_pattern")
        occ = (t.get("metadata") or {}).get("occurrences")
        do_complete = False
        if created_at:
            try:
                dt = datetime.datetime.fromisoformat(created_at.replace("Z", ""))
                age_hours = (now - dt).total_seconds() / 3600.0
                if age_hours > THRESHOLD_HOURS and (occ is not None and occ <= 1):
                    do_complete = True
            except Exception:
                pass
        if do_complete:
            t["status"] = "completed"
            t["completed_at"] = now.isoformat() + "Z"
            t["resolution_outcome"] = "auto_completed"
            t["resolution_notes"] = (
                "Auto-completed due to staleness and low recurrence."
            )
            t["root_cause"] = t.get("root_cause") or "resolved_transient"
            t["updated_at"] = now.isoformat() + "Z"
            completed += 1

if completed:
    with open(TODOS_FILE, "w") as f:
        json.dump(todos_data, f, indent=2)
print(f"Auto-completed {completed} stale todos.")
