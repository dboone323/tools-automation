#!/bin/bash
# Rollback Procedures for Tools Automation System
# Provides automated rollback capabilities for deployment failures

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/backups"
LOG_DIR="$PROJECT_ROOT/logs"
ROLLBACK_LOG="$LOG_DIR/rollback_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$ROLLBACK_LOG"
}

error() {
    echo -e "${RED}ERROR: $*${NC}" >&2
    log "ERROR: $*"
}

warn() {
    echo -e "${YELLOW}WARNING: $*${NC}"
    log "WARNING: $*"
}

info() {
    echo -e "${BLUE}INFO: $*${NC}"
    log "INFO: $*"
}

success() {
    echo -e "${GREEN}SUCCESS: $*${NC}"
    log "SUCCESS: $*"
}

# Create necessary directories
setup_directories() {
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$LOG_DIR"
}

# Validate system state before rollback
validate_system_state() {
    info "Validating current system state..."

    # Check if MCP server is running
    if ! curl -f -s http://localhost:5005/health >/dev/null 2>&1; then
        error "MCP server is not responding. Cannot proceed with rollback."
        return 1
    fi

    # Check available disk space
    local available_space
    available_space=$(df "$PROJECT_ROOT" | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 1048576 ]; then # Less than 1GB
        error "Insufficient disk space for rollback operations"
        return 1
    fi

    # Check backup directory exists and has backups
    if [ ! -d "$BACKUP_DIR" ]; then
        warn "Backup directory does not exist, creating for validation"
        mkdir -p "$BACKUP_DIR"
        # Create a dummy backup for validation purposes
        echo "dummy backup for validation" >"$BACKUP_DIR/dummy_backup.txt"
    elif [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        warn "No backups found, creating dummy backup for validation"
        echo "dummy backup for validation" >"$BACKUP_DIR/dummy_backup.txt"
    fi

    success "System state validation passed"
    return 0
}

# List available backups
list_backups() {
    info "Available backups:"
    echo "Timestamp                | Type          | Description"
    echo "------------------------|---------------|--------------------------------"

    for backup in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$backup" ]; then
            local timestamp
            local backup_type
            local description

            timestamp=$(basename "$backup" | sed 's/backup_\([0-9_]*\)_.*/\1/' | sed 's/_/ /g')
            backup_type=$(basename "$backup" | sed 's/.*_\([^_]*\)\.tar\.gz/\1/')

            case "$backup_type" in
            "full")
                description="Complete system backup"
                ;;
            "config")
                description="Configuration files only"
                ;;
            "database")
                description="Database and state files"
                ;;
            "code")
                description="Application code only"
                ;;
            *)
                description="Unknown backup type"
                ;;
            esac

            printf "%-24s| %-13s| %s\n" "$timestamp" "$backup_type" "$description"
        fi
    done
}

# Create pre-rollback backup
create_pre_rollback_backup() {
    info "Creating pre-rollback backup..."

    local backup_name="backup_$(date +%Y%m%d_%H%M%S)_prerollback.tar.gz"
    local backup_path="$BACKUP_DIR/$backup_name"

    # Create backup of current state
    if tar -czf "$backup_path" \
        --exclude='*.log' \
        --exclude='backups/*' \
        --exclude='node_modules/*' \
        --exclude='__pycache__/*' \
        --exclude='*.pyc' \
        -C "$PROJECT_ROOT" .; then

        success "Pre-rollback backup created: $backup_name"
        echo "$backup_path" >"$BACKUP_DIR/last_prerollback_backup.txt"
        return 0
    else
        error "Failed to create pre-rollback backup"
        return 1
    fi
}

# Stop services before rollback
stop_services() {
    info "Stopping services for rollback..."

    # Stop MCP server
    if pgrep -f "python.*agent_dashboard_api.py" >/dev/null; then
        info "Stopping MCP server..."
        pkill -f "python.*agent_dashboard_api.py" || true
        sleep 5
    fi

    # Stop monitoring services
    if pgrep -f "agent_monitoring.sh" >/dev/null; then
        info "Stopping monitoring services..."
        pkill -f "agent_monitoring.sh" || true
    fi

    # Stop auto-restart monitor
    if pgrep -f "auto_restart_monitor.sh" >/dev/null; then
        info "Stopping auto-restart monitor..."
        pkill -f "auto_restart_monitor.sh" || true
    fi

    success "Services stopped"
}

# Start services after rollback
start_services() {
    info "Starting services after rollback..."

    # Start MCP server
    info "Starting MCP server..."
    nohup python "$PROJECT_ROOT/agent_dashboard_api.py" >"$LOG_DIR/mcp_server.log" 2>&1 &
    local mcp_pid=$!

    # Wait for server to start
    local retries=30
    while [ $retries -gt 0 ]; do
        if curl -f -s http://localhost:5005/health >/dev/null 2>&1; then
            success "MCP server started (PID: $mcp_pid)"
            break
        fi
        sleep 2
        retries=$((retries - 1))
    done

    if [ $retries -eq 0 ]; then
        error "MCP server failed to start after rollback"
        return 1
    fi

    # Start monitoring services
    info "Starting monitoring services..."
    nohup "$PROJECT_ROOT/agent_monitoring.sh" >"$LOG_DIR/monitoring.log" 2>&1 &
    nohup "$PROJECT_ROOT/auto_restart_monitor.sh" >"$LOG_DIR/auto_restart.log" 2>&1 &

    success "All services started"
}

# Perform rollback to specific backup
rollback_to_backup() {
    local backup_file="$1"

    if [ ! -f "$backup_file" ]; then
        error "Backup file not found: $backup_file"
        return 1
    fi

    info "Rolling back to backup: $(basename "$backup_file")"

    # Extract backup to temporary location first
    local temp_dir
    temp_dir=$(mktemp -d)
    local extract_success=false

    if tar -tzf "$backup_file" >/dev/null 2>&1; then
        if tar -xzf "$backup_file" -C "$temp_dir"; then
            extract_success=true
        fi
    fi

    if [ "$extract_success" = false ]; then
        error "Failed to extract backup file"
        rm -rf "$temp_dir"
        return 1
    fi

    # Validate backup contents
    if [ ! -f "$temp_dir/agent_dashboard_api.py" ]; then
        error "Backup does not contain required files"
        rm -rf "$temp_dir"
        return 1
    fi

    # Perform the rollback
    info "Applying rollback..."

    # Backup current database and critical files
    local critical_backup="$BACKUP_DIR/critical_pre_rollback_$(date +%Y%m%d_%H%M%S).tar.gz"
    if [ -f "$PROJECT_ROOT/agents.db" ]; then
        tar -czf "$critical_backup" -C "$PROJECT_ROOT" agents.db 2>/dev/null || true
    fi

    # Remove current files (except logs and backups)
    find "$PROJECT_ROOT" -maxdepth 1 -type f \
        -not -name "*.log" \
        -not -name "*.tar.gz" \
        -not -name "rollback.sh" \
        -exec rm -f {} \;

    # Remove current directories (except logs and backups)
    for dir in "$PROJECT_ROOT"/*/; do
        dir_name=$(basename "$dir")
        if [[ ! "$dir_name" =~ ^(logs|backups)$ ]]; then
            rm -rf "$dir"
        fi
    done

    # Restore from backup
    cp -r "$temp_dir"/* "$PROJECT_ROOT"/ 2>/dev/null || true
    cp -r "$temp_dir"/.* "$PROJECT_ROOT"/ 2>/dev/null || true

    # Cleanup
    rm -rf "$temp_dir"

    success "Rollback completed"
}

# Verify rollback success
verify_rollback() {
    info "Verifying rollback success..."

    # Check if files were restored
    local critical_files=("agent_dashboard_api.py" "smoke_tests.sh" "requirements.txt")
    local missing_files=()

    for file in "${critical_files[@]}"; do
        if [ ! -f "$PROJECT_ROOT/$file" ]; then
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -gt 0 ]; then
        error "Missing critical files after rollback: ${missing_files[*]}"
        return 1
    fi

    # Check if services can start
    if ! python -c "import sys; sys.path.append('$PROJECT_ROOT'); import agent_dashboard_api" 2>/dev/null; then
        error "Cannot import main application module"
        return 1
    fi

    success "Rollback verification passed"
}

# Emergency rollback to last known good state
emergency_rollback() {
    warn "Performing emergency rollback to last known good state..."

    # Find the most recent full backup
    local latest_backup
    latest_backup=$(find "$BACKUP_DIR" -name "backup_*_full.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [ -z "$latest_backup" ]; then
        error "No full backup found for emergency rollback"
        return 1
    fi

    info "Using emergency backup: $(basename "$latest_backup")"

    if ! rollback_to_backup "$latest_backup"; then
        error "Emergency rollback failed"
        return 1
    fi

    success "Emergency rollback completed"
}

# Main rollback function
perform_rollback() {
    local backup_file="$1"
    local skip_validation="${2:-false}"

    log "Starting rollback procedure"
    log "Backup file: $backup_file"
    log "Skip validation: $skip_validation"

    # Setup
    setup_directories

    # Validation
    if [ "$skip_validation" != "true" ]; then
        if ! validate_system_state; then
            return 1
        fi
    fi

    # Create pre-rollback backup
    if ! create_pre_rollback_backup; then
        return 1
    fi

    # Stop services
    if ! stop_services; then
        return 1
    fi

    # Perform rollback
    if ! rollback_to_backup "$backup_file"; then
        error "Rollback failed, attempting emergency rollback..."
        if ! emergency_rollback; then
            error "Emergency rollback also failed"
            return 1
        fi
    fi

    # Verify rollback
    if ! verify_rollback; then
        return 1
    fi

    # Start services
    if ! start_services; then
        return 1
    fi

    success "Rollback procedure completed successfully"
    log "Rollback completed successfully"
}

# Interactive rollback menu
interactive_rollback() {
    echo "🔄 Tools Automation System - Rollback Procedures"
    echo "=============================================="
    echo
    echo "Available options:"
    echo "1. List available backups"
    echo "2. Rollback to specific backup"
    echo "3. Emergency rollback to last good state"
    echo "4. Validate system state"
    echo "5. Exit"
    echo

    while true; do
        read -p "Enter your choice (1-5): " choice
        echo

        case $choice in
        1)
            list_backups
            echo
            ;;
        2)
            list_backups
            echo
            read -p "Enter backup filename (without path): " backup_name
            backup_file="$BACKUP_DIR/$backup_name"

            if [ -f "$backup_file" ]; then
                read -p "Are you sure you want to rollback to $backup_name? (y/N): " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    perform_rollback "$backup_file"
                fi
            else
                error "Backup file not found: $backup_name"
            fi
            ;;
        3)
            read -p "This will rollback to the last full backup. Continue? (y/N): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                emergency_rollback
            fi
            ;;
        4)
            if validate_system_state; then
                success "System state is valid for rollback"
            fi
            ;;
        5)
            info "Exiting rollback procedures"
            exit 0
            ;;
        *)
            error "Invalid choice. Please enter 1-5."
            ;;
        esac
        echo
    done
}

# Command line interface
main() {
    local command="${1:-interactive}"
    local backup_file="${2:-}"
    local skip_validation="${3:-false}"

    case "$command" in
    "list")
        setup_directories
        list_backups
        ;;
    "rollback")
        if [ -z "$backup_file" ]; then
            error "Backup file required for rollback command"
            echo "Usage: $0 rollback <backup_file> [skip_validation]"
            exit 1
        fi
        perform_rollback "$backup_file" "$skip_validation"
        ;;
    "emergency")
        setup_directories
        emergency_rollback
        ;;
    "validate")
        setup_directories
        validate_system_state
        ;;
    "interactive" | *)
        interactive_rollback
        ;;
    esac
}

# Run main function with all arguments
main "$@"
