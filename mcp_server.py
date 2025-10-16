#!/usr/bin/env python3
"""
Minimal local MCP coordinator server.

Provides simple JSON HTTP endpoints for agents to register and request allowed workspace tasks.

Endpoints:
  GET /status -> {"ok": true, "agents": [...], "tasks": [...]}
  POST /register -> {"agent": "name", "capabilities": [...]}
  POST /run -> {"agent": "name", "command": "analyze", "project": "HabitQuest", "execute": false}

This server intentionally restricts executable actions to a small allowlist and runs them
from the workspace root to avoid arbitrary command execution.
"""
import hashlib
import hmac
import json
import os
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

CODE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HOST = "127.0.0.1"
PORT = 5005
TASK_TTL_DAYS = int(os.environ.get("TASK_TTL_DAYS", "7"))
CLEANUP_INTERVAL_MIN = int(os.environ.get("CLEANUP_INTERVAL_MIN", "60"))
RATE_LIMIT_WINDOW_SEC = int(os.environ.get("RATE_LIMIT_WINDOW_SEC", "60"))
# Increase default max requests to be more permissive for local dashboards and controllers
RATE_LIMIT_MAX_REQS = int(os.environ.get("RATE_LIMIT_MAX_REQS", "100"))
# Optional comma-separated whitelist of client ids that bypass rate limiting (e.g. 'dashboard,local-controller')
RATE_LIMIT_WHITELIST = [
    c.strip()
    for c in os.environ.get("RATE_LIMIT_WHITELIST", "").split(",")
    if c.strip()
]

# Allowlist mapping of high-level commands to script invocations (relative to CODE_DIR)
ALLOWED_COMMANDS = {
    "analyze": ["./Tools/Automation/ai_enhancement_system.sh", "analyze"],
    "analyze-all": ["./Tools/Automation/ai_enhancement_system.sh", "analyze-all"],
    "auto-apply": ["./Tools/Automation/ai_enhancement_system.sh", "auto-apply"],
    "ci-check": ["./Tools/Automation/mcp_workflow.sh", "ci-check"],
    "fix": ["./Tools/Automation/intelligent_autofix.sh", "fix"],
    "fix-all": ["./Tools/Automation/intelligent_autofix.sh", "fix-all"],
    "status": ["./Tools/Automation/master_automation.sh", "status"],
    "validate": ["./Tools/Automation/intelligent_autofix.sh", "validate"],
    # TODO-related commands
    "optimize-performance": [
        "./Tools/Automation/agents/agent_debug.sh",
        "optimize-performance",
    ],
    "enhance-review-engine": [
        "./Tools/Automation/agents/agent_codegen.sh",
        "enhance-review-engine",
    ],
    "implement-feature": [
        "./Tools/Automation/agents/agent_codegen.sh",
        "implement-feature",
    ],
    "integrate-api": ["./Tools/Automation/agents/agent_build.sh", "integrate-api"],
    "enhance-ui": ["./Tools/Automation/agents/agent_uiux.sh", "enhance-ui"],
    "implement-todo": ["./Tools/Automation/agents/agent_codegen.sh", "implement-todo"],
    # GitHub integration commands
    "mcp_github_list_workflows": ["./Tools/Automation/mcp_github_list_workflows.sh"],
    "mcp_github_list_workflow_runs": [
        "./Tools/Automation/mcp_github_list_workflow_runs.sh"
    ],
    "mcp_github_get_job_logs": ["./Tools/Automation/mcp_github_get_job_logs.sh"],
}


class MCPHandler(BaseHTTPRequestHandler):
    server_version = "MCP-Local/0.1"

    def _is_rate_limited(self):
        # simple per-IP sliding window rate limit using server.request_counters
        ip = self.client_address[0]
        # if client identifies itself via header and is whitelisted, bypass rate limiting
        client_id = None
        try:
            client_id = self.headers.get("X-Client-Id")
        except Exception:
            client_id = None
        if client_id and client_id in RATE_LIMIT_WHITELIST:
            return False
        now = __import__("time").time()
        window = RATE_LIMIT_WINDOW_SEC
        maxreq = RATE_LIMIT_MAX_REQS
        try:
            with self.server.rate_limit_lock:
                bucket = self.server.request_counters.setdefault(ip, [])
                # remove old timestamps
                while bucket and bucket[0] < now - window:
                    bucket.pop(0)
                if len(bucket) >= maxreq:
                    return True
                bucket.append(now)
        except Exception:
            # on any error, be permissive
            return False
        return False

    def _send_json(self, data, status=200):
        body = json.dumps(data, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self._is_rate_limited():
            self._send_json({"error": "rate_limited"}, status=429)
            return
        parsed = urlparse(self.path)
        if parsed.path == "/status":
            payload = {
                "ok": True,
                "agents": list(self.server.agents.keys()),
                "tasks": list(self.server.tasks),
                "controllers": list(self.server.controllers.values()),
            }
            self._send_json(payload)
            return

        if parsed.path == "/health":
            # simple health check for external supervisors
            self._send_json({"ok": True, "uptime": True})
            return

        if parsed.path == "/controllers":
            # return registered controllers with last heartbeat
            self._send_json(
                {"ok": True, "controllers": list(self.server.controllers.values())}
            )
            return
        else:
            self._send_json({"error": "not_found"}, status=404)

    def do_POST(self):
        if self._is_rate_limited():
            self._send_json({"error": "rate_limited"}, status=429)
            return
        parsed = urlparse(self.path)
        length = int(self.headers.get("Content-Length", 0))
        raw_bytes = self.rfile.read(length) if length else b""
        raw = raw_bytes.decode("utf-8") if raw_bytes else ""
        try:
            body = json.loads(raw) if raw else {}
        except Exception:
            self._send_json({"error": "invalid_json"}, status=400)
            return

        # Helper: verify GitHub webhook signature using GITHUB_WEBHOOK_SECRET
        def _verify_github_signature():
            secret = os.environ.get("GITHUB_WEBHOOK_SECRET")
            if not secret:
                return False
            sig_header = self.headers.get("X-Hub-Signature-256") or self.headers.get(
                "X-Hub-Signature"
            )
            if not sig_header:
                return False
            # support both sha256=... and legacy sha1=...
            try:
                if sig_header.startswith("sha256="):
                    expected = sig_header.split("=", 1)[1]
                    mac = hmac.new(
                        secret.encode("utf-8"), msg=raw_bytes, digestmod=hashlib.sha256
                    )
                    digest = mac.hexdigest()
                    return hmac.compare_digest(digest, expected)
                elif sig_header.startswith("sha1="):
                    expected = sig_header.split("=", 1)[1]
                    mac = hmac.new(
                        secret.encode("utf-8"), msg=raw_bytes, digestmod=hashlib.sha1
                    )
                    digest = mac.hexdigest()
                    return hmac.compare_digest(digest, expected)
            except Exception:
                return False
            return False

        if parsed.path == "/register":
            agent = body.get("agent")
            caps = body.get("capabilities", [])
            if not agent:
                self._send_json({"error": "agent_required"}, status=400)
                return
            self.server.agents[agent] = {"capabilities": caps}
            self._send_json({"ok": True, "registered": agent})
            return

        if parsed.path == "/heartbeat":
            # controllers POST {'agent': 'name', 'project': 'X'} to announce liveness
            agent = body.get("agent")
            proj = body.get("project")
            ts = __import__("time").time()
            if not agent:
                self._send_json({"error": "agent_required"}, status=400)
                return
            entry = {"agent": agent, "project": proj, "last_heartbeat": ts}
            # store or update
            self.server.controllers[agent] = entry
            self._send_json({"ok": True, "heartbeat": True, "agent": agent})
            return

        if parsed.path == "/run":
            agent = body.get("agent")
            command = body.get("command")
            project = body.get("project")
            execute = bool(body.get("execute", False))

            if not agent or not command:
                self._send_json({"error": "agent_and_command_required"}, status=400)
                return

            if command not in ALLOWED_COMMANDS:
                self._send_json(
                    {
                        "error": "command_not_allowed",
                        "allowed": list(ALLOWED_COMMANDS.keys()),
                    },
                    status=403,
                )
                return

            # Prepare invocation
            cmd = list(ALLOWED_COMMANDS[command])
            if project:
                cmd.append(project)

            task_id = f"task_{len(self.server.tasks) + 1}"
            task = {
                "id": task_id,
                "agent": agent,
                "command": command,
                "project": project,
                "status": "queued",
            }
            self.server.tasks.append(task)
            self._send_json({"ok": True, "task_id": task_id, "queued": True})

            # Execute in background thread if execute requested
            if execute:
                # mark queued -> running under server-level lock to avoid races
                # multiple controllers may attempt to execute same task concurrently
                try:
                    with self.server.task_lock:
                        if task.get("status") != "queued":
                            return
                        task["status"] = "running"
                except Exception:
                    # if lock isn't present for some reason, fall back to best-effort
                    task["status"] = "running"

                threading.Thread(
                    target=self._execute_task, args=(task, cmd), daemon=True
                ).start()
            return

        if parsed.path == "/workflow_alert":
            # Accept alerts from the workflow monitor or GitHub repository_dispatch
            # Expected payload: {workflow, conclusion, url, head_branch, run_id, action}
            workflow = body.get("workflow")
            conclusion = body.get("conclusion")
            url = body.get("url")
            head_branch = body.get("head_branch")
            run_id = body.get("run_id")
            action = body.get("action")  # optional action template

            # Basic validation
            if not workflow or not conclusion:
                self._send_json(
                    {"error": "workflow_and_conclusion_required"}, status=400
                )
                return

            # Enqueue a conservative 'ci-check' task for the head_branch so controllers can re-run checks
            task_id = f"wf_{len(self.server.tasks) + 1}"
            task = {
                "id": task_id,
                "agent": "workflow-monitor",
                "command": "ci-check",
                "project": head_branch or "workspace",
                "status": "queued",
                "meta": {
                    "workflow": workflow,
                    "conclusion": conclusion,
                    "url": url,
                    "run_id": run_id,
                    "action": action,
                },
            }
            self.server.tasks.append(task)
            # persist immediately
            try:
                tasks_dir = os.path.join(os.path.dirname(__file__), "tasks")
                os.makedirs(tasks_dir, exist_ok=True)
                out_path = os.path.join(tasks_dir, f"{task_id}.json")
                with open(out_path, "w", encoding="utf-8") as f:
                    json.dump(task, f, indent=2)
            except Exception:
                pass

            # If an immediate action is requested (like open-issue), we keep placeholders here
            if action == "open-issue":
                # Placeholder: controllers or separate agent can open the issue using GH API
                pass
            elif action == "rerun-workflow":
                # Placeholder: controllers may call the GH API to request a rerun
                pass

            self._send_json({"ok": True, "enqueued": True, "task_id": task_id})
            return

        if parsed.path == "/github_webhook":
            # Verify signature if secret is configured
            verified = True
            secret = os.environ.get("GITHUB_WEBHOOK_SECRET")
            if secret:
                verified = _verify_github_signature()
            if not verified:
                self._send_json({"error": "signature_verification_failed"}, status=401)
                return

            # handle repository_dispatch (manual event) or workflow_run events
            gh_event = self.headers.get("X-GitHub-Event")
            if gh_event == "repository_dispatch":
                # repository_dispatch includes an 'action' and 'client_payload'
                action_name = body.get("action")
                client_payload = body.get("client_payload", {})
                # enqueue task based on payload or action
                cmd = (
                    client_payload.get("command")
                    or client_payload.get("run")
                    or "ci-check"
                )
                proj = (
                    client_payload.get("head_branch")
                    or client_payload.get("project")
                    or "workspace"
                )
                task_id = f"gh_{len(self.server.tasks) + 1}"
                task = {
                    "id": task_id,
                    "agent": "github-webhook",
                    "command": cmd,
                    "project": proj,
                    "status": "queued",
                    "meta": {
                        "event": "repository_dispatch",
                        "action": action_name,
                        "payload": client_payload,
                    },
                }
                self.server.tasks.append(task)
                # persist
                try:
                    tasks_dir = os.path.join(os.path.dirname(__file__), "tasks")
                    os.makedirs(tasks_dir, exist_ok=True)
                    out_path = os.path.join(tasks_dir, f"{task_id}.json")
                    with open(out_path, "w", encoding="utf-8") as f:
                        json.dump(task, f, indent=2)
                except Exception:
                    pass
                # optionally execute immediately if payload requests it
                if client_payload.get("execute"):
                    try:
                        with self.server.task_lock:
                            task["status"] = "running"
                    except Exception:
                        task["status"] = "running"
                    threading.Thread(
                        target=self._execute_task,
                        args=(task, list(ALLOWED_COMMANDS.get(cmd, [cmd]))),
                        daemon=True,
                    ).start()
                self._send_json({"ok": True, "enqueued": True, "task_id": task_id})
                return

            if gh_event == "workflow_run":
                # A workflow run completed; enqueue a ci-check for the branch if it failed
                action = body.get("action")
                workflow_run = body.get("workflow_run", {})
                conclusion = workflow_run.get("conclusion")
                head_branch = workflow_run.get("head_branch")
                html_url = workflow_run.get("html_url")
                if conclusion and conclusion != "success":
                    task_id = f"ghwf_{len(self.server.tasks) + 1}"
                    task = {
                        "id": task_id,
                        "agent": "github-webhook",
                        "command": "ci-check",
                        "project": head_branch or "workspace",
                        "status": "queued",
                        "meta": {
                            "workflow": workflow_run.get("name"),
                            "conclusion": conclusion,
                            "url": html_url,
                        },
                    }
                    self.server.tasks.append(task)
                    try:
                        tasks_dir = os.path.join(os.path.dirname(__file__), "tasks")
                        os.makedirs(tasks_dir, exist_ok=True)
                        out_path = os.path.join(tasks_dir, f"{task_id}.json")
                        with open(out_path, "w", encoding="utf-8") as f:
                            json.dump(task, f, indent=2)
                    except Exception:
                        pass
                    # don't auto-execute unless explicitly configured via env
                    if os.environ.get("GITHUB_WEBHOOK_AUTO_EXEC", "").lower() in (
                        "1",
                        "true",
                        "yes",
                    ):
                        try:
                            with self.server.task_lock:
                                task["status"] = "running"
                        except Exception:
                            task["status"] = "running"
                        threading.Thread(
                            target=self._execute_task,
                            args=(
                                task,
                                list(ALLOWED_COMMANDS.get("ci-check", ["ci-check"])),
                            ),
                            daemon=True,
                        ).start()
                    self._send_json({"ok": True, "enqueued": True, "task_id": task_id})
                    return

            self._send_json({"ok": True, "ignored_event": gh_event})
            return

        if parsed.path == "/execute_task":
            task_id = body.get("task_id")
            if not task_id:
                self._send_json({"error": "task_id_required"}, status=400)
                return

            # find task
            target = None
            for t in self.server.tasks:
                if t.get("id") == task_id:
                    target = t
                    break

            if not target:
                self._send_json({"error": "task_not_found"}, status=404)
                return

            # ensure atomic queued->running transition
            try:
                with self.server.task_lock:
                    if target.get("status") != "queued":
                        self._send_json(
                            {
                                "error": "task_not_queued",
                                "status": target.get("status"),
                            },
                            status=409,
                        )
                        return
                    target["status"] = "running"
            except Exception:
                # best-effort
                if target.get("status") != "queued":
                    self._send_json(
                        {"error": "task_not_queued", "status": target.get("status")},
                        status=409,
                    )
                    return
                target["status"] = "running"

            # build command
            command = target.get("command")
            project = target.get("project")
            if command not in ALLOWED_COMMANDS:
                self._send_json(
                    {
                        "error": "command_not_allowed",
                        "allowed": list(ALLOWED_COMMANDS.keys()),
                    },
                    status=403,
                )
                return

            cmd = list(ALLOWED_COMMANDS[command])
            if project:
                cmd.append(project)

            # spawn execution
            threading.Thread(
                target=self._execute_task, args=(target, cmd), daemon=True
            ).start()
            self._send_json({"ok": True, "executing": True, "task_id": task_id})
            return

        self._send_json({"error": "not_found"}, status=404)

    def _execute_task
        gc.collect()  # Memory cleanup(self, task, cmd):
        task["status"] = "running"
        try:
            proc = subprocess.run(
                cmd,
                cwd=CODE_DIR,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=1800,
            )
            task["status"] = "success" if proc.returncode == 0 else "failed"
            task["returncode"] = proc.returncode
            task["stdout"] = proc.stdout[:8000]
            task["stderr"] = proc.stderr[:8000]
        except Exception as e:
            task["status"] = "error"
            task["stderr"] = str(e)
        finally:
            # persist task result to disk (tasks/<task_id>.json) to survive restarts
            try:
                tasks_dir = os.path.join(os.path.dirname(__file__), "tasks")
                os.makedirs(tasks_dir, exist_ok=True)
                out_path = os.path.join(tasks_dir, f"{task.get('id')}.json")
                with open(out_path, "w", encoding="utf-8") as f:
                    json.dump(task, f, indent=2)
                # cleanup old task files older than TASK_TTL_DAYS
                try:
                    import time
import gc

                    cutoff = time.time() - (TASK_TTL_DAYS * 24 * 3600)
                    for fname in os.listdir(tasks_dir):
                        if not fname.endswith(".json"):
                            continue
                        fp = os.path.join(tasks_dir, fname)
                        try:
                            if os.path.getmtime(fp) < cutoff:
                                os.remove(fp)
                        except Exception:
                            pass
                except Exception:
                    pass
            except Exception:
                pass


def run_server(host=HOST, port=PORT):
    httpd = HTTPServer((host, port), MCPHandler)
    httpd.agents = {}
    httpd.tasks = []
    # Controllers registry: maps agent -> {agent, project, last_heartbeat}
    httpd.controllers = {}
    # Lock to protect queued->running transitions
    httpd.task_lock = threading.Lock()
    # Rate limiting state
    httpd.request_counters = {}
    httpd.rate_limit_lock = threading.Lock()

    # Load persisted tasks if present
    try:
        tasks_dir = os.path.join(os.path.dirname(__file__), "tasks")
        if os.path.isdir(tasks_dir):
            for fname in os.listdir(tasks_dir):
                if fname.endswith(".json"):
                    with open(
                        os.path.join(tasks_dir, fname), "r", encoding="utf-8"
                    ) as f:
                        try:
                            t = json.load(f)
                            httpd.tasks.append(t)
                        except Exception:
                            pass
    except Exception:
        pass

    # start periodic cleanup thread
    def cleanup_loop(stop_event):
        import time
import gc

        tasks_dir = os.path.join(os.path.dirname(__file__), "tasks")
        while not stop_event.is_set():
            try:
                cutoff = time.time() - (TASK_TTL_DAYS * 24 * 3600)
                if os.path.isdir(tasks_dir):
                    for fname in os.listdir(tasks_dir):
                        if not fname.endswith(".json"):
                            continue
                        fp = os.path.join(tasks_dir, fname)
                        try:
                            if os.path.getmtime(fp) < cutoff:
                                os.remove(fp)
                        except Exception:
                            pass
            except Exception:
                pass
            stop_event.wait(CLEANUP_INTERVAL_MIN * 60)

    stop_event = threading.Event()
    cleanup_thread = threading.Thread(
        target=cleanup_loop, args=(stop_event,), daemon=True
    )
    cleanup_thread.start()
    print(f"MCP server starting on http://{host}:{port} (CODE_DIR={CODE_DIR})")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down MCP server")


if __name__ == "__main__":
    run_server()
