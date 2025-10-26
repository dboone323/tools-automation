#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGENTS_DIR="${ROOT_DIR}/Tools/Automation/agents"
KNOWLEDGE_DIR="${AGENTS_DIR}/knowledge"

echo "[init] Ensuring directories exist"
mkdir -p "${KNOWLEDGE_DIR}"

echo "[init] Seeding knowledge files if missing"
: >"${KNOWLEDGE_DIR}/error_patterns.json" || true
[[ -s "${KNOWLEDGE_DIR}/error_patterns.json" ]] || echo '{}' >"${KNOWLEDGE_DIR}/error_patterns.json"
[[ -s "${KNOWLEDGE_DIR}/fix_history.json" ]] || echo '{"fixes": []}' >"${KNOWLEDGE_DIR}/fix_history.json"
[[ -s "${KNOWLEDGE_DIR}/failure_analysis.json" ]] || echo '{"analyses": []}' >"${KNOWLEDGE_DIR}/failure_analysis.json"
[[ -s "${KNOWLEDGE_DIR}/correlation_matrix.json" ]] || echo '{"correlations": []}' >"${KNOWLEDGE_DIR}/correlation_matrix.json"

echo "[perm] Marking agent scripts executable"
chmod +x "${AGENTS_DIR}/error_learning_agent.sh" || true
chmod +x "${AGENTS_DIR}/error_learning_scan.sh" || true
chmod +x "${AGENTS_DIR}/pattern_recognizer.py" || true
chmod +x "${AGENTS_DIR}/update_knowledge.py" || true

echo "[scan] Running a one-time scan over latest test logs (if present)"
LATEST_LOG=$(ls -t "${ROOT_DIR}"/test_results_*.log 2>/dev/null | head -n 1 || true)
if [[ -n "${LATEST_LOG}" && -f "${LATEST_LOG}" ]]; then
    echo "[scan] Using ${LATEST_LOG}"
    # Inline scan to avoid agent status side-effects during bootstrap
    PY_RECOGNIZER="${AGENTS_DIR}/pattern_recognizer.py"
    PY_UPDATER="${AGENTS_DIR}/update_knowledge.py"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ \[ERROR\] || "$line" =~ ❌ || "$line" =~ [Ff]ailed ]]; then
            json="$(${PY_RECOGNIZER} --line "$line" 2>/dev/null)" || true
            if [[ -n "$json" ]]; then
                json=$(
                    python3 - "$json" "$line" <<'PY'
import json,sys
obj=json.loads(sys.argv[1])
obj.setdefault('example', sys.argv[2])
print(json.dumps(obj, ensure_ascii=False))
PY
                )
                ${PY_UPDATER} --workspace "${ROOT_DIR}" --pattern-json "$json" --source "${LATEST_LOG}" >/dev/null 2>&1 || true
            fi
        fi
    done <"${LATEST_LOG}"
    echo "[done] Scan complete. Knowledge updated at ${KNOWLEDGE_DIR}/error_patterns.json"
else
    echo "[info] No test_results_*.log found; skipping initial scan"
fi

echo "[ok] Phase 1 bootstrap complete"
