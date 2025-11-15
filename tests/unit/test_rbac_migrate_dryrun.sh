#!/usr/bin/env bash
set -euo pipefail

PWD_ROOT="$(pwd)"
SCRIPT="$PWD_ROOT/rbac_maintenance.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/rbac_config"
mkdir -p "$TMPDIR/logs"

cat >"$TMPDIR/rbac_config/sessions.json" <<'JSON'
{
  "sessions": {
    "s1": { "username": "alice" },
    "s2": { "username": "bob", "active": false }
  }
}
JSON

cp "$TMPDIR/rbac_config/sessions.json" "$TMPDIR/rbac_config/sessions.json.orig"

# Run dry-run migrate
RBAC_WORKSPACE_ROOT="$TMPDIR" bash "$SCRIPT" migrate-sessions --dry-run

# Ensure original file unchanged
if ! diff -q "$TMPDIR/rbac_config/sessions.json" "$TMPDIR/rbac_config/sessions.json.orig" >/dev/null; then
    echo "FAIL: sessions.json changed during dry-run"
    exit 2
fi

echo "PASS: migrate-sessions --dry-run left sessions.json unchanged"
