#!/bin/bash
# prune_archives.sh - Keep only the latest N archive files in github-projects/archives
# Usage: bash prune_archives.sh [N] [--dry-run]
# Default N=5. Operates in the parent folder of tools-automation (github-projects).

set -euo pipefail

N=5
DRY_RUN=0
if [[ ${1:-} =~ ^[0-9]+$ ]]; then
    N=$1
    shift || true
fi
if [[ ${1:-} == "--dry-run" ]]; then
    DRY_RUN=1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT="$(cd "${TOOL_ROOT}/.." && pwd)" # github-projects root
ARCH_DIR="$ROOT/archives"

echo "[prune] Root: $ROOT"
echo "[prune] Archives dir: $ARCH_DIR"
echo "[prune] Keeping latest $N archives per project group"

mkdir -p "$ARCH_DIR"
cd "$ARCH_DIR"

shopt -s nullglob
archives=(*-archive-*.tgz)
shopt -u nullglob

if ((${#archives[@]} == 0)); then
    echo "[prune] No archives found."
    exit 0
fi

# Build unique project groups based on the stem before '-archive-'
mapfile -t groups < <(printf '%s\n' "${archives[@]}" | sed 's/-archive-.*$//' | sort -u)

total_keep=()
total_delete=()

for g in "${groups[@]}"; do
    # List archives for this group, newest first (mtime)
    mapfile -t g_sorted < <(ls -1t -- "${g}-archive-"*.tgz 2>/dev/null || true)
    if ((${#g_sorted[@]} == 0)); then
        continue
    fi
    g_keep=("${g_sorted[@]:0:$N}")
    g_delete=("${g_sorted[@]:$N}")
    echo "[prune] Group: ${g} -> keep ${#g_keep[@]}, delete ${#g_delete[@]}"
    total_keep+=("${g_keep[@]}")
    total_delete+=("${g_delete[@]}")
done

echo "[prune] Will keep (${#total_keep[@]}):"
if ((${#total_keep[@]} > 0)); then
    printf '  %s\n' "${total_keep[@]}"
fi

if ((${#total_delete[@]} > 0)); then
    echo "[prune] Will delete (${#total_delete[@]}):"
    printf '  %s\n' "${total_delete[@]}"
    if ((DRY_RUN == 0)); then
        rm -f -- "${total_delete[@]}"
        echo "[prune] Deleted ${#total_delete[@]} archive(s)."
    else
        echo "[prune] Dry run: no files deleted."
    fi
else
    echo "[prune] Nothing to delete."
fi

echo "[prune] Done."
