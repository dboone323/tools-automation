#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
hooks_src="$root/Tools/Automation/hooks"
hooks_dst="$root/.git/hooks"

mkdir -p "$hooks_dst"
for hook in pre-commit; do
    src="$hooks_src/$hook"
    dst="$hooks_dst/$hook"
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        chmod +x "$dst"
        echo "Installed hook: $hook"
    fi
done
