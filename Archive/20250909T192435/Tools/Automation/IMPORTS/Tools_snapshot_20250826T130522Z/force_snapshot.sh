#!/usr/bin/env bash
# Robust workspace force snapshot script
# - discovers git repos under the workspace roots
# - for each repo: git add -A, commit --no-verify, push (with upstream fallback)
# - writes per-repo log to logs/force_snapshot_<ts>/

set -euo pipefail

ROOTS=(
	"/Users/danielstevens/Desktop/Code/Projects"
	"/Users/danielstevens/Desktop/Code/Shared"
	"/Users/danielstevens/Desktop/Code/Tools"
	"/Users/danielstevens/Desktop/Code/Documentation"
	"/Users/danielstevens/Desktop/CodingReviewer-Modular"
)

TS=$(date -u +%Y%m%dT%H%M%SZ)
# Allow passing an explicit OUTDIR as first argument; otherwise default to Tools/Automation/logs
DEFAULT_BASE_DIR="/Users/danielstevens/Desktop/Code/Tools/Automation/logs"
if [[ -n ${1-} ]]; then
	OUTDIR="${1%/}"
else
	OUTDIR="${DEFAULT_BASE_DIR}/force_snapshot_${TS}"
fi
mkdir -p "${OUTDIR}"

echo "Force snapshot: ${TS}" | tee "${OUTDIR}/summary.txt"

repos_file="${OUTDIR}/repos_found.txt"
: >"${repos_file}"

echo "Discovering git repositories..."
for r in "${ROOTS[@]}"; do
	if [[ -d ${r} ]]; then
		# find repository roots by locating .git dirs and strip the trailing '/.git'
		find "${r}" -type d -name .git -prune -print | sed 's#/\.git$##' >>"${repos_file}" || true
	fi
done

echo "Found repos:"
wc -l "${repos_file}" | tee -a "${OUTDIR}/summary.txt"

while IFS= read -r repo; do
	[[ -z ${repo} ]] && continue
	echo "--- Processing: ${repo}" | tee -a "${OUTDIR}/summary.txt"
	log_file="${OUTDIR}/$(basename "${repo}")_snapshot.log"
	{
		echo "Repo: ${repo}"
		cd "${repo}"
		if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
			echo "Git status (porcelain):"
			git status --porcelain || true
			echo "Adding all changes..."
			git add -A || true
			if git diff --cached --quiet; then
				echo "No staged changes after add. Skipping commit."
			else
				echo "Committing snapshot..."
				git commit -m "snapshot: commit all local changes before automation run (${TS})" --no-verify || echo "Commit failed or nothing to commit"
			fi
			echo "Pushing..."
			if git push --no-verify 2>&1; then
				echo "Pushed to default remote"
			else
				echo "Push failed; trying push -u origin HEAD..."
				git push -u origin HEAD 2>&1 || echo "Push failed; please check remote/auth"
			fi
		else
			echo "Not a git worktree: ${repo}"
		fi
	} &>"${log_file}" || true
	echo "Wrote log: ${log_file}" | tee -a "${OUTDIR}/summary.txt"
done <"${repos_file}"

echo "Completed force snapshot: ${TS}" | tee -a "${OUTDIR}/summary.txt"

echo "Logs are under: ${OUTDIR}"
