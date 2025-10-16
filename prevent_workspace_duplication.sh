#!/bin/bash

# Workspace Duplication Prevention Script
# Prevents workspace configuration drift and duplication issues

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE_FILE="${WORKSPACE_ROOT}/Tools/Automation/workspace_template.code-workspace"
PRIMARY_WORKSPACE="${WORKSPACE_ROOT}/Code.code-workspace"
LOG_FILE="${WORKSPACE_ROOT}/workspace_validation.log"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOG_FILE}"
}

# Initialize log file
init_log() {
    echo "=== Workspace Validation Log - $(date) ===" >"${LOG_FILE}"
    echo "Workspace Root: ${WORKSPACE_ROOT}" >>"${LOG_FILE}"
    echo "" >>"${LOG_FILE}"
}

# Check for duplicate workspace files
check_duplicates() {
    log_info "Checking for duplicate workspace files..."

    local duplicates
    duplicates=$(find "${WORKSPACE_ROOT}" -name "*.code-workspace" -type f | grep -v "^${PRIMARY_WORKSPACE}$" | grep -v "/workspace_template\.code-workspace$" | grep -v "/Archive/" | grep -v "/Workspace_Backup_" | grep -v "/\.vscode/backups/")

    if [[ -n ${duplicates} ]]; then
        log_error "Duplicate workspace files found:"
        echo "${duplicates}" | while read -r file; do
            log_error "  ${file}"
        done
        return 1
    else
        log_success "No duplicate workspace files detected"
        return 0
    fi
}

# Validate primary workspace file
validate_primary_workspace() {
    log_info "Validating primary workspace file..."

    if [[ ! -f ${PRIMARY_WORKSPACE} ]]; then
        log_error "Primary workspace file not found: ${PRIMARY_WORKSPACE}"
        return 1
    fi

    log_success "Primary workspace file exists"

    # Check JSON validity
    if command -v jq &>/dev/null; then
        if jq empty "${PRIMARY_WORKSPACE}" 2>/dev/null; then
            log_success "Workspace JSON structure is valid"
        else
            log_error "Workspace JSON structure is invalid"
            return 1
        fi
    else
        log_warning "jq not available - skipping JSON validation"
    fi

    # Check required sections
    local has_folders has_settings has_extensions

    has_folders=$(grep -c '"folders"' "${PRIMARY_WORKSPACE}" 2>/dev/null || echo "0")
    has_settings=$(grep -c '"settings"' "${PRIMARY_WORKSPACE}" 2>/dev/null || echo "0")
    has_extensions=$(grep -c '"extensions"' "${PRIMARY_WORKSPACE}" 2>/dev/null || echo "0")

    if [[ ${has_folders} -gt 0 ]]; then
        log_success "Workspace contains folders configuration"
    else
        log_warning "Workspace missing folders configuration"
    fi

    if [[ ${has_settings} -gt 0 ]]; then
        log_success "Workspace contains settings configuration"
    else
        log_warning "Workspace missing settings configuration"
    fi

    if [[ ${has_extensions} -gt 0 ]]; then
        log_success "Workspace contains extensions recommendations"
    else
        log_warning "Workspace missing extensions recommendations"
    fi

    return 0
}

# Compare with template (optional)
compare_with_template() {
    if [[ ! -f ${TEMPLATE_FILE} ]]; then
        log_warning "Template file not found - skipping template comparison"
        return 0
    fi

    log_info "Comparing workspace with template..."

    # This is a basic comparison - could be enhanced with more sophisticated diffing
    local template_size workspace_size
    template_size=$(wc -c <"${TEMPLATE_FILE}")
    workspace_size=$(wc -c <"${PRIMARY_WORKSPACE}")

    local size_diff=$((workspace_size - template_size))
    if [[ ${size_diff} -gt 10000 ]]; then
        log_warning "Workspace file is significantly larger than template (${size_diff} bytes difference)"
    elif [[ ${size_diff} -lt -10000 ]]; then
        log_warning "Workspace file is significantly smaller than template (${size_diff} bytes difference)"
    else
        log_success "Workspace size is reasonable compared to template"
    fi
}

# Create backup if needed
create_backup() {
    local backup_dir="${WORKSPACE_ROOT}/.vscode/backups"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    if [[ ! -d ${backup_dir} ]]; then
        mkdir -p "${backup_dir}"
        log_info "Created backup directory: ${backup_dir}"
    fi

    local backup_file="${backup_dir}/Code.code-workspace.backup.${timestamp}"
    cp "${PRIMARY_WORKSPACE}" "${backup_file}"
    log_success "Workspace backup created: ${backup_file}"
}

# Generate validation report
generate_report() {
    local report_file="${WORKSPACE_ROOT}/workspace_validation_report.md"
    local validation_status="$1"

    {
        echo "# Workspace Validation Report"
        echo "Generated: $(date)"
        echo ""
        echo "## Validation Status"
        if [[ ${validation_status} -eq 0 ]]; then
            echo "✅ **PASSED** - Workspace configuration is valid"
        else
            echo "❌ **FAILED** - Issues found with workspace configuration"
        fi
        echo ""
        echo "## Details"
        echo "- Primary Workspace: ${PRIMARY_WORKSPACE}"
        echo "- Template: ${TEMPLATE_FILE}"
        echo "- Log File: ${LOG_FILE}"
        echo ""
        echo "## Recent Log Entries"
        tail -20 "${LOG_FILE}" | sed 's/\x1b\[[0-9;]*m//g' # Strip ANSI colors
    } >"${report_file}"

    log_success "Validation report generated: ${report_file}"
}

# Main validation function
validate_workspace() {
    local exit_code=0

    init_log
    log_info "Starting workspace validation..."

    # Run checks
    if ! check_duplicates; then
        exit_code=1
    fi

    if ! validate_primary_workspace; then
        exit_code=1
    fi

    compare_with_template

    # Create backup on successful validation
    if [[ ${exit_code} -eq 0 ]]; then
        create_backup
    fi

    # Generate report
    generate_report "${exit_code}"

    log_info "Workspace validation completed"
    return ${exit_code}
}

# Auto-fix function (use with caution)
auto_fix() {
    log_warning "Auto-fix functionality is experimental"

    # Remove duplicate files (with confirmation prompt if interactive)
    if [[ -t 0 ]]; then
        echo "This will remove duplicate workspace files. Continue? (y/N)"
        read -r response
        if [[ ${response} =~ ^[Yy]$ ]]; then
            find "${WORKSPACE_ROOT}" -name "*.code-workspace" -type f | grep -v "^${PRIMARY_WORKSPACE}$" | grep -v "/Archive/" | grep -v "/Workspace_Backup_" | xargs rm -f
            log_success "Duplicate workspace files removed"
        fi
    else
        log_info "Skipping auto-fix in non-interactive mode"
    fi
}

# Usage information
show_usage() {
    echo "Workspace Duplication Prevention Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  validate    - Validate workspace configuration (default)"
    echo "  check       - Quick check for duplicates only"
    echo "  backup      - Create workspace backup"
    echo "  auto-fix    - Attempt automatic fixes (experimental)"
    echo "  help        - Show this help"
    echo ""
    echo "Exit codes:"
    echo "  0 - Validation passed"
    echo "  1 - Validation failed"
}

# Main execution
main() {
    case "${1:-validate}" in
    "validate")
        if validate_workspace; then
            log_success "✅ Workspace validation PASSED"
            exit 0
        else
            log_error "❌ Workspace validation FAILED"
            exit 1
        fi
        ;;
    "check")
        if check_duplicates && validate_primary_workspace; then
            log_success "✅ Quick check PASSED"
            exit 0
        else
            log_error "❌ Quick check FAILED"
            exit 1
        fi
        ;;
    "backup")
        create_backup
        ;;
    "auto-fix")
        auto_fix
        ;;
    "help" | "-h" | "--help")
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
    esac
}

# Run main function
main "$@"
