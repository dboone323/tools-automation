#!/bin/bash

# System-wide RBAC Integration Script
# This script provides RBAC authentication for all protected system operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RBAC_SYSTEM="$SCRIPT_DIR/rbac_system.sh"
AUDIT_SYSTEM="$SCRIPT_DIR/audit_compliance.sh"
INTEGRATION_CONFIG="$SCRIPT_DIR/rbac_integration_config.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[SYSTEM-RBAC]${NC} $1"
}

error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[SYSTEM-RBAC]${NC} $1" >&2
}

# Authenticate user and get session
authenticate_user() {
    local username="$1"
    local password="$2"

    # Call RBAC system and parse JSON to extract session_id
    local auth_out
    auth_out=$("$RBAC_SYSTEM" auth "$username" "$password" 2>/dev/null || true)

    local session_id
    session_id=$(echo "$auth_out" | jq -r '.session_id // empty' 2>/dev/null || true)

    if [[ -z "$session_id" ]]; then
        error "Authentication failed for user $username"
        exit 1
    fi

    echo "$session_id"
}

# Validate session
validate_session() {
    local session_id="$1"

    if ! "$RBAC_SYSTEM" validate "$session_id" 2>/dev/null; then
        error "Invalid session: $session_id"
        exit 1
    fi
}

# Check permission
check_permission() {
    local session_id="$1"
    local permission="$2"

    # Capture RBAC check output and log authorization event
    local check_out
    check_out=$("$RBAC_SYSTEM" check "$session_id" "$permission" 2>/dev/null || true)

    if echo "$check_out" | jq -e '.authorized == true' >/dev/null 2>&1; then
        # Log granted authorization under system (centralized audit)
        "$AUDIT_SYSTEM" log "authorization" "system" "permission_check" "$permission" "granted" "$permission" >/dev/null 2>&1 || true
        echo "$check_out"
        return 0
    else
        # Log denied authorization under system
        "$AUDIT_SYSTEM" log "authorization" "system" "permission_check" "$permission" "denied" "$permission" >/dev/null 2>&1 || true
        error "Permission denied: $permission"
        exit 1
    fi
}

# Execute protected command
exec_protected() {
    local session_id="$1"
    local permission="$2"
    local command="$3"
    shift 3

    # Validate session
    validate_session "$session_id"

    # Check permission
    check_permission "$session_id" "$permission"

    # Log execution
    "$AUDIT_SYSTEM" log "authorization" "system" "command_execution" "$command" "granted" "$permission"

    # Execute command
    log "Executing $command with $permission"
    "$command" "$@"
}

# CLI interface
case "${1:-help}" in
"auth")
    if [[ $# -lt 3 ]]; then
        echo "Usage: $0 auth <username> <password>"
        exit 1
    fi
    authenticate_user "$2" "$3"
    ;;
"validate")
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 validate <session_id>"
        exit 1
    fi
    validate_session "$2"
    echo "Session valid"
    ;;
"check")
    if [[ $# -lt 3 ]]; then
        echo "Usage: $0 check <session_id> <permission>"
        exit 1
    fi
    check_permission "$2" "$3"
    echo "Permission granted"
    ;;
"exec")
    if [[ $# -lt 4 ]]; then
        echo "Usage: $0 exec <session_id> <permission> <command> [args...]"
        exit 1
    fi
    exec_protected "$2" "$3" "$4" "${@:5}"
    ;;
"help" | *)
    echo "System RBAC Integration v1.0"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  auth <user> <pass>    - Authenticate user and get session"
    echo "  validate <session>    - Validate session"
    echo "  check <session> <perm> - Check permission"
    echo "  exec <session> <perm> <cmd> - Execute protected command"
    echo "  help                  - Show this help"
    ;;
esac
