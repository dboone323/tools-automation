#!/usr/bin/env bash
set -euo pipefail

# Test role inheritance edge case: current implementation does not apply `inherits_from`
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp rbac_system.sh "$TMPDIR/"
chmod +x "$TMPDIR/rbac_system.sh"

pushd "$TMPDIR" >/dev/null
./rbac_system.sh init >/dev/null

# Overwrite roles to add parent and child (child inherits_from parent)
cat >rbac_config/roles.json <<'JSON'
{
  "roles": {
    "parent": {
      "name": "parent",
      "description": "Parent role",
      "permissions": ["reports.view"],
      "inherits_from": [],
      "created_at": "2025-01-01T00:00:00Z"
    },
    "child": {
      "name": "child",
      "description": "Child role inheriting from parent",
      "permissions": [],
      "inherits_from": ["parent"],
      "created_at": "2025-01-01T00:00:00Z"
    }
  },
  "last_updated": null
}
JSON

# Add a user who has only the child role
cat >rbac_config/users.json <<'JSON'
{
  "users": {
    "childuser": {
      "username": "childuser",
      "password_hash": "$2b$12$dummy",
      "email": "child@local",
      "roles": ["child"],
      "status": "active",
      "created_at": "2025-01-01T00:00:00Z",
      "last_login": null,
      "failed_attempts": 0,
      "locked_until": null
    }
  },
  "last_updated": null
}
JSON

# Authenticate childuser using one of the accepted test passwords
auth_out=$(./rbac_system.sh auth childuser dev123)
session_id=$(echo "$auth_out" | jq -r '.session_id')

# Check permission that would be granted via inheritance if implemented
check_out=$(./rbac_system.sh check "$session_id" "reports.view")

# Now that inheritance is implemented, expect authorized via parent role
if echo "$check_out" | jq -e '.authorized == true' >/dev/null 2>&1; then
    echo "PASS: inherited permission granted"
    popd >/dev/null
    exit 0
else
    echo "FAIL: inherited permission not granted"
    echo "check output: $check_out"
    popd >/dev/null
    exit 2
fi
