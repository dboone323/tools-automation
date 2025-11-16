#!/usr/bin/env python3
"""Flag tests with single assertion (heuristic).
Outputs reports/low_assert_tests.json
"""
import re
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "reports" / "low_assert_tests.json"
REPORT.parent.mkdir(exist_ok=True)

ASSERT_PATTERNS = [r"assert\s", r"XCTAssert", r"\[\[.*\]\]"]

results = []
for path in ROOT.rglob("*"):
    if not path.is_file():
        continue
    rel = path.relative_to(ROOT).as_posix()
    if not (
        rel.startswith("tests/")
        or rel.endswith("Tests.swift")
        or rel.endswith(".swift")
        and "/Tests/" in rel
    ):
        continue
    try:
        text = path.read_text(errors="ignore")
    except Exception:
        continue
    count = 0
    for p in ASSERT_PATTERNS:
        count += len(re.findall(p, text))
    if 0 < count <= 1:
        results.append({"path": rel, "assertions": count})

REPORT.write_text(json.dumps({"low_assert_tests": results}, indent=2))
print(f"Wrote {REPORT}")
