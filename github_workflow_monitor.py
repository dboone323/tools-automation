#!/usr/bin/env python3
"""Simple workflow monitor that listens for repository_dispatch-like payloads
or polls the GitHub Actions API for failed runs and forwards alerts to the MCP
server so agents can take action automatically.

Usage:
  export GITHUB_TOKEN=...
  export MCP_URL=http://127.0.0.1:5005
  python Automation/github_workflow_monitor.py
"""
import json
import os
import threading
import time

import requests

DEFAULT_POLL = int(os.getenv("MONITOR_POLL_INTERVAL", "60"))
DEBOUNCE_SECONDS = int(os.getenv("MONITOR_DEBOUNCE_SECONDS", "120"))
MAX_RETRIES = int(os.getenv("MONITOR_MAX_RETRIES", "3"))
RETRY_BACKOFF = float(os.getenv("MONITOR_RETRY_BACKOFF", "2.0"))

GITHUB_OWNER = os.getenv("GITHUB_OWNER", "dboone323")
GITHUB_REPO = os.getenv("GITHUB_REPO", "Quantum-workspace")
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
MCP_URL = os.getenv("MCP_URL", "http://127.0.0.1:5005")

HEADERS = (
    {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json",
    }
    if GITHUB_TOKEN
    else {}
)


def fetch_recent_workflow_runs(status="failure"):
    url = f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/actions/runs"
    params = {"per_page": 10}
    r = requests.get(url, headers=HEADERS, params=params, timeout=15)
    r.raise_for_status()
    runs = r.json().get("workflow_runs", [])
    return [r for r in runs if r.get("conclusion") != "success"]


def notify_mcp(run):
    payload = {
        "workflow": run.get("name"),
        "conclusion": run.get("conclusion"),
        "url": run.get("html_url"),
        "head_branch": run.get("head_branch"),
        "run_id": run.get("id"),
    }
    for attempt in range(MAX_RETRIES):
        try:
            r = requests.post(f"{MCP_URL}/workflow_alert", json=payload, timeout=10)
            print("notified mcp:", r.status_code)
            return True
        except Exception as e:
            print("failed to notify mcp (attempt %d):" % (attempt + 1), e)
            time.sleep(RETRY_BACKOFF * (attempt + 1))
    return False


def open_issue_for_run(run, title=None, body=None):
    if not GITHUB_TOKEN:
        print("no GITHUB_TOKEN; cannot open issue")
        return None
    url = f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/issues"
    payload = {
        "title": title or f"CI failure: {run.get('name')} on {run.get('head_branch')}",
        "body": body or f"Workflow failed: {run.get('html_url')}",
    }
    r = requests.post(url, headers=HEADERS, json=payload, timeout=10)
    if r.status_code in (200, 201):
        return r.json().get("html_url")
    print("open_issue failed:", r.status_code, r.text)
    return None


def rerun_workflow(run):
    # Use the Actions API to re-run a workflow run
    if not GITHUB_TOKEN:
        print("no GITHUB_TOKEN; cannot rerun")
        return False
    run_id = run.get("id")
    if not run_id:
        return False
    url = f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/actions/runs/{run_id}/rerun"
    r = requests.post(url, headers=HEADERS, timeout=10)
    if r.status_code in (201, 202):
        print("rerun requested")
        return True
    print("rerun failed:", r.status_code, r.text)
    return False


def trigger_mcp_debug_run(run):
    # Ask MCP to enqueue a debug task (e.g., run 'analyze' or 'ci-check')
    payload = {
        "workflow": run.get("name"),
        "conclusion": run.get("conclusion"),
        "url": run.get("html_url"),
        "head_branch": run.get("head_branch"),
        "run_id": run.get("id"),
        "action": "debug-run",
    }
    try:
        r = requests.post(f"{MCP_URL}/workflow_alert", json=payload, timeout=10)
        print("triggered mcp debug run:", r.status_code)
        return True
    except Exception as e:
        print("failed to trigger mcp debug run", e)
        return False


def main(poll_interval=60):
    seen = {}
    while True:
        try:
            runs = fetch_recent_workflow_runs()
            for run in runs:
                rid = run.get("id")
                now = time.time()
                last = seen.get(rid)
                if last and (now - last) < DEBOUNCE_SECONDS:
                    continue
                seen[rid] = now
                print("found failed run:", run.get("name"), run.get("html_url"))
                # notify MCP (with retries)
                ok = notify_mcp(run)
                # perform action templates when configured via env or payload
                action = run.get("action") or os.getenv("MONITOR_DEFAULT_ACTION")
                if action == "open-issue":
                    open_issue_for_run(run)
                elif action == "rerun-workflow":
                    rerun_workflow(run)
                elif action == "trigger-debug-run":
                    trigger_mcp_debug_run(run)
        except Exception as e:
            print("monitor error:", e)
        time.sleep(poll_interval)


if __name__ == "__main__":
    interval = int(os.getenv("MONITOR_POLL_INTERVAL", "60"))
    main(interval)
