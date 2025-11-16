"""Basic unit tests for the tools automation project.

This file is a renamed copy of the previous `tests/unit/test_basic.py` to avoid
pytest import collisions with `tests/test_basic.py` during discovery.
"""

import pytest
import sys
import os


def test_python_version():
    """Test that we're running a supported Python version."""
    assert sys.version_info >= (3, 8), "Python 3.8+ required"


def test_project_structure():
    """Test that basic project files exist."""
    # Check for key files
    assert os.path.exists("mcp_server.py"), "MCP server should exist"
    assert os.path.exists("agent_dashboard.html"), "Dashboard HTML should exist"
    assert os.path.exists("pytest.ini"), "Pytest config should exist"


def test_imports():
    """Test that key modules can be imported."""
    try:
        import flask  # noqa: F401
        import flask_cors  # noqa: F401
        import requests  # noqa: F401
    except ImportError as e:
        pytest.fail(f"Failed to import required modules: {e}")


def test_agent_helpers_exist():
    """Test that agent helper scripts exist."""
    assert os.path.exists("agents/agent_helpers.sh"), "Agent helpers should exist"


def test_test_structure():
    """Test that test directories exist."""
    assert os.path.exists("tests"), "Tests directory should exist"
    assert os.path.exists("tests/unit"), "Unit tests directory should exist"
    assert os.path.exists(
        "tests/integration"
    ), "Integration tests directory should exist"
    assert os.path.exists("tests/e2e"), "E2E tests directory should exist"
    assert os.path.exists(
        "tests/performance"
    ), "Performance tests directory should exist"
