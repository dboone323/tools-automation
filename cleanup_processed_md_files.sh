#!/bin/bash
# Tools/Automation/cleanup_processed_md_files.sh
# Automatically delete processed MD files after fixes have been applied
# Implements retention policy for MD-generated reports and insights

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_FILE="${WORKSPACE_DIR}/Tools/Automation/md_cleanup.log"
PROCESSED_MD_LOG="${WORKSPACE_DIR}/Tools/Automation/processed_md_files.log"
RETENTION_DAYS="${MD_RETENTION_DAYS:-7}" # Default 7 days retention

# Background mode configuration
BACKGROUND_MODE="${BACKGROUND_MODE:-false}"
CLEANUP_INTERVAL="${CLEANUP_INTERVAL:-3600}" # Default 1 hour
MAX_RESTARTS="${MAX_RESTARTS:-5}"
RESTART_COUNT=0

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

mkdir -p "$(dirname "${LOG_FILE}")"
mkdir -p "$(dirname "${PROCESSED_MD_LOG}")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE}"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_status() { echo -e "${BLUE}🔄 $1${NC}"; }

# Track processed MD files
track_processed_md() {
    local md_file="$1"
    local timestamp
    timestamp="$(date +%s)"
    echo "${timestamp}:${md_file}" >>"${PROCESSED_MD_LOG}"
    log "Tracked processed MD file: ${md_file}"
}

# Check if MD file has been processed and is eligible for deletion
is_eligible_for_deletion() {
    local md_file="$1"
    local file_timestamp
    local current_timestamp
    local age_days

    # Check if processed log file exists
    if [[ ! -f "${PROCESSED_MD_LOG}" ]]; then
        return 1 # No log file, can't determine eligibility
    fi

    # Check if file exists in processed log
    if ! grep -q ":${md_file}$" "${PROCESSED_MD_LOG}"; then
        return 1 # Not processed yet
    fi

    # Get timestamp when file was processed
    file_timestamp=$(grep ":${md_file}$" "${PROCESSED_MD_LOG}" | head -1 | cut -d: -f1)
    current_timestamp=$(date +%s)
    age_days=$(((current_timestamp - file_timestamp) / 86400))

    # Check if file is older than retention period
    if [[ ${age_days} -ge ${RETENTION_DAYS} ]]; then
        return 0 # Eligible for deletion
    else
        return 1 # Too new, keep it
    fi
}

# Clean up old MD files that have been processed
cleanup_old_md_files() {
    log "Starting MD file cleanup (retention: ${RETENTION_DAYS} days)"

    local files_cleaned=0
    local total_processed=0

    # Find all MD files in workspace
    find "${WORKSPACE_DIR}" \
        \( \
        -path "*/.git" -o \
        -path "*/.build" -o \
        -path "*/DerivedData" -o \
        -path "*/Archive" -o \
        -path "*/.autofix_backups" -o \
        -path "*/node_modules" -o \
        -path "*/.venv" \
        \) -prune -o \
        -name "*.md" \
        -type f \
        -print0 | while IFS= read -r -d '' md_file; do

        ((total_processed++)) || true

        # Check if this file should be deleted
        if is_eligible_for_deletion "${md_file}"; then
            print_status "Deleting processed MD file: ${md_file}"
            rm -f "${md_file}"
            ((files_cleaned++)) || true
            log "Deleted: ${md_file}"
        fi
    done

    # Clean up the processed log file (remove entries for deleted files)
    if [[ -f "${PROCESSED_MD_LOG}" ]]; then
        local temp_log="${PROCESSED_MD_LOG}.tmp"
        while IFS=: read -r timestamp file_path; do
            if [[ -f "${WORKSPACE_DIR}/${file_path}" ]]; then
                echo "${timestamp}:${file_path}" >>"${temp_log}"
            fi
        done <"${PROCESSED_MD_LOG}"
        mv "${temp_log}" "${PROCESSED_MD_LOG}"
    fi

    print_success "MD cleanup completed: ${files_cleaned} files deleted, ${total_processed} files processed"
    log "Cleanup summary: ${files_cleaned} files deleted, ${total_processed} files processed"
}

# Mark specific MD files as processed (for immediate cleanup tracking)
mark_files_processed() {
    local pattern="$1"
    local files_found=0

    log "Marking MD files matching pattern: ${pattern}"

    find "${WORKSPACE_DIR}" \
        \( \
        -path "*/.git" -o \
        -path "*/.build" -o \
        -path "*/DerivedData" -o \
        -path "*/Archive" -o \
        -path "*/.autofix_backups" -o \
        -path "*/node_modules" -o \
        -path "*/.venv" \
        \) -prune -o \
        -name "${pattern}" \
        -type f \
        -print0 | while IFS= read -r -d '' md_file; do

        track_processed_md "${md_file}"
        ((files_found++)) || true
    done

    print_success "Marked ${files_found} MD files as processed"
}

# Clean up specific file types immediately
cleanup_specific_types() {
    log "Cleaning up specific MD file types"

    # Clean up old AI insights files (keep only recent ones)
    local ai_insights_pattern="WORKSPACE_AI_INSIGHTS_*.md"
    local max_ai_insights=3

    local ai_files
    ai_files=$(find "${WORKSPACE_DIR}" -name "${ai_insights_pattern}" -type f -print0 | xargs -0 ls -t | tail -n +$((max_ai_insights + 1)))
    if [[ -n "${ai_files}" ]]; then
        echo "${ai_files}" | while read -r file; do
            if [[ -f "${file}" ]]; then
                print_status "Deleting old AI insights: ${file}"
                rm -f "${file}"
                log "Deleted old AI insights: ${file}"
            fi
        done
    fi

    # Clean up old orchestrator status files
    local orchestrator_pattern="orchestrator_status_*.md"
    local max_orchestrator=5

    local orchestrator_files
    orchestrator_files=$(find "${WORKSPACE_DIR}" -name "${orchestrator_pattern}" -type f -print0 | xargs -0 ls -t | tail -n +$((max_orchestrator + 1)))
    if [[ -n "${orchestrator_files}" ]]; then
        echo "${orchestrator_files}" | while read -r file; do
            if [[ -f "${file}" ]]; then
                print_status "Deleting old orchestrator status: ${file}"
                rm -f "${file}"
                log "Deleted old orchestrator status: ${file}"
            fi
        done
    fi

    # Clean up old performance reports
    local perf_pattern="PERFORMANCE_REPORT_*.md"
    local max_perf=5

    local perf_files
    perf_files=$(find "${WORKSPACE_DIR}" -name "${perf_pattern}" -type f -print0 | xargs -0 ls -t | tail -n +$((max_perf + 1)))
    if [[ -n "${perf_files}" ]]; then
        echo "${perf_files}" | while read -r file; do
            if [[ -f "${file}" ]]; then
                print_status "Deleting old performance report: ${file}"
                rm -f "${file}"
                log "Deleted old performance report: ${file}"
            fi
        done
    fi
}

# Show cleanup status
show_status() {
    print_status "MD File Cleanup Status"
    echo "Retention period: ${RETENTION_DAYS} days"
    echo ""

    if [[ -f "${PROCESSED_MD_LOG}" ]]; then
        local total_tracked
        total_tracked=$(wc -l <"${PROCESSED_MD_LOG}")
        echo "Total MD files tracked: ${total_tracked}"

        local eligible_for_deletion=0
        while IFS=: read -r timestamp file_path; do
            if [[ -f "${WORKSPACE_DIR}/${file_path}" ]] && is_eligible_for_deletion "${WORKSPACE_DIR}/${file_path}"; then
                ((eligible_for_deletion++)) || true
            fi
        done <"${PROCESSED_MD_LOG}"

        echo "Files eligible for deletion: ${eligible_for_deletion}"
    else
        echo "No processed MD files tracked yet"
    fi

    echo ""
    print_status "Recent MD files by type:"

    # Count different types of MD files
    local ai_insights
    ai_insights=$(find "${WORKSPACE_DIR}" -name "WORKSPACE_AI_INSIGHTS_*.md" -type f | wc -l)
    echo "AI Insights files: ${ai_insights}"

    local orchestrator_files
    orchestrator_files=$(find "${WORKSPACE_DIR}" -name "orchestrator_status_*.md" -type f | wc -l)
    echo "Orchestrator status files: ${orchestrator_files}"

    local perf_reports
    perf_reports=$(find "${WORKSPACE_DIR}" -name "PERFORMANCE_REPORT_*.md" -type f | wc -l)
    echo "Performance reports: ${perf_reports}"

    local total_md
    total_md=$(find "${WORKSPACE_DIR}" -name "*.md" -type f | wc -l)
    echo "Total MD files: ${total_md}"
}

# Main execution
run_background() {
    log "Starting MD cleanup agent in background mode (interval: ${CLEANUP_INTERVAL}s)"

    while true; do
        if [[ ${RESTART_COUNT} -ge ${MAX_RESTARTS} ]]; then
            print_error "Maximum restart attempts (${MAX_RESTARTS}) reached. Exiting."
            log "Background agent stopped due to maximum restart attempts"
            exit 1
        fi

        # Run cleanup operations
        if cleanup_old_md_files && cleanup_specific_types; then
            log "Background cleanup cycle completed successfully"
            RESTART_COUNT=0 # Reset on success
        else
            ((RESTART_COUNT++)) || true
            print_warning "Cleanup cycle failed (attempt ${RESTART_COUNT}/${MAX_RESTARTS})"
            log "Cleanup cycle failed, restart count: ${RESTART_COUNT}"
        fi

        # Wait for next cycle
        sleep "${CLEANUP_INTERVAL}"
    done
}

main() {
    # Handle background mode
    if [[ "${BACKGROUND_MODE}" == "true" ]]; then
        run_background
        return
    fi

    case "${1:-cleanup}" in
    "cleanup")
        cleanup_old_md_files
        cleanup_specific_types
        ;;
    "mark-processed")
        if [[ -n "${2-}" ]]; then
            mark_files_processed "$2"
        else
            print_error "Usage: $0 mark-processed <pattern>"
            exit 1
        fi
        ;;
    "status")
        show_status
        ;;
    "help" | "-h" | "--help")
        cat <<EOF
MD File Cleanup Manager

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  cleanup              # Run full cleanup of old processed MD files
  mark-processed <pattern>  # Mark files matching pattern as processed
  status               # Show cleanup status and statistics
  help                 # Show this help message

Examples:
  $0 cleanup
  $0 mark-processed "WORKSPACE_AI_INSIGHTS_*.md"
  $0 status

Configuration:
  MD_RETENTION_DAYS    # Days to keep processed MD files (default: 7)
  PROCESSED_MD_LOG     # Path to processed files log (default: processed_md_files.log)
  BACKGROUND_MODE      # Run in background mode (default: false)
  CLEANUP_INTERVAL     # Background cleanup interval in seconds (default: 3600)
  MAX_RESTARTS         # Maximum restart attempts on failure (default: 5)

EOF
        ;;
    *)
        print_error "Unknown command: ${1-}"
        main help
        exit 1
        ;;
    esac
}

# Execute main function
main "$@"
