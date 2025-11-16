#!/usr/bin/env python3
# keychain.py: Manage secrets in macOS Keychain for Python scripts

import subprocess
import sys


def get_secret(service: str) -> str:
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", service, "-w"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0:
            return result.stdout.strip()
        else:
            return ""
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""


def set_secret(service: str, value: str):
    try:
        # Try to add (will fail if exists)
        subprocess.run(
            ["security", "add-generic-password", "-s", service, "-w", value],
            capture_output=True,
            timeout=10,
        )
        # If exists, update
        subprocess.run(
            ["security", "add-generic-password", "-U", "-s", service, "-w", value],
            capture_output=True,
            timeout=10,
        )
    except subprocess.TimeoutExpired:
        pass


def main():
    if len(sys.argv) < 3:
        print(
            "Usage: python keychain.py get <service> or set <service> <value>",
            file=sys.stderr,
        )
        return 1

    action = sys.argv[1]
    service = sys.argv[2]

    if action == "get":
        print(get_secret(service))
        return 0
    elif action == "set" and len(sys.argv) == 4:
        set_secret(service, sys.argv[3])
        return 0
    else:
        print("Invalid action", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
