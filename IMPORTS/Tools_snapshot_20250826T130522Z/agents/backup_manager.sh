#!/bin/bash
# Multi-level backup/restore manager for agents
# Usage: backup_manager.sh backup <project> | restore <project> | list

BACKUP_DIR="$(dirname "$0")/backups"
PROJECTS_DIR="/Users/danielstevens/Desktop/Code/Projects"
AUDIT_LOG="$(dirname "$0")/audit.log"

mkdir -p "$BACKUP_DIR"

case "$1" in
backup)
	project="$2"
	timestamp=$(date +%Y%m%d_%H%M%S)
	src="$PROJECTS_DIR/$project"
	dest="$BACKUP_DIR/${project}_$timestamp"
	user=$(whoami)
	if [[ -d $src ]]; then
		cp -r "$src" "$dest"
		echo "Backup created: $dest"
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=$user action=backup project=$project dest=$dest result=success" >>"$AUDIT_LOG"
	else
		echo "Project $project not found."
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=$user action=backup project=$project result=fail reason=not_found" >>"$AUDIT_LOG"
		exit 1
	fi
	;;
restore)
	project="$2"
	user=$(whoami)
	latest=$(ls -td "$BACKUP_DIR"/${project}_* 2>/dev/null | head -1)
	if [[ -n $latest ]]; then
		rm -rf "$PROJECTS_DIR/$project"
		cp -r "$latest" "$PROJECTS_DIR/$project"
		echo "Restored $project from $latest"
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=$user action=restore project=$project src=$latest result=success" >>"$AUDIT_LOG"
	else
		echo "No backup found for $project."
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=$user action=restore project=$project result=fail reason=no_backup" >>"$AUDIT_LOG"
		exit 1
	fi
	;;
list)
	user=$(whoami)
	ls -lh "$BACKUP_DIR"
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=$user action=list_backups result=success" >>"$AUDIT_LOG"
	;;
*)
	echo "Usage: $0 backup <project> | restore <project> | list"
	exit 1
	;;
esac
