#!/usr/bin/env bash
set -euo pipefail

# Test that a role with wildcard '*' grants any permission
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp rbac_system.sh "$TMPDIR/"
chmod +x "$TMPDIR/rbac_system.sh"

pushd "$TMPDIR" >/dev/null
./rbac_system.sh init >/dev/null

# Authenticate admin (super_admin with `*`)
auth_out=$(./rbac_system.sh auth admin admin123)
session_id=$(echo "$auth_out" | jq -r '.session_id')

# Check a random permission that only wildcard would grant
check_out=$(./rbac_system.sh check "$session_id" "some.random.permission")

if echo "$check_out" | jq -e '.authorized == true' >/dev/null 2>&1; then
    echo "PASS: wildcard role granted permission"
    popd >/dev/null
    exit 0
else
    echo "FAIL: wildcard role did not grant permission"
    echo "check output: $check_out"
    popd >/dev/null
    exit 2
fi
