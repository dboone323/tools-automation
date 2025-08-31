#!/usr/bin/env bash
set -euo pipefail

# quantum_agent_entrypoint.sh
# Safe wrapper to run policy checks and invoke AI recovery for a given project.

PROJECT_PATH="${1-}"
DRY_RUN="${2:-true}"
ENABLE_AUTO_FIX="${3:-false}"
LOGFILE="quantum_agent_${PROJECT_PATH//\//_}.log"
AUTO_FIX_MODE="${4:-auto}" # 'auto' or 'prompt' (prompt not implemented here)
USE_MCP="${USE_MCP:-false}"

if [[ -z ${PROJECT_PATH} ]]; then
	echo "Usage: $0 <project_path> [dry_run:true|false] [enable_auto_fix:true|false]"
	exit 2
fi

echo "Quantum Agent entrypoint: project=${PROJECT_PATH} dry_run=${DRY_RUN} enable_auto_fix=${ENABLE_AUTO_FIX}" | tee "${LOGFILE}"

# 1) Run policy checker (warn or auto-fix depending on flags)
if command -v python3 >/dev/null 2>&1; then
	if [[ ${ENABLE_AUTO_FIX} == "true" ]]; then
		echo "Running checker with auto-fix analysis" | tee -a "${LOGFILE}"
		python3 "$(dirname "$0")/check_architecture.py" --project "${PROJECT_PATH}" --warn-only --auto-fix | tee -a "${LOGFILE}" || true

		# If the target project is a git repo, attempt to commit any fixes produced by the checker.
		if [[ -d "${PROJECT_PATH}/.git" ]]; then
			echo "Detected git repository at ${PROJECT_PATH}; attempting to commit fixes" | tee -a "${LOGFILE}"
			pushd "${PROJECT_PATH}" >/dev/null 2>&1 || true
			git add -A || true
			if git diff --staged --quiet; then
				echo "No staged changes after auto-fix" | tee -a "${LOGFILE}"
			else
				git commit -m "auto-fix: apply safe architecture fixes (multi-doc split, action pin bumps)" || true
				git push origin HEAD || echo "push failed or no remote" | tee -a "${LOGFILE}"
			fi
			popd >/dev/null 2>&1 || true
		else
			echo "Project is not a git repo (no .git dir); leaving fixes uncommitted" | tee -a "${LOGFILE}"
		fi
	else
		python3 "$(dirname "$0")/check_architecture.py" --project "${PROJECT_PATH}" --warn-only | tee -a "${LOGFILE}" || true
	fi
else
	echo "python3 not available; skipping policy check" | tee -a "${LOGFILE}"
fi

# If configured to use MCP, register and request the MCP to queue a run instead
if [[ ${USE_MCP} == "true" ]]; then
	MCP_URL="${MCP_URL:-http://127.0.0.1:5005}"
	echo "Registering agent with MCP at ${MCP_URL}" | tee -a "${LOGFILE}"
	curl -s -X POST "${MCP_URL}/register" -H 'Content-Type: application/json' -d '{"agent": "quantum-agent", "capabilities": ["policy"]}' | tee -a "${LOGFILE}"
	echo "Requesting MCP to queue a dry-run ai_workflow_recovery for ${PROJECT_PATH}" | tee -a "${LOGFILE}"
	curl -s -X POST "${MCP_URL}/run" -H 'Content-Type: application/json' -d "{\"agent\": \"quantum-agent\", \"command\": \"ci-check\", \"project\": \"$(basename ${PROJECT_PATH})\", \"execute\": false}" | tee -a "${LOGFILE}"
fi

# 2) Invoke AI recovery script (safe defaults)
ARGS=(--project "${PROJECT_PATH}")
if [[ ${DRY_RUN} == "true" ]]; then
	ARGS+=(--dry-run)
fi
if [[ ${ENABLE_AUTO_FIX} == "true" ]]; then
	ARGS+=(--enable-auto-fix)
fi

echo "Invoking ai_workflow_recovery.py (dry-run enforced) for ${PROJECT_PATH}" | tee -a "${LOGFILE}"
# enforce dry-run for safety; ai_workflow_recovery expects --repo-path and --dry-run
python3 "$(dirname "$0")/ai_workflow_recovery.py" --repo-path "${PROJECT_PATH}" --dry-run 2>&1 | tee -a "${LOGFILE}" || true

echo "Entrypoint finished" | tee -a "${LOGFILE}"
exit 0
