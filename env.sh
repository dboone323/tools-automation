#!/bin/bash
# env.sh - Common environment bootstrap for tools-automation and related scripts.
# Usage: source "$(dirname "$BASH_SOURCE")/env.sh"
# Provides: WORKSPACE_ROOT (repo top level), REPO_ROOT (alias), SCRIPT_ROOT (directory of calling script)
# Idempotent: safe to source multiple times.

# Preserve existing if already set and points to a git root
if [[ -n "${WORKSPACE_ROOT}" && -d "${WORKSPACE_ROOT}/.git" ]]; then
    export REPO_ROOT="${WORKSPACE_ROOT}"
else
    # Determine repo root via git or fallback to current file's parent directory
    _env_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if git -C "${_env_script_dir}" rev-parse --show-toplevel >/dev/null 2>&1; then
        export WORKSPACE_ROOT="$(git -C "${_env_script_dir}" rev-parse --show-toplevel 2>/dev/null)"
    else
        export WORKSPACE_ROOT="${_env_script_dir}"
    fi
    export REPO_ROOT="${WORKSPACE_ROOT}"
fi

# Provide SCRIPT_ROOT for callers (directory of the *calling* script if possible)
# If BASH_SOURCE has more than one entry, last is caller.
if [[ ${#BASH_SOURCE[@]} -gt 1 ]]; then
    export SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[-1]}")" && pwd)"
else
    export SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Normalize path (remove trailing slash)
WORKSPACE_ROOT="${WORKSPACE_ROOT%/}"
REPO_ROOT="${REPO_ROOT%/}"
SCRIPT_ROOT="${SCRIPT_ROOT%/}"
export WORKSPACE_ROOT REPO_ROOT SCRIPT_ROOT
