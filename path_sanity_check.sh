#!/bin/bash
# path_sanity_check.sh - Fail if hardcoded user-specific absolute paths are present.
# Intended for local pre-commit/CI use.
# Usage: bash path_sanity_check.sh [root_dir]
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel 2>/dev/null || cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Patterns to flag: customize as needed
PATTERNS=(
  "/Users/[^/ ]+/(Desktop|Documents|Downloads)"
  "/Volumes/[^/ ]+"
  "C:\\\\Users\\\\[^\\ ]+\\\\(Desktop|Documents|Downloads)"
  "/home/[^/ ]+/(Desktop|Documents|Downloads)"
)

# Extensions to scan
INCLUDE_EXT="sh|bash|zsh|py|js|ts|json|yml|yaml|md|swift|rb|go|java|gradle|cfg|ini|toml|txt"

cd "$ROOT_DIR"

# Exclusions: .git, node_modules, build outputs, vendor, Pods, Carthage, .venv
EXCLUDES=(
  "./.git"
  "./node_modules"
  "./vendor"
  "./Pods"
  "./Carthage"
  "./.venv"
  "./.idea"
  "./.vscode"
  "./build"
  "./dist"
  "./.DS_Store"
)

exclude_args=()
for ex in "${EXCLUDES[@]}"; do
  exclude_args+=( -path "$ex" -prune -o )
fi

# Build find command dynamically
# shellcheck disable=SC2016
cmd=(find . \( )
cmd+=("${exclude_args[@]}")
cmd+=( -type f -regex ".*\.(${INCLUDE_EXT})$" -print )
cmd+=( \) )

mapfile -t files < <("${cmd[@]}")

violations=()
for f in "${files[@]}"; do
  for pat in "${PATTERNS[@]}"; do
    if grep -EIn -- "$pat" "$f" >/dev/null 2>&1; then
      # Capture matching lines
      while IFS= read -r line; do
        violations+=("$f:$line")
      done < <(grep -EIn -- "$pat" "$f")
    fi
  done
done

if [[ ${#violations[@]} -gt 0 ]]; then
  echo "Hardcoded absolute paths detected:" >&2
  printf '%s
' "${violations[@]}" >&2
  echo "\nPlease replace with repo-relative resolution via env.sh/paths.sh." >&2
  exit 1
else
  echo "Path sanity check passed."
fi
