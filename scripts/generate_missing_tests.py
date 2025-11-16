#!/usr/bin/env python3
"""Generate suggestions for missing tests based on source symbols not referenced.
Outputs: reports/missing_tests_suggestions.json
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
UNREF = REPORTS / "unreferenced_symbols.json"
SYMBOL_IDX = REPORTS / "source_symbol_index.json"
OUT = REPORTS / "missing_tests_suggestions.json"

if not UNREF.exists() or not SYMBOL_IDX.exists():
    print("Prerequisite reports missing; run generate_test_inventory first")
    exit(1)

unref = json.loads(UNREF.read_text())["unreferenced"]
idx = json.loads(SYMBOL_IDX.read_text())

suggestions = []
# Build simple mapping from symbol to source file
symbol_to_file = {}
for f, symbols in idx.items():
    for s in symbols:
        symbol_to_file.setdefault(s, f)

for sym in unref[:500]:  # limit
    f = symbol_to_file.get(sym)
    if not f:
        continue
    lang = (
        "python"
        if f.endswith(".py")
        else (
            "swift"
            if f.endswith(".swift")
            else "bash" if f.endswith(".sh") else "other"
        )
    )
    suggestion = {
        "symbol": sym,
        "file": f,
        "language": lang,
        "suggested_test_name": (
            f"test_{sym.lower()}"
            if lang in ("python", "bash")
            else f"test{sym[0].upper()+sym[1:]}"
        ),
        "template": "",
    }
    if lang == "python":
        suggestion["template"] = (
            f"def test_{sym.lower()}():\n    # TODO: add meaningful assertions for {sym}\n    result = {sym}  # adapt call\n    assert result is not None\n"
        )
    elif lang == "bash":
        suggestion["template"] = (
            f"test_{sym.lower()}() {{\n  # TODO: call {sym} and assert output\n  {sym} >/dev/null 2>&1 || return 1\n  # add assertions\n}}\n"
        )
    elif lang == "swift":
        suggestion["template"] = (
            f"func test{sym[0].upper()+sym[1:]}() throws {{\n    // TODO: meaningful assertions for {sym}\n    // let value = {sym}()\n    XCTAssertTrue(true)\n}}\n"
        )
    suggestions.append(suggestion)

OUT.write_text(json.dumps({"missing_test_suggestions": suggestions}, indent=2))
print(f"Wrote {OUT}")
