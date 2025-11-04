#!/usr/bin/env bash
set -euo pipefail
export CR_USE_AI=1
export CR_USE_OLLAMA=1
: "${OLLAMA_CLOUD_URL:=}"
export OLLAMA_ENDPOINT="${OLLAMA_CLOUD_URL:-http://127.0.0.1:11434}"

"$(dirname "$0")/run_validation.sh"
