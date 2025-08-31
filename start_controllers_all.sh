#!/usr/bin/env bash
# Start a controller per project directory (dry-run by default)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# canonical venv location (Automation/.venv) next to this script
VENV_PY="$SCRIPT_DIR/.venv/bin/python"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_DIR="$BASE_DIR/Projects"
DRY_RUN=1
if [[ ${1-} == "--start" ]]; then
	DRY_RUN=0
fi

for d in "${ROOT_DIR}"/*/; do
	proj=$(basename "${d}")
	# skip non-project dirs
	[[ -f "${d}/.skip_project" ]] && continue
	cmd=("${VENV_PY}" "$(dirname "$0")/mcp_controller.py")
	echo "Project: ${proj} -> ${cmd[*]} (env: PROJECT_NAME=${proj})"
	if [[ ${DRY_RUN} -eq 0 ]]; then
		LOGFILE="$BASE_DIR/logs/controller_${proj}.log"
		mkdir -p "$(dirname "$LOGFILE")"
		echo "Starting controller for $proj -> log: $LOGFILE"
		PROJECT_NAME="${proj}" PROJECT_DIR="${d}" nohup "${cmd[@]}" &>"$LOGFILE" &
	fi
done

echo "Done (dry_run=${DRY_RUN}). Use --start to actually launch controllers."
