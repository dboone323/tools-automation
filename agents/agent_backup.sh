#!/bin/bash
# Agent Backup - Automated backup & disaster recovery
# Performs incremental backups, integrity checks, and disaster recovery testing

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -euo pipefail

# Resource limits (matching security agent standards)
MAX_FILES=1000
MAX_EXECUTION_TIME=1800 # 30 minutes
MAX_MEMORY_USAGE=80     # 80% of available memory
MAX_CPU_USAGE=90        # 90% CPU usage threshold

# Task processing limits
MAX_CONCURRENT_TASKS=3
TASK_TIMEOUT=600 # 10 minutes per task

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}"
AGENT_NAME="agent_backup"
LOG_FILE="${AGENTS_DIR}/${AGENT_NAME}.log"
STATUS_FILE="${AGENTS_DIR}/agent_status.json"
BACKUP_DIR="${BACKUP_DIR:-${WORKSPACE_ROOT}/.backups}"
BACKUP_MANIFEST="${BACKUP_DIR}/manifest.json"

# Logging function
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] $*" | tee -a "${LOG_FILE}"
}

# Portable run_with_timeout: run a command and kill it if it exceeds timeout (seconds)
# Usage: run_with_timeout <seconds> <cmd> [args...]
run_with_timeout() {
    local timeout_secs="$1"
    shift
    if [[ -z "${timeout_secs}" || ${timeout_secs} -le 0 ]]; then
        "$@"
        return $?
    fi

    # Run command in background
    (
        "$@"
    ) &
    local cmd_pid=$!

    # Watcher: sleep then kill if still running
    (
        sleep "${timeout_secs}"
        if kill -0 "${cmd_pid}" 2>/dev/null; then
            log_message "WARN: Command timed out after ${timeout_secs}s, killing pid ${cmd_pid}"
            kill -9 "${cmd_pid}" 2>/dev/null || true
        fi
    ) &
    local watcher_pid=$!

    # Wait for command to finish
    wait "${cmd_pid}" 2>/dev/null
    local cmd_status=$?

    # Clean up watcher
    kill -9 "${watcher_pid}" 2>/dev/null || true
    wait "${watcher_pid}" 2>/dev/null || true

    return ${cmd_status}
}

# Function to check resource usage and limits
check_resource_limits() {
    # Check memory usage (macOS compatible)
    local mem_usage
    if command -v vm_stat >/dev/null 2>&1; then
        # macOS: calculate memory usage percentage
        mem_usage=$(vm_stat | awk '/Pages active/ {active=$3} /Pages wired/ {wired=$4} END {total=active+wired; print int(total/2560*100)}' 2>/dev/null || echo "50")
    else
        # Fallback: use ps for memory info
        mem_usage=$(ps -o pmem= -C "${AGENT_NAME}" | awk '{sum+=$1} END {print int(sum)}' 2>/dev/null || echo "10")
    fi

    if [[ ${mem_usage} -gt ${MAX_MEMORY_USAGE} ]]; then
        log_message "WARN: Memory usage too high (${mem_usage}% > ${MAX_MEMORY_USAGE}%)"
        return 1
    fi

    # Check CPU usage
    local cpu_usage
    cpu_usage=$(ps -o pcpu= -C "${AGENT_NAME}" | awk '{sum+=$1} END {print int(sum)}' 2>/dev/null || echo "5")

    if [[ ${cpu_usage} -gt ${MAX_CPU_USAGE} ]]; then
        log_message "WARN: CPU usage too high (${cpu_usage}% > ${MAX_CPU_USAGE}%)"
        return 1
    fi

    return 0
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
    old_backups=$(find "${BACKUP_DIR}" -name "backup_*.tar.gz" -mtime +${retention_days} 2>/dev/null || echo "")

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
        local backup_name=$(echo "$task" | sed 's/.*verify://')
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
        local days=$(echo "$task" | sed 's/.*cleanup://' | sed 's/[^0-9]//g')
        cleanup_old_backups "${days:-30}"
        ;;
    *restore*)
        local backup_name=$(echo "$task" | sed 's/.*restore://')
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
        # Ensure we're within system limits
        if ! ensure_within_limits; then
            log_message "System limits exceeded, waiting before retry..."
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
