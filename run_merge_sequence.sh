#!/usr/bin/env bash
set -euo pipefail

# run_merge_sequence.sh
# Usage: ./run_merge_sequence.sh [PR_NUMS...]
# Example: ./run_merge_sequence.sh 1 3 4 5 6
# If no PR numbers are given it will use a small default list.
# The script creates a local branch merge/auto-<timestamp>, fetches each PR, attempts
# a --no-commit merge, runs a lightweight check, and commits if clean.
# Logs are written to /tmp/merge-<timestamp>-pr-<N>.log

TS=$(date +%Y%m%d%H%M%S)
LOGDIR="/tmp/merge-logs-${TS}"
mkdir -p "$LOGDIR"

#!/usr/bin/env bash
set -euo pipefail

# run_merge_sequence.sh
# Usage: ./run_merge_sequence.sh [PR_NUMS...]
# Example: ./run_merge_sequence.sh 1 3 4 5 6
# If no PR numbers are given it will use a small default list.
# The script creates a local branch merge/auto-<timestamp>, fetches each PR, attempts
# a --no-commit merge, runs a lightweight check, and commits if clean.
# Logs are written to /tmp/merge-<timestamp>-pr-<N>.log

TS=$(date +%Y%m%d%H%M%S)
LOGDIR="/tmp/merge-logs-${TS}"
mkdir -p "$LOGDIR"

PR_LIST=(${@:-1 3 4 5 6})
WORK_BRANCH="merge/auto-${TS}"

echo "Working directory: $(pwd)"
echo "Creating working branch $WORK_BRANCH from origin/main"

git fetch origin
if git show-ref --verify --quiet refs/heads/"$WORK_BRANCH"; then
	git checkout "$WORK_BRANCH"
else
	git checkout origin/main -b "$WORK_BRANCH"
fi

echo "On branch: $(git rev-parse --abbrev-ref HEAD)"

for PR in "${PR_LIST[@]}"; do
	LOGFILE="$LOGDIR/merge-${TS}-pr-${PR}.log"
	echo "\n--- Processing PR #${PR} (log: $LOGFILE) ---" | tee -a "$LOGFILE"

	echo "Fetching PR ${PR}..." | tee -a "$LOGFILE"
	if ! git fetch origin pull/${PR}/head:pr-${PR} >>"$LOGFILE" 2>&1; then
		echo "Failed to fetch PR ${PR}. See $LOGFILE" | tee -a "$LOGFILE"
		exit 2
	fi

	echo "Merging pr-${PR} with --no-commit..." | tee -a "$LOGFILE"
	if ! git merge --no-commit --no-ff pr-${PR} >>"$LOGFILE" 2>&1; then
		echo "Merge conflict or error detected for PR ${PR}." | tee -a "$LOGFILE"
		echo "Conflict files:" >>"$LOGFILE"
		git diff --name-only --diff-filter=U >>"$LOGFILE" 2>&1 || true
		git merge --abort || true
		echo "Stopped at PR ${PR}. Inspect $LOGFILE and resolve manually." | tee -a "$LOGFILE"
		exit 3
	fi

	echo "Quick checks (git status, staged files)" | tee -a "$LOGFILE"
	git status --porcelain >>"$LOGFILE" 2>&1 || true
	git diff --name-only --cached >>"$LOGFILE" 2>&1 || true

	if [ -x ./Tools/Automation/master_automation.sh ]; then
		echo "Running lightweight automation status check (may be noisy)" | tee -a "$LOGFILE"
		./Tools/Automation/master_automation.sh status >>"$LOGFILE" 2>&1 || echo "automation check returned non-zero" | tee -a "$LOGFILE"
	else
		echo "No automation status script found or not executable" | tee -a "$LOGFILE"
	fi

	echo "Finalizing merge for PR ${PR} (commit)" | tee -a "$LOGFILE"
	git commit --no-edit >>"$LOGFILE" 2>&1 || true
	echo "PR ${PR} merged locally. Recent commits:" | tee -a "$LOGFILE"
	git --no-pager log --oneline -n 5 >>"$LOGFILE" 2>&1 || true
	tail -n 30 "$LOGFILE" | sed -n '1,120p'

done

echo "All done. Logs are in: $LOGDIR"
echo "To push the merge branch to origin: git push origin $WORK_BRANCH"
