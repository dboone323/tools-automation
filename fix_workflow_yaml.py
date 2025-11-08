#!/usr/bin/env python3
"""
Fix YAML formatting issues in GitHub workflow files
"""
import re
import sys
from pathlib import Path


def fix_yaml_file(file_path):
    """Fix common YAML formatting issues in a file"""
    print(f"Fixing {file_path}...")

    with open(file_path, "r") as f:
        content = f.read()

    lines = content.split("\n")
    fixed_lines = []

    for line in lines:
        original_line = line
        # Remove trailing spaces
        line = line.rstrip()

        # Fix bracket spacing - remove extra spaces inside brackets
        line = re.sub(r"\[\s+", "[", line)
        line = re.sub(r"\s+\]", "]", line)
        # Remove spaces before commas in bracketed lists (but keep spaces after)
        line = re.sub(r"\s+,", ",", line)

        stripped = line.strip()
        current_indent = len(line) - len(line.lstrip())

        # Fix common indentation issues based on content patterns
        if stripped == "jobs:":
            # jobs should be at 0 spaces (top level)
            line = stripped
        elif stripped == "steps:":
            # Steps should be at 6 spaces under jobs
            if current_indent != 6:
                line = "      " + stripped
        elif stripped.startswith("runs-on:") or stripped.startswith("needs:"):
            # These should be at 6 spaces (job properties)
            if current_indent != 6:
                line = "      " + stripped
        elif stripped.startswith("strategy:"):
            # Strategy should be at 6 spaces
            if current_indent != 6:
                line = "      " + stripped
        elif stripped.startswith("matrix:"):
            # Matrix should be at 8 spaces
            if current_indent != 8:
                line = "        " + stripped
        elif stripped.startswith("node:"):
            # Node should be at 10 spaces under matrix
            if current_indent != 10:
                line = "          " + stripped
        elif "node-version:" in stripped:
            # node-version should be at 12 spaces
            if current_indent != 12:
                line = "            " + stripped
        elif (
            re.match(r"^\s*[a-zA-Z-_]+:", line)
            and current_indent == 2
            and "jobs:" not in line
            and stripped != "steps:"
        ):
            # Job names should stay at 2 spaces
            pass
        elif stripped.startswith("- "):
            # Step list items should be at 8 spaces
            if current_indent != 8:
                line = "        " + stripped
        elif stripped.startswith(("uses:", "run:")):
            # Step properties should be at 10 spaces
            if current_indent != 10:
                line = "          " + stripped
        elif stripped == "name:" and current_indent > 0:
            # Name property under a step should be at 10 spaces
            if current_indent != 10:
                line = "          " + stripped
        elif stripped.startswith("with:"):
            # With should be at 10 spaces
            if current_indent != 10:
                line = "          " + stripped
        elif current_indent >= 10 and ":" in stripped:
            # Properties under 'with' should be at 12 spaces
            if current_indent != 12:
                line = "            " + stripped

        # Fix 'on:' value from 'true' to proper triggers
        if line.strip() == "on: true":
            line = line.replace("on: true", "on: [push, pull_request]")

        fixed_lines.append(line)

    # Add document start if missing
    if fixed_lines and not fixed_lines[0].startswith("---"):
        fixed_lines.insert(0, "---")
    elif not fixed_lines:
        fixed_lines = ["---"]

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
        print("Usage: fix_workflow_yaml.py <directory>")
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
        fix_yaml_file(file_path)

    print(f"\n✅ Fixed {len(yaml_files)} workflow files!")


if __name__ == "__main__":
    main()
