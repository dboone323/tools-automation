#!/usr/bin/env bash
set -euo pipefail

# Phase 1 prototype: parse logs, extract error patterns, update knowledge base.
# No network calls; relies on local Python helpers.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)" # Quantum-workspace

PY_RECOGNIZER="${SCRIPT_DIR}/pattern_recognizer.py"
PY_UPDATER="${SCRIPT_DIR}/update_knowledge.py"

usage() {
    cat <<EOF
Error Learning Agent (Phase 1)
Usage:
  $(basename "$0") --scan-once <log-file>
  $(basename "$0") --watch <dir> [--glob "*.log"]

Examples:
  $(basename "$0") --scan-once "${ROOT_DIR}/test_results_*.log"
  $(basename "$0") --watch "${ROOT_DIR}" --glob "test_results_*.log"
EOF
}

# Return 0 if line looks like an error-worthy line
is_error_line() {
    local line="$1"
    if [[ "$line" =~ \[ERROR\] ]] || [[ "$line" =~ ❌ ]] || [[ "$line" =~ [Ff]ailed ]]; then
        return 0
    fi
    return 1
}

process_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        if is_error_line "$line"; then
            # Recognize pattern via Python, then update KB via Python
            local json
            if ! json="$(${PY_RECOGNIZER} --line "$line" 2>/dev/null)"; then
                continue
            fi
            # Append example field for context
            json=$(
                python3 - "$json" "$line" <<'PY'
import json,sys
obj=json.loads(sys.argv[1])
obj.setdefault('example', sys.argv[2])
print(json.dumps(obj, ensure_ascii=False))
PY
            )
            ${PY_UPDATER} --workspace "${ROOT_DIR}" --pattern-json "$json" --source "$file" >/dev/null 2>&1 || true
        fi
    done <"$file"
}

scan_once() {
    local pattern="$1"
    shopt -s nullglob
    local files=($pattern)
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "[info] No files matched pattern: $pattern"
        return 0
    fi
    for f in "${files[@]}"; do
        echo "[scan] Processing $f"
        process_file "$f"
    done
}

watch_dir() {
    local dir="$1"
    shift
    local glob="${1:-*.log}"
    echo "[watch] Watching $dir for $glob"
    while true; do
        scan_once "$dir/$glob"
        sleep 10
    done
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi
    case "${1:-}" in
    --scan-once)
        shift
        local pat="${1:-}"
        [[ -n "$pat" ]] || {
            echo "--scan-once requires a file pattern"
            exit 2
        }
        scan_once "$pat"
        ;;
    --watch)
        shift
        local dir="${1:-}"
        [[ -n "$dir" ]] || {
            echo "--watch requires a directory"
            exit 2
        }
        shift || true
        local glob="${1:-*.log}"
        watch_dir "$dir" "$glob"
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
    esac
}

main "$@"
