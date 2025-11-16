#!/usr/bin/env python3
"""
Code Health Dashboard Generator
- Scans repository for basic code health metrics
- Outputs JSON to Tools/Automation/metrics/code_health.json

Metrics:
- swift_files: total count
- swift_lines: total lines across Swift files (approx)
- projects: list with per-project swift file counts and presence of tests/docs
- todos: count of TODO/FIXME in code
- last_update: unix timestamp

This complements the existing dashboard system by generating a code-focused snapshot.
"""
import re
import json
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECTS = ROOT / "Projects"
OUTPUT_DIR = ROOT / "Tools" / "Automation" / "metrics"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_PATH = OUTPUT_DIR / "code_health.json"

TODO_PATTERN = re.compile(r"\b(TODO|FIXME|BUG|HACK)\b")


def count_swift_files_and_lines(base: Path):
    total_files = 0
    total_lines = 0
    for p in base.rglob("*.swift"):
        try:
            total_files += 1
            with p.open("r", encoding="utf-8", errors="ignore") as f:
                total_lines += sum(1 for _ in f)
        except Exception:
            continue
    return total_files, total_lines


def count_todos():
    count = 0
    roots = [
        ROOT / "Projects",
        ROOT / "Shared",
        ROOT / "Tools" / "Automation",
    ]
    exts = {
        ".swift",
        ".m",
        ".mm",
        ".h",
        ".c",
        ".cpp",
        ".py",
        ".sh",
        ".js",
        ".ts",
        ".md",
    }
    max_bytes = 1_000_000  # 1MB guard
    for base in roots:
        if not base.exists():
            continue
        for p in base.rglob("*.*"):
            if p.suffix.lower() not in exts:
                continue
            try:
                if p.stat().st_size > max_bytes:
                    continue
                text = p.read_text(encoding="utf-8", errors="ignore")
            except Exception:
                continue
            count += len(TODO_PATTERN.findall(text))
    return count


def project_summary(project_dir: Path):
    name = project_dir.name
    swift_files = len(list(project_dir.rglob("*.swift")))
    has_tests = any(
        "Test" in f.name or f.name.endswith("Tests.swift")
        for f in project_dir.rglob("*.swift")
    )
    has_docs = (ROOT / "Documentation" / "API" / f"{name}_API.md").exists() or (
        project_dir / "README.md"
    ).exists()
    return {
        "name": name,
        "swift_files": swift_files,
        "has_tests": has_tests,
        "has_docs": has_docs,
    }


def main():
    swift_files, swift_lines = count_swift_files_and_lines(PROJECTS)
    todos = count_todos()
    projects = [project_summary(p) for p in PROJECTS.iterdir() if p.is_dir()]

    data = {
        "swift_files": swift_files,
        "swift_lines": swift_lines,
        "todos": todos,
        "projects": projects,
        "last_update": int(time.time()),
    }

    OUTPUT_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"[code-health] Wrote metrics to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
