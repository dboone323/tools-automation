#!/bin/bash
# Disaster Recovery Runbook for Tools Automation System
# Comprehensive procedures for system recovery from various failure scenarios

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RECOVERY_LOG="$PROJECT_ROOT/logs/disaster_recovery_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="$PROJECT_ROOT/backups"
PRIMARY_BACKUP_SERVER="${PRIMARY_BACKUP_SERVER:-backup.example.com}"
SECONDARY_BACKUP_SERVER="${SECONDARY_BACKUP_SERVER:-backup2.example.com}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$RECOVERY_LOG"
}

error() {
    echo -e "${RED}🚨 CRITICAL: $*${NC}" >&2
    log "CRITICAL: $*"
}

warn() {
    echo -e "${YELLOW}⚠️ WARNING: $*${NC}"
    log "WARNING: $*"
}

info() {
    echo -e "${BLUE}ℹ️ INFO: $*${NC}"
    log "INFO: $*"
}

success() {
    echo -e "${GREEN}✅ SUCCESS: $*${NC}"
    log "SUCCESS: $*"
}

header() {
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${PURPLE}$*${NC}"
    echo -e "${PURPLE}================================================${NC}"
}

# Initialize recovery environment
init_recovery() {
    header "DISASTER RECOVERY INITIALIZATION"

    # Create necessary directories
    mkdir -p "$PROJECT_ROOT/logs"
    mkdir -p "$PROJECT_ROOT/backups"
    mkdir -p "$PROJECT_ROOT/recovery"

    # Set recovery mode flag
    export RECOVERY_MODE=true
    export RECOVERY_START_TIME=$(date +%s)

    info "Recovery environment initialized"
    info "Recovery log: $RECOVERY_LOG"
}

# Assess damage and determine recovery strategy
assess_damage() {
    header "SYSTEM DAMAGE ASSESSMENT"

    local damage_report;

    damage_report="$PROJECT_ROOT/recovery/damage_assessment_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "=== SYSTEM DAMAGE ASSESSMENT ==="
        echo "Timestamp: $(date)"
        echo "Hostname: $(hostname)"
        echo ""

        echo "=== FILE SYSTEM STATUS ==="
        df -h
        echo ""

        echo "=== CRITICAL FILES STATUS ==="
        local critical_files;
        critical_files=(
            "agent_dashboard_api.py"
            "agents.db"
            "agent_status.json"
            "requirements.txt"
            "smoke_tests.sh"
        )

        for file in "${critical_files[@]}"; do
            if [ -f "$PROJECT_ROOT/$file" ]; then
                echo "✅ $file - EXISTS"
            else
                echo "❌ $file - MISSING"
            fi
        done
        echo ""

        echo "=== SERVICE STATUS ==="
        # Check MCP server
        if pgrep -f "agent_dashboard_api.py" >/dev/null; then
            echo "✅ MCP Server - RUNNING"
        else
            echo "❌ MCP Server - NOT RUNNING"
        fi

        # Check monitoring
        if pgrep -f "agent_monitoring.sh" >/dev/null; then
            echo "✅ Monitoring - RUNNING"
        else
            echo "❌ Monitoring - NOT RUNNING"
        fi
        echo ""

        echo "=== NETWORK CONNECTIVITY ==="
        if ping -c 1 8.8.8.8 &>/dev/null; then
            echo "✅ Internet - CONNECTED"
        else
            echo "❌ Internet - DISCONNECTED"
        fi

        if curl -f -s http://localhost:5005/health &>/dev/null; then
            echo "✅ MCP API - RESPONDING"
        else
            echo "❌ MCP API - NOT RESPONDING"
        fi
        echo ""

        echo "=== BACKUP STATUS ==="
        if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
            local tar_gz_count;
            tar_gz_count=$(ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
            echo "✅ Local backups available: $tar_gz_count .tar.gz files"
            if [ $tar_gz_count -gt 0 ]; then
                ls -la "$BACKUP_DIR"/*.tar.gz | head -5
            else
                echo "✅ Backup directory exists with $(ls "$BACKUP_DIR" | wc -l) files (may include dummy files for testing)"
            fi
        else
            echo "❌ No local backups found"
        fi

    } >"$damage_report"

    cat "$damage_report"
    log "Damage assessment completed: $damage_report"

    # Determine recovery strategy based on assessment
    determine_recovery_strategy "$damage_report"
}

# Determine appropriate recovery strategy
determine_recovery_strategy() {
    local damage_report;
    damage_report="$1"

    header "RECOVERY STRATEGY DETERMINATION"

    # Analyze damage report to determine strategy
    local missing_critical;
    missing_critical=0
    local services_down;
    services_down=0
    local backups_available;
    backups_available=0

    if grep -q "MISSING" "$damage_report"; then
        missing_critical=$(grep "MISSING" "$damage_report" | wc -l)
    fi

    if grep -q "NOT RUNNING\|NOT RESPONDING" "$damage_report"; then
        services_down=$(grep "NOT RUNNING\|NOT RESPONDING" "$damage_report" | wc -l)
    fi

    if grep -q "backups available" "$damage_report"; then
        backups_available=1
    fi

    info "Analysis Results:"
    info "- Missing critical files: $missing_critical"
    info "- Services down: $services_down"
    info "- Local backups available: $backups_available"

    # Determine strategy
    if [ $missing_critical -gt 2 ] || [ $backups_available -eq 0 ]; then
        warn "SEVERE DAMAGE: Full system restore required"
        export RECOVERY_STRATEGY="full_restore"
    elif [ $services_down -gt 0 ]; then
        warn "SERVICE FAILURE: Service restart and validation required"
        export RECOVERY_STRATEGY="service_recovery"
    else
        info "MINOR ISSUES: Quick repair possible"
        export RECOVERY_STRATEGY="quick_repair"
    fi

    info "Selected recovery strategy: $RECOVERY_STRATEGY"
}

# Quick repair for minor issues
quick_repair() {
    header "QUICK REPAIR PROCEDURE"

    info "Performing quick repairs..."

    # Fix permissions
    info "Fixing file permissions..."
    find "$PROJECT_ROOT" -type f -name "*.sh" -exec chmod +x {} \;
    find "$PROJECT_ROOT" -type f -name "*.py" -exec chmod 644 {} \;

    # Restart services
    info "Restarting services..."
    "$PROJECT_ROOT/rollback.sh" stop_services >/dev/null 2>&1 || true

    # Start services
    if "$PROJECT_ROOT/rollback.sh" start_services >/dev/null 2>&1; then
        success "Services restarted successfully"
    else
        error "Failed to restart services"
        return 1
    fi

    # Run smoke tests
    info "Running smoke tests..."
    if "$PROJECT_ROOT/smoke_tests.sh" >/dev/null 2>&1; then
        success "Smoke tests passed"
    else
        warn "Smoke tests failed - may need deeper recovery"
        return 1
    fi
}

# Service recovery for service failures
service_recovery() {
    header "SERVICE RECOVERY PROCEDURE"

    info "Performing service recovery..."

    # Stop all services
    "$PROJECT_ROOT/rollback.sh" stop_services

    # Clean up any stale processes
    info "Cleaning up stale processes..."
    pkill -9 -f "agent_dashboard_api.py" || true
    pkill -9 -f "agent_monitoring.sh" || true
    pkill -9 -f "auto_restart_monitor.sh" || true
    sleep 5

    # Check and repair database
    if [ -f "$PROJECT_ROOT/agents.db" ]; then
        info "Checking database integrity..."
        if python3 -c "
import sqlite3
import sys
try:
    conn = sqlite3.connect('$PROJECT_ROOT/agents.db')
    conn.execute('SELECT 1').fetchone()
    conn.close()
    print('Database OK')
except Exception as e:
    print(f'Database error: {e}')
    sys.exit(1)
" 2>/dev/null; then
            success "Database integrity verified"
        else
            warn "Database corruption detected - attempting repair"
            # Create backup of corrupted database
            cp "$PROJECT_ROOT/agents.db" "$PROJECT_ROOT/agents.db.corrupted.$(date +%s)"
            # Attempt to recreate from backup if available
            restore_database_from_backup
        fi
    fi

    # Start services
    "$PROJECT_ROOT/rollback.sh" start_services

    # Validate recovery
    validate_recovery
}

# Full system restore from backup
full_restore() {
    header "FULL SYSTEM RESTORE PROCEDURE"

    info "Performing full system restore..."

    # Find best available backup
    local backup_file
    backup_file=$(find "$BACKUP_DIR" -name "backup_*_full.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [ -z "$backup_file" ]; then
        error "No full backup found. Attempting remote backup retrieval..."
        if ! retrieve_remote_backup; then
            error "No backups available. Manual intervention required."
            return 1
        fi
        backup_file=$(find "$BACKUP_DIR" -name "backup_*_full.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    fi

    info "Using backup: $(basename "$backup_file")"

    # Perform rollback
    if "$PROJECT_ROOT/rollback.sh" rollback "$backup_file" true; then
        success "Full system restore completed"
    else
        error "Full system restore failed"
        return 1
    fi

    # Validate recovery
    validate_recovery
}

# Restore database from backup
restore_database_from_backup() {
    info "Attempting database restoration from backup..."

    local db_backup
    db_backup=$(find "$BACKUP_DIR" -name "*database*.tar.gz" -o -name "*db*.tar.gz" | head -1)

    if [ -n "$db_backup" ]; then
        info "Found database backup: $(basename "$db_backup")"

        # Extract database from backup
        local temp_dir
        temp_dir=$(mktemp -d)
        if tar -xzf "$db_backup" -C "$temp_dir" "agents.db" 2>/dev/null; then
            cp "$temp_dir/agents.db" "$PROJECT_ROOT/agents.db"
            success "Database restored from backup"
        else
            warn "Could not extract database from backup"
        fi
        rm -rf "$temp_dir"
    else
        warn "No database backup found"
    fi
}

# Retrieve backup from remote server
retrieve_remote_backup() {
    header "REMOTE BACKUP RETRIEVAL"

    info "Attempting to retrieve backup from remote servers..."

    local remote_servers;

    remote_servers=("$PRIMARY_BACKUP_SERVER" "$SECONDARY_BACKUP_SERVER")

    for server in "${remote_servers[@]}"; do
        if [ "$server" = "backup.example.com" ]; then
            warn "Skipping example server - configure PRIMARY_BACKUP_SERVER"
            continue
        fi

        info "Trying server: $server"

        # Attempt SCP retrieval (configure SSH keys for passwordless access)
        if scp "backup@$server:/backups/tools_automation_latest.tar.gz" "$BACKUP_DIR/" 2>/dev/null; then
            success "Backup retrieved from $server"
            return 0
        fi

        # Attempt rsync
        if rsync -avz "backup@$server::tools_automation_backup" "$BACKUP_DIR/" 2>/dev/null; then
            success "Backup synced from $server"
            return 0
        fi
    done

    error "Could not retrieve backup from any remote server"
    return 1
}

# Validate recovery success
validate_recovery() {
    header "RECOVERY VALIDATION"

    info "Validating recovery success..."

    local validation_passed;

    validation_passed=true

    # Check critical files
    local critical_files;
    critical_files=("agent_dashboard_api.py" "requirements.txt" "smoke_tests.sh")
    for file in "${critical_files[@]}"; do
        if [ ! -f "$PROJECT_ROOT/$file" ]; then
            error "Critical file missing: $file"
            validation_passed=false
        fi
    done

    # Check MCP server health
    if ! curl -f -s http://localhost:5005/health >/dev/null 2>&1; then
        error "MCP server not responding after recovery"
        validation_passed=false
    fi

    # Run smoke tests
    if ! "$PROJECT_ROOT/smoke_tests.sh" >/dev/null 2>&1; then
        error "Smoke tests failing after recovery"
        validation_passed=false
    fi

    # Check database connectivity
    if ! python3 -c "
import sqlite3
import sys
try:
    conn = sqlite3.connect('$PROJECT_ROOT/agents.db')
    conn.execute('SELECT COUNT(*) FROM sqlite_master').fetchone()
    conn.close()
    print('Database OK')
except Exception as e:
    print(f'Database error: {e}')
    sys.exit(1)
" 2>/dev/null; then
        error "Database connectivity issues after recovery"
        validation_passed=false
    fi

    if [ "$validation_passed" = true ]; then
        success "Recovery validation PASSED"
        return 0
    else
        error "Recovery validation FAILED"
        return 1
    fi
}

# Generate recovery report
generate_recovery_report() {
    header "RECOVERY REPORT GENERATION"

    local recovery_time;

    recovery_time=$(($(date +%s) - RECOVERY_START_TIME))
    local report_file;
    report_file="$PROJECT_ROOT/recovery/recovery_report_$(date +%Y%m%d_%H%M%S).md"

    {
        echo "# Disaster Recovery Report"
        echo ""
        echo "## Recovery Details"
        echo "- **Start Time:** $(date -d @$RECOVERY_START_TIME)"
        echo "- **End Time:** $(date)"
        echo "- **Duration:** ${recovery_time} seconds"
        echo "- **Strategy Used:** $RECOVERY_STRATEGY"
        echo "- **Recovery Log:** $RECOVERY_LOG"
        echo ""
        echo "## System Status After Recovery"
        echo "\`\`\`"
        echo "=== SERVICE STATUS ==="
        if pgrep -f "agent_dashboard_api.py" >/dev/null; then
            echo "✅ MCP Server - RUNNING"
        else
            echo "❌ MCP Server - NOT RUNNING"
        fi

        if curl -f -s http://localhost:5005/health &>/dev/null; then
            echo "✅ MCP API - RESPONDING"
        else
            echo "❌ MCP API - NOT RESPONDING"
        fi
        echo "\`\`\`"
        echo ""
        echo "## Recommendations"
        if [ "$RECOVERY_STRATEGY" = "full_restore" ]; then
            echo "- Investigate root cause of system failure"
            echo "- Review backup procedures and frequency"
            echo "- Consider implementing redundant systems"
        fi
        echo "- Run load tests to ensure system stability"
        echo "- Monitor system closely for the next 24 hours"
        echo ""
    } >"$report_file"

    success "Recovery report generated: $report_file"
    info "Recovery completed in ${recovery_time} seconds"
}

# Main disaster recovery orchestration
perform_disaster_recovery() {
    local scenario;
    scenario="${1:-auto}"

    init_recovery

    case "$scenario" in
    "quick")
        info "Starting quick repair recovery..."
        if quick_repair && validate_recovery; then
            success "Quick repair recovery completed successfully"
        else
            error "Quick repair failed, escalating to service recovery..."
            if service_recovery && validate_recovery; then
                success "Service recovery completed successfully"
            else
                error "Service recovery failed, performing full restore..."
                full_restore
            fi
        fi
        ;;
    "service")
        info "Starting service recovery..."
        service_recovery
        ;;
    "full")
        info "Starting full system restore..."
        full_restore
        ;;
    "auto" | *)
        info "Starting automatic disaster recovery..."
        assess_damage

        case "$RECOVERY_STRATEGY" in
        "quick_repair")
            quick_repair
            ;;
        "service_recovery")
            service_recovery
            ;;
        "full_restore")
            full_restore
            ;;
        *)
            error "Unknown recovery strategy: $RECOVERY_STRATEGY"
            return 1
            ;;
        esac
        ;;
    esac

    # Generate final report
    generate_recovery_report

    # Calculate total recovery time
    local total_time;
    total_time=$(($(date +%s) - RECOVERY_START_TIME))
    info "Total disaster recovery time: ${total_time} seconds"
}

# Interactive disaster recovery menu
interactive_recovery() {
    echo "🚨 Tools Automation System - Disaster Recovery"
    echo "============================================="
    echo
    echo "Available recovery scenarios:"
    echo "1. Automatic recovery (recommended)"
    echo "2. Quick repair (minor issues)"
    echo "3. Service recovery (service failures)"
    echo "4. Full system restore (major damage)"
    echo "5. Assess system damage"
    echo "6. Exit"
    echo

    while true; do
        read -p "Enter your choice (1-6): " choice
        echo

        case $choice in
        1)
            perform_disaster_recovery "auto"
            ;;
        2)
            perform_disaster_recovery "quick"
            ;;
        3)
            perform_disaster_recovery "service"
            ;;
        4)
            perform_disaster_recovery "full"
            ;;
        5)
            assess_damage
            ;;
        6)
            info "Exiting disaster recovery"
            exit 0
            ;;
        *)
            error "Invalid choice. Please enter 1-6."
            ;;
        esac
        echo
    done
}

# Command line interface
main() {
    local command;
    command="${1:-interactive}"

    case "$command" in
    "auto")
        perform_disaster_recovery "auto"
        ;;
    "quick")
        perform_disaster_recovery "quick"
        ;;
    "service")
        perform_disaster_recovery "service"
        ;;
    "full")
        perform_disaster_recovery "full"
        ;;
    "assess")
        init_recovery
        assess_damage
        ;;
    "interactive" | *)
        interactive_recovery
        ;;
    esac
}

# Run main function with all arguments
main "$@"
