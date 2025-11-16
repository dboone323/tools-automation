#!/usr/bin/env python3
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUARANTINE = ROOT / "tests" / "quarantine.txt"
FLAKY_LOG = ROOT / "reports" / "flaky_tests.log"
QUARANTINE.parent.mkdir(parents=True, exist_ok=True)
FLAKY_LOG.parent.mkdir(parents=True, exist_ok=True)


def add(test_name: str):
    entries = set()
    if QUARANTINE.exists():
        entries.update(
            x.strip() for x in QUARANTINE.read_text().splitlines() if x.strip()
        )
    entries.add(test_name)
    QUARANTINE.write_text("\n".join(sorted(entries)) + "\n")
    print(f"Quarantined: {test_name}")


def remove(test_name: str):
    if not QUARANTINE.exists():
        return
    entries = [
        x.strip()
        for x in QUARANTINE.read_text().splitlines()
        if x.strip() and x.strip() != test_name
    ]
    QUARANTINE.write_text("\n".join(entries) + ("\n" if entries else ""))
    print(f"Un-quarantined: {test_name}")


def list_entries():
    if QUARANTINE.exists():
        print(QUARANTINE.read_text(), end="")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("action", choices=["add", "remove", "list"])
    ap.add_argument("name", nargs="?")
    args = ap.parse_args()

    if args.action in ("add", "remove") and not args.name:
        ap.error("name required for add/remove")

    if args.action == "add":
        add(args.name)
    elif args.action == "remove":
        remove(args.name)
    else:
        list_entries()
