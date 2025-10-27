#!/usr/bin/env python3
"""
Metrics Dashboard CLI (Phase 4)

Reads the analytics summary produced by analytics_collector.py and prints a
human-friendly dashboard to stdout. Can also regenerate on-demand.

CLI:
  metrics_dashboard.py show [--refresh]
  metrics_dashboard.py html --out Tools/Automation/agents/analytics_report.html
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import time
from typing import Any, Dict


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
AGENTS_DIR = os.path.join(ROOT, "Tools", "Automation", "agents")
KNOWLEDGE_DIR = os.path.join(AGENTS_DIR, "knowledge")
SUMMARY_PATH = os.path.join(KNOWLEDGE_DIR, "analytics.json")
TASK_QUEUE_PATH = os.path.join(AGENTS_DIR, "task_queue.json")


def _load_json(path: str) -> Dict[str, Any]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def _run_refresh(html: bool = False) -> None:
    script = os.path.join(AGENTS_DIR, "analytics_collector.py")
    if html:
        html_out = os.path.join(AGENTS_DIR, "analytics_report.html")
        subprocess.run(
            [script, "collect", "--out", SUMMARY_PATH, "--html", html_out], check=False
        )
    else:
        subprocess.run([script, "collect", "--out", SUMMARY_PATH], check=False)


def _pct(x: float) -> str:
    try:
        return f"{100*float(x):.2f}%"
    except Exception:
        return "0.00%"


def _secs(x: float) -> str:
    try:
        return f"{float(x):.2f}s"
    except Exception:
        return "0.00s"


def show_dashboard(data: Dict[str, Any]) -> str:
    lines = []
    lines.append("=== Agent Analytics Dashboard ===")
    lines.append(f"Generated: {data.get('generated_at','')}")
    lines.append("")
    lines.append(
        f"Overall Success Rate:        {_pct(data.get('overall_success_rate',0))}"
    )
    lines.append(
        f"Average Resolution Time:     {_secs(data.get('average_resolution_time',0))}"
    )
    lines.append(
        f"Learning Velocity (per wk):  {int(data.get('learning_velocity_per_week',0))}"
    )
    lines.append(f"Autonomy Level:              {_pct(data.get('autonomy_level',0))}")
    lines.append(
        f"Error Recurrence Rate:       {_pct(data.get('error_recurrence_rate',0))}"
    )
    lines.append(
        f"Collaboration Score:         {_pct(data.get('cross_agent_collaboration_score',0))}"
    )
    lines.append(
        f"Open Proactive Alerts:       {int(data.get('proactive_open_alerts',0))}"
    )
    counts = data.get("counts", {})
    lines.append(
        f"Predictions: {counts.get('predictions',0)}  Strategies: {counts.get('strategies',0)}  Emergencies: {counts.get('emergencies',0)}"
    )
    lines.append("")
    lines.append("Tip: Run with --refresh to update metrics.")
    return "\n".join(lines)


def show_queue_status() -> str:
    """Show quick queue summary: queued, in_progress, failed, completed."""
    q = _load_json(TASK_QUEUE_PATH)
    tasks = q.get("tasks", [])
    completed = q.get("completed", [])
    queued = [t for t in tasks if isinstance(t, dict) and t.get("status") == "queued"]
    inprog = [
        t for t in tasks if isinstance(t, dict) and t.get("status") == "in_progress"
    ]
    failed = [t for t in tasks if isinstance(t, dict) and t.get("status") == "failed"]
    lines = []
    lines.append("=== Task Queue Status ===")
    lines.append(f"Queued:       {len(queued)}")
    lines.append(f"In Progress:  {len(inprog)}")
    lines.append(f"Failed:       {len(failed)}")
    lines.append(f"Completed:    {len(completed)}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Show the Phase 4 metrics dashboard")
    sub = parser.add_subparsers(dest="cmd")
    p_show = sub.add_parser("show", help="Show dashboard")
    p_show.add_argument(
        "--refresh", action="store_true", help="Refresh analytics before showing"
    )

    p_html = sub.add_parser("html", help="Generate HTML report")
    p_html.add_argument(
        "--out", default=os.path.join(AGENTS_DIR, "analytics_report.html")
    )

    p_queue = sub.add_parser("queue", help="Show task queue status")
    p_queue.add_argument(
        "--watch", action="store_true", help="Auto-refresh every 60 seconds"
    )

    args = parser.parse_args()
    if args.cmd == "show":
        if args.refresh:
            _run_refresh(html=False)
        data = _load_json(SUMMARY_PATH)
        print(show_dashboard(data))
        return 0
    elif args.cmd == "html":
        _run_refresh(html=True)
        print(f"HTML report generated at {args.out}")
        return 0
    elif args.cmd == "queue":
        if args.watch:
            try:
                while True:
                    print("\033[2J\033[H")  # Clear screen
                    print(show_queue_status())
                    print("\n[Refreshing every 60s... Ctrl+C to stop]")
                    time.sleep(60)
            except KeyboardInterrupt:
                print("\nStopped.")
                return 0
        else:
            print(show_queue_status())
            return 0
    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
