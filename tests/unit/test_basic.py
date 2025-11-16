"""Duplicate fallback tests for local development.

This file is a duplicate of `tests/test_basic.py` and may cause pytest import
collisions during discovery on some environments. To avoid collection while we
stabilize the test suite, skip this module; the canonical copy is
`tests/test_basic.py`.
"""

import pytest

pytest.skip(
    "duplicate test module (use tests/test_basic.py) — skipping",
    allow_module_level=True,
)
