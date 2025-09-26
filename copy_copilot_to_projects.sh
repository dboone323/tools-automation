#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="${REPO_ROOT}/.github/copilot-instructions.md"

if [[ ! -f ${SRC} ]]; then
	echo "ERROR: ${SRC} not found. Ensure .github/copilot-instructions.md exists at repo root." >&2
	exit 2
fi

changed=0
for proj in "${REPO_ROOT}"/Projects/*; do
	if [[ -d ${proj} ]]; then
		target_dir="${proj}/.github"
		mkdir -p "${target_dir}"
		cp -v "${SRC}" "${target_dir}/copilot-instructions.md" && changed=$((changed + 1))
	fi
done

if [[ ${changed} -eq 0 ]]; then
	echo "No Projects/ subdirectories found or no copies made."
else
	echo "Copied copilot instructions into ${changed} project(s)."
fi

exit 0
