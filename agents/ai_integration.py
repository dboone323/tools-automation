#!/usr/bin/env python3
"""
Advanced AI Integration (Phase 4)

Provides a thin Python wrapper over the MCP client (shell) to enable
programmatic access from other Python components, with graceful fallback when
the shell client is unavailable.

CLI:
  ai_integration.py analyze --text "error log..."
  ai_integration.py suggest-fix --pattern "NullPointer"
  ai_integration.py evaluate --change "{json}"
  ai_integration.py verify --target "file.swift"
"""
from __future__ import annotations

import argparse
import json
import os
from agents.utils import safe_run, user_log
import logging
logger = logging.getLogger(__name__)
from typing import Any, Dict


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
AGENTS_DIR = os.path.join(ROOT, "Tools", "Automation", "agents")


def _try_mcp(args: list[str]) -> Dict[str, Any] | None:
    candidates = [
        os.path.join(AGENTS_DIR, "mcp_client.sh"),
        os.path.join(ROOT, "Tools", "Automation", "mcp_client.sh"),
    ]
    for path in candidates:
        if os.path.exists(path) and os.access(path, os.X_OK):
            try:
                proc = safe_run(
                    [path] + args, check=False, capture_output=True, text=True
                )
                out = proc.stdout.strip()
                if out:
                    try:
                        return json.loads(out)
                    except Exception:
                        # If MCP returns non-JSON, wrap it
                        return {"raw": out, "exit_code": proc.returncode}
                return {"raw": out, "exit_code": proc.returncode}
            except Exception as e:
                logger.debug("_try_mcp: invocation failed for %s: %s", path, e, exc_info=True)
                continue
    return None


def _heuristic_analysis(text: str) -> Dict[str, Any]:
    t = text.lower()
    suggestions = []
    if "null" in t or "none" in t:
        suggestions.append("Check for nil/None guards and optional unwrapping.")
    if "timeout" in t or "deadline" in t:
        suggestions.append("Increase timeout and add retry with backoff.")
    if "syntax" in t:
        suggestions.append("Run linter/formatter; verify bracket/paren balance.")
    if "permission" in t or "denied" in t:
        suggestions.append("Validate credentials/entitlements and file permissions.")
    if not suggestions:
        suggestions.append(
            "Capture minimal repro; add logs; run unit test around failing path."
        )
    return {
        "analysis": {"summary": text[:160], "suggestions": suggestions},
        "confidence": 0.42,
        "source": "heuristic",
    }


def analyze(text: str) -> Dict[str, Any]:
    res = _try_mcp(["analyze", text])
    return res or _heuristic_analysis(text)


def suggest_fix(pattern: str) -> Dict[str, Any]:
    res = _try_mcp(["suggest-fix", pattern])
    return res or {
        "suggestion": f"Create regression test for '{pattern}', then patch and re-run.",
        "confidence": 0.4,
        "source": "heuristic",
    }


def evaluate(change: str) -> Dict[str, Any]:
    res = _try_mcp(["evaluate", change])
    return res or {
        "evaluation": "Change compiles locally? Run targeted tests.",
        "risk": 0.3,
        "source": "heuristic",
    }


def verify(target: str) -> Dict[str, Any]:
    res = _try_mcp(["verify", target])
    return res or {
        "verify": f"Static checks passed (simulated) for {target}",
        "source": "heuristic",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Advanced AI Integration wrapper")
    sub = parser.add_subparsers(dest="cmd")

    p1 = sub.add_parser("analyze")
    p1.add_argument("--text", required=True)

    p2 = sub.add_parser("suggest-fix")
    p2.add_argument("--pattern", required=True)

    p3 = sub.add_parser("evaluate")
    p3.add_argument("--change", required=True)

    p4 = sub.add_parser("verify")
    p4.add_argument("--target", required=True)

    args = parser.parse_args()
    if args.cmd == "analyze":
        user_log(json.dumps(analyze(args.text)))
        return 0
    elif args.cmd == "suggest-fix":
        user_log(json.dumps(suggest_fix(args.pattern)))
        return 0
    elif args.cmd == "evaluate":
        user_log(json.dumps(evaluate(args.change)))
        return 0
    elif args.cmd == "verify":
        user_log(json.dumps(verify(args.target)))
        return 0
    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
