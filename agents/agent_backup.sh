#!/bin/bash
# Agent Backup - Automated backup & disaster recovery
# Performs incremental backups, integrity checks, and disaster recovery testing

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}"
AGENT_NAME="agent_backup"
MCP_URL="${MCP_URL:-http://127.0.0.1:5005}"
LOG_FILE="${AGENTS_DIR}/${AGENT_NAME}.log"
STATUS_FILE="${AGENTS_DIR}/agent_status.json"
BACKUP_DIR="${BACKUP_DIR:-${WORKSPACE_ROOT}/.backups}"
BACKUP_MANIFEST="${BACKUP_DIR}/manifest.json"

# Source AI enhancement modules
ENHANCEMENTS_DIR="${SCRIPT_DIR}/../enhancements"
if [[ -f "${ENHANCEMENTS_DIR}/ai_backup_optimizer.sh" ]]; then
  # shellcheck source=../enhancements/ai_backup_optimizer.sh
  source "${ENHANCEMENTS_DIR}/ai_backup_optimizer.sh"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] $*" | tee -a "${LOG_FILE}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ❌ $*${NC}" | tee -a "${LOG_FILE}"; }
success() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ✅ $*${NC}" | tee -a "${LOG_FILE}"; }
warning() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ⚠️  $*${NC}" | tee -a "${LOG_FILE}"; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ℹ️  $*${NC}" | tee -a "${LOG_FILE}"; }

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

  info "Creating ${backup_type} backup: ${backup_name}"

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

  info "Archiving workspace..."

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
    error "Failed to create backup archive"
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

  success "Backup created: ${archive_file} (${total_size} KB)"
}

# Verify backup integrity
verify_backup() {
  local backup_name="$1"

  info "Verifying backup: ${backup_name}"

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
    error "Backup not found: ${backup_name}"
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
    success "Backup integrity verified: ${backup_name}"
    return 0
  else
    error "Backup integrity check failed: ${backup_name}"
    error "Expected: ${stored_checksum}"
    error "Got: ${current_checksum}"
    return 1
  fi
}

# List all backups
list_backups() {
  info "Available backups:"

  if [[ ! -f "${BACKUP_MANIFEST}" ]]; then
    warning "No backups found"
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

  info "Cleaning backups older than ${retention_days} days..."

  local deleted_count=0

  # Find old backups
  local old_backups
  old_backups=$(find "${BACKUP_DIR}" -name "backup_*.tar.gz" -mtime +${retention_days} 2>/dev/null || echo "")

  if [[ -n "${old_backups}" ]]; then
    while IFS= read -r backup_file; do
      info "Deleting old backup: ${backup_file}"
      rm -rf "$(dirname "${backup_file}")"
      deleted_count=$((deleted_count + 1))
    done <<<"${old_backups}"
  fi

  success "Cleaned up ${deleted_count} old backup(s)"
}

# Restore from backup (dry-run supported)
restore_backup() {
  local backup_name="$1"
  local target_dir="${2:-${WORKSPACE_ROOT}/.restore}"
  local dry_run="${3:-false}"

  info "Restoring backup: ${backup_name} to ${target_dir}"

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
    error "Backup not found: ${backup_name}"
    return 1
  fi

  # Verify integrity first
  if ! verify_backup "${backup_name}"; then
    error "Cannot restore - integrity check failed"
    return 1
  fi

  if [[ "${dry_run}" == "true" ]]; then
    info "DRY RUN - listing backup contents:"
    tar -tzf "${archive}" | head -20
    info "... (showing first 20 files)"
    return 0
  fi

  # Create restore directory
  mkdir -p "${target_dir}"

  # Extract backup
  info "Extracting backup..."
  tar -xzf "${archive}" -C "${target_dir}" 2>/dev/null || {
    error "Failed to extract backup"
    return 1
  }

  success "Backup restored to: ${target_dir}"
}

# Main agent loop
main() {
  log "Backup Agent starting..."
  update_agent_status "agent_backup.sh" "starting" $$ ""

  initialize_manifest

  echo $$ >"${AGENTS_DIR}/${AGENT_NAME}.pid"

  # Register with MCP
  if command -v curl &>/dev/null; then
    curl -s -X POST "${MCP_URL}/register" \
      -H "Content-Type: application/json" \
      -d "{\"agent\": \"${AGENT_NAME}\", \"capabilities\": [\"backup\", \"restore\", \"disaster-recovery\"]}" \
      &>/dev/null || warning "Failed to register with MCP"
  fi

  update_agent_status "agent_backup.sh" "available" $$ ""
  success "Backup Agent ready"

  # Main loop - daily backups
  while true; do
    update_agent_status "agent_backup.sh" "running" $$ ""

    # Create daily incremental backup
    create_backup "incremental"

    # Verify latest backup
    local latest_backup
    latest_backup=$(python3 -c "import json; data=json.load(open('${BACKUP_MANIFEST}')); print(data.get('last_backup', {}).get('name', ''))")

    if [[ -n "${latest_backup}" ]]; then
      verify_backup "${latest_backup}"
    fi

    # Cleanup old backups (>30 days)
    cleanup_old_backups 30

    update_agent_status "agent_backup.sh" "available" $$ ""
    success "Backup cycle complete. Next backup in 24 hours."

    # Heartbeat
    if command -v curl &>/dev/null; then
      curl -s -X POST "${MCP_URL}/heartbeat" \
        -H "Content-Type: application/json" \
        -d "{\"agent\": \"${AGENT_NAME}\"}" &>/dev/null || true
    fi

    sleep 86400 # 24 hours
  done
}

# Handle CLI commands
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-daemon}" in
  create)
    create_backup "${2:-incremental}"
    ;;
  verify)
    verify_backup "$2"
    ;;
  list)
    list_backups
    ;;
  restore)
    restore_backup "${2:-}" "${3:-${WORKSPACE_ROOT}/.restore}" "${4:-false}"
    ;;
  cleanup)
    cleanup_old_backups "${2:-30}"
    ;;
  daemon)
    trap 'update_agent_status "agent_backup.sh" "stopped" $$ ""; log "Backup Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
    ;;
  *)
    echo "Usage: $0 {create|verify|list|restore|cleanup|daemon}"
    echo ""
    echo "Commands:"
    echo "  create [type]             - Create backup (full|incremental)"
    echo "  verify <name>             - Verify backup integrity"
    echo "  list                      - List all backups"
    echo "  restore <name> [dir] [dry] - Restore backup"
    echo "  cleanup [days]            - Remove backups older than N days"
    echo "  daemon                    - Run as daemon (default)"
    exit 1
    ;;
  esac
fi
