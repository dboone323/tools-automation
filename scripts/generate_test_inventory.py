#!/usr/bin/env python3
"""Scan repository for test files, test cases, and source symbols.
Outputs JSON reports:
  reports/tests_inventory.json
  reports/source_symbol_index.json
  reports/unreferenced_symbols.json
Simplified initial implementation; enhancement hooks can be added later.
"""
import re, json, os, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "reports"
REPORT_DIR.mkdir(exist_ok=True)

TEST_FILE_PATTERNS = [
    r"test_.*\.py$",
    r".*_test\.py$",
    r"test_.*\.sh$",
    r"Tests.swift$",
    r".*Tests\.swift$",
]
PY_TEST_FUNC = re.compile(r"^def (test_[A-Za-z0-9_]+)\(", re.MULTILINE)
SH_TEST_FUNC = re.compile(r"^test_[A-Za-z0-9_]+\(\)", re.MULTILINE)
SWIFT_TEST_FUNC = re.compile(r"func (test[A-Za-z0-9_]+)\s*\(", re.MULTILINE)
PLACEHOLDER_MARKERS = [
    "TODO",
    "FIXME",
    "pass",
    "NotImplementedError",
    'echo "TODO"',
    'echo "Placeholder"',
]
SOURCE_PATTERNS = {
    "python": re.compile(r"^(def|class)\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE),
    "shell": re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*\(\)", re.MULTILINE),
    "swift": re.compile(
        r"^(public\s+)?(class|struct|enum|func)\s+([A-Za-z_][A-Za-z0-9_]*)",
        re.MULTILINE,
    ),
}

inventory = []


def matches_any(name: str, patterns):
    return any(re.match(p, name) for p in patterns)


for path in ROOT.rglob("*"):
    if not path.is_file():
        continue
    rel = path.relative_to(ROOT).as_posix()
    fname = path.name
    if matches_any(fname, TEST_FILE_PATTERNS):
        text = path.read_text(errors="ignore")
        if fname.endswith(".py"):
            tests = PY_TEST_FUNC.findall(text)
            lang = "python"
        elif fname.endswith(".sh"):
            tests = SH_TEST_FUNC.findall(text)
            lang = "bash"
        elif fname.endswith(".swift"):
            tests = SWIFT_TEST_FUNC.findall(text)
            lang = "swift"
        else:
            tests = []
            lang = "other"
        placeholders = []
        for marker in PLACEHOLDER_MARKERS:
            if marker in text:
                placeholders.append(marker)
        inventory.append(
            {
                "path": rel,
                "language": lang,
                "test_count": len(tests),
                "tests": tests[:50],  # limit
                "placeholders": placeholders,
            }
        )

# Source symbol scanning
source_symbols = {}
for path in ROOT.rglob("*"):
    if not path.is_file():
        continue
    rel = path.relative_to(ROOT).as_posix()
    text = ""
    try:
        text = path.read_text(errors="ignore")
    except Exception:
        continue
    if rel.startswith("tests/"):
        continue
    if path.suffix == ".py":
        kind = "python"
    elif path.suffix == ".sh":
        kind = "shell"
    elif path.suffix == ".swift":
        kind = "swift"
    else:
        continue
    pattern = SOURCE_PATTERNS[kind]
    if kind == "python":
        extract_group = 2
    elif kind == "swift":
        extract_group = 3
    else:  # shell
        extract_group = 1
    symbols = [
        m.group(extract_group) for m in pattern.finditer(text) if m.group(extract_group)
    ]
    if symbols:
        source_symbols[rel] = symbols[:200]

# Correlate
all_test_text = []
for item in inventory:
    try:
        all_test_text.append((ROOT / item["path"]).read_text(errors="ignore"))
    except Exception:
        pass
joined_tests = "\n".join(all_test_text)
referenced = set()
for symbols in source_symbols.values():
    for s in symbols:
        if s in joined_tests:
            referenced.add(s)

unreferenced = [
    s for symbols in source_symbols.values() for s in symbols if s not in referenced
]

# Write reports
(TESTS_INV := REPORT_DIR / "tests_inventory.json").write_text(
    json.dumps({"tests": inventory}, indent=2)
)
(SYMBOL_IDX := REPORT_DIR / "source_symbol_index.json").write_text(
    json.dumps(source_symbols, indent=2)
)
(UNREF := REPORT_DIR / "unreferenced_symbols.json").write_text(
    json.dumps({"unreferenced": unreferenced}, indent=2)
)

print(f"Wrote {TESTS_INV}")
print(f"Wrote {SYMBOL_IDX}")
print(f"Wrote {UNREF}")
