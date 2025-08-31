#!/usr/bin/env bash
#set -e
# Make a small modification to a test file, then exit with non-zero to simulate failure.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTFILE="$ROOT/test_modify_target.txt"
mkdir -p "$(dirname "$TESTFILE")"
# allow a brief window for agents to detect the queued task and create backups
sleep 1
echo "backup-$(date +%s)" >>"$TESTFILE"
# sleep to simulate work
sleep 1
# return failure
exit 2
