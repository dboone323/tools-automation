#!/usr/bin/env bash
# Helper to find hardcoded Quantum-workspace references and optionally replace them with WORKSPACE_ROOT
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SEARCH_PATTERN="/Users/danielstevens/Desktop/Quantum-workspace"
REPLACE_EXPR='${WORKSPACE_ROOT}'

if [[ "${1:-}" == "--apply" ]]; then
    echo "Applying replacements across repo (backing up files)
"
    # Make a backup directory
    backup_dir="${REPO_ROOT}/.workspace_patch_backups_$(date +%s)"
    mkdir -p "${backup_dir}"

    # Replace in all files (text)
    while IFS= read -r file; do
        echo "Patching: ${file}"
        cp "${file}" "${backup_dir}/$(basename "${file}").bak"
        # Use perl in-place to avoid sed differences across macOS vs Linux.
        # We build the perl expression using single-quotes and
        # concatenation so the literal "${WORKSPACE_ROOT}" is not
        # interpreted by the shell when set -u is active.
        # Use perl with a shift argument so the replacement string is
        # passed as a separate argv item and not re-interpreted by the shell
        perl -0777 -pe 'BEGIN{ $r = shift } s|\Q'"${SEARCH_PATTERN}"'\E|$r|g' "${REPLACE_EXPR}" -i.bak "${file}"
    done < <(grep -R -I --line-number --exclude-dir=.git --exclude-dir=node_modules --exclude=*.json "${SEARCH_PATTERN}" || true)

    echo "Done. Backups stored in ${backup_dir}"
else
    echo "Dry Run - files that would be changed:"
    grep -R -I --line-number --exclude-dir=.git --exclude-dir=node_modules --exclude=*.json "${SEARCH_PATTERN}" || true
    echo "
Run with --apply to automatically replace occurrences with \\${WORKSPACE_ROOT}."
fi
