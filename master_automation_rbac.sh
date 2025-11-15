#!/bin/bash

# RBAC-wrapped Master Automation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RBAC_INTEGRATION="$SCRIPT_DIR/rbac_integration.sh"

# Check if user is provided
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <username> [automation_args...]"
    exit 1
fi

USERNAME="$1"
shift

# Source RBAC integration
if [[ -f "$RBAC_INTEGRATION" ]]; then
    source "$RBAC_INTEGRATION"
    rbac_exec "$USERNAME" "automation" "$SCRIPT_DIR/master_automation.sh" "$@"
else
    echo "RBAC integration not found, running without authentication"
    "$SCRIPT_DIR/master_automation.sh" "$@"
fi
