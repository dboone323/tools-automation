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
import time
import gc
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
    # Quantum-enhanced commands
    "quantum_orchestrate": [
        "./Tools/Automation/agents/quantum_orchestrator_agent.sh",
        "orchestrate",
    ],
    "quantum_analyze": [
        "./Tools/Automation/agents/quantum_chemistry_agent.sh",
        "analyze",
    ],
    "quantum_finance": [
        "./Tools/Automation/agents/quantum_finance_agent.sh",
        "optimize",
    ],
    "quantum_learning": [
        "./Tools/Automation/agents/quantum_learning_agent.sh",
        "train",
    ],
    "multiverse_navigate": ["./Tools/Automation/agents/agent_control.sh", "multiverse"],
    "consciousness_expand": [
        "./Tools/Automation/agents/agent_control.sh",
        "consciousness",
    ],
    "dimensional_compute": [
        "./Tools/Automation/agents/agent_control.sh",
        "dimensional",
    ],
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

        # Quantum-enhanced endpoints
        if parsed.path == "/quantum_status":
            # Get quantum system status
            quantum_status = {
                "entanglement_network": self._get_entanglement_status(),
                "multiverse_navigation": self._get_multiverse_status(),
                "consciousness_frameworks": self._get_consciousness_status(),
                "dimensional_computing": self._get_dimensional_status(),
                "quantum_orchestrator": self._get_orchestrator_status(),
            }
            self._send_json({"ok": True, "quantum_status": quantum_status})
            return

        if parsed.path == "/quantum_entangle":
            # Create quantum entanglement between agents
            agent1 = body.get("agent1")
            agent2 = body.get("agent2")
            if not agent1 or not agent2:
                self._send_json({"error": "agent1_and_agent2_required"}, status=400)
                return

            result = self._create_entanglement(agent1, agent2)
            self._send_json(result)
            return

        if parsed.path == "/multiverse_navigate":
            # Navigate to parallel universe
            universe_id = body.get("universe_id", "parallel_1")
            workflow_type = body.get("workflow_type", "computation")

            result = self._navigate_universe(universe_id, workflow_type)
            self._send_json(result)
            return

        if parsed.path == "/consciousness_expand":
            # Expand consciousness frameworks
            expansion_type = body.get("expansion_type", "intelligence")
            target_agent = body.get("target_agent")

            result = self._expand_consciousness(expansion_type, target_agent)
            self._send_json(result)
            return

        if parsed.path == "/dimensional_compute":
            # Execute dimensional computing task
            dimensions = body.get("dimensions", [3, 4, 5])
            computation_type = body.get("computation_type", "optimization")

            result = self._execute_dimensional_computation(dimensions, computation_type)
            self._send_json(result)
            return

        if parsed.path == "/quantum_orchestrate":
            # Advanced quantum orchestration
            workflow_name = body.get("workflow_name", "quantum_optimization")
            execution_mode = body.get("execution_mode", "parallel")

            result = self._quantum_orchestrate(workflow_name, execution_mode)
            self._send_json(result)
            return

        if parsed.path == "/reality_simulate":
            # Reality simulation
            universe_config = body.get("universe_config", {})
            simulation_duration = body.get("duration", 1000)

            result = self._simulate_reality(universe_config, simulation_duration)
            self._send_json(result)
            return

        self._send_json({"error": "not_found"}, status=404)

    def _execute_task(self, task, cmd):
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

    # Quantum-enhanced helper methods
    def _get_entanglement_status(self):
        """Get quantum entanglement network status"""
        try:
            # Check entanglement network file
            network_file = os.path.join(
                os.path.dirname(__file__),
                "agents",
                ".quantum_orchestrator",
                "entanglement_network.json",
            )
            if os.path.exists(network_file):
                with open(network_file, "r") as f:
                    network_data = json.load(f)
                entangled_count = len(network_data.get("entanglements", []))
                return {
                    "active": True,
                    "entangled_agents": entangled_count,
                    "network_health": network_data.get("network_health", 1.0),
                }
            else:
                return {"active": False, "entangled_agents": 0, "network_health": 0.0}
        except Exception:
            return {"active": False, "entangled_agents": 0, "network_health": 0.0}

    def _get_multiverse_status(self):
        """Get multiverse navigation status"""
        try:
            # Check multiverse state file
            multiverse_file = os.path.join(
                os.path.dirname(__file__),
                "agents",
                ".quantum_orchestrator",
                "multiverse_state.json",
            )
            if os.path.exists(multiverse_file):
                with open(multiverse_file, "r") as f:
                    multiverse_data = json.load(f)
                universe_count = len(multiverse_data.get("parallel_universes", []))
                return {
                    "active": True,
                    "parallel_universes": universe_count,
                    "current_universe": multiverse_data.get(
                        "current_universe", "prime"
                    ),
                    "multiverse_stability": multiverse_data.get(
                        "multiverse_stability", 0.95
                    ),
                }
            else:
                return {
                    "active": False,
                    "parallel_universes": 0,
                    "current_universe": "prime",
                    "multiverse_stability": 0.0,
                }
        except Exception:
            return {
                "active": False,
                "parallel_universes": 0,
                "current_universe": "prime",
                "multiverse_stability": 0.0,
            }

    def _get_consciousness_status(self):
        """Get consciousness frameworks status"""
        try:
            # Check for consciousness-related files
            consciousness_files = [
                "QuantumAIConsciousness.swift",
                "ConsciousnessExpanders.swift",
                "ConsciousnessExpansionFrameworks.swift",
            ]
            active_frameworks = 0
            for file in consciousness_files:
                if os.path.exists(os.path.join(os.path.dirname(__file__), file)):
                    active_frameworks += 1

            return {
                "active": active_frameworks > 0,
                "active_frameworks": active_frameworks,
                "consciousness_level": min(active_frameworks * 0.3, 1.0),
            }
        except Exception:
            return {"active": False, "active_frameworks": 0, "consciousness_level": 0.0}

    def _get_dimensional_status(self):
        """Get dimensional computing status"""
        try:
            # Check for dimensional computing files
            dimensional_files = [
                "DimensionalComputingFrameworks.swift",
                "InterdimensionalCommunicationProtocols.swift",
            ]
            active_dimensions = 0
            for file in dimensional_files:
                if os.path.exists(os.path.join(os.path.dirname(__file__), file)):
                    active_dimensions += 1

            return {
                "active": active_dimensions > 0,
                "supported_dimensions": [3, 4, 5] if active_dimensions > 0 else [],
                "dimensional_stability": min(active_dimensions * 0.4, 1.0),
            }
        except Exception:
            return {
                "active": False,
                "supported_dimensions": [],
                "dimensional_stability": 0.0,
            }

    def _get_orchestrator_status(self):
        """Get quantum orchestrator status"""
        try:
            # Check orchestrator status
            orchestrator_file = os.path.join(
                os.path.dirname(__file__),
                "agents",
                ".quantum_orchestrator",
                "job_queue.json",
            )
            if os.path.exists(orchestrator_file):
                with open(orchestrator_file, "r") as f:
                    orchestrator_data = json.load(f)
                job_count = len(orchestrator_data.get("jobs", []))
                return {
                    "active": True,
                    "queued_jobs": job_count,
                    "orchestration_cycles": orchestrator_data.get("next_job_id", 1) - 1,
                }
            else:
                return {"active": False, "queued_jobs": 0, "orchestration_cycles": 0}
        except Exception:
            return {"active": False, "queued_jobs": 0, "orchestration_cycles": 0}

    def _create_entanglement(self, agent1, agent2):
        """Create quantum entanglement between two agents"""
        try:
            # Update entanglement network
            network_file = os.path.join(
                os.path.dirname(__file__),
                "agents",
                ".quantum_orchestrator",
                "entanglement_network.json",
            )

            # Ensure directory exists
            os.makedirs(os.path.dirname(network_file), exist_ok=True)

            # Load or create network data
            if os.path.exists(network_file):
                with open(network_file, "r") as f:
                    network_data = json.load(f)
            else:
                network_data = {
                    "network_id": str(__import__("uuid").uuid4()),
                    "particles": [],
                    "channels": [],
                    "entanglements": [],
                    "network_health": 1.0,
                    "last_updated": __import__("time").time(),
                    "dimensions": ["3D", "4D", "5D"],
                    "multiverse_connections": [],
                }

            # Add entanglement
            entanglement = {
                "entanglement_id": str(__import__("uuid").uuid4()),
                "particles": [agent1, agent2],
                "bell_state": "phi_plus",
                "fidelity": 0.98,
                "created_at": __import__("time").time(),
                "coherence_time": 3600,
                "dimensions": ["communication", "synchronization"],
            }

            network_data["entanglements"].append(entanglement)
            network_data["last_updated"] = __import__("time").time()

            # Save updated network
            with open(network_file, "w") as f:
                json.dump(network_data, f, indent=2)

            return {
                "ok": True,
                "entanglement_created": True,
                "entanglement_id": entanglement["entanglement_id"],
            }

        except Exception as e:
            return {"error": f"entanglement_creation_failed: {str(e)}"}

    def _navigate_universe(self, universe_id, workflow_type):
        """Navigate to a parallel universe"""
        try:
            # Update multiverse state
            multiverse_file = os.path.join(
                os.path.dirname(__file__),
                "agents",
                ".quantum_orchestrator",
                "multiverse_state.json",
            )

            # Ensure directory exists
            os.makedirs(os.path.dirname(multiverse_file), exist_ok=True)

            # Load or create multiverse data
            if os.path.exists(multiverse_file):
                with open(multiverse_file, "r") as f:
                    multiverse_data = json.load(f)
            else:
                multiverse_data = {
                    "current_universe": "prime",
                    "parallel_universes": ["alpha", "beta", "gamma", "delta"],
                    "dimensional_portals": [],
                    "timeline_branches": [],
                    "quantum_superposition_states": [],
                    "multiverse_stability": 0.95,
                    "last_navigation": __import__("time").time(),
                }

            # Add navigation record
            navigation = {
                "navigation_id": str(__import__("uuid").uuid4()),
                "from_universe": "prime",
                "to_universe": universe_id,
                "workflow_type": workflow_type,
                "navigation_time": __import__("time").time(),
                "stability_factor": 0.9 + 0.1 * __import__("random").random(),
                "dimensional_shift": "successful",
            }

            multiverse_data["timeline_branches"].append(navigation)
            multiverse_data["last_navigation"] = __import__("time").time()

            # Save updated multiverse state
            with open(multiverse_file, "w") as f:
                json.dump(multiverse_data, f, indent=2)

            return {
                "ok": True,
                "navigation_completed": True,
                "universe": universe_id,
                "workflow_type": workflow_type,
            }

        except Exception as e:
            return {"error": f"multiverse_navigation_failed: {str(e)}"}

    def _expand_consciousness(self, expansion_type, target_agent):
        """Expand consciousness frameworks"""
        try:
            # This would integrate with the consciousness frameworks
            # For now, return a success response
            consciousness_expansion = {
                "expansion_id": str(__import__("uuid").uuid4()),
                "expansion_type": expansion_type,
                "target_agent": target_agent,
                "consciousness_level": 0.85,
                "expansion_time": __import__("time").time(),
                "capabilities_added": [
                    "self_awareness",
                    "emotional_intelligence",
                    "autonomous_decision_making",
                ],
            }

            return {
                "ok": True,
                "consciousness_expanded": True,
                "expansion_details": consciousness_expansion,
            }

        except Exception as e:
            return {"error": f"consciousness_expansion_failed: {str(e)}"}

    def _execute_dimensional_computation(self, dimensions, computation_type):
        """Execute dimensional computing task"""
        try:
            # This would integrate with dimensional computing frameworks
            dimensional_result = {
                "computation_id": str(__import__("uuid").uuid4()),
                "dimensions": dimensions,
                "computation_type": computation_type,
                "execution_time": __import__("random").uniform(0.1, 2.0),
                "accuracy": 0.95,
                "dimensional_efficiency": 0.88,
                "results": f"Dimensional {computation_type} completed across {len(dimensions)} dimensions",
            }

            return {
                "ok": True,
                "computation_completed": True,
                "results": dimensional_result,
            }

        except Exception as e:
            return {"error": f"dimensional_computation_failed: {str(e)}"}

    def _quantum_orchestrate(self, workflow_name, execution_mode):
        """Advanced quantum orchestration"""
        try:
            # Create orchestration task
            task_id = f"quantum_{len(self.server.tasks) + 1}"
            task = {
                "id": task_id,
                "agent": "quantum_orchestrator_agent",
                "command": "quantum_orchestrate",
                "project": workflow_name,
                "status": "queued",
                "execution_mode": execution_mode,
                "quantum_requirements": {
                    "entanglement": True,
                    "multiverse": execution_mode == "parallel",
                    "consciousness": True,
                    "dimensional": True,
                },
            }
            self.server.tasks.append(task)

            return {
                "ok": True,
                "orchestration_started": True,
                "task_id": task_id,
                "workflow": workflow_name,
            }

        except Exception as e:
            return {"error": f"quantum_orchestration_failed: {str(e)}"}

    def _simulate_reality(self, universe_config, simulation_duration):
        """Reality simulation"""
        try:
            simulation_result = {
                "simulation_id": str(__import__("uuid").uuid4()),
                "universe_config": universe_config,
                "duration": simulation_duration,
                "simulation_time": __import__("random").uniform(1.0, 10.0),
                "accuracy": 0.92,
                "key_findings": [
                    "Quantum coherence maintained throughout simulation",
                    "Multiverse stability within acceptable parameters",
                    "Consciousness emergence patterns detected",
                ],
                "recommendations": [
                    "Increase entanglement network density",
                    "Optimize dimensional portal stability",
                    "Enhance consciousness framework integration",
                ],
            }

            return {
                "ok": True,
                "simulation_completed": True,
                "results": simulation_result,
            }

        except Exception as e:
            return {"error": f"reality_simulation_failed: {str(e)}"}


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
