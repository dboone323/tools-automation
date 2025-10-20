#!/bin/bash
# Multi-level backup/restore manager for agents with automatic rotation
# Usage: backup_manager.sh backup_if_needed <project> | backup <project> | restore <project> | rotate <project> | list
#
# Features:
# - Automatic backup rotation (keeps ${MAX_BACKUPS_PER_PROJECT} most recent backups per project)
# - backup_if_needed: Only creates backup if none exists in last hour
# - backup: Force creates backup and triggers rotation
# - rotate: Manually rotate backups for a specific project | rotate <project>

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

BACKUP_DIR="$(dirname "$0")/backups"
PROJECTS_DIR="/Users/danielstevens/Desktop/Quantum-workspace/Projects"
AUDIT_LOG="$(dirname "$0")/audit.log"

# Configuration
MAX_BACKUPS_PER_PROJECT=5 # Keep only the 5 most recent backups per project

mkdir -p "${BACKUP_DIR}"

# Rotate backups for a project, keeping only the most recent MAX_BACKUPS_PER_PROJECT
rotate_backups() {
    local project="$1"
    local project_backups
    local backup_count

    # Find all backups for this project, sorted by modification time (newest first)
    mapfile -t project_backups < <(find "${BACKUP_DIR}" -maxdepth 1 -type d -name "${project}_*" -print0 2>/dev/null | xargs -0 ls -td 2>/dev/null)

    backup_count=${#project_backups[@]}

    if [[ ${backup_count} -gt ${MAX_BACKUPS_PER_PROJECT} ]]; then
        local backups_to_remove=$((backup_count - MAX_BACKUPS_PER_PROJECT))
        echo "Rotating backups for ${project}: keeping ${MAX_BACKUPS_PER_PROJECT}, removing ${backups_to_remove} old backups"

        # Remove oldest backups
        for ((i = MAX_BACKUPS_PER_PROJECT; i < backup_count; i++)); do
            local old_backup="${project_backups[$i]}"
            if [[ -d ${old_backup} ]]; then
                echo "Removing old backup: ${old_backup}"
                rm -rf "${old_backup}"
                echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=${USER:-$(whoami)} action=rotate_backup project=${project} removed=${old_backup} result=success" >>"${AUDIT_LOG}"
            fi
        done
    fi
}

backup_if_needed() {
    project="$1"
    # Check if backup was made in last hour (3600 seconds)
    local recent_backup
    recent_backup=$(find "${BACKUP_DIR}" -name "${project}_*" -type d -mmin -60 | head -1)
    if [[ -n ${recent_backup} ]]; then
        echo "Recent backup exists for ${project}, skipping backup creation"
        return 0
    fi
    # No recent backup, create one
    backup "${project}"
}

case "$1" in
backup)
    project="$2"
    timestamp=$(date +%Y%m%d_%H%M%S)
    src="${PROJECTS_DIR}/${project}"
    dest="${BACKUP_DIR}/${project}_${timestamp}"
    user=$(whoami)
    if [[ -d ${src} ]]; then
        cp -r "${src}" "${dest}"
        echo "Backup created: ${dest}"

        # Rotate backups after successful creation
        rotate_backups "${project}"

        echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=${user} action=backup project=${project} dest=${dest} result=success" >>"${AUDIT_LOG}"
    else
        echo "Project ${project} not found."
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=${user} action=backup project=${project} result=fail reason=not_found" >>"${AUDIT_LOG}"
        exit 1
    fi
    ;;
backup_if_needed)
    backup_if_needed "$2"
    ;;
rotate)
    project="$2"
    if [[ -z ${project} ]]; then
        echo "Usage: $0 rotate <project>"
        echo "Rotates all backups for the specified project, keeping only the ${MAX_BACKUPS_PER_PROJECT} most recent."
        exit 1
    fi
    rotate_backups "${project}"
    echo "Backup rotation completed for ${project}"
    ;;
restore)
    project="$2"
    user=$(whoami)
    latest=""
    latest_mtime=0
    while IFS= read -r -d '' dir; do
        if [[ -d ${dir} ]]; then
            if stat -f "%m" "${dir}" >/dev/null 2>&1; then
                mtime=$(stat -f "%m" "${dir}")
            else
                mtime=$(stat -c "%Y" "${dir}" 2>/dev/null || echo 0)
            fi
            if [[ -n ${mtime} && ${mtime} -gt ${latest_mtime} ]]; then
                latest_mtime=${mtime}
                latest="${dir}"
            fi
        fi
    done < <(find "${BACKUP_DIR}" -maxdepth 1 -type d -name "${project}_*" -print0 2>/dev/null)

    if [[ -n ${latest} ]]; then
        rm -rf "${PROJECTS_DIR:?}/${project}"
        cp -r "${latest}" "${PROJECTS_DIR}/${project}"
        echo "Restored ${project} from ${latest}"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=${user} action=restore project=${project} src=${latest} result=success" >>"${AUDIT_LOG}"
    else
        echo "No backup found for ${project}."
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=${user} action=restore project=${project} result=fail reason=no_backup" >>"${AUDIT_LOG}"
        exit 1
    fi
    ;;
list)
    user=$(whoami)
    ls -lh "${BACKUP_DIR}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=${user} action=list_backups result=success" >>"${AUDIT_LOG}"
    ;;
*)
    echo "Usage: $0 backup_if_needed <project> | backup <project> | restore <project> | rotate <project> | list"
    echo "  backup_if_needed: Create backup only if none exists in last hour"
    echo "  backup: Force create a new backup (triggers rotation)"
    echo "  restore: Restore project from latest backup"
    echo "  rotate: Manually rotate backups for a project (keep ${MAX_BACKUPS_PER_PROJECT} most recent)"
    echo "  list: List all backups"
    exit 1
    ;;
esac
