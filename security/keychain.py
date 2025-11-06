#!/usr/bin/env python3
"""
Keychain secrets management for tools-automation (Python version)
"""

import subprocess
import sys
import os

KEYCHAIN_SERVICE = "tools-automation"


def get_secret(key: str) -> str:
    """Get a secret from macOS Keychain"""
    service = f"{KEYCHAIN_SERVICE}-{key}"

    try:
        result = subprocess.run(
            [
                "security",
                "find-generic-password",
                "-a",
                os.environ["USER"],
                "-s",
                service,
                "-w",
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        raise KeyError(f"Secret not found for key: {key}")


def set_secret(key: str, value: str) -> None:
    """Set a secret in macOS Keychain"""
    service = f"{KEYCHAIN_SERVICE}-{key}"

    # Try to add, if exists delete and re-add
    try:
        subprocess.run(
            [
                "security",
                "add-generic-password",
                "-a",
                os.environ["USER"],
                "-s",
                service,
                "-w",
                value,
                "-U",
            ],
            capture_output=True,
            check=True,
        )
    except subprocess.CalledProcessError:
        # Delete and retry
        subprocess.run(
            [
                "security",
                "delete-generic-password",
                "-a",
                os.environ["USER"],
                "-s",
                service,
            ],
            capture_output=True,
        )
        subprocess.run(
            [
                "security",
                "add-generic-password",
                "-a",
                os.environ["USER"],
                "-s",
                service,
                "-w",
                value,
                "-U",
            ],
            capture_output=True,
            check=True,
        )

    print(f"✓ Secret stored for key: {key}")


def delete_secret(key: str) -> None:
    """Delete a secret from macOS Keychain"""
    service = f"{KEYCHAIN_SERVICE}-{key}"

    try:
        subprocess.run(
            [
                "security",
                "delete-generic-password",
                "-a",
                os.environ["USER"],
                "-s",
                service,
            ],
            capture_output=True,
            check=True,
        )
        print(f"✓ Secret deleted for key: {key}")
    except subprocess.CalledProcessError:
        raise KeyError(f"Secret not found for key: {key}")


def list_secrets() -> list:
    """List all secrets for this service"""
    try:
        result = subprocess.run(
            ["security", "dump-keychain"],
            capture_output=True,
            text=True,
            stderr=subprocess.DEVNULL,
        )

        secrets = []
        for line in result.stdout.split("\n"):
            if KEYCHAIN_SERVICE in line:
                # Extract service name
                if "svce" in line or "service" in line:
                    parts = line.split('"')
                    if len(parts) >= 2:
                        secrets.append(parts[1])

        return list(set(secrets))
    except subprocess.CalledProcessError:
        return []


def main():
    if len(sys.argv) < 2:
        print("Usage: keychain.py {get|set|delete|list} [key] [value]")
        print("")
        print("Examples:")
        print("  keychain.py set mcp-token abc123")
        print("  keychain.py get mcp-token")
        print("  keychain.py delete mcp-token")
        print("  keychain.py list")
        sys.exit(1)

    command = sys.argv[1]

    try:
        if command == "get":
            if len(sys.argv) < 3:
                print("Usage: keychain.py get <key>")
                sys.exit(1)
            value = get_secret(sys.argv[2])
            print(value)

        elif command == "set":
            if len(sys.argv) < 4:
                print("Usage: keychain.py set <key> <value>")
                sys.exit(1)
            set_secret(sys.argv[2], sys.argv[3])

        elif command == "delete":
            if len(sys.argv) < 3:
                print("Usage: keychain.py delete <key>")
                sys.exit(1)
            delete_secret(sys.argv[2])

        elif command == "list":
            secrets = list_secrets()
            if secrets:
                print(f"Found {len(secrets)} secrets:")
                for secret in secrets:
                    print(f"  - {secret}")
            else:
                print("No secrets found")

        else:
            print(f"Unknown command: {command}")
            sys.exit(1)

    except KeyError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
