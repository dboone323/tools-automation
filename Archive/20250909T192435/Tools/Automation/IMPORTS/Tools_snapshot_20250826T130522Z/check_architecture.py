#!/usr/bin/env python3
"""check_architecture.py

Lightweight checker that enforces a subset of `Tools/ARCHITECTURE.md` rules.
This script emits warnings and exit 0 for warn-only mode, or non-zero for strict mode.
"""
import argparse
import os
import sys


def check_project(path, warn_only=True):
    issues = []
    fixes = []

    # Quick helpers
    def is_yaml_multi_doc(fp):
        try:
            with open(fp, "r", encoding="utf-8") as fh:
                return "\n---" in fh.read()
        except Exception:
            return False

    # Rule: No Swift files under SharedTypes should import SwiftUI
    for root, _dirs, files in os.walk(path):
        for f in files:
            if f.endswith(".swift"):
                fp = os.path.join(root, f)
                try:
                    with open(fp, "r", encoding="utf-8") as fh:
                        txt = fh.read()
                        if "SharedTypes" in root and "import SwiftUI" in txt:
                            issues.append(f"{fp}: SharedTypes must not import SwiftUI")
                except Exception:
                    pass

    # Example rule: Avoid TODO/FIXME in code (stricter)
    todo_count = 0
    for root, _dirs, files in os.walk(path):
        for f in files:
            if f.endswith((".swift", ".py", ".sh", ".m", ".mm", ".kt", ".java")):
                fp = os.path.join(root, f)
                try:
                    with open(fp, "r", encoding="utf-8") as fh:
                        for line in fh:
                            if "TODO" in line or "FIXME" in line:
                                todo_count += 1
                except Exception:
                    pass
    if todo_count > 10:
        issues.append(
            f"Project has {todo_count} TODO/FIXME markers; consider cleaning up (threshold=10)"
        )

    # Rule: Detect GitHub Actions workflow multi-document YAMLs (not allowed by policy)
    workflows_dir = os.path.join(path, ".github", "workflows")
    if os.path.isdir(workflows_dir):
        for wf in os.listdir(workflows_dir):
            if wf.endswith((".yml", ".yaml")):
                fp = os.path.join(workflows_dir, wf)
                if is_yaml_multi_doc(fp):
                    issues.append(
                        f"Workflow {fp} contains multiple YAML documents (---). Split into single-document files."
                    )
                # Rule: detect deprecated/pinned actions usage heuristics
                try:
                    with open(fp, "r", encoding="utf-8") as fh:
                        txt = fh.read()
                        # simple heuristic: actions/checkout@v1 or actions/setup-python@v1
                        if "@v1" in txt or (
                            "@v2" in txt
                            and (
                                "actions/checkout" in txt
                                or "actions/setup-python" in txt
                            )
                        ):
                            issues.append(
                                f"Workflow {fp} may reference deprecated action major versions (check version pins)"
                            )
                        # collect candidate files for auto-fix
                        if "---" in txt:
                            fixes.append(("multi-doc", fp))
                        if (
                            "actions/checkout@v1" in txt
                            or "actions/setup-python@v1" in txt
                        ):
                            fixes.append(("pin-actions", fp))
                except Exception:
                    pass
    else:
        issues.append(f"Missing workflows directory: {workflows_dir}")

    # Rule: Check Dockerfiles that use 'latest' tag
    for root, _dirs, files in os.walk(path):
        for f in files:
            if f == "Dockerfile":
                fp = os.path.join(root, f)
                try:
                    with open(fp, "r", encoding="utf-8") as fh:
                        for line in fh:
                            if "FROM" in line and ":latest" in line:
                                issues.append(
                                    f"Dockerfile {fp} pins image with :latest; use an explicit tag or digest"
                                )
                except Exception:
                    pass

    # Rule: If project contains an Xcode project, ensure there's at least one macOS/iOS workflow
    has_xcode = any(
        f.endswith(".xcodeproj") for _, _dirs, files in os.walk(path) for f in files
    )
    if has_xcode:
        found_ci = False
        if os.path.isdir(workflows_dir):
            for wf in os.listdir(workflows_dir):
                if wf.endswith((".yml", ".yaml")):
                    fp = os.path.join(workflows_dir, wf)
                    try:
                        with open(fp, "r", encoding="utf-8") as fh:
                            txt = fh.read()
                            if "macos" in txt or "macOS" in txt or "xcodebuild" in txt:
                                found_ci = True
                    except Exception:
                        pass
        if not found_ci:
            issues.append(
                "Xcode project detected but no macOS/iOS CI workflow found in .github/workflows"
            )

    return issues


def auto_fix_project(path, fixes_requested=None):
    """Perform safe, low-risk auto-fixes. Returns list of fix messages."""
    if fixes_requested is None:
        fixes_requested = []
    results = []

    def split_multi_doc(fp):
        try:
            with open(fp, "r", encoding="utf-8") as fh:
                content = fh.read()
            parts = [p.strip() for p in content.split("\n---") if p.strip()]
            if len(parts) <= 1:
                return False, "no-split-needed"
            created = []
            base = fp
            dirn = os.path.dirname(fp)
            for i, part in enumerate(parts, start=1):
                new_name = os.path.join(
                    dirn, f"{os.path.splitext(os.path.basename(base))[0]}-part{i}.yml"
                )
                with open(new_name, "w", encoding="utf-8") as out:
                    out.write(part + "\n")
                created.append(new_name)
            # backup and remove original
            bak = fp + ".bak"
            os.rename(fp, bak)
            return (
                True,
                f"split into {len(created)} files: {', '.join(created)} (backup: {bak})",
            )
        except Exception as e:
            return False, f"split-failed:{e}"

    def bump_action_pins(fp):
        try:
            with open(fp, "r", encoding="utf-8") as fh:
                txt = fh.read()
            orig = txt
            # safe heuristics: bump common widely-used actions
            txt = txt.replace("actions/checkout@v1", "actions/checkout@v4")
            txt = txt.replace("actions/setup-python@v1", "actions/setup-python@v4")
            if txt != orig:
                bak = fp + ".bak"
                os.rename(fp, bak)
                with open(fp, "w", encoding="utf-8") as fh:
                    fh.write(txt)
                return True, f"bumped pins in {fp} (backup: {bak})"
            return False, "no-pin-changes"
        except Exception as e:
            return False, f"pin-failed:{e}"

    for kind, fp in fixes_requested:
        if kind == "multi-doc":
            ok, msg = split_multi_doc(fp)
            results.append((fp, "multi-doc", ok, msg))
        elif kind == "pin-actions":
            ok, msg = bump_action_pins(fp)
            results.append((fp, "pin-actions", ok, msg))

    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--warn-only", action="store_true", default=False)
    parser.add_argument(
        "--auto-fix",
        action="store_true",
        default=False,
        help="Attempt safe auto-fixes for low-risk issues (multi-doc split, pin common actions)",
    )
    args = parser.parse_args()

    path = args.project
    if not os.path.isdir(path):
        print(f"Project path not found: {path}")
        sys.exit(2)

    issues = check_project(path, warn_only=args.warn_only)
    if issues:
        print("Architecture issues detected:")
        for it in issues:
            print(f" - {it}")
    else:
        print("No architecture issues detected")

    if args.auto_fix:
        # Re-run detection to gather files to fix (check_project already populated 'fixes' via side-effects),
        # but because check_project returns only issues we need to re-run a short pass to collect fixes.
        # Simpler: run check_project and inspect local variables by calling it again and capturing fixes via returned structure.
        # Modify check_project to return both issues and fixes would be ideal; as a minimal change, re-run the file inspection here.
        # We'll perform a focused scan to collect candidate fixes (multi-doc and common action pins).
        candidate_fixes = []
        workflows_dir = os.path.join(path, ".github", "workflows")
        if os.path.isdir(workflows_dir):
            for wf in os.listdir(workflows_dir):
                if wf.endswith((".yml", ".yaml")):
                    fp = os.path.join(workflows_dir, wf)
                    try:
                        with open(fp, "r", encoding="utf-8") as fh:
                            txt = fh.read()
                            if "---" in txt:
                                candidate_fixes.append(("multi-doc", fp))
                            if (
                                "actions/checkout@v1" in txt
                                or "actions/setup-python@v1" in txt
                            ):
                                candidate_fixes.append(("pin-actions", fp))
                    except Exception:
                        pass
        if candidate_fixes:
            print("AUTO_FIX_CANDIDATES:")
            for kind, fp in candidate_fixes:
                print(f" - {kind}: {fp}")
            # attempt auto-fixes
            results = auto_fix_project(path, fixes_requested=candidate_fixes)
            print("AUTO_FIX_RESULTS:")
            for fp, kind, ok, msg in results:
                status = "APPLIED" if ok else "SKIPPED"
                print(f" - {status}: {kind} -> {fp}: {msg}")
            # exit 0 to indicate we ran auto-fix analysis (caller will examine repo state)
            sys.exit(0)

    # If there were issues and not warn-only, fail.
    if issues and not args.warn_only:
        print("Strict mode: failing")
        sys.exit(1)
    else:
        if issues:
            print("Warn-only mode: continuing with warnings")
        sys.exit(0)


if __name__ == "__main__":
    main()
