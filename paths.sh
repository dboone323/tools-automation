#!/bin/bash
# paths.sh - Shared path utility functions. Source after env.sh.
# Usage: source "$(dirname "$BASH_SOURCE")/env.sh" && source "$(dirname "$BASH_SOURCE")/paths.sh"

# Ensure env loaded
if [[ -z "${WORKSPACE_ROOT}" ]]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
fi

# get_repo_root: echo the repository root directory
get_repo_root() {
    echo "${REPO_ROOT}" # alias of WORKSPACE_ROOT
}

# require_repo_root: ensure the repo root exists and contains .git
require_repo_root() {
    if [[ -z "${REPO_ROOT}" || ! -d "${REPO_ROOT}" ]]; then
        echo "[paths.sh] ERROR: REPO_ROOT is not set or not a directory" >&2
        return 1
    fi
    if [[ ! -d "${REPO_ROOT}/.git" ]]; then
        echo "[paths.sh] ERROR: REPO_ROOT (${REPO_ROOT}) does not contain a .git directory" >&2
        return 1
    fi
    return 0
}

# path_join: join multiple path segments safely, removing duplicate slashes
# Example: path_join "$REPO_ROOT" "agents" "script.sh"
path_join() {
    local IFS="/"
    local joined="$*"
    # Replace multiple slashes with single slash
    echo "${joined}" | sed -e 's#//#/#g' -e 's#/$##'
}

# repo_relative: produce absolute path from repo root + relative segments
repo_relative() {
    require_repo_root || return 1
    local rel
    rel="$(path_join "$@")"
    echo "$(path_join "${REPO_ROOT}" "${rel}")"
}

# ensure_dir: create directory if missing
ensure_dir() {
    local dir="$1"
    [[ -z "$dir" ]] && {
        echo "[paths.sh] ERROR: ensure_dir requires directory arg" >&2
        return 1
    }
    mkdir -p "$dir"
}

# is_absolute: check if given path is absolute
is_absolute() {
    local p="$1"
    [[ "$p" == /* ]]
}

# resolve_path: canonicalize path (no symlink resolution beyond realpath availability)
resolve_path() {
    local p="$1"
    if command -v realpath >/dev/null 2>&1; then
        realpath "$p" 2>/dev/null || echo "$p"
    else
        # Fallback: cd and print pwd
        (cd "$p" 2>/dev/null && pwd) || echo "$p"
    fi
}
