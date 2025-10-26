#!/usr/bin/env python3
"""
Error pattern recognizer (Phase 1 prototype)

Input: a single error line via --line or stdin
Output: JSON with { pattern, category, severity, hash }

No external network calls. Pure local heuristics with safe fallbacks.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import sys
from dataclasses import dataclass, asdict


@dataclass
class Pattern:
    pattern: str
    category: str
    severity: str
    hash: str


ERROR_HINTS = [
    (r"swiftpm build failed|SwiftPM build failed", ("build", "high")),
    (r"xcode.*build failed|iOS build failed|macOS build failed", ("build", "high")),
    (r"tests? failed|failing test|assertion failed", ("test", "high")),
    (r"lint|swiftlint|format|swiftformat", ("lint", "medium")),
    (r"dependency|package|resolve|pod|spm", ("dependency", "medium")),
]


def normalize_message(msg: str) -> str:
    # Collapse multiple spaces, strip timestamps and emojis/icons, trim paths
    m = re.sub(r"\x1b\[[0-9;]*m", "", msg)  # strip ANSI
    m = re.sub(r"^\[[0-9: \-]+\]\s*", "", m)  # leading timestamps like [16:34:02]
    m = re.sub(
        r"[\u2705\u274c\u26a0\ufe0f\u2b50\u2699\ufe0f\ud83d\udd27\ud83d\udd0d\ud83d\udca1]",
        "",
        m,
    )
    m = re.sub(r"\s+", " ", m).strip()
    return m


def categorize(msg: str) -> tuple[str, str]:
    lm = msg.lower()
    for pattern, (cat, sev) in ERROR_HINTS:
        if re.search(pattern, lm):
            return cat, sev
    # Fallbacks
    if "error" in lm:
        return "general", "medium"
    return "info", "low"


def stable_hash(s: str) -> str:
    return hashlib.sha1(s.encode("utf-8")).hexdigest()[:12]


def recognize(line: str) -> Pattern:
    norm = normalize_message(line)
    # Coarse normalization: drop volatile numbers in line/column references
    coarse = re.sub(r":\d+", ":<n>", norm)
    coarse = re.sub(r"line \d+", "line <n>", coarse, flags=re.I)
    cat, sev = categorize(coarse)
    return Pattern(pattern=coarse, category=cat, severity=sev, hash=stable_hash(coarse))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--line", help="Error line to analyze; if omitted, read stdin", default=None
    )
    args = ap.parse_args()
    if args.line:
        line = args.line
    else:
        data = sys.stdin.read()
        line = data.strip().splitlines()[0] if data.strip() else ""
    p = recognize(line)
    print(json.dumps(asdict(p), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
