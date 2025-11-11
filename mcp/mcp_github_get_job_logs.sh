#!/bin/bash

# MCP GitHub Get Job Logs Tool
# Gets logs for a specific GitHub Actions workflow run

set -euo pipefail

# Check if GitHub CLI is available
if ! command -v gh &>/dev/null; then
    echo "Error: GitHub CLI (gh) is not installed" >&2
    exit 1
fi

# Check if authenticated
if ! gh auth status &>/dev/null; then
    echo "Error: Not authenticated with GitHub CLI. Run 'gh auth login'" >&2
    exit 1
fi

# Get repository info from git remote
REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -z ${REPO_URL} ]]; then
    echo "Error: No git remote found" >&2
    exit 1
fi

# Extract owner/repo from URL
if [[ ${REPO_URL} =~ github\.com[\/:]([^\/]+)\/([^\/\.]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
else
    echo "Error: Could not parse repository from git remote" >&2
    exit 1
fi

# Get run number from arguments
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <run-number> [job-name]" >&2
    exit 1
fi

RUN_NUMBER="$1"
JOB_NAME="${2:-}"

echo "Getting logs for workflow run ${RUN_NUMBER} in ${OWNER}/${REPO}:"
echo "============================================================"

if [[ -n ${JOB_NAME} ]]; then
    echo "Filtering for job: ${JOB_NAME}"
    echo ""
    # Get logs for specific job
    gh run view "${RUN_NUMBER}" --repo "${OWNER}/${REPO}" --log --job "${JOB_NAME}" 2>/dev/null || echo "Job '${JOB_NAME}' not found or no logs available"
else
    # Get all logs for the run
    gh run view "${RUN_NUMBER}" --repo "${OWNER}/${REPO}" --log 2>/dev/null || echo "Run ${RUN_NUMBER} not found or no logs available"
fi
