#!/bin/bash

# RBAC Integration Test Script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RBAC_SYSTEM="$SCRIPT_DIR/rbac_system.sh"
AUDIT_SYSTEM="$SCRIPT_DIR/audit_compliance.sh"
INTEGRATION="$SCRIPT_DIR/rbac_system_integration.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[TEST]${NC} $1"
}

error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[TEST]${NC} $1"
}

# Test authentication
test_authentication() {
    log "Testing authentication..."

    # Test valid authentication
    if session_id=$("$INTEGRATION" auth admin admin123 2>/dev/null); then
        log "✓ Admin authentication successful"
        # Store session for later tests
        TEST_SESSION_ID="$session_id"
    else
        error "✗ Admin authentication failed"
        return 1
    fi

    # Test invalid authentication
    if "$INTEGRATION" auth admin wrongpass 2>/dev/null; then
        error "✗ Invalid authentication should have failed"
        return 1
    else
        log "✓ Invalid authentication correctly rejected"
    fi
}

# Test authorization
test_authorization() {
    log "Testing authorization..."

    # Test admin permissions
    if "$INTEGRATION" check "$TEST_SESSION_ID" system.config 2>/dev/null; then
        log "✓ Admin has system configuration permission"
    else
        error "✗ Admin should have system configuration permission"
        return 1
    fi

    # Test developer permissions - first get developer session
    if dev_session=$("$INTEGRATION" auth developer dev123 2>/dev/null); then
        if "$INTEGRATION" check "$dev_session" system.config 2>/dev/null; then
            error "✗ Developer should not have system configuration permission"
            return 1
        else
            log "✓ Developer correctly denied system configuration permission"
        fi

        # Test developer agent management permission
        if "$INTEGRATION" check "$dev_session" agents.manage 2>/dev/null; then
            log "✓ Developer has agent management permission"
        else
            error "✗ Developer should have agent management permission"
            return 1
        fi
    else
        error "✗ Could not authenticate developer"
        return 1
    fi
}

# Test audit logging
test_audit_logging() {
    log "Testing audit logging..."

    # Perform an action that should be logged
    "$INTEGRATION" check "$TEST_SESSION_ID" system_configuration 2>/dev/null || true

    # Check if audit event was logged
    if "$AUDIT_SYSTEM" query "username=system,event_type=authorization" | jq -e '. | length > 0' 2>/dev/null; then
        log "✓ Audit logging working correctly"
    else
        error "✗ Audit logging not working"
        return 1
    fi
}

# Test protected command execution
test_protected_execution() {
    log "Testing protected command execution..."

    # Test successful execution
    if "$INTEGRATION" exec "$TEST_SESSION_ID" system.config echo "test command" 2>/dev/null; then
        log "✓ Protected command execution successful"
    else
        error "✗ Protected command execution failed"
        return 1
    fi

    # Test permission denied - try with developer session
    if dev_session=$("$INTEGRATION" auth developer dev123 2>/dev/null); then
        if "$INTEGRATION" exec "$dev_session" system.config echo "test command" 2>/dev/null; then
            error "✗ Should not allow execution without permission"
            return 1
        else
            log "✓ Correctly denied execution without permission"
        fi
    fi
}

# Run all tests
main() {
    log "Starting RBAC integration tests..."

    local failed=0

    if ! test_authentication; then
        ((failed++))
    fi

    if ! test_authorization; then
        ((failed++))
    fi

    if ! test_audit_logging; then
        ((failed++))
    fi

    if ! test_protected_execution; then
        ((failed++))
    fi

    if ((failed == 0)); then
        log "✓ All RBAC integration tests passed!"
        return 0
    else
        error "✗ $failed RBAC integration tests failed"
        return 1
    fi
}

main "$@"
