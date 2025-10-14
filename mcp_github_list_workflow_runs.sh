#!/bin/bash

# MCP GitHub List Workflow Runs Tool
# Lists recent GitHub Actions workflow runs for the repository

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

# Get limit from arguments (default 10)
LIMIT="${1:-10}"

echo "Recent workflow runs for ${OWNER}/${REPO} (last ${LIMIT}):"
echo "======================================================="

# List recent workflow runs using GitHub CLI
gh run list --repo "${OWNER}/${REPO}" --limit "${LIMIT}" --json number,workflowName,status,conclusion,createdAt,url | jq -r '.[] | "\(.number): \(.workflowName) - \(.status)/\(.conclusion) - \(.createdAt) - \(.url)"'