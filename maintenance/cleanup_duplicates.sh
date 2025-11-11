#!/bin/bash
# cleanup_duplicates.sh - Archive and remove duplicate project directories
# This script targets the parent folder of tools-automation (github-projects).
# It will:
# - Archive and remove top-level project clones (avoid-obstacle-game, coding-reviewer, habitquest, momentum-finance, planner-app, shared-kit)
# - Archive and remove stray nested copy tools-automation/quantum-workspace/coding-reviewer
# - Archive and remove top-level Projects/
# Archives are created in the github-projects folder as <name>-archive-YYYYMMDD_HHMMSS.tgz

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT="$(cd "${TOOL_ROOT}/.." && pwd)" # parent of tools-automation, i.e., github-projects
TS="$(date +%Y%m%d_%H%M%S)"

echo "[cleanup] Operating in root: $ROOT"

archive_and_remove() {
    local path="$1"
    shift || true
    local label="${1:-}"
    if [[ -d "$path" ]]; then
        local rel base archive_name
        case "$path" in
        "$ROOT"/*) rel="${path#${ROOT}/}" ;;
        *) rel="$(basename "$path")" ;;
        esac
        base="$(basename "$path")"
        archive_name="${label:-$base}-archive-${TS}.tgz"
        echo "[cleanup] Archiving $path -> $archive_name (as $rel)"
        tar -C "$ROOT" -czf "$ROOT/$archive_name" "$rel"
        echo "[cleanup] Removing $path"
        rm -rf "$path"
    else
        echo "[cleanup] Skip (not found): $path"
    fi
}

cd "$ROOT"

echo "[cleanup] Step 1: Top-level duplicate project clones"
for repo in avoid-obstacle-game coding-reviewer habitquest momentum-finance planner-app shared-kit; do
    if [[ -d "$ROOT/$repo" ]]; then
        archive_and_remove "$ROOT/$repo" "$repo"
    else
        echo "[cleanup] Skip (not found): $repo"
    fi
done

echo "[cleanup] Step 2: Stray nested copy under tools-automation/quantum-workspace/coding-reviewer"
if [[ -d "$ROOT/tools-automation/quantum-workspace/coding-reviewer" ]]; then
    archive_and_remove "$ROOT/tools-automation/quantum-workspace/coding-reviewer" "coding-reviewer-quantum"
else
    echo "[cleanup] Skip (not found): tools-automation/quantum-workspace/coding-reviewer"
fi

echo "[cleanup] Step 3: Top-level Projects folder"
if [[ -d "$ROOT/Projects" ]]; then
    archive_and_remove "$ROOT/Projects" "Projects"
else
    echo "[cleanup] Skip (not found): Projects"
fi

echo "[cleanup] Done. Remaining top-level items:"
ls -1 "$ROOT"
