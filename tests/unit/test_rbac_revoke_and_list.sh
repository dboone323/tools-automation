#!/usr/bin/env bash
set -euo pipefail

PWD_ROOT="$(pwd)"
SCRIPT="$PWD_ROOT/rbac_maintenance.sh"

# Ensure no sessions DB exists
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/logs"
RBAC_WORKSPACE_ROOT="$TMPDIR" bash "$SCRIPT" list >/tmp/rbac_list_out.json
if [[ $(cat /tmp/rbac_list_out.json) != '{}' ]]; then
    echo "FAIL: expected empty object when no sessions DB"
    exit 2
fi

# Revoke should report no sessions DB
set +e
RBAC_WORKSPACE_ROOT="$TMPDIR" bash "$SCRIPT" revoke some-session
RC=$?
set -e
if [[ $RC -eq 0 ]]; then
    echo "FAIL: revoke should have failed when sessions DB missing"
    exit 3
fi

echo "PASS: list and revoke edge cases behaved as expected"
