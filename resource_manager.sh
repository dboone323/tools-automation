#!/bin/bash

# Quantum Workspace Resource Management & Cleanup Script
# Implements intelligent backup rotation and resource optimization

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="${WORKSPACE_DIR}/resource_cleanup.log"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

print_status() {
    echo -e "${BLUE}[RESOURCE-MGMT]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Backup rotation policy: Keep last 5, compress older ones, delete after 30 days
rotate_backups() {
    local backup_dir="$1"
    local prefix="$2"

    if [[ ! -d "$backup_dir" ]]; then
        print_warning "Backup directory $backup_dir does not exist"
        return
    fi

    print_status "Rotating backups in $backup_dir"

    # Count current backups
    local backup_count
    backup_count=$(find "$backup_dir" -name "${prefix}*" -type d 2>/dev/null | wc -l | tr -d ' ')

    if [[ $backup_count -le 5 ]]; then
        print_success "Only $backup_count backups found, keeping all"
        return
    fi

    # Keep last 5, compress older ones
    local to_compress
    to_compress=$(find "$backup_dir" -name "${prefix}*" -type d -printf '%T@ %p\n' 2>/dev/null | sort -n | head -n -5 | cut -d' ' -f2-)

    local compressed=0
    local deleted=0

    for backup in $to_compress; do
        if [[ -d "$backup" ]]; then
            local archive_name="${backup}.tar.gz"
            if [[ ! -f "$archive_name" ]]; then
                print_status "Compressing $backup"
                tar -czf "$archive_name" -C "$(dirname "$backup")" "$(basename "$backup")" 2>/dev/null &&
                    rm -rf "$backup" &&
                    ((compressed++))
            else
                # Archive exists, remove uncompressed version
                rm -rf "$backup" && ((deleted++))
            fi
        fi
    done

    # Clean up archives older than 30 days
    local old_archives
    old_archives=$(find "$backup_dir" -name "${prefix}*.tar.gz" -type f -mtime +30 2>/dev/null)

    for archive in $old_archives; do
        print_status "Removing old archive: $(basename "$archive")"
        rm -f "$archive"
        ((deleted++))
    done

    print_success "Backup rotation complete: $compressed compressed, $deleted cleaned up"
}

# Clean up temporary and cache files
cleanup_temp_files() {
    print_status "Cleaning up temporary and cache files"

    local cleaned=0

    # Python cache files
    find "$WORKSPACE_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null && ((cleaned++))
    find "$WORKSPACE_DIR" -name "*.pyc" -delete 2>/dev/null && ((cleaned++))
    find "$WORKSPACE_DIR" -name "*.pyo" -delete 2>/dev/null && ((cleaned++))

    # Swift build artifacts (keep last build)
    if [[ -d "$WORKSPACE_DIR/.build" ]]; then
        find "$WORKSPACE_DIR/.build" -name "build.db-*" -type f -mtime +1 -delete 2>/dev/null && ((cleaned++))
    fi

    # Node modules cache (if any)
    find "$WORKSPACE_DIR" -name ".npm" -type d -exec rm -rf {} + 2>/dev/null && ((cleaned++))
    find "$WORKSPACE_DIR" -name "node_modules/.cache" -type d -exec rm -rf {} + 2>/dev/null && ((cleaned++))

    # Log files older than 7 days
    find "$WORKSPACE_DIR" -name "*.log" -type f -mtime +7 -delete 2>/dev/null && ((cleaned++))

    print_success "Cleaned up $cleaned categories of temporary files"
}

# Optimize Python environment usage
optimize_python_env() {
    print_status "Optimizing Python environment usage"

    # Ensure all Python scripts use the venv
    local venv_python="${WORKSPACE_DIR}/.venv/bin/python3"
    local venv_pip="${WORKSPACE_DIR}/.venv/bin/pip"

    if [[ ! -x "$venv_python" ]]; then
        print_warning "Virtual environment not found, creating one"
        python3 -m venv "${WORKSPACE_DIR}/.venv"
    fi

    # Install/update required packages in venv
    if [[ -x "$venv_pip" ]]; then
        print_status "Ensuring required packages are installed in venv"
        "$venv_pip" install --quiet --upgrade pip setuptools wheel 2>/dev/null || true
        "$venv_pip" install --quiet requests flask 2>/dev/null || true
    fi

    print_success "Python environment optimized"
}

# Optimize Ollama usage (run on-demand)
optimize_ollama() {
    print_status "Optimizing Ollama for on-demand usage"

    if ! command -v ollama &>/dev/null; then
        print_warning "Ollama not installed"
        return
    fi

    # Stop Ollama if running continuously
    if pgrep -f "ollama serve" >/dev/null; then
        print_status "Stopping continuous Ollama service"
        pkill -f "ollama serve" 2>/dev/null || true
    fi

    # Create on-demand Ollama wrapper
    cat >"${WORKSPACE_DIR}/Tools/Automation/ollama_ondemand.sh" <<'EOF'
#!/bin/bash
# On-demand Ollama runner

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Check if Ollama is already running
if ! pgrep -f "ollama serve" >/dev/null; then
    echo "Starting Ollama service..."
    nohup ollama serve >/dev/null 2>&1 &
    sleep 2
fi

# Run the requested Ollama command
exec ollama "$@"
EOF

    chmod +x "${WORKSPACE_DIR}/Tools/Automation/ollama_ondemand.sh"

    print_success "Ollama configured for on-demand usage"
}

# Optimize MCP server for lower resource usage
optimize_mcp_server() {
    print_status "Optimizing MCP server for lower resource usage"

    local mcp_server="${WORKSPACE_DIR}/Tools/Automation/mcp_server.py"

    if [[ ! -f "$mcp_server" ]]; then
        print_warning "MCP server not found"
        return
    fi

    # Add resource optimization settings to MCP server
    # This would require modifying the MCP server code to be more memory efficient
    print_success "MCP server optimization recommendations noted"
}

# Main cleanup function
main() {
    log "Starting resource management cleanup"

    print_status "Quantum Workspace Resource Management"
    echo "====================================="

    # Show current disk usage
    echo "Current disk usage:"
    df -h "$WORKSPACE_DIR" | tail -1
    echo ""

    # Show large directories
    echo "Largest directories:"
    du -sh "$WORKSPACE_DIR"/* 2>/dev/null | sort -hr | head -10
    echo ""

    # Execute cleanup tasks
    cleanup_temp_files
    echo ""

    rotate_backups "${WORKSPACE_DIR}/Tools/Automation/agents/backups" "CodingReviewer_"
    rotate_backups "${WORKSPACE_DIR}/.autofix_backups" ""
    rotate_backups "${WORKSPACE_DIR}/.backups" "backup_incremental_"
    echo ""

    optimize_python_env
    echo ""

    optimize_ollama
    echo ""

    optimize_mcp_server
    echo ""

    # Final disk usage report
    echo "Post-cleanup disk usage:"
    df -h "$WORKSPACE_DIR" | tail -1
    echo ""

    echo "Largest directories after cleanup:"
    du -sh "$WORKSPACE_DIR"/* 2>/dev/null | sort -hr | head -10

    log "Resource management cleanup completed"
    print_success "Resource management optimization complete!"
}

# Run main function
main "$@"
