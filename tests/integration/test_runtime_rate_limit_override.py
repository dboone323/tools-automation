import os
import time
import requests
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed


def start_mcp_server(env_overrides=None):
    env = os.environ.copy()
    env.update(env_overrides or {})
    proc = subprocess.Popen(["python3", "mcp_server.py"], cwd=os.getcwd(), env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    # wait for server
    time.sleep(2)
    return proc


def stop_mcp_server(proc):
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()


def make_requests_concurrent(count, max_workers=20):
    def _req():
        try:
            r = requests.get("http://localhost:5005/status", timeout=3)
            return r.status_code
        except Exception:
            return None

    with ThreadPoolExecutor(max_workers=max_workers) as ex:
        futures = [ex.submit(_req) for _ in range(count)]
        return [f.result() for f in as_completed(futures)]


def test_runtime_rate_limit_override_precedence():
    # Start server with test mode enabled and env bypass true (default fallback)
    proc = start_mcp_server({"MCP_TEST_MODE": "1", "MCP_TEST_BYPASS_RATE_LIMIT": "1"})
    try:
        # Ensure server reachable
        time.sleep(0.5)
        r = requests.get("http://localhost:5005/health", timeout=3)
        assert r.status_code in (200, 503)

        # Set a low max and disable bypass runtime to force rate limits
        requests.post("http://localhost:5005/_test/set_rate_limit", json={"max": 5, "bypass": False})
        requests.get("http://localhost:5005/_test/reset_rate_limits")
        time.sleep(0.5)

        responses = make_requests_concurrent(100, max_workers=50)
        successes = sum(1 for s in responses if s == 200)
        rate_limited = sum(1 for s in responses if s == 429)
        assert rate_limited > 0
        assert successes > 0

        # Now enable bypass at runtime and confirm no 429s
        set_resp = requests.post("http://localhost:5005/_test/set_rate_limit", json={"max": 5, "bypass": True})
        set_data = set_resp.json() if set_resp is not None else {}
        assert set_data.get("rate_limit_bypass", False) is True
        requests.get("http://localhost:5005/_test/reset_rate_limits")
        time.sleep(0.5)

        responses = make_requests_concurrent(100, max_workers=50)
        rate_limited = sum(1 for s in responses if s == 429)
        assert rate_limited == 0

    finally:
        # Reset bypass at the end so other tests are not affected
        try:
            requests.post("http://localhost:5005/_test/set_rate_limit", json={"max": 99999, "bypass": True}, timeout=2)
            requests.get("http://localhost:5005/_test/reset_rate_limits", timeout=2)
        except Exception:
            pass
        stop_mcp_server(proc)
