import os
import time
import subprocess
import pytest
import requests


@pytest.fixture(scope="session")
def mcp_server(request):
    """Start the MCP server in test mode for integration tests.

    Sets `MCP_TEST_MODE=1` by default and uses `MCP_TEST_BYPASS_RATE_LIMIT` env
    variable to control bypass; tests can override by calling the runtime
    endpoints `/ _test/set_rate_limit` as needed.
    """
    env = os.environ.copy()
    env["MCP_TEST_MODE"] = "1"
    # Default to bypass rate limits for tests unless a test wants to explicitly set otherwise
    env.setdefault("MCP_TEST_BYPASS_RATE_LIMIT", "1")
    proc = subprocess.Popen(
        ["python3", "mcp_server.py"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=os.getcwd(), env=env
    )
    # Wait for server to start
    time.sleep(2)
    # Confirm server started
    for _ in range(10):
        try:
            r = requests.get("http://localhost:5005/health", timeout=3)
            if r.status_code in (200, 503, 429):
                break
        except Exception:
            time.sleep(0.5)
    else:
        proc.terminate()
        pytest.fail("MCP server failed to start for tests")
    # Try to ensure server starts with a permissive rate limiter for tests
    try:
        requests.post(
            "http://localhost:5005/_test/set_rate_limit",
            json={"max": int(os.environ.get("RATE_LIMIT_MAX_REQS", "99999")), "bypass": True},
            timeout=2,
        )
    except Exception:
        pass

    yield proc

    # Teardown: reset runtime rate limits to permissive defaults
    try:
        requests.post(
            "http://localhost:5005/_test/set_rate_limit",
            json={"max": int(os.environ.get("RATE_LIMIT_MAX_REQS", "99999")), "bypass": True},
            timeout=2,
        )
        requests.get("http://localhost:5005/_test/reset_rate_limits", timeout=2)
    except Exception:
        pass
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except Exception:
        proc.kill()


@pytest.fixture
def default_headers():
    """Return a default headers dict for tests.
    Tests that want to be whitelisted can use this fixture explicitly.
    """
    return {"X-Client-Id": "test_client"}
