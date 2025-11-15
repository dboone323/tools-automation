#!/bin/bash

# Phase 17: Enterprise Features - RBAC Integration

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RBAC_SYSTEM="$WORKSPACE_ROOT/rbac_system.sh"
AUDIT_SYSTEM="$WORKSPACE_ROOT/audit_compliance.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[RBAC-INTEGRATION]${NC} $1"
}

# Check if RBAC system is available
check_rbac_system() {
    if [[ ! -f "$RBAC_SYSTEM" ]]; then
        echo -e "${RED}Error: RBAC system not found at $RBAC_SYSTEM${NC}"
        exit 1
    fi

    if [[ ! -x "$RBAC_SYSTEM" ]]; then
        chmod +x "$RBAC_SYSTEM"
    fi

    if [[ ! -f "$AUDIT_SYSTEM" ]]; then
        echo -e "${RED}Error: Audit system not found at $AUDIT_SYSTEM${NC}"
        exit 1
    fi

    if [[ ! -x "$AUDIT_SYSTEM" ]]; then
        chmod +x "$AUDIT_SYSTEM"
    fi
}

# Initialize RBAC integration
init_rbac_integration() {
    log "Initializing RBAC integration..."

    # Initialize RBAC system
    "$RBAC_SYSTEM" init

    # Initialize audit system
    "$AUDIT_SYSTEM" init

    # Create integration configuration
    cat >"$WORKSPACE_ROOT/rbac_integration_config.json" <<'EOF'
{
  "rbac_integration": {
    "enabled": true,
    "protected_commands": [
      "intelligent_orchestrator.sh",
      "agent_dashboard_api.py",
      "master_automation.sh",
      "deploy_workflows_all_projects.sh",
      "security_audit.sh",
      "final_security_audit.sh"
    ],
    "protected_scripts": [
      "scripts/*.sh",
      "agents/*.sh",
      "security/*.sh",
      "ci/*.sh"
    ],
    "audit_all_commands": true,
    "session_required": true,
    "permission_checks": {
      "orchestrator_access": ["admin", "operator"],
      "agent_management": ["admin", "developer"],
      "deployment_access": ["admin", "operator"],
      "security_operations": ["admin", "auditor"],
      "system_configuration": ["admin"]
    }
  }
}
EOF

    log "RBAC integration initialized"
}

# RBAC-authenticated command wrapper
rbac_exec() {
    local username="$1"
    local command="$2"
    shift 2

    # Get session for user (this is a simplified approach - in production you'd use proper session management)
    # For now, we'll authenticate each time to get a session
    local session_id
    session_id=$("$RBAC_SYSTEM" auth "$username" "dummy_password" 2>/dev/null | grep -v "Enterprise RBAC System" | tail -1)

    if [[ -z "$session_id" ]]; then
        echo -e "${RED}Error: Cannot authenticate user $username${NC}"
        "$AUDIT_SYSTEM" log "authentication" "$username" "authentication" "rbac_exec" "failed" "auth_failed"
        exit 1
    fi

    # Check command permissions
    local permission_required
    case "$command" in
    "intelligent_orchestrator.sh" | "orchestrator")
        permission_required="orchestrator_access"
        ;;
    "agent_dashboard_api.py" | "dashboard")
        permission_required="agent_management"
        ;;
    "master_automation.sh" | "automation")
        permission_required="deployment_access"
        ;;
    "deploy_workflows_all_projects.sh" | "deploy")
        permission_required="deployment_access"
        ;;
    "security_audit.sh" | "audit")
        permission_required="security_operations"
        ;;
    "final_security_audit.sh" | "security")
        permission_required="security_operations"
        ;;
    *)
        permission_required="system_access"
        ;;
    esac

    if ! "$RBAC_SYSTEM" check "$session_id" "$permission_required" 2>/dev/null; then
        echo -e "${RED}Error: User $username does not have permission for $permission_required${NC}"
        "$AUDIT_SYSTEM" log "authorization" "$username" "permission_check" "$command" "denied" "insufficient_permissions"
        exit 1
    fi

    # Log successful authorization
    "$AUDIT_SYSTEM" log "authorization" "$username" "command_execution" "$command" "granted" "permission_verified"

    # Execute command with remaining arguments
    log "Executing $command as $username"
    "$@"
}

# Integrate with intelligent orchestrator
integrate_intelligent_orchestrator() {
    local orchestrator_file="$WORKSPACE_ROOT/intelligent_orchestrator.sh"

    if [[ ! -f "$orchestrator_file" ]]; then
        log "Intelligent orchestrator not found, skipping integration"
        return
    fi

    log "Integrating RBAC with intelligent orchestrator..."

    # Create RBAC wrapper for orchestrator
    cat >"$WORKSPACE_ROOT/intelligent_orchestrator_rbac.sh" <<'EOF'
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
EOF

    chmod +x "$WORKSPACE_ROOT/intelligent_orchestrator_rbac.sh"
    log "Created RBAC wrapper for intelligent orchestrator"
}

# Integrate with agent dashboard API
integrate_agent_dashboard() {
    local dashboard_file="$WORKSPACE_ROOT/agent_dashboard_api.py"

    if [[ ! -f "$dashboard_file" ]]; then
        log "Agent dashboard API not found, skipping integration"
        return
    fi

    log "Integrating RBAC with agent dashboard API..."

    # Create RBAC middleware for dashboard
    cat >"$WORKSPACE_ROOT/rbac_dashboard_middleware.py" <<'EOF'
#!/usr/bin/env python3
"""
RBAC Middleware for Agent Dashboard API

Provides authentication and authorization middleware for the dashboard API.
"""

import os
import json
import subprocess
import functools
from flask import request, jsonify, g
from werkzeug.exceptions import Unauthorized

class RBACMiddleware:
    def __init__(self, workspace_root):
        self.workspace_root = workspace_root
        self.rbac_script = os.path.join(workspace_root, "rbac_system.sh")
        self.audit_script = os.path.join(workspace_root, "audit_compliance.sh")

    def authenticate_request(self):
        """Authenticate incoming request"""
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            raise Unauthorized("Missing or invalid authorization header")

        token = auth_header[7:]  # Remove 'Bearer ' prefix

        # Parse token (format: username:session_id)
        try:
            username, session_id = token.split(':', 1)
        except ValueError:
            raise Unauthorized("Invalid token format")

        # Validate session
        result = subprocess.run(
            [self.rbac_script, "validate", session_id],
            capture_output=True, text=True
        )

        if result.returncode != 0:
            # Log failed authentication
            subprocess.run([
                self.audit_script, "log", "authentication",
                username, "api_access", "dashboard", "failed", "invalid_session"
            ], capture_output=True)
            raise Unauthorized("Invalid session")

        # Store user in request context
        g.username = username
        g.session_id = session_id

        # Log successful authentication
        subprocess.run([
            self.audit_script, "log", "authentication",
            username, "api_access", "dashboard", "success", "session_validated"
        ], capture_output=True)

    def require_permission(self, permission):
        """Decorator to require specific permission"""
        def decorator(f):
            @functools.wraps(f)
            def wrapped(*args, **kwargs):
                if not hasattr(g, 'session_id'):
                    raise Unauthorized("Authentication required")

                session_id = g.session_id

                # Check permission
                result = subprocess.run(
                    [self.rbac_script, "check", session_id, permission],
                    capture_output=True, text=True
                )

                if result.returncode != 0:
                    # Log authorization failure
                    subprocess.run([
                        self.audit_script, "log", "authorization",
                        g.username, "api_access", request.path, "denied", f"missing_{permission}"
                    ], capture_output=True)
                    raise Unauthorized(f"Permission '{permission}' required")

                # Log successful authorization
                subprocess.run([
                    self.audit_script, "log", "authorization",
                    g.username, "api_access", request.path, "granted", permission
                ], capture_output=True)

                return f(*args, **kwargs)
            return wrapped
        return decorator

    def get_current_user(self):
        """Get current authenticated user"""
        return getattr(g, 'username', None)

# Global middleware instance
rbac_middleware = None

def init_rbac_middleware(app, workspace_root):
    """Initialize RBAC middleware for Flask app"""
    global rbac_middleware
    rbac_middleware = RBACMiddleware(workspace_root)

    @app.before_request
    def authenticate_before_request():
        # Skip authentication for health check and login endpoints
        if request.path in ['/health', '/login', '/']:
            return

        try:
            rbac_middleware.authenticate_request()
        except Unauthorized as e:
            return jsonify({"error": str(e)}), 401

def require_permission(permission):
    """Decorator for requiring permissions on routes"""
    if rbac_middleware is None:
        return lambda f: f
    return rbac_middleware.require_permission(permission)

def get_current_user():
    """Get current authenticated user"""
    if rbac_middleware is None:
        return None
    return rbac_middleware.get_current_user()
EOF

    # Modify agent dashboard API to include RBAC
    # This is a simplified integration - in practice, you'd modify the actual API file
    cat >"$WORKSPACE_ROOT/agent_dashboard_api_rbac.py" <<'EOF'
#!/usr/bin/env python3
"""
RBAC-Integrated Agent Dashboard API Server

Provides REST API endpoints for the agent performance dashboard with RBAC authentication.
"""

import os
import sys
from flask import Flask, jsonify, request
from flask_cors import CORS

# Add current directory to path for imports
sys.path.insert(0, os.path.dirname(__file__))

# Import original dashboard
from agent_dashboard_api import AgentDashboardAPI
from rbac_dashboard_middleware import init_rbac_middleware, require_permission, get_current_user

class RBACAgentDashboardAPI(AgentDashboardAPI):
    def __init__(self, workspace_root):
        super().__init__(workspace_root)

        # Initialize RBAC middleware
        init_rbac_middleware(self.app, workspace_root)

        # Override routes with RBAC protection
        self.setup_rbac_routes()

    def setup_rbac_routes(self):
        """Setup routes with RBAC protection"""

        @self.app.route('/api/agents/status')
        @require_permission('agent_management')
        def get_agent_status():
            return super().get_agent_status()

        @self.app.route('/api/agents/performance')
        @require_permission('agent_management')
        def get_agent_performance():
            return super().get_agent_performance()

        @self.app.route('/api/tasks/history')
        @require_permission('agent_management')
        def get_task_history():
            return super().get_task_history()

        @self.app.route('/api/system/config', methods=['GET'])
        @require_permission('system_configuration')
        def get_system_config():
            return super().get_system_config()

        @self.app.route('/api/system/config', methods=['POST'])
        @require_permission('system_configuration')
        def update_system_config():
            return super().update_system_config()

        @self.app.route('/api/security/audit')
        @require_permission('security_operations')
        def get_security_audit():
            return super().get_security_audit()

        @self.app.route('/api/deploy', methods=['POST'])
        @require_permission('deployment_access')
        def deploy_system():
            return super().deploy_system()

def main():
    workspace_root = os.path.dirname(os.path.abspath(__file__))
    dashboard = RBACAgentDashboardAPI(workspace_root)

    # Add user info to all responses
    @dashboard.app.after_request
    def add_user_info(response):
        if hasattr(request, 'user') and request.user:
            response_data = response.get_json()
            if response_data:
                response_data['current_user'] = request.user
                response = jsonify(response_data)
        return response

    dashboard.app.run(host='0.0.0.0', port=5001, debug=False)

if __name__ == '__main__':
    main()
EOF

    log "Created RBAC middleware and integrated dashboard API"
}

# Integrate with master automation script
integrate_master_automation() {
    local master_file="$WORKSPACE_ROOT/master_automation.sh"

    if [[ ! -f "$master_file" ]]; then
        log "Master automation script not found, skipping integration"
        return
    fi

    log "Integrating RBAC with master automation..."

    # Create RBAC wrapper for master automation
    cat >"$WORKSPACE_ROOT/master_automation_rbac.sh" <<'EOF'
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
EOF

    chmod +x "$WORKSPACE_ROOT/master_automation_rbac.sh"
    log "Created RBAC wrapper for master automation"
}

# Create system integration script
create_system_integration() {
    cat >"$WORKSPACE_ROOT/rbac_system_integration.sh" <<'EOF'
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

    local session_id
    session_id=$("$RBAC_SYSTEM" auth "$username" "$password" 2>/dev/null | grep -v "Enterprise RBAC System" | tail -1)

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

    if ! "$RBAC_SYSTEM" check "$session_id" "$permission" 2>/dev/null; then
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
    "$@"
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
    "help"|*)
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
EOF

    chmod +x "$WORKSPACE_ROOT/rbac_system_integration.sh"
    log "Created system-wide RBAC integration script"
}

# Create integration test
create_integration_test() {
    cat >"$WORKSPACE_ROOT/test_rbac_integration.sh" <<'EOF'
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
    if "$INTEGRATION" check "$TEST_SESSION_ID" system_configuration 2>/dev/null; then
        log "✓ Admin has system configuration permission"
    else
        error "✗ Admin should have system configuration permission"
        return 1
    fi

    # Test developer permissions - first get developer session
    if dev_session=$("$INTEGRATION" auth developer dev123 2>/dev/null); then
        if "$INTEGRATION" check "$dev_session" system_configuration 2>/dev/null; then
            error "✗ Developer should not have system configuration permission"
            return 1
        else
            log "✓ Developer correctly denied system configuration permission"
        fi

        # Test developer agent management permission
        if "$INTEGRATION" check "$dev_session" agent_management 2>/dev/null; then
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
    if "$INTEGRATION" exec "$TEST_SESSION_ID" system_configuration echo "test command" 2>/dev/null; then
        log "✓ Protected command execution successful"
    else
        error "✗ Protected command execution failed"
        return 1
    fi

    # Test permission denied - try with developer session
    if dev_session=$("$INTEGRATION" auth developer dev123 2>/dev/null); then
        if "$INTEGRATION" exec "$dev_session" system_configuration echo "test command" 2>/dev/null; then
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

    if (( failed == 0 )); then
        log "✓ All RBAC integration tests passed!"
        return 0
    else
        error "✗ $failed RBAC integration tests failed"
        return 1
    fi
}

main "$@"
EOF

    chmod +x "$WORKSPACE_ROOT/test_rbac_integration.sh"
    log "Created RBAC integration test script"
}

# CLI interface
case "${1:-help}" in
"init")
    check_rbac_system
    init_rbac_integration
    ;;
"integrate-orchestrator")
    integrate_intelligent_orchestrator
    ;;
"integrate-dashboard")
    integrate_agent_dashboard
    ;;
"integrate-automation")
    integrate_master_automation
    ;;
"integrate-all")
    integrate_intelligent_orchestrator
    integrate_agent_dashboard
    integrate_master_automation
    create_system_integration
    create_integration_test
    ;;
"test")
    "$WORKSPACE_ROOT/test_rbac_integration.sh"
    ;;
"help" | *)
    echo "RBAC Integration Manager v1.0"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  init                    - Initialize RBAC integration"
    echo "  integrate-orchestrator  - Integrate with intelligent orchestrator"
    echo "  integrate-dashboard     - Integrate with agent dashboard API"
    echo "  integrate-automation    - Integrate with master automation"
    echo "  integrate-all           - Integrate with all systems"
    echo "  test                    - Run integration tests"
    echo "  help                    - Show this help"
    echo ""
    echo "Run 'integrate-all' to enable full RBAC protection"
    ;;
esac
