#!/usr/bin/env python3
"""
Analytics Collector (Phase 4)

Aggregates key metrics from the agent knowledge base into a single summary JSON
and optionally an HTML report.

Inputs (best-effort, all optional):
- Tools/Automation/agents/knowledge/predictions.json
- Tools/Automation/agents/knowledge/proactive_metrics.json
- Tools/Automation/agents/knowledge/proactive_alerts.json
- Tools/Automation/agents/knowledge/strategies.json
- Tools/Automation/agents/knowledge/central_hub.json
- Tools/Automation/agents/knowledge/emergencies.json
- Tools/Automation/agents/knowledge/failure_analysis.json
- Tools/Automation/agents/knowledge/fix_history.json

Outputs:
- Tools/Automation/agents/knowledge/analytics.json (summary)
- Optional HTML report (via --html)

CLI:
  analytics_collector.py collect [--out <summary.json>] [--html <report.html>]
"""
from __future__ import annotations

import argparse
import json
import os
import statistics
import logging
from agents.utils import user_log
logger = logging.getLogger(__name__)
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
AGENTS_DIR = os.path.join(ROOT, "Tools", "Automation", "agents")
KNOWLEDGE_DIR = os.path.join(AGENTS_DIR, "knowledge")


def _load_json(path: str, default: Any) -> Any:
    try:
        if not os.path.exists(path):
            return default
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        logger.debug("Failed to load JSON from %s: %s", path, e, exc_info=True)
        return default


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _mean_safe(values: List[float], default: float = 0.0) -> float:
    clean = [v for v in values if isinstance(v, (int, float))]
    return float(statistics.fmean(clean)) if clean else default


def collect_metrics() -> Dict[str, Any]:
    # Load inputs (best-effort)
    predictions = _load_json(os.path.join(KNOWLEDGE_DIR, "predictions.json"), [])
    _proactive_metrics = _load_json(
        os.path.join(KNOWLEDGE_DIR, "proactive_metrics.json"), {}
    )
    proactive_alerts = _load_json(
        os.path.join(KNOWLEDGE_DIR, "proactive_alerts.json"), []
    )
    strategies = _load_json(os.path.join(KNOWLEDGE_DIR, "strategies.json"), [])
    central_hub = _load_json(os.path.join(KNOWLEDGE_DIR, "central_hub.json"), {})
    emergencies = _load_json(os.path.join(KNOWLEDGE_DIR, "emergencies.json"), [])
    failure_analysis = _load_json(
        os.path.join(KNOWLEDGE_DIR, "failure_analysis.json"), []
    )
    fix_history = _load_json(os.path.join(KNOWLEDGE_DIR, "fix_history.json"), [])

    # Overall success rate and average resolution time from strategies
    success_rates = []
    avg_times = []
    if isinstance(strategies, list):
        for s in strategies:
            if isinstance(s, dict):
                sr = s.get("success_rate")
                at = s.get("avg_execution_time") or s.get("average_time")
                if isinstance(sr, (int, float)):
                    success_rates.append(float(sr))
                if isinstance(at, (int, float)):
                    avg_times.append(float(at))

    overall_success_rate = _mean_safe(success_rates)
    average_resolution_time = _mean_safe(avg_times)

    # Learning velocity: fixes/week based on timestamps when present; else count
    def _timestamps(items: Any) -> List[datetime]:
        ts = []
        if isinstance(items, list):
            for it in items:
                if isinstance(it, dict):
                    raw = it.get("timestamp") or it.get("time") or it.get("date")
                    if isinstance(raw, str):
                        for fmt in (
                            "%Y-%m-%dT%H:%M:%SZ",
                            "%Y-%m-%d %H:%M:%S",
                            "%Y-%m-%d",
                        ):
                            try:
                                parsed = datetime.strptime(raw, fmt)
                                # Make timezone-aware by assuming UTC
                                ts.append(parsed.replace(tzinfo=timezone.utc))
                                break
                            except Exception as e:
                                logger.debug("Failed to parse timestamp %s: %s", raw, e)
                                continue
        return ts

    now = datetime.now(timezone.utc)
    week_ago = now - timedelta(days=7)
    fixes_ts = _timestamps(fix_history)
    fixes_last_week = (
        len([t for t in fixes_ts if t >= week_ago]) if fixes_ts else len(fix_history)
    )
    learning_velocity = fixes_last_week  # per week

    # Autonomy level: 1 - (emergencies requiring human / total)
    human_flags = 0
    if isinstance(emergencies, list) and emergencies:
        for e in emergencies:
            if isinstance(e, dict):
                sev = (e.get("severity") or "").lower()
                escalations = e.get("escalations") or []
                reached_human = any(
                    (
                        isinstance(x, dict)
                        and str(x.get("level", "")).strip() in ("4", "L4", "level4")
                    )
                    for x in escalations
                )
                if sev == "critical" or reached_human:
                    human_flags += 1
        autonomy_level = 1.0 - (human_flags / max(1.0, float(len(emergencies))))
    else:
        autonomy_level = 1.0

    # Error recurrence rate: naive ratio of repeated failure signatures
    recurrence_rate = 0.0
    if isinstance(failure_analysis, list) and failure_analysis:
        sig_counts: Dict[str, int] = {}
        for fa in failure_analysis:
            if isinstance(fa, dict):
                sig = fa.get("signature") or fa.get("pattern") or fa.get("error") or ""
                sig_counts[sig] = sig_counts.get(sig, 0) + 1
        repeats = sum(1 for k, v in sig_counts.items() if v > 1)
        recurrence_rate = float(repeats) / max(1.0, float(len(sig_counts)))

    # Cross-agent collaboration score: based on present insight counts
    collaboration_score = 0.0
    if isinstance(central_hub, dict):
        insights = central_hub.get("cross_agent_insights") or []
        best_practices = central_hub.get("best_practices") or []
        # Simple bounded score
        collaboration_score = min(
            1.0, (len(insights) + 0.5 * len(best_practices)) / 20.0
        )

    # Proactive monitoring snapshot
    open_alerts = 0
    if isinstance(proactive_alerts, list):
        open_alerts = len(
            [
                a
                for a in proactive_alerts
                if isinstance(a, dict) and a.get("status", "active") == "active"
            ]
        )

    metrics = {
        "generated_at": _now_iso(),
        "overall_success_rate": round(overall_success_rate, 4),
        "average_resolution_time": round(average_resolution_time, 2),
        "learning_velocity_per_week": int(learning_velocity),
        "autonomy_level": round(autonomy_level, 4),
        "error_recurrence_rate": round(recurrence_rate, 4),
        "cross_agent_collaboration_score": round(collaboration_score, 4),
        "proactive_open_alerts": int(open_alerts),
        "counts": {
            "predictions": len(predictions) if isinstance(predictions, list) else 0,
            "strategies": len(strategies) if isinstance(strategies, list) else 0,
            "emergencies": len(emergencies) if isinstance(emergencies, list) else 0,
        },
    }

    return metrics


def _write_json(path: str, data: Dict[str, Any]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)


def _write_html(path: str, data: Dict[str, Any]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    html = f"""
<!doctype html>
<html>
<head>
  <meta charset=\"utf-8\" />
  <title>Agent Analytics Dashboard</title>
  <style>
    body {{ font-family: -apple-system, system-ui, Segoe UI, Roboto, Arial, sans-serif; margin: 2rem; }}
    h1 {{ margin-bottom: 0.5rem; }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; }}
    .card {{ border: 1px solid #e5e7eb; border-radius: 8px; padding: 16px; box-shadow: 0 1px 2px rgba(0,0,0,0.03); }}
    .kpi {{ font-size: 28px; font-weight: 700; margin-top: 6px; }}
    .muted {{ color: #6b7280; font-size: 12px; }}
    pre {{ background: #f8fafc; padding: 12px; border-radius: 6px; overflow-x: auto; }}
  </style>
  <meta http-equiv=\"refresh\" content=\"60\" />
  <script>function pct(x){{return (100*Number(x)).toFixed(2)+'%';}}</script>
  <script>function ms(x){{return Number(x).toFixed(0)+'s';}}</script>
  <script>function int(x){{return Number(x).toFixed(0);}}</script>
  <script>function fmt(x){{return Number(x).toFixed(4);}}</script>
  <script>function onload(){{}}</script>
  
</head>
<body>
  <h1>Agent Analytics Dashboard</h1>
  <div class=\"muted\">Generated: {data.get('generated_at','')}</div>
  <div class=\"grid\">
    <div class=\"card\"><div>Overall Success Rate</div><div class=\"kpi\">{round(100*data.get('overall_success_rate',0),2)}%</div></div>
    <div class=\"card\"><div>Avg Resolution Time</div><div class=\"kpi\">{round(data.get('average_resolution_time',0),2)}s</div></div>
    <div class=\"card\"><div>Learning Velocity</div><div class=\"kpi\">{int(data.get('learning_velocity_per_week',0))}/week</div></div>
    <div class=\"card\"><div>Autonomy Level</div><div class=\"kpi\">{round(100*data.get('autonomy_level',0),2)}%</div></div>
    <div class=\"card\"><div>Error Recurrence</div><div class=\"kpi\">{round(100*data.get('error_recurrence_rate',0),2)}%</div></div>
    <div class=\"card\"><div>Collaboration Score</div><div class=\"kpi\">{round(100*data.get('cross_agent_collaboration_score',0),2)}%</div></div>
    <div class=\"card\"><div>Open Alerts</div><div class=\"kpi\">{int(data.get('proactive_open_alerts',0))}</div></div>
  </div>
  <h2>Raw Summary</h2>
  <pre>{json.dumps(data, indent=2)}</pre>
</body>
</html>
"""
    with open(path, "w", encoding="utf-8") as f:
        f.write(html)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Collect and summarize agent analytics"
    )
    sub = parser.add_subparsers(dest="cmd")
    p = sub.add_parser("collect", help="Collect analytics and emit JSON")
    p.add_argument(
        "--out",
        default=os.path.join(KNOWLEDGE_DIR, "analytics.json"),
        help="Path to write JSON summary",
    )
    p.add_argument("--html", default=None, help="Also write a simple HTML report")

    args = parser.parse_args()
    if args.cmd != "collect":
        parser.print_help()
        return 1

    data = collect_metrics()
    # Print to stdout (or structured log depending on env)
    user_log(json.dumps(data))
    # Persist JSON
    _write_json(args.out, data)
    # Optional HTML
    if args.html:
        _write_html(args.html, data)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
