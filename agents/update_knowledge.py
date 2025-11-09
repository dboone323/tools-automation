#!/usr/bin/env python3
"""
Safe JSON knowledge base updater (avoids shell quoting issues).

Updates Tools/Automation/agents/knowledge/error_patterns.json with discovered
patterns and basic metadata. Can be extended to update other knowledge files.
"""
from __future__ import annotations
import argparse
import json
import os
import sys
from datetime import datetime, timezone


def load_json(path: str, default):
    if not os.path.exists(path):
        return default
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default


def save_json(path: str, obj) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def update_error_patterns(
    base_dir: str, pattern_obj: dict, source_file: str | None = None
) -> None:
    path = os.path.join(
        base_dir, "Tools", "Automation", "agents", "knowledge", "error_patterns.json"
    )
    db = load_json(path, {})
    key = pattern_obj.get("hash") or pattern_obj.get("pattern")
    if not key:
        return
    now = datetime.now(timezone.utc).isoformat() + "Z"
    entry = db.get(key) or {
        "pattern": pattern_obj.get("pattern", ""),
        "category": pattern_obj.get("category", "general"),
        "severity": pattern_obj.get("severity", "medium"),
        "count": 0,
        "examples": [],
        "files": [],
        "first_seen": now,
        "last_seen": now,
    }
    entry["count"] = int(entry.get("count", 0)) + 1
    entry["last_seen"] = now
    ex = pattern_obj.get("example") or pattern_obj.get("pattern")
    if ex and ex not in entry["examples"]:
        entry["examples"].append(ex)
    if source_file and source_file not in entry["files"]:
        entry["files"].append(source_file)
    # Update category/severity if new is higher priority
    entry["category"] = (
        pattern_obj.get("category", entry["category"]) or entry["category"]
    )
    entry["severity"] = (
        pattern_obj.get("severity", entry["severity"]) or entry["severity"]
    )
    db[key] = entry
    save_json(path, db)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--workspace", required=True, help="Path to workspace root (Quantum-workspace)"
    )
    ap.add_argument(
        "--pattern-json", required=True, help="JSON object for a single pattern"
    )
    ap.add_argument("--source", help="Optional source file/log path", default=None)
    args = ap.parse_args()

    try:
        pattern_obj = json.loads(args.pattern_json)
    except json.JSONDecodeError as e:
        print(f"Invalid JSON for --pattern-json: {e}", file=sys.stderr)
        return 2

    update_error_patterns(args.workspace, pattern_obj, args.source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
