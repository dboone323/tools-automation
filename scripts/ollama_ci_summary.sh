#!/usr/bin/env bash
# Summarize fast validation results via Ollama model (optional)
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATION_DIR="${ROOT_DIR}/metrics/validation"
MODEL="${OLLAMA_MODEL:-llama2}"
SYSTEM_PROMPT="Summarize validation status for submodules with key actions. Keep under 120 words."

if [[ ! -d "$VALIDATION_DIR" ]]; then
    echo "No validation results directory: $VALIDATION_DIR" >&2
    exit 0
fi

# Combine JSON files
combined=$(jq -s '[.[]]' "$VALIDATION_DIR"/*.json 2>/dev/null || echo '[]')

# Build plain text summary for model
summary_text=$(echo "$combined" | jq -r '.[] | "Submodule: \(.submodule) | Lint: \(.lint.result) W: \(.lint.warnings) E: \(.lint.errors) | Validation: \(.validation.mode):\(.validation.status) | Coverage: \(.coverage)"')

prompt="${SYSTEM_PROMPT}\n\n${summary_text}"

# Use local ollama if available
if command -v ollama >/dev/null 2>&1; then
    echo "[CI-SUMMARY] Generating AI summary with model: $MODEL" >&2
    ollama run "$MODEL" "$prompt" || echo "[CI-SUMMARY] Model call failed" >&2
else
    echo "[CI-SUMMARY] Ollama not installed; raw summary:" >&2
    echo "$summary_text"
fi
