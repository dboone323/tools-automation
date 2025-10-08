#!/bin/bash

# Setup Cron Job for Regular Repository Maintenance
# This script sets up automated weekly cleanup of AI analysis files

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLEANUP_SCRIPT="${REPO_ROOT}/Tools/Automation/cleanup_ai_analysis.sh"
CRON_SCHEDULE="0 2 * * 0"  # Every Sunday at 2:00 AM

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

check_cron_available() {
    if ! command -v crontab &> /dev/null; then
        log_warning "crontab command not available on this system"
        echo "Alternative scheduling methods:"
        echo "1. Use launchd (macOS):"
        echo "   - Create a plist file in ~/Library/LaunchAgents/"
        echo "2. Use Windows Task Scheduler (Windows)"
        echo "3. Use systemd timers (Linux)"
        echo "4. Manual weekly execution"
        return 1
    fi
    return 0
}

setup_cron_job() {
    log_info "Setting up weekly cleanup cron job..."

    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "${CLEANUP_SCRIPT}"; then
        log_warning "Cron job already exists for cleanup script"
        echo "Current cron jobs:"
        crontab -l | grep "${CLEANUP_SCRIPT}" || true
        return 0
    fi

    # Create the cron job entry
    local cron_job="${CRON_SCHEDULE} ${CLEANUP_SCRIPT} >> ${REPO_ROOT}/cleanup_cron.log 2>&1"

    # Add to crontab
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -

    log_success "Cron job added successfully"
    echo "Schedule: Every Sunday at 2:00 AM"
    echo "Command: $cron_job"
}

verify_cron_setup() {
    log_info "Verifying cron job setup..."

    if crontab -l 2>/dev/null | grep -q "${CLEANUP_SCRIPT}"; then
        log_success "Cron job verified in crontab"
        echo "Active cron jobs for cleanup:"
        crontab -l | grep "${CLEANUP_SCRIPT}" || true
    else
        log_warning "Cron job not found in crontab"
        return 1
    fi
}

create_log_file() {
    local log_file="${REPO_ROOT}/cleanup_cron.log"
    if [[ ! -f "$log_file" ]]; then
        touch "$log_file"
        log_success "Created log file: $log_file"
    fi
}

show_alternatives() {
    echo ""
    echo "📋 Alternative Setup Methods:"
    echo ""
    echo "1. **Manual Weekly Execution:**"
    echo "   bash ${CLEANUP_SCRIPT}"
    echo ""
    echo "2. **macOS LaunchAgent** (recommended for macOS):"
    echo "   Create: ~/Library/LaunchAgents/com.quantum.cleanup.plist"
    cat << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.quantum.cleanup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>CLEANUP_SCRIPT_PATH</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>LOG_FILE_PATH</string>
    <key>StandardErrorPath</key>
    <string>LOG_FILE_PATH</string>
</dict>
</plist>
EOF
    echo ""
    echo "   Then load: launchctl load ~/Library/LaunchAgents/com.quantum.cleanup.plist"
    echo ""
    echo "3. **GitHub Actions** (for automated repository maintenance):"
    echo "   Create .github/workflows/weekly-cleanup.yml"
}

main() {
    echo "⏰ Setting up Automated Weekly Cleanup"
    echo "====================================="
    echo ""

    if ! check_cron_available; then
        show_alternatives
        exit 0
    fi

    create_log_file
    setup_cron_job

    if verify_cron_setup; then
        echo ""
        log_success "Weekly cleanup automation is now active!"
        echo ""
        echo "📊 What happens weekly:"
        echo "• Archives AI analysis files older than 30 days"
        echo "• Updates archive index"
        echo "• Logs all activity to cleanup_cron.log"
        echo ""
        echo "🔍 Monitor the process:"
        echo "• Check logs: tail -f ${REPO_ROOT}/cleanup_cron.log"
        echo "• View archives: ls -la ${REPO_ROOT}/Archives/AI_Analysis/"
    else
        log_warning "Cron job setup failed"
        show_alternatives
    fi
}

# Run main if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi