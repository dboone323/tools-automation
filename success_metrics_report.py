#!/usr/bin/env python3
"""Generate success metrics report for task lifecycle.
Writes reports/success_metrics_<timestamp>.md
"""
import json
import os
import datetime
import statistics

ROOT = os.path.dirname(os.path.abspath(__file__))
TODOS_FILE = os.path.join(ROOT, "unified_todos.json")
REPORTS_DIR = os.path.join(ROOT, "reports")
os.makedirs(REPORTS_DIR, exist_ok=True)

if not os.path.exists(TODOS_FILE):
    print("No todos file found.")
    exit(0)

data = json.load(open(TODOS_FILE))
todos = data.get("todos", [])
completed = [t for t in todos if t.get("status") == "completed"]
pending = [t for t in todos if t.get("status") != "completed"]

# Compute MTTR overall & per category
cat_times = {}
for t in completed:
    dur = t.get("time_to_resolution_seconds")
    if dur is not None:
        cat = t.get("category", "uncategorized")
        cat_times.setdefault(cat, []).append(dur)

overall_mttr = (
    statistics.mean(
        [d for d in (t.get("time_to_resolution_seconds") for t in completed) if d]
    )
    if completed
    else 0
)
cat_mttr = {c: statistics.mean(vals) for c, vals in cat_times.items() if vals}

# Agent effectiveness: completed / assigned
agent_stats = {}
for t in todos:
    agent = t.get("assignee") or "unassigned"
    s = agent_stats.setdefault(agent, {"assigned": 0, "completed": 0})
    s["assigned"] += 1
    if t.get("status") == "completed":
        s["completed"] += 1

# Outcome distribution
outcomes = {}
for t in completed:
    oc = t.get("resolution_outcome", "unknown")
    outcomes[oc] = outcomes.get(oc, 0) + 1

now = datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%SZ")
path = os.path.join(
    REPORTS_DIR,
    f'success_metrics_{datetime.datetime.utcnow().strftime("%Y%m%d_%H%M%S")}.md',
)

with open(path, "w") as f:
    f.write(f"# Success Metrics Report\nGenerated: {now}\n\n")
    f.write("## Summary\n")
    f.write(f"- Total Todos: {len(todos)}\n")
    f.write(f"- Completed Todos: {len(completed)}\n")
    f.write(f"- Pending Todos: {len(pending)}\n")
    completion_rate = (len(completed) * 100 / len(todos)) if todos else 0
    f.write(f"- Completion Rate: {completion_rate:.1f}%\n")
    f.write(f"- Overall MTTR (seconds): {overall_mttr:.2f}\n\n")

    f.write("## MTTR by Category\n")
    if cat_mttr:
        for c, mttr in sorted(cat_mttr.items(), key=lambda x: x[1]):
            f.write(f"- {c}: {mttr:.2f}s\n")
    else:
        f.write("(No completed tasks with timing data)\n")
    f.write("\n")

    f.write("## Agent Effectiveness\n")
    for agent, stats in agent_stats.items():
        rate = (
            (stats["completed"] * 100 / stats["assigned"]) if stats["assigned"] else 0
        )
        f.write(
            f"- {agent}: {stats['completed']}/{stats['assigned']} completed ({rate:.1f}%)\n"
        )
    f.write("\n")

    f.write("## Resolution Outcomes\n")
    if outcomes:
        for oc, count in outcomes.items():
            f.write(f"- {oc}: {count}\n")
    else:
        f.write("(No outcomes yet)\n")
    f.write("\n")

    f.write("## Recommendations\n")
    if completion_rate < 50:
        f.write(
            "- Increase focus on high-priority infrastructure tasks to raise completion rate.\n"
        )
    if overall_mttr > 3600:
        f.write(
            "- Investigate root causes of long resolution times; consider automated remediation.\n"
        )
    if "failed" in outcomes:
        f.write(
            "- Analyze failed resolutions for pattern correlations and improve playbooks.\n"
        )
    f.write("- Expand self-healing scripts to cover recurring dependency issues.\n")
    f.write("- Add automated closure for tasks resolved by background agents.\n")

print(f"Success metrics report written to {path}")
