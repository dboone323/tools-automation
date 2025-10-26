#!/usr/bin/env python3
"""Agent recovery and scaling utility.

Usage examples:
  python3 agent_recovery.py --summary
  python3 agent_recovery.py --apply --verbose
  python3 agent_recovery.py --apply --scale agent_build.sh=2 --scale agent_debug.sh=1
"""
from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

AGENTS_DIR = Path(__file__).resolve().parent
STATUS_PATH = AGENTS_DIR / "agent_status.json"
QUEUE_PATH = AGENTS_DIR / "task_queue.json"
METRICS_STATE_PATH = AGENTS_DIR / ".dashboard_metrics_state.json"
RUNTIME_DIR = AGENTS_DIR / ".runtime"
CLONES_PATH = RUNTIME_DIR / "agent_clones.json"
LOGS_DIR = AGENTS_DIR / "logs"

OK_STATUSES = {"available", "running", "idle", "healthy", "ready"}
STOP_STATUSES = {"stopped", "offline", "error", "failed", "crashed"}
PROGRESS_STATUSES = {"queued", "pending", "waiting"}
STALE_SECONDS = 300
BACKLOG_THRESHOLD = 1000
DEFAULT_EXTRA_WORKERS = {
    "agent_build.sh": 1,
    "agent_debug.sh": 1,
    "agent_codegen.sh": 1,
}
CRITICAL_AGENTS = [
    "agent_build.sh",
    "agent_debug.sh",
    "agent_codegen.sh",
    "task_orchestrator.sh",
]

CRITICAL_IDENTIFIERS = set(CRITICAL_AGENTS)
for item in list(CRITICAL_AGENTS):
    if item.endswith(".sh"):
        bare = item[:-3]
        CRITICAL_IDENTIFIERS.add(bare)
        if bare.startswith("agent_"):
            CRITICAL_IDENTIFIERS.add(bare[len("agent_") :])
    elif item.startswith("agent_"):
        CRITICAL_IDENTIFIERS.add(f"{item}.sh")
        CRITICAL_IDENTIFIERS.add(item[len("agent_") :])


def load_json(path: Path, default):
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        return default
    except json.JSONDecodeError as exc:
        print(f"Warning: failed to parse {path}: {exc}", file=sys.stderr)
        return default


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, sort_keys=True)


def is_process_running(pid: Optional[int]) -> bool:
    if pid in (None, 0):
        return False
    try:
        os.kill(pid, 0)
        return True
    except (ProcessLookupError, PermissionError):
        return False


def resolve_script(agent_key: str) -> Optional[Path]:
    candidates: List[str] = []
    raw = agent_key.strip()
    if raw.endswith(".sh"):
        candidates.append(raw)
    else:
        candidates.append(f"{raw}.sh")
        if raw.startswith("agent_"):
            suffix = raw[len("agent_") :]
            candidates.append(f"agent_{suffix}.sh")
            candidates.append(f"{raw}")
            candidates.append(f"{suffix}_agent.sh")
        elif raw.endswith("_agent"):
            prefix = raw[:-len("_agent")]
            candidates.append(f"agent_{prefix}.sh")
            candidates.append(f"{prefix}_agent.sh")
        else:
            candidates.append(f"agent_{raw}.sh")
    cleaned: List[str] = []
    for item in candidates:
        if item and item not in cleaned:
            cleaned.append(item)
    for candidate in cleaned:
        candidate_path = AGENTS_DIR / candidate
        if candidate_path.exists() and candidate_path.is_file():
            return candidate_path
    return None


def read_pidfile(agent_key: str) -> Optional[int]:
    script = resolve_script(agent_key)
    if script is None:
        return None
    pid_file = AGENTS_DIR / f"{script.name}.pid"
    if not pid_file.exists():
        return None
    try:
        content = pid_file.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    if not content:
        return None
    try:
        return int(content.splitlines()[0].strip())
    except (ValueError, IndexError):
        return None


def read_agent_status() -> Dict[str, Dict]:
    data = load_json(STATUS_PATH, {})
    agents = data.get("agents") if isinstance(data, dict) else {}
    return agents if isinstance(agents, dict) else {}


def update_agent_status(agent_keys: Iterable[str], status: str, pid: Optional[int] = None) -> None:
    data = load_json(STATUS_PATH, {})
    if not isinstance(data, dict):
        data = {}
    agents = data.setdefault("agents", {})
    now = int(time.time())
    for key in agent_keys:
        entry = agents.setdefault(key, {})
        entry["status"] = status
        entry["last_seen"] = now
        if pid is not None:
            entry["pid"] = pid
        entry["restart_count"] = int(entry.get("restart_count", 0)) + 1
    data["last_update"] = now
    save_json(STATUS_PATH, data)


def load_queue_summary() -> Tuple[int, Dict[str, int]]:
    data = load_json(QUEUE_PATH, {})
    tasks: List[Dict] = []
    if isinstance(data, list):
        tasks = [item for item in data if isinstance(item, dict)]
    elif isinstance(data, dict):
        raw_tasks = data.get("tasks", [])
        if isinstance(raw_tasks, list):
            tasks = [item for item in raw_tasks if isinstance(item, dict)]
    queued: List[Dict] = []
    for task in tasks:
        status = str(task.get("status", "queued")).lower()
        if status in PROGRESS_STATUSES or status == "queued":
            queued.append(task)
    distribution: Dict[str, int] = {}
    for task in queued:
        agent_name = task.get("assigned_agent") or task.get("type") or "unknown"
        distribution[agent_name] = distribution.get(agent_name, 0) + 1
    return len(queued), distribution


def load_drain_rate() -> Optional[float]:
    state = load_json(METRICS_STATE_PATH, {})
    if not isinstance(state, dict):
        return None
    rate = state.get("drain_rate_per_min")
    if isinstance(rate, (int, float)):
        return float(rate)
    # legacy state only tracks queued and timestamp; cannot compute here
    return None


def stop_process(pid: Optional[int], verbose: bool = False) -> None:
    if not is_process_running(pid):
        return
    try:
        os.kill(pid, signal.SIGTERM)
        if verbose:
            print(f"Sent SIGTERM to PID {pid}")
        timeout = time.time() + 5
        while time.time() < timeout:
            if not is_process_running(pid):
                return
            time.sleep(0.25)
        os.kill(pid, signal.SIGKILL)
        if verbose:
            print(f"Sent SIGKILL to PID {pid}")
    except PermissionError:
        print(f"Warning: insufficient permissions to stop PID {pid}", file=sys.stderr)
    except ProcessLookupError:
        return


def launch_agent(script: Path, log_prefix: str, dry_run: bool, verbose: bool) -> Optional[int]:
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    log_path = LOGS_DIR / f"{log_prefix}.out"
    err_path = LOGS_DIR / f"{log_prefix}.err"
    if dry_run:
        if verbose:
            print(f"Dry run: would launch {script} (logs: {log_path})")
        return None
    with log_path.open("a", encoding="utf-8") as stdout, err_path.open("a", encoding="utf-8") as stderr:
        process = subprocess.Popen(
            ["bash", str(script)],
            cwd=str(AGENTS_DIR),
            stdout=stdout,
            stderr=stderr,
            start_new_session=True,
        )
    if verbose:
        print(f"Launched {script.name} (pid {process.pid})")
    return process.pid


def related_keys(agent_key: str) -> List[str]:
    keys = [agent_key]
    if agent_key.endswith(".sh"):
        bare = agent_key[:-3]
        keys.append(bare)
        if bare.startswith("agent_"):
            keys.append(bare[len("agent_") :])
    else:
        keys.append(f"{agent_key}.sh")
        if agent_key.startswith("agent_"):
            keys.append(agent_key[len("agent_") :])
        elif agent_key.endswith("_agent"):
            keys.append(f"agent_{agent_key[:-len('_agent')]}")
    seen: List[str] = []
    for key in keys:
        if key and key not in seen:
            seen.append(key)
    return seen


def restart_agent(agent_key: str, script: Path, pid: Optional[int], dry_run: bool, verbose: bool) -> None:
    if verbose:
        print(f"Restarting {agent_key} using {script.name}")
    stop_process(pid, verbose=verbose)
    new_pid = launch_agent(script, agent_key.replace("/", "_"), dry_run, verbose)
    if new_pid is not None:
        update_agent_status(related_keys(agent_key), "restarting", new_pid)


def load_clones() -> Dict[str, List[Dict[str, int]]]:
    data = load_json(CLONES_PATH, {})
    return data if isinstance(data, dict) else {}


def save_clones(clones: Dict[str, List[Dict[str, int]]]) -> None:
    save_json(CLONES_PATH, clones)


def prune_dead_clones(clones: Dict[str, List[Dict[str, int]]], verbose: bool) -> None:
    for agent, records in list(clones.items()):
        alive: List[Dict[str, int]] = []
        for record in records:
            pid = record.get("pid")
            if is_process_running(pid):
                alive.append(record)
            elif verbose:
                print(f"Removed stale clone for {agent} (pid {pid})")
        if alive:
            clones[agent] = alive
        else:
            clones.pop(agent, None)


def ensure_extra_workers(clones: Dict[str, List[Dict[str, int]]], plan: Dict[str, int], dry_run: bool, verbose: bool) -> None:
    for agent, desired in plan.items():
        if desired <= 0:
            continue
        current = len(clones.get(agent, []))
        while current < desired:
            script = resolve_script(agent)
            if script is None:
                print(f"Warning: cannot scale {agent}; script not found", file=sys.stderr)
                break
            suffix = int(time.time())
            log_prefix = f"{agent.replace('.sh', '')}_extra_{current+1}"
            new_pid = launch_agent(script, log_prefix, dry_run, verbose)
            if new_pid is None:
                break
            record = {"pid": new_pid, "started": int(time.time())}
            clones.setdefault(agent, []).append(record)
            current += 1
            if verbose:
                print(f"Started extra worker {agent} (pid {new_pid})")
    if not dry_run:
        save_clones(clones)


def evaluate_agents(agents: Dict[str, Dict]) -> List[Dict]:
    now = int(time.time())
    summary: List[Dict] = []
    for name, info in agents.items():
        if not isinstance(info, dict):
            continue
        status = str(info.get("status", "")).lower()
        last_seen = info.get("last_seen")
        raw_pid = info.get("pid")
        pid: Optional[int] = None
        if isinstance(raw_pid, int):
            pid = raw_pid
        elif isinstance(raw_pid, str):
            cleaned = raw_pid.strip()
            if cleaned.isdigit():
                pid = int(cleaned)
        elif isinstance(raw_pid, float) and raw_pid.is_integer():
            pid = int(raw_pid)
        if pid is None:
            pid = read_pidfile(name)
        try:
            last_seen_int = int(last_seen) if last_seen is not None else None
        except (TypeError, ValueError):
            last_seen_int = None
        stale = False
        if last_seen_int is not None and now - last_seen_int > STALE_SECONDS:
            stale = True
        summary.append(
            {
                "name": name,
                "status": status,
                "pid": pid,
                "stale": stale,
                "last_seen": last_seen_int,
                "needs_restart": status in STOP_STATUSES or stale,
            }
        )
    return summary


def format_agent_label(name: str) -> str:
    if name.endswith(".sh"):
        name = name[:-3]
    if name.startswith("agent_"):
        name = name[len("agent_") :]
    return name.replace("_", " ")


def main() -> None:
    parser = argparse.ArgumentParser(description="Recover stalled automation agents")
    parser.add_argument("--apply", action="store_true", help="Restart agents and launch extra workers")
    parser.add_argument("--scale", action="append", default=[], help="Request extra workers (agent=count)")
    parser.add_argument("--threshold", type=int, default=BACKLOG_THRESHOLD, help="Queue size threshold for auto scaling")
    parser.add_argument("--verbose", action="store_true", help="Verbose output")
    parser.add_argument("--summary", action="store_true", help="Print summary and exit")
    args = parser.parse_args()

    agents = read_agent_status()
    agent_info = evaluate_agents(agents)

    queued_count, distribution = load_queue_summary()
    drain_rate = load_drain_rate()

    if args.verbose or args.summary or not args.apply:
        print(f"Queued tasks: {queued_count}")
        if distribution:
            top = sorted(distribution.items(), key=lambda item: item[1], reverse=True)[:10]
            print("Top task assignments:")
            for name, count in top:
                print(f"  {name}: {count}")
        print(f"Drain rate (per min): {drain_rate if drain_rate is not None else 'unknown'}")
        print("Agent statuses:")
        for info in agent_info:
            state = "stale" if info["stale"] else info["status"]
            label = format_agent_label(info["name"])
            print(f"  {label:25s} {state:10s} pid={info['pid']}")

    restart_targets = [
        item
        for item in agent_info
        if item["needs_restart"] and item["name"] in CRITICAL_IDENTIFIERS
    ]

    scale_plan: Dict[str, int] = {}
    for entry in args.scale:
        if "=" not in entry:
            print(f"Warning: ignoring invalid --scale entry '{entry}'", file=sys.stderr)
            continue
        agent, count = entry.split("=", 1)
        agent = agent.strip()
        try:
            count_int = int(count)
        except ValueError:
            print(f"Warning: invalid count '{count}' for agent {agent}", file=sys.stderr)
            continue
        scale_plan[agent] = count_int

    auto_scale_needed = queued_count >= args.threshold and (drain_rate is None or drain_rate <= 0)
    if auto_scale_needed:
        for agent, extra in DEFAULT_EXTRA_WORKERS.items():
            scale_plan.setdefault(agent, extra)

    if args.summary and not args.apply:
        return

    dry_run = not args.apply

    if restart_targets:
        for target in restart_targets:
            script = resolve_script(target["name"])
            if script is None:
                print(f"Warning: no script found for {target['name']}", file=sys.stderr)
                continue
            restart_agent(target["name"], script, target.get("pid"), dry_run, args.verbose)
    elif args.verbose:
        print("No critical agents require restart")

    if scale_plan:
        clones = load_clones()
        prune_dead_clones(clones, args.verbose)
        ensure_extra_workers(clones, scale_plan, dry_run, args.verbose)
    elif args.verbose:
        print("No scaling actions requested")

    if dry_run:
        print("Dry run complete. Re-run with --apply to restart agents.")


if __name__ == "__main__":
    main()
