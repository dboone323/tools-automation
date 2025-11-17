import os
import time
from types import SimpleNamespace
import threading

from mcp_server import MCPHandler


class DummyHandler(SimpleNamespace):
    def __init__(self, server, client_address=("127.0.0.1", 12345), path="/status", command="GET", headers=None):
        super().__init__()
        self.server = server
        self.client_address = client_address
        self.path = path
        self.command = command
        self.headers = headers or {}


def test_runtime_bypass_precedence_true(monkeypatch):
    server = SimpleNamespace()
    server.rate_limit_lock = threading.Lock()
    server.rate_limit_bypass = True
    server.rate_limit_maxreqs = 1
    # Make counters exceed maxreq so rate limiting would normally apply
    server.request_counters = {"127.0.0.1": [time.time(), time.time()]}
    handler = DummyHandler(server)
    # Should skip rate limiting when runtime bypass True
    assert MCPHandler._is_rate_limited(handler) is False


def test_runtime_bypass_precedence_false(monkeypatch):
    # runtime flag explicitly False should not bypass even if env var set
    server = SimpleNamespace()
    server.rate_limit_lock = threading.Lock()
    server.rate_limit_bypass = False
    server.rate_limit_maxreqs = 1
    # Make counters exceed maxreq so rate limiting would normally apply
    server.request_counters = {"127.0.0.1": [time.time(), time.time()]}
    monkeypatch.setenv("MCP_TEST_MODE", "1")
    monkeypatch.setenv("MCP_TEST_BYPASS_RATE_LIMIT", "1")
    handler = DummyHandler(server)
    # Because runtime_bypass is explicitly False, rate limiting should still apply
    assert MCPHandler._is_rate_limited(handler) is True


def test_env_fallback_bypass(monkeypatch):
    # If runtime flag is None and env fallback enabled, bypass should apply
    server = SimpleNamespace()
    server.rate_limit_lock = threading.Lock()
    # runtime flag not present
    server.rate_limit_maxreqs = 1
    server.request_counters = {"127.0.0.1": [time.time(), time.time()]}
    monkeypatch.setenv("MCP_TEST_MODE", "1")
    monkeypatch.setenv("MCP_TEST_BYPASS_RATE_LIMIT", "1")
    handler = DummyHandler(server)
    assert MCPHandler._is_rate_limited(handler) is False
