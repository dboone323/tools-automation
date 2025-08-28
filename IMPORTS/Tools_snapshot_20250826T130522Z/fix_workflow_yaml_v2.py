#!/usr/bin/env python3
"""
More comprehensive YAML workflow fixing script
"""
import os
import re
import sys
from pathlib import Path


def fix_yaml_workflow(file_path):
    """Fix GitHub workflow YAML formatting issues"""
    print(f"Fixing {file_path}...")

    with open(file_path, "r") as f:
        content = f.read()

    lines = content.split("\n")
    fixed_lines = []
    in_steps = False
    current_job_indent = 0

    i = 0
    while i < len(lines):
        line = lines[i]
        original_line = line

        # Remove trailing spaces
        line = line.rstrip()

        # Fix bracket spacing
        line = re.sub(r"\[\s+", "[", line)
        line = re.sub(r"\s+\]", "]", line)

        # Track if we're in a job definition
        if re.match(r"^  [a-zA-Z][a-zA-Z0-9_-]*:", line):
            current_job_indent = 2
            in_steps = False

        # Track if we're in steps
        if line.strip() == "steps:":
            in_steps = True
            # Ensure steps: is properly indented (4 spaces from job level)
            if not line.startswith("    "):
                line = "    steps:"

        # Fix step items and their properties
        if in_steps and line.strip():
            stripped = line.strip()
            current_indent = len(line) - len(line.lstrip())

            # Step items should start with - and be indented 6 spaces from job start
            if (
                stripped.startswith("- name:")
                or stripped.startswith("- uses:")
                or stripped.startswith("- run:")
                or stripped.startswith("- id:")
            ):
                line = "      " + stripped
            # Step properties (uses, with, env, etc.) should be indented 8 spaces from job start
            elif stripped.startswith(
                (
                    "uses:",
                    "with:",
                    "env:",
                    "run:",
                    "id:",
                    "if:",
                    "continue-on-error:",
                    "timeout-minutes:",
                )
            ):
                line = "        " + stripped
            # Sub-properties (with parameters, env vars) should be indented 10 spaces from job start
            elif (
                current_indent > 0 and not stripped.startswith("-") and ":" in stripped
            ):
                # Check if previous line was a 'with:' or 'env:' block
                prev_line = fixed_lines[-1].strip() if fixed_lines else ""
                if prev_line.endswith((":")) or any(
                    fixed_lines[-j].strip().startswith(("with:", "env:"))
                    for j in range(1, min(3, len(fixed_lines)))
                ):
                    line = "          " + stripped
                else:
                    line = "        " + stripped

        # Fix job-level properties
        elif re.match(r"^  [a-zA-Z][a-zA-Z0-9_-]*:", line):
            # This is a job definition
            pass
        elif line.strip() and not line.startswith("#") and current_job_indent == 2:
            stripped = line.strip()
            if stripped.startswith(
                (
                    "runs-on:",
                    "needs:",
                    "strategy:",
                    "outputs:",
                    "permissions:",
                    "env:",
                    "if:",
                )
            ):
                line = "    " + stripped
            elif ":" in stripped and not line.startswith("    "):
                # Generic job property
                line = "    " + stripped

        # Fix top-level properties
        elif line.strip() and not line.startswith(("#", "---")):
            stripped = line.strip()
            if stripped.startswith(("name:", "on:", "permissions:", "env:", "jobs:")):
                if not line.startswith(stripped):  # If it has indentation
                    line = stripped  # Remove incorrect indentation

        # Fix 'on: true' issue
        if "on: true" in line:
            line = line.replace("on: true", "on: [push, pull_request]")

        fixed_lines.append(line)
        i += 1

    # Add document start if missing
    if not fixed_lines or not fixed_lines[0].startswith("---"):
        fixed_lines.insert(0, "---")

    # Remove excessive blank lines at end
    while fixed_lines and fixed_lines[-1] == "":
        fixed_lines.pop()

    # Write back the fixed content
    fixed_content = "\n".join(fixed_lines) + "\n"

    with open(file_path, "w") as f:
        f.write(fixed_content)

    print(f"  ✅ Fixed {file_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: fix_workflow_yaml_v2.py <directory>")
        sys.exit(1)

    workflow_dir = Path(sys.argv[1])

    if not workflow_dir.exists():
        print(f"Directory {workflow_dir} does not exist")
        sys.exit(1)

    yaml_files = list(workflow_dir.glob("*.yml")) + list(workflow_dir.glob("*.yaml"))

    if not yaml_files:
        print(f"No YAML files found in {workflow_dir}")
        sys.exit(1)

    print(f"Found {len(yaml_files)} YAML files to fix:")
    for file_path in yaml_files:
        fix_yaml_workflow(file_path)

    print(f"\n✅ Fixed {len(yaml_files)} workflow files!")


if __name__ == "__main__":
    main()
