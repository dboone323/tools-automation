#!/usr/bin/env bash
# Setup default environment variables for the tools-automation repository
set -euo pipefail

# Determine repository root (safe fallback to PWD if not a git repo)
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# Primary code dir default is the repo root; override with CODE_DIR if set
CODE_DIR="${CODE_DIR:-${WORKSPACE_ROOT}}"

# Projects root inside workspace
PROJECT_DIR="${PROJECT_DIR:-${WORKSPACE_ROOT}}"

# Agent status path
AGENT_STATUS_PATH="${AGENT_STATUS_PATH:-${WORKSPACE_ROOT}/config/agent_status.json}"

# Ollama endpoint for local inference (for dev/test)
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"

# Make envs available to children
export WORKSPACE_ROOT CODE_DIR PROJECT_DIR AGENT_STATUS_PATH OLLAMA_URL

# Print a compact summary when run interactively for debugging
if [[ -t 1 ]]; then
    echo "WORKSPACE_ROOT=${WORKSPACE_ROOT}"
    echo "CODE_DIR=${CODE_DIR}"
    echo "PROJECT_DIR=${PROJECT_DIR}"
    echo "AGENT_STATUS_PATH=${AGENT_STATUS_PATH}"
    echo "OLLAMA_URL=${OLLAMA_URL}"
fi
