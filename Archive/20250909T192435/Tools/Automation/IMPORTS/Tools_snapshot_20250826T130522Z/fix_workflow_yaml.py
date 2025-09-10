#!/usr/bin/env python3
"""
Fix YAML formatting issues in GitHub workflow files
"""
import os
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

    for i, line in enumerate(lines):
        # Remove trailing spaces
        line = line.rstrip()

        # Fix bracket spacing - remove extra spaces inside brackets
        line = re.sub(r"\[\s+", "[", line)
        line = re.sub(r"\s+\]", "]", line)

        # Fix indentation issues for common workflow patterns
        if line.strip().startswith("runs-on:") and not line.startswith("      "):
            if line.startswith("    runs-on:"):
                line = "      " + line.strip()
            elif line.startswith("  runs-on:"):
                line = "      " + line.strip()

        if line.strip().startswith("steps:") and not line.startswith("      "):
            if line.startswith("    steps:"):
                line = "      " + line.strip()
            elif line.startswith("  steps:"):
                line = "      " + line.strip()

        # Fix job indentation
        if re.match(r"^  [a-zA-Z-_]+:", line) and "jobs:" not in line:
            # This is likely a job definition, should be at 2-space indentation
            pass
        elif (
            re.match(r"^    [a-zA-Z-_]+:", line)
            and not line.strip().startswith("env:")
            and not line.strip().startswith("with:")
        ):
            # Job properties should be at 4-space indentation, but some need 6
            if any(
                prop in line
                for prop in ["runs-on:", "steps:", "strategy:", "env:", "needs:"]
            ):
                if not line.startswith("      "):
                    line = "  " + line

        # Fix step indentation - steps should be 8 spaces, step properties 10 spaces
        if (
            line.strip().startswith("- name:")
            or line.strip().startswith("- uses:")
            or line.strip().startswith("- run:")
        ):
            if not line.startswith("        "):
                # Count current indentation
                current_indent = len(line) - len(line.lstrip())
                if current_indent < 8:
                    line = "        " + line.strip()

        # Fix 'on:' value from 'true' to proper triggers
        if line.strip() == "on: true":
            line = line.replace("on: true", "on: [push, pull_request]")

        fixed_lines.append(line)

    # Add document start if missing
    if not fixed_lines[0].startswith("---"):
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
