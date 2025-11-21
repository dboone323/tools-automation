#!/bin/bash
#
# Safe Disk Cleanup Script
#
# Usage: ./scripts/cleanup.sh [options]
# Options:
#   --dry-run       (Default) Only print what would be done.
#   --confirm       Execute the cleanup actions.
#   --archive-dir   Directory to archive files to (default: ~/tools-automation-archive).
#   --retention     Days to keep files (default: 30).
#   --quarantine    Days to keep in quarantine before delete (default: 7).
#   --allow-models  Allow processing of model files (requires explicit flag).
#   --prune-docker  Prune unused Docker objects (stopped containers, unused networks/images).
#   --prune-caches  Prune package manager caches (npm, pip, etc).
#   --compress      Compress archived items (tar.gz) to save space.
#

set -e

# Defaults
DRY_RUN=true
ARCHIVE_BASE_DIR="$HOME/tools-automation-archive"
RETENTION_DAYS=30
QUARANTINE_DAYS=7
ALLOW_MODELS=false
PRUNE_DOCKER=false
PRUNE_CACHES=false
COMPRESS_ARCHIVES=false
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_STR=$(date +%Y%m%d)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        --confirm) DRY_RUN=false ;;
        --archive-dir) ARCHIVE_BASE_DIR="$2"; shift ;;
        --retention) RETENTION_DAYS="$2"; shift ;;
        --quarantine) QUARANTINE_DAYS="$2"; shift ;;
        --allow-models) ALLOW_MODELS=true ;;
        --prune-docker) PRUNE_DOCKER=true ;;
        --prune-caches) PRUNE_CACHES=true ;;
        --compress) COMPRESS_ARCHIVES=true ;;
        *) error "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

ARCHIVE_DIR="${ARCHIVE_BASE_DIR}/${DATE_STR}"
QUARANTINE_DIR="${ARCHIVE_BASE_DIR}/quarantine"
MANIFEST_FILE="${ARCHIVE_DIR}/manifest_${TIMESTAMP}.txt"

log "Starting cleanup script..."
log "Mode: $(if $DRY_RUN; then echo "${YELLOW}DRY-RUN${NC}"; else echo "${RED}LIVE${NC}"; fi)"
log "Retention: ${RETENTION_DAYS} days"
log "Archive Dir: ${ARCHIVE_DIR}"

if ! $DRY_RUN; then
    mkdir -p "$ARCHIVE_DIR"
    mkdir -p "$QUARANTINE_DIR"
    touch "$MANIFEST_FILE"
fi

# Function to process a file or directory
process_item() {
    local item="$1"
    local type="$2" # 'archive' or 'delete' (delete means move to quarantine)

    if [[ ! -e "$item" ]]; then
        return
    fi

    # Safety checks
    if [[ "$item" == *".git"* && "$item" != *".gitignore"* ]]; then
        warn "Skipping .git directory: $item"
        return
    fi
    
    if [[ "$item" == *"models"* && "$ALLOW_MODELS" == "false" ]]; then
        warn "Skipping models directory (use --allow-models to override): $item"
        return
    fi

    local size
    size=$(du -sh "$item" 2>/dev/null | cut -f1)
    
    if $DRY_RUN; then
        local type_upper=$(echo "$type" | tr '[:lower:]' '[:upper:]')
        echo -e "[${YELLOW}PLAN${NC}] Action: $type_upper | Item: $item | Size: $size"
    else
        local type_upper=$(echo "$type" | tr '[:lower:]' '[:upper:]')
        echo -e "[${GREEN}EXEC${NC}] Action: $type_upper | Item: $item | Size: $size"
        
        # Calculate checksum for files if archiving
        local checksum="N/A"
        if [[ -f "$item" ]]; then
            if command -v sha256sum >/dev/null; then
                checksum=$(sha256sum "$item" | awk '{print $1}')
            elif command -v shasum >/dev/null; then
                checksum=$(shasum -a 256 "$item" | awk '{print $1}')
            fi
        fi

        if [[ "$type" == "archive" ]]; then
            # Copy to archive
            local rel_path
            rel_path=$(python3 -c "import os.path; print(os.path.relpath('$item', '$REPO_ROOT'))")
            local dest_dir="${ARCHIVE_DIR}/$(dirname "$rel_path")"
            mkdir -p "$dest_dir"
            
            if $COMPRESS_ARCHIVES; then
                local archive_name="$(basename "$item").tar.gz"
                tar -czf "${dest_dir}/${archive_name}" -C "$(dirname "$item")" "$(basename "$item")"
                echo "$(date +%s) | ARCHIVE_COMPRESSED | $item | $size | $checksum | ${dest_dir}/${archive_name}" >> "$MANIFEST_FILE"
            else
                if [[ -d "$item" ]]; then
                    cp -R "$item" "$dest_dir/"
                else
                    cp "$item" "$dest_dir/"
                fi
                echo "$(date +%s) | ARCHIVE | $item | $size | $checksum | $dest_dir" >> "$MANIFEST_FILE"
            fi
            
            # Move to quarantine (effectively deleting from source but keeping safety copy)
            local quarantine_dest="${QUARANTINE_DIR}/${DATE_STR}/$(dirname "$rel_path")"
            mkdir -p "$quarantine_dest"
            mv "$item" "$quarantine_dest/"
             echo "$(date +%s) | QUARANTINE | $item | $size | $checksum | $quarantine_dest" >> "$MANIFEST_FILE"

        elif [[ "$type" == "delete" ]]; then
             # Direct move to quarantine (skip long-term archive)
            local rel_path
            rel_path=$(python3 -c "import os.path; print(os.path.relpath('$item', '$REPO_ROOT'))")
            local quarantine_dest="${QUARANTINE_DIR}/${DATE_STR}/$(dirname "$rel_path")"
            mkdir -p "$quarantine_dest"
            mv "$item" "$quarantine_dest/"
            echo "$(date +%s) | QUARANTINE | $item | $size | $checksum | $quarantine_dest" >> "$MANIFEST_FILE"
        fi
    fi
}

# 1. Clean up old archives/quarantine
log "Checking for old quarantine items (> ${QUARANTINE_DAYS} days)..."
if [[ -d "$QUARANTINE_DIR" ]]; then
    if $DRY_RUN; then
        find "$QUARANTINE_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +${QUARANTINE_DAYS} -exec echo "[PLAN] DELETE PERMANENTLY: {}" \;
    else
        find "$QUARANTINE_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +${QUARANTINE_DAYS} -exec rm -rf {} \; -exec echo "[EXEC] DELETED PERMANENTLY: {}" \;
    fi
fi

cd "$REPO_ROOT"

# 2. Process Candidates

# 2.1 Node Modules (Low Risk - Delete/Quarantine directly)
log "Scanning for node_modules..."
find . -name "node_modules" -type d -not -path "*/.*" -prune | while read -r item; do
    process_item "$item" "delete"
done

# 2.2 Virtual Envs (Consolidate - Delete/Quarantine directly)
log "Scanning for virtual environments..."
for venv in .venv venv test_venv; do
    if [[ -d "$venv" ]]; then
        process_item "$venv" "delete"
    fi
done

# 2.3 Caches (Safe to delete)
log "Scanning for caches..."
for cache in .cache .pytest_cache .ruff_cache htmlcov coverage playwright-report; do
    if [[ -d "$cache" ]]; then
        process_item "$cache" "delete"
    fi
done

# 2.4 Logs (Archive then delete)
log "Scanning for old logs (> ${RETENTION_DAYS} days)..."
find logs -type f -mtime +${RETENTION_DAYS} 2>/dev/null | while read -r item; do
    process_item "$item" "archive"
done

# 2.5 Backups (Archive then delete)
log "Scanning for .bak files..."
find . -type f -name "*.bak" -not -path "*/.git/*" | while read -r item; do
    process_item "$item" "archive"
done

# 3. Optional Pruning
if $PRUNE_DOCKER; then
    log "Pruning Docker objects..."
    if $DRY_RUN; then
        echo "[PLAN] docker system prune -a -f (volumes excluded)"
    else
        if command -v docker >/dev/null; then
            docker system prune -a -f
        else
            warn "Docker not found, skipping prune."
        fi
    fi
fi

if $PRUNE_CACHES; then
    log "Pruning package manager caches..."
    if $DRY_RUN; then
        echo "[PLAN] npm cache clean --force"
        echo "[PLAN] pip cache purge"
    else
        if command -v npm >/dev/null; then
            npm cache clean --force
        fi
        if command -v pip >/dev/null; then
            pip cache purge
        fi
    fi
fi

log "Cleanup scan complete."
if $DRY_RUN; then
    log "Run with --confirm to execute changes."
else
    log "Cleanup completed. Manifest: $MANIFEST_FILE"
fi
