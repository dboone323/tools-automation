import os
import socket
import sys
import threading
import time

import pytest
import requests

# make repository root importable so Tools.Automation can be imported
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
# Import the server runner
import importlib

try:
    mcp_server = importlib.import_module("Tools.Automation.mcp_server")
except Exception:
    # fallback: try loading directly by path
    pkg_path = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    sys.path.insert(0, pkg_path)
    mcp_server = importlib.import_module("mcp_server")


def _find_free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    addr, port = s.getsockname()
    s.close()
    return port


def run_server_in_thread(port, env=None):
    def target():
        # set environment variables for the child server
        if env:
            os.environ.update(env)
            # also set module-level vars so run_server picks them up without new import
            try:
                if "RATE_LIMIT_WINDOW_SEC" in env:
                    mcp_server.RATE_LIMIT_WINDOW_SEC = int(env["RATE_LIMIT_WINDOW_SEC"])
                if "RATE_LIMIT_MAX_REQS" in env:
                    mcp_server.RATE_LIMIT_MAX_REQS = int(env["RATE_LIMIT_MAX_REQS"])
                if "RATE_LIMIT_WHITELIST" in env:
                    mcp_server.RATE_LIMIT_WHITELIST = [
                        c.strip()
                        for c in env["RATE_LIMIT_WHITELIST"].split(",")
                        if c.strip()
                    ]
            except Exception:
                pass
        mcp_server.run_server(host="127.0.0.1", port=port)

    t = threading.Thread(target=target, daemon=True)
    t.start()
    # wait briefly for server to start
    time.sleep(0.8)
    return t


def test_whitelist_bypasses_rate_limit():
    port = _find_free_port()
    base = f"http://127.0.0.1:{port}"
    # set a very small rate limit so we can trip it quickly
    env = {
        "RATE_LIMIT_WINDOW_SEC": "5",
        "RATE_LIMIT_MAX_REQS": "2",
        "RATE_LIMIT_WHITELIST": "test-dashboard,local-controller-TesterProject",
    }
    run_server_in_thread(port, env=env)

    # make requests without header until we get a 429
    ok = 0
    got_429 = False
    for i in range(6):
        r = requests.get(base + "/status")
        if r.status_code == 200:
            ok += 1
        if r.status_code == 429:
            got_429 = True
            break
        time.sleep(0.1)
    assert got_429, "Expected to see a 429 when rate limit exceeded"

    # Now call with whitelisted header; should succeed even after quota reached
    headers = {"X-Client-Id": "test-dashboard"}
    r2 = requests.get(base + "/status", headers=headers)
    assert r2.status_code == 200

    # Also test a whitelisted controller id
    ctrl_headers = {"X-Client-Id": "local-controller-TesterProject"}
    r3 = requests.get(base + "/status", headers=ctrl_headers)
    assert r3.status_code == 200
