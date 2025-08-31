import json
import os
import sys

import pytest

# make top-level 'Tools' package importable during tests
sys.path.insert(
    0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
)
# Skip tests if Flask is not available in the environment
pytest.importorskip("flask")
from Tools.Automation import mcp_dashboard_flask as dashboard


# Use Flask test client
@pytest.fixture
def client():
    dashboard.app.config["TESTING"] = True
    with dashboard.app.test_client() as c:
        yield c


class DummyResponse:
    def __init__(self, status_code=200, text='{"ok":true}', headers=None):
        self.status_code = status_code
        self.text = text
        self.headers = headers or {"Content-Type": "application/json"}

    def json(self):
        return json.loads(self.text)


def test_api_status_happypath(monkeypatch, client):
    # simulate MCP /status returns valid JSON
    def fake_get(url, timeout=0):
        if url.endswith("/status"):
            return DummyResponse(
                200, text='{"ok": true, "tasks": [], "controllers": []}'
            )
        if url.endswith("/controllers"):
            return DummyResponse(200, text='{"controllers": []}')
        raise RuntimeError("unexpected")

    monkeypatch.setattr(dashboard.session, "get", fake_get, raising=False)
    rv = client.get("/api/status")
    assert rv.status_code == 200
    data = rv.get_json()
    assert data.get("ok") is True


def test_health_unavailable(monkeypatch, client):
    # simulate MCP /health raising an exception
    def fake_get(url, timeout=0):
        raise Exception("conn refused")

    monkeypatch.setattr(dashboard.session, "get", fake_get, raising=False)
    rv = client.get("/health")
    assert rv.status_code == 503
    data = rv.get_json()
    assert data.get("ok") is False
