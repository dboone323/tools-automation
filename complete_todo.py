#!/usr/bin/env python3
"""Mark a todo as completed and update lifecycle metrics.
Usage:
  python complete_todo.py --id <TODO_ID> [--notes "resolution notes"] [--outcome success|partial|failed] [--root-cause "root cause"]
"""
import argparse, json, os, sys, datetime

ROOT = os.path.dirname(os.path.abspath(__file__))
TODOS_FILE = os.path.join(ROOT, "unified_todos.json")


def load_todos():
    if not os.path.exists(TODOS_FILE):
        return {"todos": []}
    with open(TODOS_FILE, "r") as f:
        return json.load(f)


def save_todos(data):
    with open(TODOS_FILE, "w") as f:
        json.dump(data, f, indent=2)


def ensure_fields(todo):
    defaults = {
        "completed_at": None,
        "resolution_notes": None,
        "resolution_outcome": None,
        "attempts": 0,
        "time_to_resolution_seconds": None,
        "root_cause": None,
    }
    for k, v in defaults.items():
        if k not in todo:
            todo[k] = v


parser = argparse.ArgumentParser()
parser.add_argument("--id", required=True, help="Todo ID to complete")
parser.add_argument("--notes", default="", help="Resolution notes")
parser.add_argument(
    "--outcome", choices=["success", "partial", "failed"], default="success"
)
parser.add_argument("--root-cause", default="undetermined", help="Root cause summary")
args = parser.parse_args()

store = load_todos()
found = False
now_iso = datetime.datetime.utcnow().isoformat() + "Z"
for t in store.get("todos", []):
    if t.get("id") == args.id:
        ensure_fields(t)
        t["attempts"] = (t.get("attempts") or 0) + 1
        if t["status"] != "completed":
            t["status"] = "completed"
            t["completed_at"] = now_iso
            created_at = t.get("created_at")
            dur = None
            if created_at:
                try:
                    start = datetime.datetime.fromisoformat(created_at.replace("Z", ""))
                    end = datetime.datetime.fromisoformat(now_iso.replace("Z", ""))
                    dur = (end - start).total_seconds()
                except Exception:
                    pass
            t["time_to_resolution_seconds"] = dur
        t["resolution_notes"] = args.notes or t.get("resolution_notes")
        t["resolution_outcome"] = args.outcome
        t["root_cause"] = args.root_cause
        t["updated_at"] = now_iso
        found = True
        break

if not found:
    print(f"ERROR: todo id {args.id} not found", file=sys.stderr)
    sys.exit(1)

save_todos(store)
print(f"Marked {args.id} completed (outcome={args.outcome}).")
