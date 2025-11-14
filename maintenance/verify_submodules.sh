#!/bin/bash
# verify_submodules.sh - Check submodule HEAD vs remote default branch (ahead/behind)
# Usage: bash verify_submodules.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SUPER="$TOOL_ROOT" # superproject (tools-automation)

cd "$SUPER"
if [[ ! -f .gitmodules ]]; then
    echo "[verify] No .gitmodules found in $SUPER" >&2
    exit 0
fi

echo "[verify] Superproject: $SUPER"

# List submodule paths from .gitmodules
mapfile -t SUB_PATHS < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path' | awk '{print $2}')

if ((${#SUB_PATHS[@]} == 0)); then
    echo "[verify] No submodules defined."
    exit 0
fi

printf "%-28s %-8s %-8s %-12s %-12s %s\n" "submodule" "ahead" "behind" "HEAD" "remote" "branch"
printf "%-28s %-8s %-8s %-12s %-12s %s\n" "---------" "-----" "------" "----" "------" "------"

for p in "${SUB_PATHS[@]}"; do
    path="$SUPER/$p"
    if [[ ! -d "$path/.git" && ! -f "$path/.git" ]]; then
        printf "%-28s %s\n" "$p" "(missing checkout)"
        continue
    fi
    # Determine default remote branch
    default_branch=$(git -C "$path" remote show origin 2>/dev/null | awk '/HEAD branch:/ {print $NF}' || true)
    if [[ -z "$default_branch" ]]; then
        default_branch=main
    fi
    # Fetch quietly
    git -C "$path" fetch -q origin || true
    head_sha=$(git -C "$path" rev-parse --short HEAD 2>/dev/null || echo "-")
    remote_sha=$(git -C "$path" rev-parse --short "origin/$default_branch" 2>/dev/null || echo "-")
    # Compute ahead/behind
    ab="$(git -C "$path" rev-list --left-right --count HEAD..."origin/$default_branch" 2>/dev/null || echo "0\t0")"
    ahead=$(echo "$ab" | awk '{print $1}')
    behind=$(echo "$ab" | awk '{print $2}')
    printf "%-28s %-8s %-8s %-12s %-12s %s\n" "$p" "$ahead" "$behind" "$head_sha" "$remote_sha" "$default_branch"
done

echo "[verify] Done."
