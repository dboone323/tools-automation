#!/bin/bash
# Multi-level backup/restore manager for agents
# Usage: backup_manager.sh backup <project> | restore <project> | list

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

BACKUP_DIR="$(dirname "$0")/backups"
PROJECTS_DIR="/Users/danielstevens/Desktop/Quantum-workspace/Projects"
AUDIT_LOG="$(dirname "$0")/audit.log"

mkdir -p "${BACKUP_DIR}"

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
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=${user} action=backup project=${project} dest=${dest} result=success" >>"${AUDIT_LOG}"
  else
    echo "Project ${project} not found."
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=${user} action=backup project=${project} result=fail reason=not_found" >>"${AUDIT_LOG}"
    exit 1
  fi
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
  echo "Usage: $0 backup <project> | restore <project> | list"
  exit 1
  ;;
esac
