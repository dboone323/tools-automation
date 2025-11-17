#!/usr/bin/env python3
"""
Agent Orchestrator v2 (Phase 4)

Coordinates tasks across agents based on availability and historical performance.

Files used (best-effort):
- Tools/Automation/agents/agent_status.json
- Tools/Automation/agents/task_queue.json
- Tools/Automation/agents/knowledge/strategies.json

Behavior:
- assign: assign a task to the best available agent, else queue
- balance: attempt to rebalance tasks if some agents are overloaded
- status: print orchestrator and agent snapshot

CLI:
  orchestrator_v2.py assign --task '{"id":"t1","type":"analysis","priority":2}'
  orchestrator_v2.py balance
  orchestrator_v2.py status
"""
from __future__ import annotations

import argparse
import json
import os
import time
import logging
import uuid
from typing import Any, Dict, List
from agents.utils import user_log, safe_start

logger = logging.getLogger(__name__)


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
AGENTS_DIR = os.path.join(ROOT, "Tools", "Automation", "agents")
KNOWLEDGE_DIR = os.path.join(AGENTS_DIR, "knowledge")
AGENT_STATUS_PATH = os.path.join(AGENTS_DIR, "agent_status.json")
TASK_QUEUE_PATH = os.path.join(AGENTS_DIR, "task_queue.json")
DLQ_PATH = os.path.join(AGENTS_DIR, "dead_letter_queue.json")
STRATEGIES_PATH = os.path.join(KNOWLEDGE_DIR, "strategies.json")


def _load_json(path: str, default: Any) -> Any:
    try:
        if not os.path.exists(path):
            return default
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        logger.debug("_load_json failed for %s: %s", path, e, exc_info=True)
        return default


def _aliases_for(name: str) -> set:
    """Return a set of normalized alias variants for agent names and script filenames.

    This helps match override names to agent IDs or filenames.
    """
    if not name:
        return set()
    n = str(name).strip().lower()
    variants = {n}
    if n.endswith(".sh"):
        variants.add(n[:-3])
    # strip common agent prefixes/suffixes
    variants.add(n.replace('_', '-'))
    variants.add(n.replace('-', '_'))
    # Add a trimmed alphanumeric-only version
    import re

    alnum = re.sub(r"[^a-z0-9]", "", n)
    if alnum:
        variants.add(alnum)
    return variants


def _write_json(path: str, data: Any) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)


def _agent_score(agent: Dict[str, Any], strategies: List[Dict[str, Any]]) -> float:
    # Simple score: higher success_rate strategy boosts agent if names match
    base = 1.0
    if not isinstance(agent, dict):
        return base
    name = agent.get("name") or agent.get("id") or ""
    for s in strategies or []:
        if isinstance(s, dict):
            if s.get("name") == name or s.get("agent") == name:
                sr = s.get("success_rate")
                if isinstance(sr, (int, float)):
                    base += float(sr)
    # Availability bonus
    if agent.get("status") in ("idle", "ready"):
        base += 0.5
    # Load penalty
    try:
        q = int(agent.get("queue_size", 0))
        base -= 0.05 * q
    except Exception as e:
        logger.debug("_agent_score: error computing queue size for agent %s: %s", agent, e, exc_info=True)
    return base


def _pick_agent(
    agents: List[Dict[str, Any]], strategies: List[Dict[str, Any]]
) -> Dict[str, Any] | None:
    candidates = [a for a in agents if a.get("status") in ("idle", "ready")]
    if not candidates:
        candidates = agents
    if not candidates:
        return None
    scored = sorted(candidates, key=lambda a: _agent_score(a, strategies), reverse=True)
    return scored[0]


def _start_agent_if_needed(agent_id: str) -> bool:
    """Start an agent if it's not already running."""
    import logging
    logger = logging.getLogger(__name__)
    import os

    try:
        # Check if agent is already running by looking for PID file
        agent_base = agent_id
        if agent_base.endswith(".sh"):
            agent_base = agent_base[:-3]

        pid_file = os.path.join(AGENTS_DIR, f"{agent_base}.pid")
        if os.path.exists(pid_file):
            try:
                with open(pid_file, "r") as f:
                    pid = int(f.read().strip())
                # Check if process is still running
                os.kill(pid, 0)
                return True  # Already running
            except (OSError, ValueError):
                # Process not running, remove stale PID file
                os.remove(pid_file)

        # Start the agent
        agent_script = os.path.join(AGENTS_DIR, agent_id)
        if not os.path.exists(agent_script):
            return False

        # Start in background
        log_file = os.path.join(AGENTS_DIR, f"{agent_base}.log")
        with open(log_file, "a") as log:
            proc = safe_start([agent_script], stdout=log, stderr=log, cwd=ROOT)

        # Write PID file
        with open(pid_file, "w") as f:
            f.write(str(proc.pid))

        return True
    except Exception:
        logger.debug("_start_agent_if_needed: failed to start %s", agent_id, exc_info=True)
        return False


def assign_task(task: Dict[str, Any]) -> Dict[str, Any]:
    agents_data = _load_json(AGENT_STATUS_PATH, [])

    # Support both list and dict schemas for agent_status.json
    if isinstance(agents_data, dict):
        # Convert dict format to list of agents
        agents = []
        for agent_name, agent_info in agents_data.get("agents", {}).items():
            if isinstance(agent_info, dict):
                agent = agent_info.copy()
                if "id" not in agent:
                    agent["id"] = agent_name
                if "name" not in agent:
                    agent["name"] = agent_name
                agents.append(agent)
    elif isinstance(agents_data, list):
        agents = agents_data
    else:
        agents = []

    if not agents:
        agents = [
            {
                "id": "default-agent",
                "name": "default-agent",
                "status": "idle",
                "queue_size": 0,
            }
        ]
    strategies = _load_json(STRATEGIES_PATH, []) or []

    # Ensure task has correlation id and retry metadata
    if not isinstance(task, dict):
        task = {"id": str(uuid.uuid4()), "meta": {}}
    if "correlation_id" not in task:
        task["correlation_id"] = str(uuid.uuid4())
    if "retries" not in task:
        task["retries"] = int(task.get("retries", 0))
    if "max_retries" not in task:
        task["max_retries"] = int(task.get("max_retries", 3))

    # Support both list and object schemas for task_queue.json
    queue_data = _load_json(TASK_QUEUE_PATH, [])
    if isinstance(queue_data, dict):
        queue_list = queue_data.get("tasks") or []
    elif isinstance(queue_data, list):
        queue_list = queue_data
    else:
        queue_list = []

    # Respect explicit assignment if provided
    override = task.get("assigned_agent") or task.get("assigned_to")
    chosen_agent = None
    if override:
        ov_aliases = _aliases_for(str(override))
        for a in agents:
            cand = (a.get("id") or a.get("name") or "").lower()
            if cand in ov_aliases:
                chosen_agent = a
                break

    if not chosen_agent:
        # Simple routing by task type to prefer a matching agent
        task_type = (task.get("type") or "").lower()
        preferred_keywords: List[str] = []
        if "debug" in task_type:
            preferred_keywords = ["debug"]
        elif any(k in task_type for k in ("build", "test", "verify", "verification")):
            preferred_keywords = ["build"]
        elif any(k in task_type for k in ("codegen", "generate", "scaffold")):
            preferred_keywords = ["codegen"]

        candidate_agents = agents
        if preferred_keywords:
            filtered = [
                a
                for a in agents
                if any(
                    k in (a.get("id", "") + ":" + a.get("name", "")).lower()
                    for k in preferred_keywords
                )
            ]
            if filtered:
                candidate_agents = filtered

        chosen_agent = _pick_agent(candidate_agents, strategies)

    agent = chosen_agent
    if agent:
        # Write compatible fields so agents can pick up tasks
        assigned_id = agent.get("id") or agent.get("name")
        now_ts = int(time.time())
        # Back-compat: set both fields; agents look for assigned_agent + queued
        task["assigned_agent"] = assigned_id
        task["assigned_to"] = assigned_id
        # Queue the task for pickup by the agent loop
        task["queued_at"] = now_ts
        task["status"] = "queued"
        # Keep assigned_at for analytics/back-compat
        task["assigned_at"] = now_ts
        queue_list.append(task)
        # update agent load best-effort
        try:
            for a in agents:
                if (a.get("id") == assigned_id) or (a.get("name") == assigned_id):
                    a["queue_size"] = int(a.get("queue_size", 0)) + 1
                    a["status"] = "busy"
                    break
        except Exception:
            pass

        # Start the agent if needed
        _start_agent_if_needed(assigned_id)

        # Persist back in original shape
        if isinstance(queue_data, dict):
            queue_data["tasks"] = queue_list
            queue_data["last_updated"] = int(time.time())
            _write_json(TASK_QUEUE_PATH, queue_data)
        else:
            _write_json(TASK_QUEUE_PATH, queue_list)
        _write_json(AGENT_STATUS_PATH, agents)
        return {"result": "assigned", "task": task}
    else:
        task["status"] = "queued"
        queue_list.append(task)
        if isinstance(queue_data, dict):
            queue_data["tasks"] = queue_list
            queue_data["last_updated"] = int(time.time())
            _write_json(TASK_QUEUE_PATH, queue_data)
        else:
            _write_json(TASK_QUEUE_PATH, queue_list)
        # persist a lightweight DLQ structure (ensure file exists)
        _write_json(DLQ_PATH, _load_json(DLQ_PATH, []))
        return {"result": "queued", "task": task}


def move_to_dlq(task: Dict[str, Any], reason: str = "moved_to_dlq") -> None:
    """Move a task to the dead-letter-queue with reason metadata."""
    try:
        dlq = _load_json(DLQ_PATH, []) or []
        entry = task.copy()
        entry["dlq_reason"] = reason
        entry["moved_at"] = int(time.time())
        dlq.append(entry)
        _write_json(DLQ_PATH, dlq)
    except Exception:
        # best-effort: if DLQ can't be persisted, write to a file per task
        try:
            fallback = os.path.join(AGENTS_DIR, "dlq_fallback")
            os.makedirs(fallback, exist_ok=True)
            fname = os.path.join(fallback, f"{entry.get('id', str(uuid.uuid4()))}.json")
            with open(fname, "w", encoding="utf-8") as f:
                json.dump(entry, f, indent=2)
        except Exception:
            pass


def retry_or_dlq(task: Dict[str, Any]) -> None:
    """Increment retries and move to DLQ when max_retries exceeded."""
    try:
        task["retries"] = int(task.get("retries", 0)) + 1
        if int(task.get("retries", 0)) > int(task.get("max_retries", 3)):
            move_to_dlq(task, reason="max_retries_exceeded")
        else:
            # persist updated retry count back to task queue
            queue_data = _load_json(TASK_QUEUE_PATH, [])
            if isinstance(queue_data, dict):
                q = queue_data.get("tasks") or []
                for i, t in enumerate(q):
                    if isinstance(t, dict) and t.get("id") == task.get("id"):
                        q[i] = task
                        break
                queue_data["tasks"] = q
                _write_json(TASK_QUEUE_PATH, queue_data)
            elif isinstance(queue_data, list):
                for i, t in enumerate(queue_data):
                    if isinstance(t, dict) and t.get("id") == task.get("id"):
                        queue_data[i] = task
                        break
                _write_json(TASK_QUEUE_PATH, queue_data)
    except Exception:
        try:
            move_to_dlq(task, reason="retry_error")
        except Exception:
            pass


def balance_load() -> Dict[str, Any]:
    # Naive balancing: just report distribution; advanced moves could be added
    queue_data = _load_json(TASK_QUEUE_PATH, [])
    if isinstance(queue_data, dict):
        queue = queue_data.get("tasks") or []
    elif isinstance(queue_data, list):
        queue = queue_data
    else:
        queue = []
    dist: Dict[str, int] = {}
    for t in queue:
        if isinstance(t, dict):
            # Prefer assigned_agent, fallback to assigned_to for legacy tasks
            owner = t.get("assigned_agent") or t.get("assigned_to") or "unassigned"
            dist[owner] = dist.get(owner, 0) + 1
    return {"queue_size": len(queue), "distribution": dist}


def snapshot() -> Dict[str, Any]:
    q = _load_json(TASK_QUEUE_PATH, [])
    if isinstance(q, dict):
        qv = q.get("tasks") or []
    else:
        qv = q
    return {
        "agents": _load_json(AGENT_STATUS_PATH, []),
        "queue": qv,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Agent Orchestrator v2")
    sub = parser.add_subparsers(dest="cmd")

    p_assign = sub.add_parser("assign", help="Assign a task to an agent or queue it")
    p_assign.add_argument(
        "--task", required=True, help='Task as JSON string, e.g. \'{"id":"t1"}\''
    )

    sub.add_parser("balance", help="Show current load distribution")
    sub.add_parser("status", help="Show orchestrator snapshot")

    args = parser.parse_args()
    if args.cmd == "assign":
        try:
            task = json.loads(args.task)
            if not isinstance(task, dict):
                raise ValueError("task must be a JSON object")
        except Exception as e:
            user_log(json.dumps({"error": f"invalid task: {e}"}))
            return 2
        result = assign_task(task)
        user_log(json.dumps(result))
        return 0
    elif args.cmd == "balance":
        user_log(json.dumps(balance_load()))
        return 0
    elif args.cmd == "status":
        user_log(json.dumps(snapshot()))
        return 0
    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
