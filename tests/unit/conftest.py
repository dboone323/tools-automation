"""pytest conftest for tests/unit

Ignore duplicate fallback modules that would otherwise cause import-file
mismatch errors during collection in some environments.
"""

collect_ignore = [
    "test_basic.py",
]
