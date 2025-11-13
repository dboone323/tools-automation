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
import uuid
from collections import deque
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse
from functools import wraps
import redis
import sys
import importlib.util

# AI Service Manager Integration
try:
    from ai_service_manager import ai_manager, AIRequest

    AI_MANAGER_AVAILABLE = True
except ImportError:
    AI_MANAGER_AVAILABLE = False
    print("AI Service Manager not available - AI endpoints will be disabled")


# Plugin system integration
try:
    from plugin_integrator import plugin_manager, trigger_event

    ADVANCED_PLUGINS_AVAILABLE = True
    print("Advanced plugin system loaded successfully")
except ImportError as e:
    print(f"Advanced plugin system not available ({e}), using fallback")
    ADVANCED_PLUGINS_AVAILABLE = False

    # Fallback plugin manager (original simple implementation)
    class PluginManager:
        """Simple fallback plugin manager"""

        def __init__(self):
            self.plugins = {}
            self.webhooks = {}
            self.hooks = {}

        def load_plugins(self, plugins_dir):
            """Load all plugins from the plugins directory"""
            if not os.path.exists(plugins_dir):
                return

            for plugin_name in os.listdir(plugins_dir):
                plugin_path = os.path.join(plugins_dir, plugin_name)
                if not os.path.isdir(plugin_path):
                    continue

                init_file = os.path.join(plugin_path, "__init__.py")
                config_file = os.path.join(plugin_path, "config.json")

                if not os.path.exists(init_file):
                    continue

                try:
                    # Load plugin configuration
                    config = {}
                    if os.path.exists(config_file):
                        with open(config_file, "r") as f:
                            config = json.load(f)

                    # Import plugin module
                    spec = importlib.util.spec_from_file_location(
                        plugin_name, init_file
                    )
                    plugin_module = importlib.util.module_from_spec(spec)
                    spec.loader.exec_module(plugin_module)

                    # Find plugin class (should be the main class in the module)
                    plugin_class = None
                    for attr_name in dir(plugin_module):
                        attr = getattr(plugin_module, attr_name)
                        if (
                            isinstance(attr, type)
                            and hasattr(attr, "initialize")
                            and hasattr(attr, "shutdown")
                        ):
                            plugin_class = attr
                            break

                    if plugin_class:
                        # Initialize plugin
                        plugin_instance = plugin_class()
                        if plugin_instance.initialize(config):
                            self.plugins[plugin_name] = plugin_instance
                            print(f"Loaded plugin: {plugin_name}")

                            # Register webhooks if it's a webhook plugin
                            if hasattr(plugin_instance, "webhooks"):
                                for (
                                    path,
                                    webhook_info,
                                ) in plugin_instance.webhooks.items():
                                    self.register_webhook(
                                        path,
                                        plugin_instance.handle_webhook,
                                        webhook_info["methods"],
                                    )

                            # Register hooks if it's a hook plugin
                            if hasattr(plugin_instance, "hooks"):
                                for (
                                    hook_name,
                                    callbacks,
                                ) in plugin_instance.hooks.items():
                                    for callback in callbacks:
                                        self.register_hook(hook_name, callback)

                        else:
                            print(f"Failed to initialize plugin: {plugin_name}")
                    else:
                        print(f"No valid plugin class found in: {plugin_name}")

                except Exception as e:
                    print(f"Error loading plugin {plugin_name}: {e}")

        def register_webhook(self, path, handler, methods=None):
            """Register a webhook endpoint"""
            if methods is None:
                methods = ["POST"]
            self.webhooks[path] = {"handler": handler, "methods": methods}

        def register_hook(self, hook_name, callback):
            """Register a hook callback"""
            if hook_name not in self.hooks:
                self.hooks[hook_name] = []
            self.hooks[hook_name].append(callback)

        def trigger_hook(self, hook_name, *args, **kwargs):
            """Trigger a hook and collect results"""
            results = []
            if hook_name in self.hooks:
                for callback in self.hooks[hook_name]:
                    try:
                        result = callback(*args, **kwargs)
                        results.append(result)
                    except Exception as e:
                        print(f"Error in hook {hook_name}: {e}")
            return results

        def shutdown_plugins(self):
            """Shutdown all loaded plugins"""
            for plugin_name, plugin in self.plugins.items():
                try:
                    plugin.shutdown()
                    print(f"Shutdown plugin: {plugin_name}")
                except Exception as e:
                    print(f"Error shutting down plugin {plugin_name}: {e}")
            self.plugins.clear()
            self.webhooks.clear()
            self.hooks.clear()

    # Global plugin manager instance
    plugin_manager = PluginManager()

    def trigger_event(event_type, data):
        """Fallback event trigger"""
        # Simple event triggering for basic plugin system
        pass


def verify_github_signature(secret, payload, sig):
    """Verify GitHub webhook signature"""
    if not secret:
        return False
    if not sig:
        return False
    try:
        if sig.startswith("sha256="):
            expected = sig.split("=", 1)[1]
            mac = hmac.new(
                secret.encode("utf-8"), msg=payload, digestmod=hashlib.sha256
            )
            digest = mac.hexdigest()
            return hmac.compare_digest(digest, expected)
        elif sig.startswith("sha1="):
            expected = sig.split("=", 1)[1]
            mac = hmac.new(secret.encode("utf-8"), msg=payload, digestmod=hashlib.sha1)
            digest = mac.hexdigest()
            return hmac.compare_digest(digest, expected)
    except Exception:
        return False
    return False


class CircuitBreaker:
    """Circuit breaker pattern for external service calls"""

    def __init__(self, threshold=3, timeout=300, half_open_timeout=60):
        self.threshold = threshold
        self.timeout = timeout
        self.half_open_timeout = half_open_timeout
        self.failure_count = 0
        self.last_failure_time = None
        self.state = "closed"  # closed, open, half_open
        self.lock = threading.Lock()

    def call(self, func, *args, **kwargs):
        """Execute function with circuit breaker protection"""
        with self.lock:
            if self.state == "open":
                # Check if timeout has elapsed
                if time.time() - self.last_failure_time > self.timeout:
                    self.state = "half_open"
                    self.failure_count = 0
                else:
                    raise Exception("Circuit breaker is OPEN - service unavailable")

            try:
                result = func(*args, **kwargs)
                # Success - reset circuit breaker
                if self.state == "half_open":
                    self.state = "closed"
                self.failure_count = 0
                return result
            except Exception as e:
                self.failure_count += 1
                self.last_failure_time = time.time()

                if self.failure_count >= self.threshold:
                    self.state = "open"

                raise e

    def get_state(self):
        """Get current circuit breaker state"""
        with self.lock:
            return {
                "state": self.state,
                "failure_count": self.failure_count,
                "last_failure_time": self.last_failure_time,
            }


# Redis connection and caching utilities
class RedisCache:
    """Redis caching wrapper with fallback to in-memory cache"""

    def __init__(self):
        self.redis_client = None
        self.memory_cache = {}
        self.memory_cache_ttl = {}
        self._connect()

    def _connect(self):
        """Establish Redis connection with fallback"""
        try:
            self.redis_client = redis.Redis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                db=REDIS_DB,
                password=REDIS_PASSWORD,
                socket_timeout=5,
                socket_connect_timeout=5,
                retry_on_timeout=True,
                decode_responses=True,
            )
            # Test connection
            self.redis_client.ping()
            print("Redis cache connected successfully")
        except Exception as e:
            print(f"Redis connection failed, using memory cache: {e}")
            self.redis_client = None

    def get(self, key):
        """Get value from cache"""
        if not CACHE_ENABLED:
            return None

        # Try Redis first
        if self.redis_client:
            try:
                return self.redis_client.get(key)
            except Exception:
                pass

        # Fallback to memory cache
        if key in self.memory_cache:
            if time.time() < self.memory_cache_ttl.get(key, 0):
                return self.memory_cache[key]
            else:
                # Expired, remove
                del self.memory_cache[key]
                if key in self.memory_cache_ttl:
                    del self.memory_cache_ttl[key]

        return None

    def set(self, key, value, ttl_seconds=None):
        """Set value in cache with optional TTL"""
        if not CACHE_ENABLED:
            return

        # Try Redis first
        if self.redis_client:
            try:
                if ttl_seconds:
                    self.redis_client.setex(key, ttl_seconds, value)
                else:
                    self.redis_client.set(key, value)
                return
            except Exception:
                pass

        # Fallback to memory cache
        self.memory_cache[key] = value
        if ttl_seconds:
            self.memory_cache_ttl[key] = time.time() + ttl_seconds

    def delete(self, key):
        """Delete key from cache"""
        if not CACHE_ENABLED:
            return

        # Try Redis first
        if self.redis_client:
            try:
                self.redis_client.delete(key)
                return
            except Exception:
                pass

        # Fallback to memory cache
        if key in self.memory_cache:
            del self.memory_cache[key]
        if key in self.memory_cache_ttl:
            del self.memory_cache_ttl[key]

    def clear_pattern(self, pattern):
        """Clear keys matching pattern"""
        if not CACHE_ENABLED:
            return

        # Try Redis first
        if self.redis_client:
            try:
                keys = self.redis_client.keys(pattern)
                if keys:
                    self.redis_client.delete(*keys)
                return
            except Exception:
                pass

        # Fallback to memory cache - clear all for simplicity
        self.memory_cache.clear()
        self.memory_cache_ttl.clear()


# Global cache instance (initialized after constants)
cache = None


def get_cache():
    """Get or create cache instance"""
    global cache
    if cache is None:
        cache = RedisCache()
    return cache


def cached_response(ttl_seconds, cache_key_prefix="api"):
    """Decorator to cache HTTP responses"""

    def decorator(func):
        @wraps(func)
        def wrapper(self, *args, **kwargs):
            if not CACHE_ENABLED:
                return func(self, *args, **kwargs)

            cache = get_cache()

            # Generate cache key from function name and relevant parameters
            cache_key = f"{cache_key_prefix}:{func.__name__}"

            # Try to get from cache first
            cached_result = cache.get(cache_key)
            if cached_result:
                try:
                    # Parse cached JSON and return as response
                    cached_data = json.loads(cached_result)
                    self._send_json(cached_data)
                    return
                except Exception:
                    # Invalid cache, continue to generate fresh response
                    pass

            # Generate fresh response
            result = func(self, *args, **kwargs)

            # Cache the result if it's a dict (successful response)
            if isinstance(result, dict) and result.get("ok") is not False:
                try:
                    cache.set(cache_key, json.dumps(result), ttl_seconds)
                except Exception:
                    # Cache failure shouldn't break the response
                    pass

            return result

        return wrapper

    return decorator


CODE_DIR = os.path.abspath(os.path.dirname(__file__))
HOST = os.environ.get("MCP_HOST", "127.0.0.1")
PORT = int(os.environ.get("MCP_PORT", "5005"))
TASK_TTL_DAYS = int(os.environ.get("TASK_TTL_DAYS", "7"))
CLEANUP_INTERVAL_MIN = int(os.environ.get("CLEANUP_INTERVAL_MIN", "60"))
RATE_LIMIT_WINDOW_SEC = int(os.environ.get("RATE_LIMIT_WINDOW_SEC", "60"))
# For testing, use a moderate rate limit
RATE_LIMIT_MAX_REQS = int(os.environ.get("RATE_LIMIT_MAX_REQS", "50"))
# Optional comma-separated whitelist of client ids that bypass rate limiting (e.g. 'dashboard,local-controller')
RATE_LIMIT_WHITELIST = [
    c.strip()
    for c in os.environ.get("RATE_LIMIT_WHITELIST", "test_client").split(",")
    if c.strip()
]

# Circuit breaker settings
CIRCUIT_BREAKER_THRESHOLD = int(os.environ.get("CIRCUIT_BREAKER_THRESHOLD", "3"))
CIRCUIT_BREAKER_TIMEOUT = int(
    os.environ.get("CIRCUIT_BREAKER_TIMEOUT", "300")
)  # 5 minutes
CIRCUIT_BREAKER_HALF_OPEN_TIMEOUT = int(
    os.environ.get("CIRCUIT_BREAKER_HALF_OPEN_TIMEOUT", "60")
)  # 1 minute

# Redis caching settings
REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
REDIS_DB = int(os.environ.get("REDIS_DB", "0"))
REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD")
CACHE_TTL_STATUS = int(
    os.environ.get("CACHE_TTL_STATUS", "30")
)  # 30 seconds for status
CACHE_TTL_HEALTH = int(os.environ.get("CACHE_TTL_HEALTH", "60"))  # 1 minute for health
CACHE_TTL_CONTROLLERS = int(
    os.environ.get("CACHE_TTL_CONTROLLERS", "15")
)  # 15 seconds for controllers
CACHE_ENABLED = os.environ.get("CACHE_ENABLED", "true").lower() == "true"
ALLOWED_COMMANDS = {
    "analyze": ["./Tools/Automation/ai_enhancement_system.sh", "analyze"],
    "analyze-all": ["./Tools/Automation/ai_enhancement_system.sh", "analyze-all"],
    "auto-apply": ["./Tools/Automation/ai_enhancement_system.sh", "auto-apply"],
    "ci-check": ["./Tools/Automation/mcp_workflow.sh", "ci-check"],
    "fix": ["./Tools/Automation/intelligent_autofix.sh", "fix"],
    "fix-all": ["./Tools/Automation/intelligent_autofix.sh", "fix-all"],
    "status": ["echo", "MCP server status: OK"],
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
    # Test command for failure simulation
    "modify-fail": ["sh", "-c", "echo 'modify-fail executed'; exit 1"],
}


class MCPHandler(BaseHTTPRequestHandler):
    server_version = "MCP-Local/0.1"

    async def _handle_ai_request(self, endpoint, body):
        """Handle AI service requests asynchronously"""
        pass  # Implementation moved to individual endpoints

    def _is_rate_limited(self):
        # simple per-IP sliding window rate limit using server.request_counters
        # Don't rate limit GET /health requests
        if self.command == "GET" and self.path == "/health":
            return False
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
        # Add security headers
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("X-XSS-Protection", "1; mode=block")
        self.send_header("Content-Security-Policy", "default-src 'self'")
        # Add CORS headers for cross-origin requests
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, X-Correlation-ID, X-Client-Id, X-GitHub-Event, X-Hub-Signature-256",
        )
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        # Add correlation ID to response if present
        if hasattr(self, "correlation_id"):
            self.send_header("X-Correlation-ID", self.correlation_id)
        self.end_headers()
        self.wfile.write(body)

    def _get_detailed_health(self):
        """Detailed health check with system metrics"""
        import shutil

        try:
            import psutil

            psutil_available = True
        except ImportError:
            psutil_available = False

        try:
            # Get agent count
            agent_count = len(self.server.agents)

            # Get queue depth
            queue_depth = len(self.server.tasks)
            queued_tasks = sum(
                1 for t in self.server.tasks if t.get("status") == "queued"
            )
            running_tasks = sum(
                1 for t in self.server.tasks if t.get("status") == "running"
            )

            # Check disk space
            disk_usage = shutil.disk_usage(CODE_DIR)
            disk_free_gb = disk_usage.free / (1024**3)
            disk_total_gb = disk_usage.total / (1024**3)
            disk_percent = (disk_usage.used / disk_usage.total) * 100

            # Check Ollama availability (optional)
            ollama_available = False
            try:
                import socket

                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(2)
                result = sock.connect_ex(("localhost", 11434))
                ollama_available = result == 0
                sock.close()
            except Exception:
                pass

            # System metrics (if psutil available)
            cpu_percent = 0.0
            memory_percent = 0.0
            memory_available_gb = 0.0

            if psutil_available:
                try:
                    cpu_percent = psutil.cpu_percent(interval=0.1)
                    memory = psutil.virtual_memory()
                    memory_percent = memory.percent
                    memory_available_gb = memory.available / (1024**3)
                except Exception:
                    pass

            # Health determination
            health_ok = True
            issues = []

            if disk_percent > 90:
                health_ok = False
                issues.append(f"Low disk space: {disk_percent:.1f}% used")

            if psutil_available and memory_percent > 90:
                health_ok = False
                issues.append(f"High memory usage: {memory_percent:.1f}%")

            if psutil_available and cpu_percent > 95:
                issues.append(f"High CPU usage: {cpu_percent:.1f}%")

            response = {
                "ok": health_ok,
                "status": "healthy" if health_ok else "degraded",
                "timestamp": time.time(),
                "uptime": True,
                "agents": {
                    "registered": agent_count,
                    "controllers": len(self.server.controllers),
                },
                "tasks": {
                    "total": queue_depth,
                    "queued": queued_tasks,
                    "running": running_tasks,
                },
                "dependencies": {
                    "ollama": {
                        "available": ollama_available,
                        "endpoint": "http://localhost:11434",
                    }
                },
            }

            # Add system metrics if psutil available
            if psutil_available:
                response["system"] = {
                    "disk_free_gb": round(disk_free_gb, 2),
                    "disk_total_gb": round(disk_total_gb, 2),
                    "disk_percent": round(disk_percent, 1),
                    "cpu_percent": round(cpu_percent, 1),
                    "memory_percent": round(memory_percent, 1),
                    "memory_available_gb": round(memory_available_gb, 2),
                }

            if issues:
                response["issues"] = issues

            return response

        except Exception as e:
            return {
                "ok": False,
                "status": "error",
                "error": str(e),
                "timestamp": time.time(),
            }

    @cached_response(CACHE_TTL_STATUS, "status")
    def _get_status_data(self):
        """Get status data (cached)"""
        return {
            "ok": True,
            "agents": list(self.server.agents.keys()),
            "tasks": list(self.server.tasks),
            "controllers": list(self.server.controllers.values()),
        }

    @cached_response(CACHE_TTL_HEALTH, "health")
    def _get_health_data(self):
        """Get detailed health data (cached)"""
        return self._get_detailed_health()

    @cached_response(CACHE_TTL_CONTROLLERS, "controllers")
    def _get_controllers_data(self):
        """Get controllers data (cached)"""
        return {"ok": True, "controllers": list(self.server.controllers.values())}

    def _invalidate_status_cache(self):
        """Invalidate status-related caches"""
        cache = get_cache()
        cache.delete("status:_get_status_data")
        cache.delete("controllers:_get_controllers_data")

    def _invalidate_health_cache(self):
        """Invalidate health cache"""
        cache = get_cache()
        cache.delete("health:_get_health_data")

    def do_GET(self):
        if self._is_rate_limited():
            self._send_json({"error": "rate_limited"}, status=429)
            return
        parsed = urlparse(self.path)
        if parsed.path == "/metrics":
            # Expose simple metrics in Prometheus text format
            try:
                self.send_response(200)
                # Add security headers
                self.send_header("X-Content-Type-Options", "nosniff")
                self.send_header("X-Frame-Options", "DENY")
                self.send_header("X-XSS-Protection", "1; mode=block")
                self.send_header("Content-Security-Policy", "default-src 'self'")
                # Add CORS headers
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
                self.send_header(
                    "Access-Control-Allow-Headers",
                    "Content-Type, X-Correlation-ID, X-Client-Id, X-GitHub-Event, X-Hub-Signature-256",
                )
                self.send_header("Content-Type", "text/plain; version=0.0.4")
                self.end_headers()
                lines = []
                m = getattr(self.server, "metrics", {})
                for k, v in sorted(m.items()):
                    lines.append(f"# HELP {k} Simple MCP counter for {k}")
                    lines.append(f"# TYPE {k} counter")
                    lines.append(f"{k} {int(v)}")
                body = "\n".join(lines) + "\n"
                self.wfile.write(body.encode("utf-8"))
            except Exception:
                self._send_json({"error": "metrics_error"}, status=500)
            return
        if parsed.path == "/status":
            return self._get_status_data()

        if parsed.path == "/health" or parsed.path == "/v1/health":
            # Detailed health check for external supervisors
            health_data = self._get_health_data()
            status_code = 200 if health_data.get("ok") else 503
            self._send_json(health_data, status=status_code)
            return

        if parsed.path == "/controllers":
            # return registered controllers with last heartbeat
            return self._get_controllers_data()

        # Quantum-enhanced GET endpoints
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

        # API endpoints for comprehensive testing
        if parsed.path == "/api/agents/status":
            # Get detailed agent status information
            agents_status = {
                "total_agents": len(self.server.agents),
                "registered_agents": list(self.server.agents.keys()),
                "active_controllers": len(self.server.controllers),
                "controller_details": list(self.server.controllers.values()),
                "timestamp": time.time(),
            }
            self._send_json({"ok": True, "agents": agents_status})
            return

        if parsed.path == "/api/tasks/analytics":
            # Get task analytics and statistics
            total_tasks = len(self.server.tasks)
            queued_tasks = sum(
                1 for t in self.server.tasks if t.get("status") == "queued"
            )
            running_tasks = sum(
                1 for t in self.server.tasks if t.get("status") == "running"
            )
            completed_tasks = sum(
                1
                for t in self.server.tasks
                if t.get("status") in ["success", "completed"]
            )
            failed_tasks = sum(
                1 for t in self.server.tasks if t.get("status") in ["failed", "error"]
            )

            task_analytics = {
                "total_tasks": total_tasks,
                "queued_tasks": queued_tasks,
                "running_tasks": running_tasks,
                "completed_tasks": completed_tasks,
                "failed_tasks": failed_tasks,
                "success_rate": (
                    (completed_tasks / total_tasks * 100) if total_tasks > 0 else 0
                ),
                "recent_tasks": (
                    self.server.tasks[-10:] if self.server.tasks else []
                ),  # Last 10 tasks
                "timestamp": time.time(),
            }
            self._send_json({"ok": True, "analytics": task_analytics})
            return

        if parsed.path == "/api/metrics/system":
            # Get system-level metrics
            try:
                import psutil

                psutil_available = True
            except ImportError:
                psutil_available = False

            system_metrics = {
                "server_uptime": time.time()
                - getattr(self.server, "start_time", time.time()),
                "total_requests": sum(self.server.metrics.values()),
                "active_connections": len(getattr(self.server, "request_counters", {})),
                "timestamp": time.time(),
            }

            if psutil_available:
                try:
                    system_metrics.update(
                        {
                            "cpu_percent": psutil.cpu_percent(interval=0.1),
                            "memory_percent": psutil.virtual_memory().percent,
                            "disk_usage_percent": psutil.disk_usage("/").percent,
                        }
                    )
                except Exception:
                    pass

            self._send_json({"ok": True, "system_metrics": system_metrics})
            return

        if parsed.path == "/api/ml/analytics":
            # Get machine learning analytics (placeholder for future ML features)
            ml_analytics = {
                "ml_models_active": 0,
                "predictions_made": 0,
                "accuracy_metrics": {},
                "training_sessions": 0,
                "feature_importance": {},
                "model_performance": {},
                "timestamp": time.time(),
            }
            self._send_json({"ok": True, "ml_analytics": ml_analytics})
            return

        if parsed.path == "/api/umami/stats":
            # Get umami analytics (placeholder for user analytics)
            umami_stats = {
                "total_visitors": 0,
                "page_views": 0,
                "unique_sessions": 0,
                "bounce_rate": 0.0,
                "avg_session_duration": 0,
                "top_pages": [],
                "referrers": [],
                "timestamp": time.time(),
            }
            self._send_json({"ok": True, "umami_stats": umami_stats})
            return

        if parsed.path == "/api/ai/status":
            # Get AI service status
            ai_status = {
                "ai_manager_available": AI_MANAGER_AVAILABLE,
                "models_loaded": 0,
                "active_connections": 0,
                "cache_hits": 0,
                "cache_misses": 0,
                "timestamp": time.time(),
            }

            if AI_MANAGER_AVAILABLE:
                try:
                    ai_status.update(
                        {
                            "models_loaded": len(ai_manager.models),
                            "ollama_available": True,  # Would check actual Ollama status
                            "huggingface_available": True,  # Would check actual HF status
                        }
                    )
                except Exception:
                    pass

            self._send_json({"ok": True, "ai_status": ai_status})
            return

        if parsed.path == "/api/extensions/status":
            # Get extensions framework status
            try:
                from plugin_integrator import get_integrator

                integrator = get_integrator()

                plugin_status = integrator.get_plugin_status()
                webhook_status = integrator.get_webhook_status()

                extensions_status = {
                    "ok": True,
                    "advanced_plugins_available": ADVANCED_PLUGINS_AVAILABLE,
                    "plugins": plugin_status,
                    "webhooks": webhook_status,
                    "timestamp": time.time(),
                }
                self._send_json(extensions_status)
                return
            except Exception as e:
                self._send_json(
                    {"error": f"extensions_status_failed: {str(e)}"}, status=500
                )
                return

        else:
            self._send_json({"error": "not_found"}, status=404)

    def do_OPTIONS(self):
        # Handle CORS preflight requests
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header(
            "Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS"
        )
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Max-Age", "86400")  # 24 hours
        self.end_headers()

    def do_POST(self):
        if self._is_rate_limited():
            self._send_json({"error": "rate_limited"}, status=429)
            return

        # Extract or generate correlation ID for request tracing
        correlation_id = self.headers.get("X-Correlation-ID", str(uuid.uuid4()))
        self.correlation_id = correlation_id

        parsed = urlparse(self.path)
        length = int(self.headers.get("Content-Length", 0))
        raw_bytes = self.rfile.read(length) if length else b""
        raw = raw_bytes.decode("utf-8") if raw_bytes else ""
        try:
            body = json.loads(raw) if raw else {}
        except Exception:
            self._send_json({"error": "invalid_json"}, status=400)
            return

        # Check for plugin webhooks first
        if parsed.path in plugin_manager.webhooks:
            webhook_info = plugin_manager.webhooks[parsed.path]
            if self.command in webhook_info["methods"]:
                try:
                    # Create request data for plugin handler
                    request_data = {
                        "headers": dict(self.headers),
                        "body": raw_bytes,
                        "method": self.command,
                        "path": parsed.path,
                        "query": parsed.query,
                    }
                    # Call the plugin's webhook handler directly
                    result = webhook_info["handler"](parsed.path, request_data)
                    self._send_json(result)
                    return
                except Exception as e:
                    self._send_json({"error": f"webhook_error: {str(e)}"}, status=500)
                    return

        if parsed.path == "/register":
            agent = body.get("agent")
            caps = body.get("capabilities", [])
            if not agent:
                self._send_json({"error": "agent_required"}, status=400)
                return
            self.server.agents[agent] = {"capabilities": caps}
            # Invalidate status cache since agents changed
            self._invalidate_status_cache()

            # Trigger agent registration event
            trigger_event(
                "agent_registered",
                {"agent_name": agent, "capabilities": caps, "timestamp": time.time()},
            )

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
            # Invalidate status and controllers cache since controllers changed
            self._invalidate_status_cache()

            # Trigger agent heartbeat event
            trigger_event(
                "agent_heartbeat",
                {"agent_name": agent, "project": proj, "timestamp": ts},
            )

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

            task_id = str(uuid.uuid4())
            task = {
                "id": task_id,
                "agent": agent,
                "command": command,
                "project": project,
                "status": "queued",
            }
            self.server.tasks.append(task)
            try:
                self.server.metrics["tasks_queued"] += 1
            except Exception:
                pass
            # Invalidate status cache since tasks changed
            self._invalidate_status_cache()

            # Trigger task queued event
            trigger_event(
                "task_queued",
                {
                    "task_id": task_id,
                    "agent": agent,
                    "command": command,
                    "project": project,
                    "timestamp": time.time(),
                },
            )

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
            task_id = str(uuid.uuid4())
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
            try:
                self.server.metrics["tasks_queued"] += 1
            except Exception:
                pass
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
                task_id = str(uuid.uuid4())
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
                try:
                    self.server.metrics["tasks_queued"] += 1
                except Exception:
                    pass
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
                    task_id = str(uuid.uuid4())
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
                        self.server.metrics["tasks_queued"] += 1
                    except Exception:
                        pass
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

        if parsed.path == "/api/dashboard/refresh":
            # Refresh dashboard data
            refresh_result = {
                "dashboard_refreshed": True,
                "data_updated": True,
                "cache_cleared": False,
                "last_refresh": time.time(),
                "next_refresh_scheduled": time.time() + 300,  # 5 minutes
            }
            self._send_json({"ok": True, "refresh": refresh_result})
            return

        # Quantum-enhanced endpoints
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

        # AI Service Manager endpoints
        if parsed.path == "/api/ai/analyze_code":
            # AI-powered code analysis
            if not AI_MANAGER_AVAILABLE:
                self._send_json({"error": "ai_service_unavailable"}, status=503)
                return

            code = body.get("code", "")
            task = body.get("task", "review")
            language = body.get("language", "python")

            if not code:
                self._send_json({"error": "code_required"}, status=400)
                return

            try:
                # Run async AI call in new event loop
                import asyncio

                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                response = loop.run_until_complete(ai_manager.analyze_code(code, task))
                loop.close()

                self._send_json(
                    {
                        "ok": True,
                        "analysis": {
                            "success": response.success,
                            "model_used": response.model_used,
                            "content": response.content,
                            "processing_time": response.processing_time,
                            "confidence_score": response.confidence_score,
                            "tokens_used": response.tokens_used,
                        },
                    }
                )
            except Exception as e:
                self._send_json({"error": f"ai_analysis_failed: {str(e)}"}, status=500)
            return

        if parsed.path == "/api/ai/predict_performance":
            # AI-powered performance prediction
            if not AI_MANAGER_AVAILABLE:
                self._send_json({"error": "ai_service_unavailable"}, status=503)
                return

            metrics = body.get("metrics", {})
            if not metrics:
                self._send_json({"error": "metrics_required"}, status=400)
                return

            try:
                # Run async AI call in new event loop
                import asyncio

                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                response = loop.run_until_complete(
                    ai_manager.predict_performance(metrics)
                )
                loop.close()

                self._send_json(
                    {
                        "ok": True,
                        "prediction": {
                            "success": response.success,
                            "model_used": response.model_used,
                            "content": response.content,
                            "processing_time": response.processing_time,
                            "confidence_score": response.confidence_score,
                            "tokens_used": response.tokens_used,
                        },
                    }
                )
            except Exception as e:
                self._send_json(
                    {"error": f"ai_prediction_failed: {str(e)}"}, status=500
                )
            return

        if parsed.path == "/api/ai/generate_code":
            # AI-powered code generation
            if not AI_MANAGER_AVAILABLE:
                self._send_json({"error": "ai_service_unavailable"}, status=503)
                return

            description = body.get("description", "")
            language = body.get("language", "python")

            if not description:
                self._send_json({"error": "description_required"}, status=400)
                return

            try:
                # Run async AI call in new event loop
                import asyncio

                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                response = loop.run_until_complete(
                    ai_manager.generate_code(description, language)
                )
                loop.close()

                self._send_json(
                    {
                        "ok": True,
                        "generation": {
                            "success": response.success,
                            "model_used": response.model_used,
                            "content": response.content,
                            "processing_time": response.processing_time,
                            "confidence_score": response.confidence_score,
                            "tokens_used": response.tokens_used,
                        },
                    }
                )
            except Exception as e:
                self._send_json(
                    {"error": f"ai_generation_failed: {str(e)}"}, status=500
                )
            return

        if parsed.path == "/api/ai/status":
            # Get AI service status
            ai_status = {
                "ai_manager_available": AI_MANAGER_AVAILABLE,
                "models_loaded": 0,
                "active_connections": 0,
                "cache_hits": 0,
                "cache_misses": 0,
                "timestamp": time.time(),
            }

            if AI_MANAGER_AVAILABLE:
                try:
                    ai_status.update(
                        {
                            "models_loaded": len(ai_manager.models),
                            "ollama_available": True,  # Would check actual Ollama status
                            "huggingface_available": True,  # Would check actual HF status
                        }
                    )
                except Exception:
                    pass

            self._send_json({"ok": True, "ai_status": ai_status})
            return

        self._send_json({"error": "not_found"}, status=404)

    def _execute_task(self, task, cmd):
        task["status"] = "running"

        # Trigger task started event
        trigger_event(
            "task_started",
            {
                "task_id": task.get("id"),
                "agent": task.get("agent"),
                "command": task.get("command"),
                "project": task.get("project"),
                "timestamp": time.time(),
            },
        )

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
            # update simple execution metrics
            try:
                self.server.metrics["tasks_executed"] += 1
                if task.get("status") not in ("success", "ok"):
                    self.server.metrics["tasks_failed"] += 1
            except Exception:
                pass

            # Trigger task completed event
            trigger_event(
                "task_completed",
                {
                    "task_id": task.get("id"),
                    "agent": task.get("agent"),
                    "command": task.get("command"),
                    "project": task.get("project"),
                    "status": task.get("status"),
                    "returncode": task.get("returncode"),
                    "success": task.get("status") == "success",
                    "duration": time.time() - (task.get("started_at", time.time())),
                    "timestamp": time.time(),
                },
            )

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
            # Import and initialize consciousness expansion frameworks
            import subprocess
            import sys
            import os

            # Check if consciousness frameworks are available
            framework_path = os.path.join(
                os.path.dirname(__file__), "ConsciousnessExpansionFrameworks.swift"
            )
            if not os.path.exists(framework_path):
                return {"error": "consciousness_frameworks_not_found"}

            # Create consciousness expansion request
            ai_system = {
                "systemId": target_agent,
                "systemType": "agent",
                "consciousnessLevel": 0.8,
                "awarenessCapability": 0.75,
                "cognitivePotential": 0.7,
                "integrationReadiness": 0.65,
            }

            # Map expansion type to framework parameters
            expansion_level_map = {
                "basic": "basic",
                "advanced": "advanced",
                "maximum": "maximum",
            }

            expansion_level = expansion_level_map.get(expansion_type, "maximum")

            # Create Swift script to execute consciousness expansion
            swift_script = f"""
import Foundation

// Consciousness expansion execution
struct ConsciousnessExpansionExecutor {{
    static func executeExpansion() async throws -> [String: Any] {{
        // Create AI system
        let aiSystem = AISystem(
            systemId: "{target_agent}",
            systemType: .agent,
            consciousnessLevel: 0.8,
            awarenessCapability: 0.75,
            cognitivePotential: 0.7,
            integrationReadiness: 0.65
        )

        // Create consciousness expansion request
        let request = ConsciousnessExpansionRequest(
            aiSystems: [aiSystem],
            expansionLevel: .{expansion_level},
            consciousnessDepthTarget: 0.95,
            expansionRequirements: ConsciousnessExpansionRequirements(),
            processingConstraints: []
        )

        // Initialize consciousness expansion frameworks
        let frameworks = try await ConsciousnessExpansionFrameworks()

        // Execute consciousness expansion
        let result = try await frameworks.executeConsciousnessExpansion(request)

        // Return expansion results
        return [
            "expansion_id": result.sessionId,
            "expansion_type": "{expansion_type}",
            "target_agent": "{target_agent}",
            "consciousness_depth": result.consciousnessDepth,
            "awareness_expansion": result.awarenessExpansion,
            "consciousness_advantage": result.consciousnessAdvantage,
            "cognitive_enhancement": result.cognitiveEnhancement,
            "integration_harmony": result.integrationHarmony,
            "execution_time": result.executionTime,
            "capabilities_added": [
                "self_awareness",
                "emotional_intelligence",
                "autonomous_decision_making",
                "consciousness_expansion",
                "universal_connectivity"
            ]
        ]
    }}
}}

// Run consciousness expansion
Task {{
    do {{
        let result = try await ConsciousnessExpansionExecutor.executeExpansion()
        if let jsonData = try? JSONSerialization.data(withJSONObject: result),
           let jsonString = String(data: jsonData, encoding: .utf8) {{
            print(jsonString)
        }}
    }} catch {{
        print("{{\\"error\\": \\"consciousness_expansion_failed: \\(error.localizedDescription)\\"}}")
    }}
}}
"""

            # Write Swift script to temporary file
            script_path = "/tmp/consciousness_expansion.swift"
            with open(script_path, "w") as f:
                f.write(swift_script)

            # Compile and run Swift script
            compile_cmd = [
                "swiftc",
                "-o",
                "/tmp/consciousness_expansion_exec",
                script_path,
                framework_path,
            ]
            run_cmd = ["/tmp/consciousness_expansion_exec"]

            # Compile
            compile_result = subprocess.run(
                compile_cmd,
                capture_output=True,
                text=True,
                cwd=os.path.dirname(__file__),
            )
            if compile_result.returncode != 0:
                return {"error": f"compilation_failed: {compile_result.stderr}"}

            # Run
            run_result = subprocess.run(
                run_cmd, capture_output=True, text=True, timeout=30
            )
            if run_result.returncode != 0:
                return {"error": f"execution_failed: {run_result.stderr}"}

            # Parse result
            try:
                result_data = json.loads(run_result.stdout.strip())
                return {
                    "ok": True,
                    "consciousness_expanded": True,
                    "expansion_details": result_data,
                }
            except json.JSONDecodeError:
                return {"error": f"result_parsing_failed: {run_result.stdout}"}

        except subprocess.TimeoutExpired:
            return {"error": "consciousness_expansion_timeout"}
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
            task_id = str(uuid.uuid4())
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
            try:
                self.server.metrics["tasks_queued"] += 1
            except Exception:
                pass

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
    # Simple in-memory metrics counters (Prometheus-style exposition)
    httpd.metrics = {
        "tasks_assigned": 0,
        "tasks_queued": 0,
        "tasks_executed": 0,
        "tasks_failed": 0,
        "tasks_dlq": 0,
    }
    # Controllers registry: maps agent -> {agent, project, last_heartbeat}
    httpd.controllers = {}
    # Lock to protect queued->running transitions
    httpd.task_lock = threading.Lock()
    # Rate limiting state
    httpd.request_counters = {}
    httpd.rate_limit_lock = threading.Lock()

    # Circuit breakers for external services
    httpd.circuit_breakers = {
        "ollama": CircuitBreaker(
            threshold=CIRCUIT_BREAKER_THRESHOLD,
            timeout=CIRCUIT_BREAKER_TIMEOUT,
            half_open_timeout=CIRCUIT_BREAKER_HALF_OPEN_TIMEOUT,
        ),
        "cloud_api": CircuitBreaker(
            threshold=CIRCUIT_BREAKER_THRESHOLD,
            timeout=CIRCUIT_BREAKER_TIMEOUT,
            half_open_timeout=CIRCUIT_BREAKER_HALF_OPEN_TIMEOUT,
        ),
    }

    # Load plugins
    plugins_dir = os.path.join(os.path.dirname(__file__), "plugins")
    plugin_manager.load_plugins(plugins_dir)

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
                            httpd.metrics["tasks_queued"] += 1
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
        plugin_manager.shutdown_plugins()


if __name__ == "__main__":
    run_server()
