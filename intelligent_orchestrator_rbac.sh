#!/bin/bash

# RBAC-wrapped Intelligent Orchestrator

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RBAC_INTEGRATION="$SCRIPT_DIR/rbac_integration.sh"

# Check if user is provided
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <username> [orchestrator_args...]"
    exit 1
fi

USERNAME="$1"
shift

# Source RBAC integration
if [[ -f "$RBAC_INTEGRATION" ]]; then
    source "$RBAC_INTEGRATION"
    rbac_exec "$USERNAME" "orchestrator" "$SCRIPT_DIR/intelligent_orchestrator.sh" "$@"
else
    echo "RBAC integration not found, running without authentication"
    "$SCRIPT_DIR/intelligent_orchestrator.sh" "$@"
fi
