        #!/usr/bin/env bash

# ══════════════════════════════════════════════════════════════
# Enhanced with Agent Autonomy Features
# ══════════════════════════════════════════════════════════════

# Dynamic Configuration Discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh"
    WORKSPACE_ROOT=$(get_workspace_root 2>/dev/null || echo "$HOME/workspace")
    MCP_URL=$(get_mcp_url 2>/dev/null || echo "http://127.0.0.1:5000")
fi

# AI Decision Helpers (optional - uncomment to enable)
# if [[ -f "${SCRIPT_DIR}/../monitoring/ai_helpers.sh" ]]; then
#     source "${SCRIPT_DIR}/../monitoring/ai_helpers.sh"
# fi

# State Manager Integration (optional - uncomment to enable)
# STATE_MANAGER="${SCRIPT_DIR}/../monitoring/state_manager.py"

# ══════════════════════════════════════════════════════════════

        # Auto-injected health & reliability shim

        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer shared helpers when available
if [[ -f "$DIR/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="agent_backup.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  issues=()
  if [[ ! -w "/tmp" ]]; then
    issues+=("tmp_not_writable")
  fi
  if [[ ! -d "$DIR" ]]; then
    issues+=("cwd_missing")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
    exit 2
  fi
  printf '{"ok":true}\n'
  exit 0
fi

# Original agent script continues below
#!/bin/bash
# Agent Backup - Automated backup & disaster recovery
# Performs incremental backups, integrity checks, and disaster recovery testing

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Add reliability features for enterprise-grade operation
set -euo pipefail

# Portable run_with_timeout: run a command and kill it if it exceeds timeout (seconds)
# Usage: run_with_timeout <seconds> <cmd> [args...]
run_with_timeout() {
    local timeout="$1"
    shift
    local cmd="$*"

    # Use timeout command if available (Linux), otherwise implement with background process
    if command -v timeout >/dev/null 2>&1; then
        timeout --kill-after=5s "${timeout}s" bash -c "$cmd"
    else
        # macOS/BSD implementation using background process
        local pid_file
        pid_file=$(mktemp)
        local exit_file
        exit_file=$(mktemp)

        # Run command in background
        (
            if bash -c "$cmd"; then
                echo 0 >"$exit_file"
            else
                echo $? >"$exit_file"
            fi
        ) &
        local cmd_pid=$!

        echo "$cmd_pid" >"$pid_file"

        # Wait for completion or timeout
        local count=0
        while [[ $count -lt $timeout ]] && kill -0 $cmd_pid 2>/dev/null; do
            sleep 1
            ((count++))
        done

        # Check if still running
        if kill -0 $cmd_pid 2>/dev/null; then
            # Kill the process group
            pkill -TERM -P "$cmd_pid" 2>/dev/null || true
            sleep 1
            pkill -KILL -P "$cmd_pid" 2>/dev/null || true
            rm -f "$pid_file" "$exit_file"
            log_message "ERROR" "Command timed out after ${timeout}s: $cmd"
            return 124
        else
            # Command completed, get exit code
            local exit_code
            if [[ -f "$exit_file" ]]; then
                exit_code=$(cat "$exit_file")
                rm -f "$pid_file" "$exit_file"
                return "$exit_code"
            else
                rm -f "$pid_file" "$exit_file"
                return 0
            fi
        fi
    fi
}

mkdir -p "${BACKUP_DIR}"

# Initialize backup manifest
initialize_manifest() {
    if [[ ! -f "${BACKUP_MANIFEST}" ]]; then
        cat >"${BACKUP_MANIFEST}" <<EOF
{
  "backups": [],
  "last_backup": null,
  "version": "1.0"
}
EOF
    fi
}

# Calculate checksum
calculate_checksum() {
    local file="$1"

    if command -v shasum &>/dev/null; then
        shasum -a 256 "$file" 2>/dev/null | awk '{print $1}'
    elif command -v sha256sum &>/dev/null; then
        sha256sum "$file" 2>/dev/null | awk '{print $1}'
    else
        echo "UNSUPPORTED"
    fi
}

# Create incremental backup
create_backup() {
    local backup_type="${1:-incremental}" # full or incremental
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="backup_${backup_type}_${timestamp}"
    local backup_path="${BACKUP_DIR}/${backup_name}"

    log_message "INFO: Creating ${backup_type} backup: ${backup_name}"

    # Check resource limits before proceeding
    if ! check_resource_limits; then
        log_message "ERROR: Resource limits exceeded, cannot create backup"
        return 1
    fi

    mkdir -p "${backup_path}"

    # Define what to backup
    local items_to_backup=(
        "Projects"
        "Shared"
        "Tools/Automation"
        ".github"
        "Documentation"
        "quality-config.yaml"
        ".swiftformat"
        ".swiftlint.yml"
    )

    local total_size=0
    local file_count=0

    # Create backup archive
    local archive_file="${backup_path}/${backup_name}.tar.gz"

    cd "${WORKSPACE_ROOT}" || return 1

    log_message "INFO: Archiving workspace..."

    # Create tar archive
    tar -czf "${archive_file}" \
        --exclude="*.xcodeproj/project.xcworkspace" \
        --exclude="*.xcodeproj/xcuserdata" \
        --exclude="DerivedData" \
        --exclude=".build" \
        --exclude="build" \
        --exclude="*.swiftmodule" \
        --exclude=".git" \
        --exclude=".backups" \
        --exclude="node_modules" \
        "${items_to_backup[@]}" 2>/dev/null || {
        log_message "ERROR: Failed to create backup archive"
        return 1
    }

    cd - >/dev/null || return 1

    # Calculate metrics
    local size
    size=$(du -sk "${archive_file}" 2>/dev/null | awk '{print $1}')
    total_size=$((size))
    file_count=$(tar -tzf "${archive_file}" 2>/dev/null | wc -l | tr -d ' ')

    # Calculate checksum
    local checksum
    checksum=$(calculate_checksum "${archive_file}")

    # Update manifest
    python3 <<PYTHON
import json
import time

try:
    with open('${BACKUP_MANIFEST}', 'r') as f:
        data = json.load(f)

    if 'backups' not in data:
        data['backups'] = []

    backup_info = {
        'name': '${backup_name}',
        'type': '${backup_type}',
        'timestamp': time.time(),
        'date': '$(date -Iseconds)',
        'path': '${backup_path}',
        'archive': '${archive_file}',
        'size_kb': ${total_size},
        'file_count': ${file_count},
        'checksum': '${checksum}'
    }

    data['backups'].append(backup_info)
    data['last_backup'] = backup_info

    # Keep only last 10 backups in manifest
    data['backups'] = data['backups'][-10:]

    with open('${BACKUP_MANIFEST}', 'w') as f:
        json.dump(data, f, indent=2)

    print(f"✅ Backup complete: {backup_info['size_kb']/1024:.1f} MB, {backup_info['file_count']} files")
except Exception as e:
    print(f'❌ Error updating manifest: {e}')
PYTHON

    log_message "SUCCESS: Backup created: ${archive_file} (${total_size} KB)"
}

# Verify backup integrity
verify_backup() {
    local backup_name="$1"

    log_message "INFO: Verifying backup: ${backup_name}"

    # Find backup in manifest
    local archive
    archive=$(
        python3 <<PYTHON
import json
try:
    with open('${BACKUP_MANIFEST}', 'r') as f:
        data = json.load(f)

    for backup in data.get('backups', []):
        if backup['name'] == '${backup_name}':
            print(backup['archive'])
            break
except:
    pass
PYTHON
    )

    if [[ -z "${archive}" || ! -f "${archive}" ]]; then
        log_message "ERROR: Backup not found: ${backup_name}"
        return 1
    fi

    # Verify checksum
    local stored_checksum
    stored_checksum=$(
        python3 <<PYTHON
import json
try:
    with open('${BACKUP_MANIFEST}', 'r') as f:
        data = json.load(f)

    for backup in data.get('backups', []):
        if backup['name'] == '${backup_name}':
            print(backup.get('checksum', ''))
            break
except:
    pass
PYTHON
    )

    local current_checksum
    current_checksum=$(calculate_checksum "${archive}")

    if [[ "${stored_checksum}" == "${current_checksum}" ]]; then
        log_message "SUCCESS: Backup integrity verified: ${backup_name}"
        return 0
    else
        log_message "ERROR: Backup integrity check failed: ${backup_name}"
        log_message "ERROR: Expected: ${stored_checksum}"
        log_message "ERROR: Got: ${current_checksum}"
        return 1
    fi
}

# List all backups
list_backups() {
    log_message "INFO: Available backups:"

    if [[ ! -f "${BACKUP_MANIFEST}" ]]; then
        log_message "WARNING: No backups found"
        return 0
    fi

    python3 <<PYTHON
import json
try:
    with open('${BACKUP_MANIFEST}', 'r') as f:
        data = json.load(f)

    backups = data.get('backups', [])

    if not backups:
        print("No backups found")
    else:
        print(f"\nTotal backups: {len(backups)}\n")

        for backup in sorted(backups, key=lambda x: x['timestamp'], reverse=True):
            size_mb = backup['size_kb'] / 1024
            print(f"  • {backup['name']}")
            print(f"    Date: {backup['date']}")
            print(f"    Type: {backup['type']}")
            print(f"    Size: {size_mb:.1f} MB")
            print(f"    Files: {backup['file_count']}")
            print()
except Exception as e:
    print(f'Error reading backups: {e}')
PYTHON
}

# Clean old backups
cleanup_old_backups() {
    local retention_days="${1:-30}"

    log_message "INFO: Cleaning backups older than ${retention_days} days..."

    local deleted_count=0

    # Find old backups
    local old_backups
    old_backups=$(find "${BACKUP_DIR}" -name "backup_*.tar.gz" -mtime +"${retention_days}" 2>/dev/null || echo "")

    if [[ -n "${old_backups}" ]]; then
        while IFS= read -r backup_file; do
            log_message "INFO: Deleting old backup: ${backup_file}"
            rm -rf "$(dirname "${backup_file}")"
            deleted_count=$((deleted_count + 1))
        done <<<"${old_backups}"
    fi

    log_message "SUCCESS: Cleaned up ${deleted_count} old backup(s)"
}

# Restore from backup (dry-run supported)
restore_backup() {
    local backup_name="$1"
    local target_dir="${2:-${WORKSPACE_ROOT}/.restore}"
    local dry_run="${3:-false}"

    log_message "INFO: Restoring backup: ${backup_name} to ${target_dir}"

    # Find backup
    local archive
    archive=$(
        python3 <<PYTHON
import json
try:
    with open('${BACKUP_MANIFEST}', 'r') as f:
        data = json.load(f)

    for backup in data.get('backups', []):
        if backup['name'] == '${backup_name}':
            print(backup['archive'])
            break
except:
    pass
PYTHON
    )

    if [[ -z "${archive}" || ! -f "${archive}" ]]; then
        log_message "ERROR: Backup not found: ${backup_name}"
        return 1
    fi

    # Verify integrity first
    if ! verify_backup "${backup_name}"; then
        log_message "ERROR: Cannot restore - integrity check failed"
        return 1
    fi

    if [[ "${dry_run}" == "true" ]]; then
        log_message "INFO: DRY RUN - listing backup contents:"
        tar -tzf "${archive}" | head -20
        log_message "INFO: ... (showing first 20 files)"
        return 0
    fi

    # Create restore directory
    mkdir -p "${target_dir}"

    # Extract backup
    log_message "INFO: Extracting backup..."
    tar -xzf "${archive}" -C "${target_dir}" 2>/dev/null || {
        log_message "ERROR: Failed to extract backup"
        return 1
    }

    log_message "SUCCESS: Backup restored to: ${target_dir}"
}

# Main agent loop
# Process backup task
process_backup_task() {
    local task="$1"

    log_message "Processing backup task: $task"

    # Parse task to determine backup type
    case "$task" in
    test_backup_run)
        # Test run - just verify manifest and list backups without creating new ones
        log_message "INFO: Test run - verifying backup system integrity"
        if [[ -f "${BACKUP_MANIFEST}" ]]; then
            log_message "SUCCESS: Backup manifest exists"
            list_backups
        else
            log_message "WARNING: Backup manifest not found, initializing..."
            initialize_manifest
            log_message "SUCCESS: Backup manifest initialized"
        fi
        ;;
    *full*)
        create_backup "full"
        ;;
    *incremental*)
        create_backup "incremental"
        ;;
    *verify*)
        local backup_name
        backup_name="${task#*verify:}"
        if [[ -n "$backup_name" ]]; then
            verify_backup "$backup_name"
        else
            # Verify latest backup
            local latest_backup
            latest_backup=$(python3 -c "import json; data=json.load(open('${BACKUP_MANIFEST}')); print(data.get('last_backup', {}).get('name', ''))")
            if [[ -n "${latest_backup}" ]]; then
                verify_backup "${latest_backup}"
            fi
        fi
        ;;
    *cleanup*)
        local days
        days=$(echo "$task" | sed 's/.*cleanup://' | sed 's/[^0-9]//g')
        cleanup_old_backups "${days:-30}"
        ;;
    *restore*)
        local backup_name
        backup_name="${task#*restore:}"
        if [[ -n "$backup_name" ]]; then
            restore_backup "$backup_name" "${WORKSPACE_ROOT}/.restore" "false"
        fi
        ;;
    *list*)
        list_backups
        ;;
    *)
        # Default: create incremental backup
        create_backup "incremental"
        ;;
    esac

    log_message "Backup task completed successfully"
}

# Main agent loop
main() {
    log_message "Backup Agent starting..."

    # Initialize backup manifest
    initialize_manifest

    # Check for single run mode (for testing)
    if [[ "${SINGLE_RUN:-false}" == "true" ]]; then
        log_message "Running in SINGLE_RUN mode for testing"
        process_backup_task "test_backup_run"
        log_message "Single run backup complete"
        return 0
    fi

    while true; do
        # Check resource limits before processing
        if ! check_resource_limits; then
            log_message "WARN" "Resource limits exceeded, waiting before retry..."
            sleep 30
            continue
        fi

        # Get next task for this agent
        local task
        task=$(get_next_task "agent_backup")

        if [[ -n "$task" ]]; then
            # Mark task as in progress
            update_task_status "$task" "in_progress" "agent_backup"

            # Process the task
            if process_backup_task "$task"; then
                update_task_status "$task" "completed" "agent_backup"
    increment_task_count "agent_backup"
                log_message "Task $task completed successfully"
            else
                update_task_status "$task" "failed" "agent_backup"
                log_message "Task $task failed"
            fi
        else
            # No tasks available, wait before checking again
            sleep 60
        fi
    done
}

# Run main loop
main "$@"
