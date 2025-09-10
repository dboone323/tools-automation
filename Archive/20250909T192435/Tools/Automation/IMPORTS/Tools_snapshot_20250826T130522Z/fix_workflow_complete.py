#!/usr/bin/env python3
"""
Final comprehensive GitHub workflow YAML fixer
"""
import os
import re
import sys
from pathlib import Path


def fix_workflow_completely(file_path):
    """Completely rewrite workflow with proper formatting"""
    print(f"Completely fixing {file_path}...")

    with open(file_path, "r") as f:
        content = f.read()

    lines = content.split("\n")
    fixed_lines = ["---"]  # Start with document separator

    i = 0
    while i < len(lines):
        line = lines[i].rstrip()  # Remove trailing whitespace
        original_line = line

        # Skip existing document separators and empty lines at start
        if not line or line == "---":
            i += 1
            continue

        stripped = line.strip()

        # Top-level directives (no indentation)
        if stripped.startswith(("name:", "on:", "permissions:", "env:", "jobs:")):
            if stripped == "on: true":
                fixed_lines.append("on: [push, pull_request]")
            else:
                fixed_lines.append(stripped)

        # Handle 'on:' block structure
        elif stripped.startswith(
            ("push:", "pull_request:", "schedule:", "workflow_dispatch:")
        ):
            fixed_lines.append("  " + stripped)
        elif stripped.startswith("branches:") and "on:" in "".join(fixed_lines[-5:]):
            fixed_lines.append("    " + stripped)
        elif stripped.startswith("paths:") and "on:" in "".join(fixed_lines[-10:]):
            fixed_lines.append("    " + stripped)
        elif stripped.startswith("- ") and any(
            "branches:" in fl or "paths:" in fl for fl in fixed_lines[-3:]
        ):
            fixed_lines.append("      " + stripped)

        # Handle permissions block
        elif stripped.startswith(
            ("contents:", "issues:", "pull-requests:", "actions:")
        ) and "permissions:" in "".join(fixed_lines[-5:]):
            fixed_lines.append("  " + stripped)

        # Handle env block
        elif stripped.endswith('":') and "env:" in "".join(fixed_lines[-5:]):
            fixed_lines.append("  " + stripped)

        # Handle jobs
        elif re.match(r"^[a-zA-Z][a-zA-Z0-9_-]*:", stripped) and "jobs:" in "".join(
            fixed_lines[-10:]
        ):
            # This is a job name
            fixed_lines.append("  " + stripped)

        # Job properties (runs-on, needs, outputs, etc.)
        elif stripped.startswith(
            ("runs-on:", "needs:", "outputs:", "strategy:", "if:", "name:")
        ):
            # Check if we're in a job context
            job_context = any(
                re.match(r"  [a-zA-Z][a-zA-Z0-9_-]*:", fl) for fl in fixed_lines[-10:]
            )
            if job_context:
                fixed_lines.append("    " + stripped)
            else:
                fixed_lines.append(stripped)

        # Job outputs and other nested properties
        elif (
            ":" in stripped
            and not stripped.startswith("-")
            and not stripped.startswith("#")
        ):
            # Look for context to determine proper indentation
            if any("outputs:" in fl for fl in fixed_lines[-3:]):
                fixed_lines.append("      " + stripped)
            elif any(re.match(r"    [a-zA-Z-]+:", fl) for fl in fixed_lines[-5:]):
                fixed_lines.append("      " + stripped)
            elif "jobs:" in "".join(fixed_lines[-10:]) and not any(
                re.match(r"  [a-zA-Z]", fl) for fl in fixed_lines[-5:]
            ):
                fixed_lines.append("    " + stripped)
            else:
                fixed_lines.append("  " + stripped)

        # Steps block
        elif stripped == "steps:":
            fixed_lines.append("    " + stripped)

        # Step items (- name:, - uses:, - run:)
        elif stripped.startswith("- ") and (
            "steps:" in "".join(fixed_lines[-10:])
            or any("- name:" in fl or "- uses:" in fl for fl in fixed_lines[-5:])
        ):
            fixed_lines.append("      " + stripped)

        # Step properties (uses:, with:, env:, run:, id:, if:)
        elif stripped.startswith(
            ("uses:", "with:", "env:", "run:", "id:", "if:", "continue-on-error:")
        ):
            # Check if we're in a step context
            in_step = any(
                "- name:" in fl or "- uses:" in fl or "- run:" in fl
                for fl in fixed_lines[-5:]
            )
            if in_step:
                fixed_lines.append("        " + stripped)
            else:
                fixed_lines.append("      " + stripped)

        # With/env parameters and multiline content
        elif stripped and not stripped.startswith(("#", "-")):
            # Check context for proper indentation
            if any("with:" in fl or "env:" in fl for fl in fixed_lines[-3:]):
                if ":" in stripped:
                    fixed_lines.append("          " + stripped)
                else:
                    # Continuation of multiline content
                    fixed_lines.append("          " + stripped)
            elif (
                "run:" in "".join(fixed_lines[-3:])
                and not stripped.startswith("echo")
                and not stripped.startswith("if")
            ):
                fixed_lines.append("          " + stripped)
            elif stripped.startswith(
                ("echo ", "if ", "then", "else", "fi", "cat ", "EOF")
            ):
                fixed_lines.append("          " + stripped)
            else:
                # Default to previous line indentation + 2
                prev_indent = 0
                if fixed_lines:
                    prev_line = fixed_lines[-1]
                    prev_indent = len(prev_line) - len(prev_line.lstrip())
                fixed_lines.append(" " * (prev_indent + 2) + stripped)

        # Comments and empty lines
        elif stripped.startswith("#"):
            # Preserve comment indentation context
            prev_indent = 0
            if fixed_lines:
                for fl in reversed(fixed_lines[-5:]):
                    if fl.strip() and not fl.strip().startswith("#"):
                        prev_indent = len(fl) - len(fl.lstrip())
                        break
            fixed_lines.append(" " * prev_indent + stripped)

        i += 1

    # Remove excessive blank lines
    clean_lines = []
    prev_empty = False
    for line in fixed_lines:
        if not line.strip():
            if not prev_empty:
                clean_lines.append("")
            prev_empty = True
        else:
            clean_lines.append(line)
            prev_empty = False

    # Remove trailing empty lines
    while clean_lines and clean_lines[-1] == "":
        clean_lines.pop()

    # Write the completely fixed content
    fixed_content = "\n".join(clean_lines) + "\n"

    with open(file_path, "w") as f:
        f.write(fixed_content)

    print(f"  ✅ Completely fixed {file_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: fix_workflow_complete.py <directory>")
        sys.exit(1)

    workflow_dir = Path(sys.argv[1])

    if not workflow_dir.exists():
        print(f"Directory {workflow_dir} does not exist")
        sys.exit(1)

    yaml_files = list(workflow_dir.glob("*.yml")) + list(workflow_dir.glob("*.yaml"))

    # Remove the test file
    yaml_files = [f for f in yaml_files if not f.name.endswith("-fixed.yml")]

    if not yaml_files:
        print(f"No YAML files found in {workflow_dir}")
        sys.exit(1)

    print(f"Found {len(yaml_files)} YAML files to fix:")
    for file_path in yaml_files:
        fix_workflow_completely(file_path)

    print(f"\n✅ Completely fixed {len(yaml_files)} workflow files!")


if __name__ == "__main__":
    main()
