#!/usr/bin/env python3
"""Atomic helpers for updating agent coordination JSON files."""
from __future__ import annotations

import argparse
import json
import os
import sys
import logging
logger = logging.getLogger(__name__)
import time
from typing import Any, Callable, Dict

try:
    import fcntl  # type: ignore
except ImportError:  # pragma: no cover - fcntl should exist on macOS/Linux
    fcntl = None  # type: ignore

JsonObject = Dict[str, Any]
DefaultFactory = Callable[[], JsonObject]
Mutator = Callable[[JsonObject], JsonObject | None]


def _default_status() -> JsonObject:
    return {"agents": {}, "last_update": 0}


def _default_queue() -> JsonObject:
    return {"tasks": []}


def _parse_value(raw: str) -> Any:
    value = raw.strip()
    lowered = value.lower()
    if lowered == "null":
        return None
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    try:
        if value.startswith("0") and value not in {"0", "0.0"} and not value.startswith("0."):
            raise ValueError
        return int(value)
    except ValueError:
        try:
            return float(value)
        except ValueError:
            return value


def _parse_assignment(item: str) -> tuple[str, Any]:
    if "=" not in item:
        raise ValueError(f"Expected key=value assignment, got: {item!r}")
    key, value = item.split("=", 1)
    key = key.strip()
    if not key:
        raise ValueError("Assignment key cannot be empty")
    return key, _parse_value(value)


def _ensure_parent(path: str) -> None:
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)


def _load_existing(handle) -> JsonObject:
    handle.seek(0)
    contents = handle.read()
    if contents.strip():
        try:
            return json.loads(contents)
        except json.JSONDecodeError:
            pass
    return {}


def _write_json(handle, payload: JsonObject) -> None:
    handle.seek(0)
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.truncate()
    handle.flush()
    os.fsync(handle.fileno())


def _update_file(path: str, default_factory: DefaultFactory, mutator: Mutator) -> None:
    _ensure_parent(path)
    flags = os.O_RDWR | os.O_CREAT
    fd = os.open(path, flags, 0o644)
    handle = os.fdopen(fd, "r+", buffering=1)
    try:
        if fcntl is not None:
            fcntl.flock(handle, fcntl.LOCK_EX)
        data = _load_existing(handle)
        if not isinstance(data, dict):
            data = default_factory()
        if not data:
            data = default_factory()
        updated = mutator(data)
        if updated is not None:
            data = updated
        _write_json(handle, data)
    finally:
        try:
            handle.flush()
            os.fsync(handle.fileno())
        except Exception as e:
            logger.debug("Failed to flush fsync: %s", e, exc_info=True)
        if fcntl is not None:
            try:
                fcntl.flock(handle, fcntl.LOCK_UN)
            except Exception as e:
                logger.debug("Failed to unlock file: %s", e, exc_info=True)
        handle.close()


def _update_agent(args: argparse.Namespace) -> None:
    last_seen = args.last_seen if args.last_seen is not None else int(time.time())
    pid = args.pid

    def mutator(data: JsonObject) -> JsonObject:
        agents = data.setdefault("agents", {})
        entry = agents.setdefault(args.agent, {})
        if args.status is not None:
            entry["status"] = args.status
        entry["last_seen"] = last_seen
        if args.clear_pid:
            entry.pop("pid", None)
        elif pid is not None:
            entry["pid"] = pid
        for assignment in args.set_field:
            key, value = _parse_assignment(assignment)
            entry[key] = value
        for field in args.increment_field:
            entry[field] = int(entry.get(field, 0) or 0) + 1
        data["last_update"] = int(time.time())
        return data

    _update_file(args.status_file, _default_status, mutator)


def _update_task(args: argparse.Namespace) -> None:
    updated_flag = int(time.time())

    def mutator(data: JsonObject) -> JsonObject:
        tasks = data.setdefault("tasks", [])
        found = False
        for task in tasks:
            if str(task.get("id")) == args.task_id:
                if args.status is not None:
                    task["status"] = args.status
                for assignment in args.set_field:
                    key, value = _parse_assignment(assignment)
                    task[key] = value
                task["updated"] = updated_flag
                found = True
                break
        if not found and args.create_if_missing:
            new_task: JsonObject = {"id": args.task_id, "status": args.status or "queued", "updated": updated_flag}
            for assignment in args.set_field:
                key, value = _parse_assignment(assignment)
                new_task[key] = value
            tasks.append(new_task)
        return data

    _update_file(args.queue_file, _default_queue, mutator)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Safe helpers for agent coordination files.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    update_agent = subparsers.add_parser("update-agent", help="Update an agent entry in agent_status.json")
    update_agent.add_argument("--status-file", required=True)
    update_agent.add_argument("--agent", required=True)
    update_agent.add_argument("--status")
    update_agent.add_argument("--last-seen", type=int)
    update_agent.add_argument("--pid", type=int)
    update_agent.add_argument("--clear-pid", action="store_true")
    update_agent.add_argument("--set-field", action="append", default=[])
    update_agent.add_argument("--increment-field", action="append", default=[])
    update_agent.set_defaults(func=_update_agent)

    update_task = subparsers.add_parser("update-task", help="Update a task entry in task_queue.json")
    update_task.add_argument("--queue-file", required=True)
    update_task.add_argument("--task-id", required=True)
    update_task.add_argument("--status")
    update_task.add_argument("--set-field", action="append", default=[])
    update_task.add_argument("--create-if-missing", action="store_true")
    update_task.set_defaults(func=_update_task)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        args.func(args)
    except Exception as exc:  # pragma: no cover - defensive logging
        print(f"status_utils: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
