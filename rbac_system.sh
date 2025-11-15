#!/bin/bash

# Phase 17: Enterprise Features - Role-Based Access Control (RBAC) System

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RBAC_CONFIG_DIR="$WORKSPACE_ROOT/rbac_config"
RBAC_LOG="$WORKSPACE_ROOT/logs/rbac.log"
USERS_DB="$RBAC_CONFIG_DIR/users.json"
ROLES_DB="$RBAC_CONFIG_DIR/roles.json"
PERMISSIONS_DB="$RBAC_CONFIG_DIR/permissions.json"
SESSIONS_DB="$RBAC_CONFIG_DIR/sessions.json"

# Create RBAC config directory
mkdir -p "$RBAC_CONFIG_DIR" "$WORKSPACE_ROOT/logs"

# Logging function
log() {
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  # Append to log file and write log output to stderr to avoid polluting stdout (JSON)
  echo "[$ts] $*" >>"$RBAC_LOG"
  echo "[$ts] $*" >&2
}

# Resolve a role's permissions including inherited roles (handles cycles)
resolve_role_permissions() {
  local root_role="$1"
  local queue seen perms

  queue=("$root_role")
  seen=()
  perms=()

  while ((${#queue[@]})); do
    local r="${queue[0]}"
    queue=("${queue[@]:1}")

    # skip if already processed
    local skip=false
    for s in "${seen[@]:-}"; do
      if [[ "$s" == "$r" ]]; then
        skip=true
        break
      fi
    done
    $skip && continue
    seen+=("$r")

    # fetch permissions for this role
    local p_raw
    p_raw=$(jq -r ".roles.\"$r\".permissions[]? // empty" "$ROLES_DB" 2>/dev/null || true)
    while read -r p; do
      [[ -n "$p" ]] && perms+=("$p")
    done <<<"$p_raw"

    # enqueue inherited roles
    local inh_raw
    inh_raw=$(jq -r ".roles.\"$r\".inherits_from[]? // empty" "$ROLES_DB" 2>/dev/null || true)
    while read -r ir; do
      [[ -n "$ir" ]] && queue+=("$ir")
    done <<<"$inh_raw"
  done

  # print unique permissions
  if ((${#perms[@]})); then
    printf '%s\n' "${perms[@]}" | sort -u
  fi
}

# Convert ISO8601 timestamp to epoch seconds (portable)
iso_to_epoch() {
  local iso="$1"
  if [[ -z "$iso" || "$iso" == "null" ]]; then
    echo 0
    return
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    # Fallback: try date (may fail on macOS for some formats)
    date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null || echo 0
    return
  fi

  # Pass the ISO string to Python via stdin to ensure correct parsing
  printf '%s' "$iso" | python3 - <<'PY'
import sys,datetime
s=sys.stdin.read().strip()
s=s.replace('Z','+00:00')
try:
    dt=datetime.datetime.fromisoformat(s)
    sys.stdout.write(str(int(dt.timestamp())) + "\n")
except Exception:
    sys.stdout.write("0\n")
PY
}

# Initialize RBAC system
init_rbac_system() {
  # Initialize users database
  cat >"$USERS_DB" <<'EOF'
{
  "users": {
    "admin": {
      "username": "admin",
      "password_hash": "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPjYQmLx8HnOa",
      "email": "admin@tools-automation.local",
      "roles": ["super_admin"],
      "status": "active",
      "created_at": "2025-01-01T00:00:00Z",
      "last_login": null,
      "failed_attempts": 0,
      "locked_until": null
    },
    "developer": {
      "username": "developer",
      "password_hash": "$2b$12$dummy.hash.for.demo.purposes.only",
      "email": "dev@tools-automation.local",
      "roles": ["developer"],
      "status": "active",
      "created_at": "2025-01-01T00:00:00Z",
      "last_login": null,
      "failed_attempts": 0,
      "locked_until": null
    },
    "operator": {
      "username": "operator",
      "password_hash": "$2b$12$dummy.hash.for.demo.purposes.only",
      "email": "ops@tools-automation.local",
      "roles": ["operator"],
      "status": "active",
      "created_at": "2025-01-01T00:00:00Z",
      "last_login": null,
      "failed_attempts": 0,
      "locked_until": null
    },
    "auditor": {
      "username": "auditor",
      "password_hash": "$2b$12$dummy.hash.for.demo.purposes.only",
      "email": "audit@tools-automation.local",
      "roles": ["auditor"],
      "status": "active",
      "created_at": "2025-01-01T00:00:00Z",
      "last_login": null,
      "failed_attempts": 0,
      "locked_until": null
    }
  },
  "last_updated": null
}
EOF

  # Initialize roles database
  cat >"$ROLES_DB" <<'EOF'
{
  "roles": {
    "super_admin": {
      "name": "super_admin",
      "description": "Super Administrator with full system access",
      "permissions": ["*"],
      "inherits_from": [],
      "created_at": "2025-01-01T00:00:00Z"
    },
    "admin": {
      "name": "admin",
      "description": "Administrator with system management access",
      "permissions": [
        "users.manage",
        "roles.manage",
        "system.config",
        "agents.manage",
        "monitoring.view",
        "audit.view"
      ],
      "inherits_from": [],
      "created_at": "2025-01-01T00:00:00Z"
    },
    "developer": {
      "name": "developer",
      "description": "Developer with code and deployment access",
      "permissions": [
        "code.read",
        "code.write",
        "build.execute",
        "deploy.execute",
        "monitoring.view",
        "logs.view"
      ],
      "inherits_from": [],
      "created_at": "2025-01-01T00:00:00Z"
    },
    "operator": {
      "name": "operator",
      "description": "Operations team with system monitoring access",
      "permissions": [
        "monitoring.view",
        "monitoring.manage",
        "agents.view",
        "agents.control",
        "alerts.manage",
        "logs.view"
      ],
      "inherits_from": [],
      "created_at": "2025-01-01T00:00:00Z"
    },
    "auditor": {
      "name": "auditor",
      "description": "Auditor with read-only access to logs and reports",
      "permissions": [
        "audit.view",
        "logs.view",
        "reports.view",
        "monitoring.view"
      ],
      "inherits_from": [],
      "created_at": "2025-01-01T00:00:00Z"
    },
    "guest": {
      "name": "guest",
      "description": "Guest with minimal read-only access",
      "permissions": [
        "status.view"
      ],
      "inherits_from": [],
      "created_at": "2025-01-01T00:00:00Z"
    }
  },
  "last_updated": null
}
EOF

  # Initialize permissions database
  cat >"$PERMISSIONS_DB" <<'EOF'
{
  "permissions": {
    "users.manage": {
      "name": "users.manage",
      "description": "Manage user accounts",
      "resource_type": "users",
      "actions": ["create", "read", "update", "delete"]
    },
    "roles.manage": {
      "name": "roles.manage",
      "description": "Manage roles and permissions",
      "resource_type": "roles",
      "actions": ["create", "read", "update", "delete"]
    },
    "system.config": {
      "name": "system.config",
      "description": "System configuration management",
      "resource_type": "system",
      "actions": ["read", "update"]
    },
    "agents.manage": {
      "name": "agents.manage",
      "description": "Full agent management",
      "resource_type": "agents",
      "actions": ["create", "read", "update", "delete", "execute"]
    },
    "agents.view": {
      "name": "agents.view",
      "description": "View agent status and logs",
      "resource_type": "agents",
      "actions": ["read"]
    },
    "agents.control": {
      "name": "agents.control",
      "description": "Start/stop agents",
      "resource_type": "agents",
      "actions": ["start", "stop", "restart"]
    },
    "code.read": {
      "name": "code.read",
      "description": "Read source code",
      "resource_type": "code",
      "actions": ["read"]
    },
    "code.write": {
      "name": "code.write",
      "description": "Modify source code",
      "resource_type": "code",
      "actions": ["create", "update", "delete"]
    },
    "build.execute": {
      "name": "build.execute",
      "description": "Execute build processes",
      "resource_type": "build",
      "actions": ["execute"]
    },
    "deploy.execute": {
      "name": "deploy.execute",
      "description": "Execute deployments",
      "resource_type": "deploy",
      "actions": ["execute"]
    },
    "monitoring.view": {
      "name": "monitoring.view",
      "description": "View monitoring data",
      "resource_type": "monitoring",
      "actions": ["read"]
    },
    "monitoring.manage": {
      "name": "monitoring.manage",
      "description": "Manage monitoring configuration",
      "resource_type": "monitoring",
      "actions": ["create", "read", "update", "delete"]
    },
    "alerts.manage": {
      "name": "alerts.manage",
      "description": "Manage alerts and notifications",
      "resource_type": "alerts",
      "actions": ["create", "read", "update", "delete", "acknowledge"]
    },
    "logs.view": {
      "name": "logs.view",
      "description": "View system logs",
      "resource_type": "logs",
      "actions": ["read"]
    },
    "audit.view": {
      "name": "audit.view",
      "description": "View audit logs",
      "resource_type": "audit",
      "actions": ["read"]
    },
    "reports.view": {
      "name": "reports.view",
      "description": "View reports and analytics",
      "resource_type": "reports",
      "actions": ["read"]
    },
    "status.view": {
      "name": "status.view",
      "description": "View basic system status",
      "resource_type": "status",
      "actions": ["read"]
    }
  },
  "last_updated": null
}
EOF

  # Initialize sessions database
  cat >"$SESSIONS_DB" <<'EOF'
{
  "sessions": {},
  "last_updated": null
}
EOF

  log "Initialized RBAC system with default users, roles, and permissions"
}

# Authenticate user
authenticate_user() {
  local username="$1"
  local password="$2"

  # Get user data
  local user_data
  user_data=$(jq -r ".users.\"$username\" // empty" "$USERS_DB")

  if [[ -z "$user_data" || "$user_data" == "null" ]]; then
    echo '{"error": "user_not_found"}'
    return 1
  fi

  # Check if user is active
  local status
  status=$(echo "$user_data" | jq -r '.status')
  if [[ "$status" != "active" ]]; then
    echo '{"error": "user_inactive"}'
    return 1
  fi

  # Check if account is locked
  local locked_until
  locked_until=$(echo "$user_data" | jq -r '.locked_until // null')
  if [[ "$locked_until" != "null" ]]; then
    local current_time
    current_time=$(date +%s)
    local lock_time
    lock_time=$(date -d "$locked_until" +%s 2>/dev/null || echo 0)
    if ((current_time < lock_time)); then
      echo '{"error": "account_locked"}'
      return 1
    fi
  fi

  # Simple password check (in production, use proper hashing)
  local stored_hash
  stored_hash=$(echo "$user_data" | jq -r '.password_hash')
  if [[ "$password" != "admin123" && "$password" != "dev123" && "$password" != "op123" && "$password" != "audit123" ]]; then
    # Increment failed attempts
    local failed_attempts
    failed_attempts=$(echo "$user_data" | jq -r '.failed_attempts // 0')
    ((failed_attempts++))
    jq ".users.\"$username\".failed_attempts = $failed_attempts" "$USERS_DB" >"${USERS_DB}.tmp" && mv "${USERS_DB}.tmp" "$USERS_DB"

    # Lock account after 5 failed attempts
    if ((failed_attempts >= 5)); then
      local lock_until
      lock_until=$(
        python3 - <<PY
    from datetime import datetime, timedelta, timezone
    import sys
    sys.stdout.write((datetime.now(timezone.utc)+timedelta(minutes=15)).strftime('%Y-%m-%dT%H:%M:%SZ') + "\n")
    PY
      )
      jq ".users.\"$username\".locked_until = \"$lock_until\"" "$USERS_DB" >"${USERS_DB}.tmp" && mv "${USERS_DB}.tmp" "$USERS_DB"
    fi

    echo '{"error": "invalid_credentials"}'
    return 1
  fi

  # Reset failed attempts and update last login
  local current_time_iso
  current_time_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq ".users.\"$username\".failed_attempts = 0 | .users.\"$username\".locked_until = null | .users.\"$username\".last_login = \"$current_time_iso\"" "$USERS_DB" >"${USERS_DB}.tmp" && mv "${USERS_DB}.tmp" "$USERS_DB"

  # Create session
  local session_id
  session_id="session_$(date +%s)_$RANDOM"
  local roles
  roles=$(echo "$user_data" | jq -r '.roles | join(",")')
  # Compute expiry ISO (portable)
  local expires_iso
  expires_iso=$(
    python3 - <<PY
from datetime import datetime, timedelta, timezone
import sys
sys.stdout.write((datetime.now(timezone.utc)+timedelta(hours=8)).strftime('%Y-%m-%dT%H:%M:%SZ') + "\n")
PY
  )

  jq ".sessions.\"$session_id\" = {
    \"session_id\": \"$session_id\",
    \"username\": \"$username\",
    \"roles\": \"$roles\",
    \"created_at\": \"$current_time_iso\",
    \"expires_at\": \"$expires_iso\",
    \"active\": true
  }" "$SESSIONS_DB" >"${SESSIONS_DB}.tmp" && mv "${SESSIONS_DB}.tmp" "$SESSIONS_DB"

  log "User $username authenticated successfully"

  jq -n \
    --arg session_id "$session_id" \
    --arg username "$username" \
    --arg roles "$roles" \
    '{
            authenticated: true,
            session_id: $session_id,
            username: $username,
            roles: ($roles | split(",")),
            message: "Authentication successful"
        }'
}

# Validate session
validate_session() {
  local session_id="$1"

  local session_data
  session_data=$(jq -r ".sessions.\"$session_id\" // empty" "$SESSIONS_DB")

  if [[ -z "$session_data" || "$session_data" == "null" ]]; then
    echo '{"error": "invalid_session"}'
    return 1
  fi

  local active
  active=$(echo "$session_data" | jq -r '.active')
  if [[ "$active" != "true" ]]; then
    echo '{"error": "session_inactive"}'
    return 1
  fi

  local expires_at
  expires_at=$(echo "$session_data" | jq -r '.expires_at')
  local current_time
  current_time=$(date +%s)
  local expiry_time
  expiry_time=$(iso_to_epoch "$expires_at")

  # If expiry_time is 0 (missing/invalid), treat as no expiry
  if [[ -z "$expiry_time" || "$expiry_time" -le 0 ]]; then
    echo "$session_data"
    return 0
  fi

  if ((current_time > expiry_time)); then
    # Expire session
    jq ".sessions.\"$session_id\".active = false" "$SESSIONS_DB" >"${SESSIONS_DB}.tmp" && mv "${SESSIONS_DB}.tmp" "$SESSIONS_DB"
    echo '{"error": "session_expired"}'
    return 1
  fi

  echo "$session_data"
}

# Check permission
check_permission() {
  local session_id="$1"
  local permission="$2"
  local action="${3:-}"

  # Validate session
  local session_data
  session_data=$(validate_session "$session_id")
  if echo "$session_data" | jq -e '.error' >/dev/null 2>&1; then
    echo "$session_data"
    return 1
  fi

  local username
  username=$(echo "$session_data" | jq -r '.username')
  local roles_str
  roles_str=$(echo "$session_data" | jq -r '.roles')

  # Convert roles string to array
  local roles
  IFS=',' read -ra roles <<<"$roles_str"

  # Check if any role has the required permission
  for role in "${roles[@]}"; do
    # Resolve permissions including inherited roles
    local permissions
    permissions=$(resolve_role_permissions "$role" )

    # Check for wildcard permission
    if echo "$permissions" | grep -q "^\*$"; then
      jq -n \
        --arg username "$username" \
        --arg permission "$permission" \
        --arg action "$action" \
        '{
                      authorized: true,
                      username: $username,
                      permission: $permission,
                      action: $action,
                      granted_by: "wildcard"
                  }'
      return 0
    fi

    # Check specific permission
    if echo "$permissions" | grep -q "^$permission$"; then
      jq -n \
        --arg username "$username" \
        --arg permission "$permission" \
        --arg action "$action" \
        --arg role "$role" \
        '{
                      authorized: true,
                      username: $username,
                      permission: $permission,
                      action: $action,
                      granted_by: $role
                  }'
      return 0
    fi
  done

  jq -n \
    --arg username "$username" \
    --arg permission "$permission" \
    --arg action "$action" \
    '{
            authorized: false,
            username: $username,
            permission: $permission,
            action: $action,
            reason: "insufficient_permissions"
        }'
}

# Get user permissions
get_user_permissions() {
  local session_id="$1"

  # Validate session
  local session_data
  session_data=$(validate_session "$session_id")
  if echo "$session_data" | jq -e '.error' >/dev/null 2>&1; then
    echo "$session_data"
    return 1
  fi

  local username
  username=$(echo "$session_data" | jq -r '.username')
  local roles_str
  roles_str=$(echo "$session_data" | jq -r '.roles')

  # Convert roles string to array
  local roles
  IFS=',' read -ra roles <<<"$roles_str"

  local all_permissions=()

  # Collect all permissions from user's roles
  for role in "${roles[@]}"; do
    local role_data
    role_data=$(jq -r ".roles.\"$role\" // empty" "$ROLES_DB")
    if [[ -n "$role_data" && "$role_data" != "null" ]]; then
      # Resolve permissions including inherited roles
      local permissions
      permissions=$(resolve_role_permissions "$role")

      while read -r perm; do
        if [[ -n "$perm" ]]; then
          all_permissions+=("$perm")
        fi
      done <<<"$permissions"
    fi
  done

  # Remove duplicates
  local unique_permissions
  unique_permissions=$(printf '%s\n' "${all_permissions[@]}" | sort | uniq)

  jq -n \
    --arg username "$username" \
    --arg roles "$roles_str" \
    --args "${unique_permissions[@]}" \
    '{
            username: $username,
            roles: ($roles | split(",")),
            permissions: [$@]
        }'
}

# CLI interface
case "${1:-help}" in
"init")
  init_rbac_system
  ;;
"auth")
  if [[ $# -lt 3 ]]; then
    echo "Usage: $0 auth <username> <password>"
    exit 1
  fi
  authenticate_user "$2" "$3"
  ;;
"check")
  if [[ $# -lt 3 ]]; then
    echo "Usage: $0 check <session_id> <permission> [action]"
    exit 1
  fi
  check_permission "$2" "$3" "${4:-}"
  ;;
"permissions")
  if [[ $# -lt 2 ]]; then
    echo "Usage: $0 permissions <session_id>"
    exit 1
  fi
  get_user_permissions "$2"
  ;;
"validate")
  if [[ $# -lt 2 ]]; then
    echo "Usage: $0 validate <session_id>"
    exit 1
  fi
  validate_session "$2"
  ;;
"help" | *)
  echo "Enterprise RBAC System v1.0"
  echo ""
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "Commands:"
  echo "  init                    - Initialize RBAC system"
  echo "  auth <user> <pass>      - Authenticate user"
  echo "  check <session> <perm>  - Check permission"
  echo "  permissions <session>   - Get user permissions"
  echo "  validate <session>      - Validate session"
  echo "  help                    - Show this help"
  echo ""
  echo "Default users: admin/admin123, developer/dev123,"
  echo "               operator/op123, auditor/audit123"
  ;;
esac
