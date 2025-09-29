#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Get workflow status
get_workflow_status() {
  local temp_file
  temp_file=$(mktemp)

  if gh workflow list --json name,state --repo dboone323/Quantum-workspace >"${temp_file}" 2>/dev/null; then
    print_success "Workflow status retrieved" >&2
    echo "${temp_file}"
    return 0
  else
    print_error "Failed to retrieve workflow status" >&2
    rm -f "${temp_file}"
    return 1
  fi
}

# Get recent runs
get_recent_runs() {
  local limit="${1:-20}"
  local temp_file
  temp_file=$(mktemp)

  if gh run list --limit "${limit}" --json conclusion --repo dboone323/Quantum-workspace >"${temp_file}" 2>/dev/null; then
    print_success "Recent runs retrieved" >&2
    echo "${temp_file}"
    return 0
  else
    print_error "Failed to retrieve recent runs" >&2
    rm -f "${temp_file}"
    return 1
  fi
}

echo "Testing get_workflow_status..."
status_file=$(get_workflow_status)
echo "Status file: ${status_file}"
if [[ -f ${status_file} ]]; then
  echo "Status file exists"
  ls -la "${status_file}"
else
  echo "Status file does not exist"
  exit 1
fi

echo "Testing get_recent_runs..."
runs_file=$(get_recent_runs 5)
echo "Runs file: ${runs_file}"
if [[ -f ${runs_file} ]]; then
  echo "Runs file exists"
  ls -la "${runs_file}"
else
  echo "Runs file does not exist"
  exit 1
fi

echo "All tests passed!"
