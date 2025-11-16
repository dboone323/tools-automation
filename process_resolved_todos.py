#!/usr/bin/env python3
"""Process resolved todos to update predictive learning correlations.
Usage: python process_resolved_todos.py
"""
import json
import os
import collections

ROOT = os.path.dirname(os.path.abspath(__file__))
TODOS_FILE = os.path.join(ROOT, "unified_todos.json")
PRED_FILE = os.path.join(ROOT, "predictive_data.json")

if not os.path.exists(TODOS_FILE) or not os.path.exists(PRED_FILE):
    print("Required files missing.")
    exit(0)

todos = json.load(open(TODOS_FILE)).get("todos", [])
predictive = json.load(open(PRED_FILE))
learning = predictive.setdefault(
    "learning_data",
    {"successful_fixes": [], "failed_fixes": [], "pattern_correlations": {}},
)

for t in todos:
    if t.get("status") == "completed" and t.get("completed_at"):
        entry = {
            "id": t.get("id"),
            "category": t.get("category"),
            "root_cause": t.get("root_cause"),
            "time_to_resolution_seconds": t.get("time_to_resolution_seconds"),
            "outcome": t.get("resolution_outcome"),
            "timestamp": t.get("completed_at"),
        }
        if t.get("resolution_outcome") == "success":
            learning["successful_fixes"].append(entry)
        elif t.get("resolution_outcome") == "failed":
            learning["failed_fixes"].append(entry)
        # correlate error pattern with root cause
        pattern = (t.get("metadata") or {}).get("error_pattern")
        if pattern and t.get("root_cause"):
            pc = learning["pattern_correlations"].setdefault(
                pattern, collections.Counter()
            )
            pc[t["root_cause"]] += 1

# Convert counters to plain dicts
for pat, counter in list(learning.get("pattern_correlations", {}).items()):
    if isinstance(counter, collections.Counter):
        learning["pattern_correlations"][pat] = dict(counter)

predictive["learning_data"] = learning
with open(PRED_FILE, "w") as f:
    json.dump(predictive, f, indent=2)
print("Learning data updated from resolved todos.")
