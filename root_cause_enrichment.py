#!/usr/bin/env python3
"""Suggest root causes for pending todos lacking a root_cause field.
Heuristic mapping from error_pattern or title keywords.
"""
import json
import os
import datetime

ROOT = os.path.dirname(os.path.abspath(__file__))
TODOS_FILE = os.path.join(ROOT, "unified_todos.json")

if not os.path.exists(TODOS_FILE):
    print("No unified_todos.json found")
    exit(0)

data = json.load(open(TODOS_FILE))
changed = 0

pattern_map = {
    "ModuleNotFoundError": "missing_dependency",
    "ImportError": "missing_dependency",
    "OSError: [Errno 98] Address already in use": "port_conflict",
    "bc: command not found": "missing_system_package",
    "command not found": "missing_system_package",
    "Connection refused": "service_down_or_firewall",
    "TimeoutError": "network_latency_or_service_hang",
    "Permission denied": "insufficient_permissions",
    "SyntaxError": "code_defect",
    "Cannot connect to the Docker daemon": "docker_daemon_inactive",
}

for t in data.get("todos", []):
    if t.get("status") != "completed":
        rc = t.get("root_cause")
        if not rc or rc in (None, "undetermined", ""):
            ep = (t.get("metadata") or {}).get("error_pattern", "")
            suggestion = None
            # direct pattern match
            if ep in pattern_map:
                suggestion = pattern_map[ep]
            else:
                # substring matches
                for key, val in pattern_map.items():
                    if key.lower() in ep.lower():
                        suggestion = val
                        break
            if not suggestion:
                title = t.get("title", "").lower()
                if "redis" in title:
                    suggestion = "missing_dependency"
                elif "flask" in title:
                    suggestion = "missing_dependency"
                elif "port" in title:
                    suggestion = "port_conflict"
                elif "timeout" in title:
                    suggestion = "network_latency_or_service_hang"
            if suggestion:
                t["root_cause"] = suggestion
                t["updated_at"] = datetime.datetime.utcnow().isoformat() + "Z"
                changed += 1

if changed:
    with open(TODOS_FILE, "w") as f:
        json.dump(data, f, indent=2)
print(f"Root cause enrichment complete. Updated {changed} todos.")
