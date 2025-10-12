#!/bin/bash

# Repository Health & Security Status Report
# Comprehensive overview of security scanning, cleanup, and notification management

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log_info() {
    echo "[REPO-HEALTH] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo "[✅ SUCCESS] $1"
}

log_warning() {
    echo "[⚠️  WARNING] $1"
}

log_error() {
    echo "[❌ ERROR] $1" >&2
}

# Check Dependabot status
check_dependabot() {
    log_info "Checking Dependabot configuration..."

    if [[ -f "${REPO_ROOT}/.github/dependabot.yml" ]]; then
        log_success "Dependabot enabled - configuration file exists"
        echo "   📄 Configuration: .github/dependabot.yml"
        echo "   🔄 Monitors: npm, swift, github-actions"
        echo "   📅 Schedule: Weekly updates"
    else
        log_error "Dependabot not configured"
    fi
}

# Check CodeQL status
check_codeql() {
    log_info "Checking CodeQL code scanning..."

    if [[ -f "${REPO_ROOT}/.github/workflows/codeql-analysis.yml" ]]; then
        log_success "CodeQL enabled - workflow file exists"
        echo "   📄 Workflow: .github/workflows/codeql-analysis.yml"
        echo "   🔍 Languages: Swift, JavaScript"
        echo "   ⏰ Schedule: Weekly + on pushes/PRs"
    else
        log_warning "CodeQL not configured"
    fi
}

# Check Secret Scanning status (via API if possible)
check_secret_scanning() {
    log_info "Checking Secret Scanning status..."

    # Note: Secret scanning status requires repository admin access
    log_warning "Secret scanning status requires manual verification"
    echo "   🔗 Check: https://github.com/dboone323/Quantum-workspace/settings/security_analysis"
    echo "   💡 Enable: Secret scanning alerts"
}

# Check AI analysis cleanup status
    check_cleanup_status() {
        log_info "Checking AI analysis cleanup status..."

        local archive_dir="${REPO_ROOT}/Archives/AI_Analysis"
        local cleanup_script="${REPO_ROOT}/Tools/Automation/cleanup_ai_analysis.sh"

        if [[ -f "${cleanup_script}" ]]; then
            log_success "Cleanup script exists"
            echo "   📄 Script: Tools/Automation/cleanup_ai_analysis.sh"
        else
            log_error "Cleanup script missing"
        fi

        # Check if cron job is set up
        if crontab -l 2>/dev/null | grep -q "${cleanup_script}"; then
            log_success "Automated cleanup scheduled"
            echo "   ⏰ Cron job: Every Sunday at 2:00 AM"
            echo "   📝 Log file: cleanup_cron.log"
        else
            log_info "Manual cleanup available"
            echo "   💡 Run manually: bash Tools/Automation/cleanup_ai_analysis.sh"
        fi

        if [[ -d "${archive_dir}" ]]; then
            local archive_count
            archive_count=$(find "${archive_dir}" -name "*.md" 2>/dev/null | wc -l)
            local index_count
            index_count=$(find "${archive_dir}" -name "archive_index_*.txt*" 2>/dev/null | wc -l)

            log_success "Archive directory exists"
            echo "   📁 Location: Archives/AI_Analysis/"
            echo "   📊 Archived files: ${archive_count}"
            echo "   📋 Archive indices: ${index_count}"
        else
            log_info "No archive directory yet (normal for recent setup)"
        fi
    }

# Check notification management
check_notification_management() {
    log_info "Checking notification management..."

    local notify_script="${REPO_ROOT}/Tools/Automation/manage_notifications.sh"

    if [[ -f "${notify_script}" ]]; then
        log_success "Notification management script exists"
        echo "   📄 Script: Tools/Automation/manage_notifications.sh"
        echo "   🛠️  Commands: mark-all-read, mark-automation-read, list, filters"
    else
        log_error "Notification management script missing"
    fi
}

# Generate comprehensive report
generate_report() {
    log_info "Generating comprehensive repository health report..."
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "           QUANTUM-WORKSPACE HEALTH & SECURITY REPORT"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    check_dependabot
    echo ""

    check_codeql
    echo ""

    check_secret_scanning
    echo ""

    check_cleanup_status
    echo ""

    check_notification_management
    echo ""

    echo "═══════════════════════════════════════════════════════════════"
    echo "                        NEXT STEPS"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "1. 🔐 Enable Secret Scanning:"
    echo "   • Visit: https://github.com/dboone323/Quantum-workspace/settings/security_analysis"
    echo "   • Enable: Secret scanning alerts"
    echo ""
    echo "2. 🧹 Schedule Regular Cleanup:"
    echo "   • Add to cron: 0 2 * * 0 ${REPO_ROOT}/Tools/Automation/cleanup_ai_analysis.sh"
    echo "   • Or run manually: bash Tools/Automation/cleanup_ai_analysis.sh"
    echo ""
    echo "3. 📢 Notification Management:"
    echo "   • Run: bash Tools/Automation/manage_notifications.sh filters"
    echo "   • Configure filters in GitHub settings"
    echo ""
    echo "4. 🔍 Monitor Security Alerts:"
    echo "   • Check: https://github.com/dboone323/Quantum-workspace/security"
    echo "   • Review Dependabot PRs regularly"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Report generated: $(date)"
    echo "═══════════════════════════════════════════════════════════════"
}

# Main execution
main() {
    generate_report
}

# Run main if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi