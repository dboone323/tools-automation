#!/usr/bin/env bash
set -euo pipefail

# Safe consolidation script.
# Default is dry-run: prints planned actions. Use --execute to perform moves.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
cd "${ROOT_DIR}"

EXECUTE=false
ARCHIVE_DIR="${ROOT_DIR}/Tools/Automation/Archive/$(date '+%Y%m%dT%H%M%S')"
mkdir -p "${ARCHIVE_DIR}"

log() { echo "[consolidate] $*"; }
run() {
  if $EXECUTE; then
    "$@"
  else
    printf 'DRY-RUN: %q ' "$@"; echo
  fi
}

usage() {
  cat <<USG
Usage: $(basename "$0") [--execute]

Actions (safe, idempotent):
- Quarantine snapshot/backup directories into Archive
- De-duplicate stray cspell.json copies, keeping Shared/cspell.json as canonical
USG
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

quarantine_dir() {
  local rel="$1"
  local dest="${ARCHIVE_DIR}/${rel}"
  mkdir -p "$(dirname "$dest")"
  run mkdir -p "$(dirname "$dest")"
  run mv "$rel" "$dest"
}

# 1) Quarantine snapshot-like directories
mapfile -t SNAP_DIRS < <(\
  find Tools -type d \( -path '*/IMPORTS/*' -o -path '*/Imported/*' -o -path '*/_merge_backups/*' \) -prune | sort || true)

for d in "${SNAP_DIRS[@]}"; do
  log "Quarantining: $d"
  quarantine_dir "$d"
done

# 2) cspell.json de-duplication (retain Shared/cspell.json)
CANON="Shared/cspell.json"
if [ -f "$CANON" ]; then
  mapfile -t CSPELLS < <(find . -type f -name 'cspell.json' ! -path "./${CANON}" | sort || true)
  for f in "${CSPELLS[@]}"; do
    # Skip inside Archive we just created
    [[ "$f" == ./Tools/Automation/Archive/* ]] && continue
    dest="${ARCHIVE_DIR}/${f#./}"
    mkdir -p "$(dirname "$dest")"
    run mkdir -p "$(dirname "$dest")"
    log "Archiving duplicate cspell.json: $f"
    run mv "$f" "$dest"
  done
else
  log "Canonical cspell not found at $CANON; skipping de-dup."
fi

log "Done. Mode: $($EXECUTE && echo EXECUTE || echo DRY-RUN)"
