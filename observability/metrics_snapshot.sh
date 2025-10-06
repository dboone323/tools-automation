#!/bin/bash
# OA-06: Metrics Snapshot Script
# Collects daily metrics and stores them for trend analysis

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
readonly METRICS_DIR="${ROOT_DIR}/Tools/Automation/metrics"
readonly SNAPSHOTS_DIR="${METRICS_DIR}/snapshots"
readonly MCP_SERVER="${MCP_SERVER:-http://localhost:3000}"
readonly OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $*"
}

# Get current date for snapshot filename
get_snapshot_filename() {
    echo "${SNAPSHOTS_DIR}/$(date +%Y-%m-%d).json"
}

# Collect validation metrics
collect_validation_metrics() {
    log_info "Collecting validation metrics..."
    
    local total_validations=0
    local passed_validations=0
    local failed_validations=0
    
    # Count validation results from logs (last 24 hours)
    if [[ -d "${ROOT_DIR}/Tools/Automation" ]]; then
        total_validations=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log" -mtime -1 -exec grep -c "Validation" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        passed_validations=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log" -mtime -1 -exec grep -c "PASS" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        failed_validations=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log" -mtime -1 -exec grep -c "FAIL" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    fi
    
    local success_rate=0
    if [[ $total_validations -gt 0 ]]; then
        success_rate=$(awk "BEGIN {printf \"%.2f\", ($passed_validations / $total_validations) * 100}")
    fi
    
    cat <<EOF
  "validations": {
    "total": ${total_validations},
    "passed": ${passed_validations},
    "failed": ${failed_validations},
    "success_rate": ${success_rate}
  }
EOF
}

# Collect AI review metrics
collect_ai_review_metrics() {
    log_info "Collecting AI review metrics..."
    
    local total_reviews=0
    local approved_reviews=0
    local needs_changes=0
    local blocked_reviews=0
    
    # Count AI review results from logs (last 24 hours)
    if [[ -d "${ROOT_DIR}/Tools/Automation" ]]; then
        total_reviews=$(find "${ROOT_DIR}/Tools/Automation" -name "*ai_review*.log" -mtime -1 2>/dev/null | wc -l | tr -d ' ')
        approved_reviews=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log" -mtime -1 -exec grep -c "APPROVED" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        needs_changes=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log" -mtime -1 -exec grep -c "NEEDS_CHANGES" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        blocked_reviews=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log" -mtime -1 -exec grep -c "BLOCKED" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    fi
    
    cat <<EOF
  "ai_reviews": {
    "total": ${total_reviews},
    "approved": ${approved_reviews},
    "needs_changes": ${needs_changes},
    "blocked": ${blocked_reviews}
  }
EOF
}

# Collect MCP alert metrics
collect_mcp_metrics() {
    log_info "Collecting MCP alert metrics..."
    
    local critical_alerts=0
    local error_alerts=0
    local warning_alerts=0
    local info_alerts=0
    
    # Try to fetch from MCP server, fall back to log analysis
    if curl -sf "${MCP_SERVER}/alerts?since=24h" >/dev/null 2>&1; then
        local alerts
        alerts=$(curl -sf "${MCP_SERVER}/alerts?since=24h" 2>/dev/null || echo '[]')
        critical_alerts=$(echo "$alerts" | jq '[.[] | select(.level == "critical")] | length' 2>/dev/null || echo 0)
        error_alerts=$(echo "$alerts" | jq '[.[] | select(.level == "error")] | length' 2>/dev/null || echo 0)
        warning_alerts=$(echo "$alerts" | jq '[.[] | select(.level == "warning")] | length' 2>/dev/null || echo 0)
        info_alerts=$(echo "$alerts" | jq '[.[] | select(.level == "info")] | length' 2>/dev/null || echo 0)
    else
        log_warning "MCP server unavailable, using log-based counting"
        critical_alerts=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log" -mtime -1 -exec grep -c "\"level\": \"critical\"" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        error_alerts=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log" -mtime -1 -exec grep -c "\"level\": \"error\"" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        warning_alerts=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log" -mtime -1 -exec grep -c "\"level\": \"warning\"" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        info_alerts=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log" -mtime -1 -exec grep -c "\"level\": \"info\"" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    fi
    
    cat <<EOF
  "mcp_alerts": {
    "critical": ${critical_alerts},
    "error": ${error_alerts},
    "warning": ${warning_alerts},
    "info": ${info_alerts}
  }
EOF
}

# Collect Ollama usage metrics
collect_ollama_metrics() {
    log_info "Collecting Ollama metrics..."
    
    local ollama_available="false"
    local model_count=0
    
    if curl -sf "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
        ollama_available="true"
        model_count=$(curl -sf "${OLLAMA_URL}/api/tags" 2>/dev/null | jq '.models | length' 2>/dev/null || echo 0)
    fi
    
    cat <<EOF
  "ollama": {
    "available": ${ollama_available},
    "models_installed": ${model_count}
  }
EOF
}

# Collect disk usage metrics
collect_disk_metrics() {
    log_info "Collecting disk usage metrics..."
    
    local total_gb
    local used_gb
    local available_gb
    local usage_percent
    
    local df_output
    df_output=$(df -h "${ROOT_DIR}" | awk 'NR==2 {print $2,$3,$4,$5}')
    total_gb=$(echo "$df_output" | awk '{print $1}' | sed 's/Gi\?//')
    used_gb=$(echo "$df_output" | awk '{print $2}' | sed 's/Gi\?//')
    available_gb=$(echo "$df_output" | awk '{print $3}' | sed 's/Gi\?//')
    usage_percent=$(echo "$df_output" | awk '{print $4}' | sed 's/%//')
    
    # Count log files and calculate total log size
    local log_count
    local log_size_mb
    log_count=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log*" 2>/dev/null | wc -l | tr -d ' ')
    
    # Use du for efficient size calculation (works on both macOS and Linux)
    if [[ $(uname -s) == "Darwin" ]]; then
        # macOS: du -k outputs KB, sum with awk, convert to MB
        log_size_mb=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log*" -print0 2>/dev/null | xargs -0 du -k 2>/dev/null | awk '{sum+=$1} END {printf "%.2f", sum/1024}')
    else
        # Linux: du -b outputs bytes, sum with awk, convert to MB
        log_size_mb=$(find "${ROOT_DIR}/Tools/Automation" -name "*.log*" -print0 2>/dev/null | xargs -0 du -b 2>/dev/null | awk '{sum+=$1} END {printf "%.2f", sum/1024/1024}')
    fi
    
    cat <<EOF
  "disk_usage": {
    "total_gb": "${total_gb}",
    "used_gb": "${used_gb}",
    "available_gb": "${available_gb}",
    "usage_percent": ${usage_percent},
    "log_files_count": ${log_count},
    "log_files_size_mb": ${log_size_mb}
  }
EOF
}

# Collect repository metrics
collect_repo_metrics() {
    log_info "Collecting repository metrics..."
    
    local branch_count=0
    local stale_branches=0
    local open_prs=0
    
    # Count branches
    if git rev-parse --git-dir >/dev/null 2>&1; then
        branch_count=$(git branch -a | wc -l | tr -d ' ')
        # Count branches with no commits in last 30 days
        stale_branches=$(git for-each-ref --format='%(refname:short) %(committerdate:relative)' refs/heads/ | grep -c 'months\|years' || echo 0)
    fi
    
    cat <<EOF
  "repository": {
    "total_branches": ${branch_count},
    "stale_branches": ${stale_branches},
    "open_prs_estimate": ${open_prs}
  }
EOF
}

# Generate snapshot
generate_snapshot() {
    local snapshot_file
    snapshot_file=$(get_snapshot_filename)
    
    log_info "Generating metrics snapshot: ${snapshot_file}"
    
    # Create snapshots directory if it doesn't exist
    mkdir -p "$SNAPSHOTS_DIR"
    
    # Build JSON snapshot
    cat > "$snapshot_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "date": "$(date +%Y-%m-%d)",
$(collect_validation_metrics),
$(collect_ai_review_metrics),
$(collect_mcp_metrics),
$(collect_ollama_metrics),
$(collect_disk_metrics),
$(collect_repo_metrics)
}
EOF
    
    log_info "Snapshot saved: ${snapshot_file}"
    
    # Pretty print summary
    echo ""
    log_info "================================================"
    log_info "Metrics Snapshot Summary:"
    log_info "================================================"
    jq -C . "$snapshot_file" 2>/dev/null || cat "$snapshot_file"
    log_info "================================================"
}

# Publish snapshot to MCP
publish_snapshot_to_mcp() {
    local snapshot_file
    snapshot_file=$(get_snapshot_filename)
    
    if [[ ! -f "$snapshot_file" ]]; then
        log_warning "Snapshot file not found: ${snapshot_file}"
        return 1
    fi
    
    log_info "Publishing snapshot to MCP..."
    
    local payload
    payload=$(cat <<EOF
{
  "source": "metrics_snapshot",
  "level": "info",
  "message": "Daily metrics snapshot collected",
  "details": $(cat "$snapshot_file"),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
    
    if curl -sf -X POST "${MCP_SERVER}/alerts" \
        -H "Content-Type: application/json" \
        -d "$payload" >/dev/null 2>&1; then
        log_info "Published snapshot to MCP"
    else
        log_warning "Failed to publish to MCP (server may be offline)"
    fi
}

# Main function
main() {
    log_info "Starting metrics snapshot collection..."
    log_info "Time: $(date)"
    echo ""
    
    # Generate snapshot
    generate_snapshot
    
    # Publish to MCP
    echo ""
    publish_snapshot_to_mcp
    
    log_info "Metrics collection complete!"
}

# Run main function
main "$@"
