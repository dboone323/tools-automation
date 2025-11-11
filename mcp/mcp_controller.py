#!/usr/bin/env python3
"""
MCP Controller Agent

Polls the local MCP server for queued tasks, ensures only one execution per project,
and triggers execution via the MCP execute_task endpoint. After completion, it
collects stdout/stderr and uploads artifacts using the artifact uploader script.
"""
import logging
import os
import threading
import time
from pathlib import Path

import requests

MCP_URL = os.environ.get("MCP_URL", "http://127.0.0.1:5005")
AGENT_NAME = os.environ.get("AGENT_NAME", "controller-agent")
# Base poll/heartbeat intervals (seconds). Use env to tune in CI or prod.
POLL_INTERVAL = float(os.environ.get("POLL_INTERVAL", "4.0"))
HEARTBEAT_INTERVAL = float(os.environ.get("HEARTBEAT_INTERVAL", "8.0"))
ARTIFACT_DIR = os.environ.get("ARTIFACT_DIR", str(Path.home() / "mcp_artifacts"))

# Optional per-instance project name (for per-project controllers)
PROJECT_NAME = os.environ.get("PROJECT_NAME")

# ensure logs dir exists next to this script
LOG_DIR = Path(__file__).parent.parent / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_NAME = LOG_DIR / (f"controller{('_'+PROJECT_NAME) if PROJECT_NAME else ''}.log")

# configure logging to file with immediate flush behavior
logger = logging.getLogger("mcp_controller")
logger.setLevel(logging.INFO)
if not logger.handlers:
    fh = logging.FileHandler(LOG_NAME, encoding="utf-8")
    fh.setLevel(logging.INFO)
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    fh.setFormatter(fmt)
    # ensure FileHandler flushes after each emit by wrapping emit
    orig_emit = fh.emit

    def _emit_and_flush(record):
        orig_emit(record)
        try:
            fh.flush()
        except Exception:
            pass

    fh.emit = _emit_and_flush
    logger.addHandler(fh)

logger.info(f"Controller starting (agent={AGENT_NAME}, project={PROJECT_NAME})")

os.makedirs(ARTIFACT_DIR, exist_ok=True)

# Track running projects to prevent concurrent execution
running_projects = set()
lock = threading.Lock()


def register():
    # retry with exponential backoff on failure
    # ensure controller identifies itself so server whitelist can recognize it
    session = requests.Session()
    cid = (
        f"local-controller-{PROJECT_NAME}"
        if PROJECT_NAME
        else "local-controller-unknown"
    )
    session.headers.update({"X-Client-Id": cid})
    backoff = 1.0
    for attempt in range(6):
        try:
            session.post(
                f"{MCP_URL}/register",
                json={"agent": AGENT_NAME, "capabilities": ["controller"]},
                timeout=5,
            )
            logger.info("Registered with MCP")
            return True
        except Exception as e:
            logger.warning("Register attempt %d failed: %s", attempt + 1, e)
            time.sleep(backoff + (0.1 * (attempt)))
            backoff = min(backoff * 2, 30)
    logger.error("Register failed after retries")
    return False


_session = requests.Session()
_session.headers.update(
    {
        "X-Client-Id": (
            f"local-controller-{PROJECT_NAME}"
            if PROJECT_NAME
            else "local-controller-unknown"
        )
    }
)


def _safe_request(func, url, **kwargs):
    """Call a requests function (post/get) and if the target doesn't accept
    certain keyword args (like 'headers' when tests monkeypatch), retry
    without headers so unit tests remain compatible.
    """
    try:
        return func(url, **kwargs)
    except TypeError:
        # try removing headers and retry
        if "headers" in kwargs:
            kwargs2 = dict(kwargs)
            kwargs2.pop("headers", None)
            return func(url, **kwargs2)
        raise


def send_heartbeat(project=None):
    try:
        _session.post(
            f"{MCP_URL}/heartbeat",
            json={"agent": AGENT_NAME, "project": project},
            timeout=4,
        )
        logger.debug("Sent heartbeat (project=%s)", project)
    except Exception as e:
        logger.debug("Heartbeat failed: %s", e)


def poll_tasks():
    # poll /status with retry/backoff on transient errors. Return [] on errors.
    backoff = 0.5
    for _ in range(3):
        try:
            r = _session.get(f"{MCP_URL}/status", timeout=6)
            if r.status_code != 200:
                return []
            data = r.json()
            return data.get("tasks", [])
        except Exception as e:
            logger.debug("poll_tasks transient error: %s", e)
            time.sleep(backoff)
            backoff = min(backoff * 2, 5)
    return []


def execute_task(task):
    task_id = task["id"]
    proj = task.get("project") or "workspace"

    # ensure only one execution per project
    with lock:
        if proj in running_projects:
            return False
        running_projects.add(proj)

    try:
        # ask MCP to execute
        # prefer requests.* so unit tests that monkeypatch requests.* will intercept
        r = _safe_request(
            requests.post,
            f"{MCP_URL}/execute_task",
            json={"task_id": task_id},
            timeout=5,
            headers=_session.headers,
        )
        if r.status_code not in (200, 202):
            return False

        # poll task status until finished with backoff
        poll_backoff = 1.0
        while True:
            try:
                s = _safe_request(
                    requests.get,
                    f"{MCP_URL}/status",
                    timeout=6,
                    headers=_session.headers,
                ).json()
            except Exception:
                logger.debug("execute_task: status fetch failed, will retry")
                time.sleep(poll_backoff)
                poll_backoff = min(poll_backoff * 2, 6)
                continue
            # find task by id
            t = next((x for x in s.get("tasks", []) if x.get("id") == task_id), None)
            if not t:
                break
            if t.get("status") in ("success", "failed", "error"):
                # save artifacts
                save_artifacts(t)
                # upload artifacts
                upload_artifacts(t)
                break
            time.sleep(1.0)
        return True
    finally:
        with lock:
            running_projects.discard(proj)


def save_artifacts(task):
    tid = task.get("id")
    proj = task.get("project") or "workspace"
    out = task.get("stdout", "")
    err = task.get("stderr", "")
    ts = int(time.time())
    base = Path(ARTIFACT_DIR) / f"{proj}_{tid}_{ts}"
    base.mkdir(parents=True, exist_ok=True)
    (base / "stdout.txt").write_text(out)
    (base / "stderr.txt").write_text(err)
    # point to any generated report paths in stdout (best-effort)
    logger.info(f"Artifacts saved: {base}")


def upload_artifacts(task):
    # call a local uploader script if present; otherwise leave artifacts in ARTIFACT_DIR
    uploader = Path(__file__).parent / "artifact_uploader.sh"
    if uploader.exists() and os.access(uploader, os.X_OK):
        tid = task.get("id")
        proj = task.get("project") or "workspace"
        ts = int(time.time())
        base = Path(ARTIFACT_DIR) / f"{proj}_{tid}_{ts}"
        try:
            requests.get(
                f"{MCP_URL}/status", timeout=3
            )  # quick check to ensure MCP reachable
        except Exception:
            pass

        # run uploader (invoke directly without shell when possible)
        # run uploader in a background thread using subprocess to avoid replacing the process
        def run_uploader(uploader_path, target):
            try:
                import subprocess

                subprocess.run([str(uploader_path), str(target)], check=False)
            except Exception:
                logger.exception("Artifact upload failed")

        threading.Thread(
            target=run_uploader, args=(uploader, base), daemon=True
        ).start()


def main():
    register()
    logger.info("Controller agent registered, polling for tasks...")

    # start heartbeat thread (include optional PROJECT_NAME)
    def hb_loop():
        while True:
            send_heartbeat(PROJECT_NAME)
            time.sleep(HEARTBEAT_INTERVAL)

    threading.Thread(target=hb_loop, daemon=True).start()
    try:
        while True:
            tasks = poll_tasks()
            for t in tasks:
                if t.get("status") == "queued":
                    threading.Thread(
                        target=execute_task, args=(t,), daemon=True
                    ).start()
            time.sleep(POLL_INTERVAL)
    except KeyboardInterrupt:
        logger.info("Controller received KeyboardInterrupt, exiting")
        return


if __name__ == "__main__":
    main()
