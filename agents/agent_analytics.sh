#!/bin/bash
# Agent Analytics - Project metrics collection & analysis
# Tracks code complexity, build times, test coverage, and agent performance

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}"
AGENT_NAME="agent_analytics"
MCP_URL="${MCP_URL:-http://127.0.0.1:5005}"
LOG_FILE="${AGENTS_DIR}/${AGENT_NAME}.log"
STATUS_FILE="${AGENTS_DIR}/agent_status.json"
METRICS_DIR="${WORKSPACE_ROOT}/.metrics"
ANALYTICS_DATA="${METRICS_DIR}/analytics_$(date +%Y%m).json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] $*" >&2
}

error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ERROR: $*${NC}" >&2
}

success() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ✅ $*${NC}" >&2
}

warning() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ⚠️  $*${NC}" >&2
}

info() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ℹ️  $*${NC}" >&2
}

# Initialize metrics directory
mkdir -p "${METRICS_DIR}"
mkdir -p "${METRICS_DIR}/history"
mkdir -p "${METRICS_DIR}/reports"

# Update agent status

# Collect code metrics for a project
collect_code_metrics() {
  local project_path="$1"
  local project_name=$(basename "${project_path}")

  local swift_files=0
  local total_lines=0
  local code_lines=0
  local comment_lines=0
  local blank_lines=0

  # Count Swift files
  if [[ -d "${project_path}" ]]; then
    swift_files=$(find "${project_path}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

    # Analyze file content
    while IFS= read -r file; do
      [[ ! -f "$file" ]] && continue

      local lines=$(wc -l <"$file" 2>/dev/null | tr -d ' \n')
      total_lines=$((total_lines + lines))

      # Count comment and blank lines
      local comments=$(grep -c '^\s*//' "$file" 2>/dev/null | tr -d '\n' || echo 0)
      local blanks=$(grep -c '^\s*$' "$file" 2>/dev/null | tr -d '\n' || echo 0)

      comment_lines=$((comment_lines + comments))
      blank_lines=$((blank_lines + blanks))
    done < <(find "${project_path}" -name "*.swift" 2>/dev/null)

    code_lines=$((total_lines - comment_lines - blank_lines))
  fi

  # Return JSON
  cat <<EOF
{
  "project": "${project_name}",
  "swift_files": ${swift_files},
  "total_lines": ${total_lines},
  "code_lines": ${code_lines},
  "comment_lines": ${comment_lines},
  "blank_lines": ${blank_lines},
  "comment_ratio": $(awk "BEGIN {if (${code_lines} > 0) print ${comment_lines}/${code_lines}; else print 0}")
}
EOF
}

# Collect build metrics
collect_build_metrics() {

  local build_logs=()
  local avg_build_time=0
  local total_builds=0

  # Find recent build logs
  while IFS= read -r log; do
    build_logs+=("$log")
  done < <(find "${WORKSPACE_ROOT}" -name "*build*.log" -mtime -7 2>/dev/null | head -20)

  # Analyze build times (simplified - would need actual timing data)
  total_builds=${#build_logs[@]}

  cat <<EOF
{
  "total_builds_7d": ${total_builds},
  "avg_build_time_seconds": ${avg_build_time},
  "last_build": "$(date -Iseconds)"
}
EOF
}

# Collect test coverage metrics
collect_coverage_metrics() {
  local project_path="$1"
  local project_name=$(basename "${project_path}")

  # Look for coverage reports
  local coverage_file="${project_path}/.build/debug/codecov/*.json"
  local coverage_pct=0

  if compgen -G "${coverage_file}" >/dev/null 2>&1; then
    # Parse coverage from file (simplified)
    coverage_pct=$(grep -o '"coverage":[0-9.]*' "${coverage_file}" 2>/dev/null | head -1 | cut -d: -f2 || echo 0)
  fi

  cat <<EOF
{
  "project": "${project_name}",
  "coverage_percent": ${coverage_pct},
  "has_tests": $([ -d "${project_path}/Tests" ] && echo "true" || echo "false")
}
EOF
}

# Collect agent performance metrics
collect_agent_metrics() {

  local agent_count=0
  local active_agents=0
  local tasks_completed=0

  if [[ -f "${STATUS_FILE}" ]]; then
    agent_count=$(python3 -c "
import json
try:
    with open('${STATUS_FILE}', 'r') as f:
        data = json.load(f)
    print(len(data.get('agents', {})))
except:
    print(0)
" 2>/dev/null || echo 0)

    active_agents=$(python3 -c "
import json, time
try:
    with open('${STATUS_FILE}', 'r') as f:
        data = json.load(f)
    active = sum(1 for a in data.get('agents', {}).values()
                if a.get('status') in ['available', 'running', 'busy']
                and time.time() - a.get('last_seen', 0) < 300)
    print(active)
except:
    print(0)
" 2>/dev/null || echo 0)

    tasks_completed=$(python3 -c "
import json
try:
    with open('${STATUS_FILE}', 'r') as f:
        data = json.load(f)
    total = sum(a.get('tasks_completed', 0) for a in data.get('agents', {}).values())
    print(total)
except:
    print(0)
" 2>/dev/null || echo 0)
  fi

  cat <<EOF
{
  "total_agents": ${agent_count},
  "active_agents": ${active_agents},
  "tasks_completed_all_time": ${tasks_completed},
  "agent_availability": $(awk "BEGIN {if (${agent_count} > 0) print ${active_agents}/${agent_count}; else print 0}")
}
EOF
}

# Collect complexity metrics
collect_complexity_metrics() {
  local project_path="$1"
  local project_name=$(basename "${project_path}")

  # Use SwiftLint if available
  local complexity_violations=0
  local avg_file_complexity=0

  if command -v swiftlint &>/dev/null && [[ -d "${project_path}" ]]; then
    # Count complexity warnings
    complexity_violations=$(cd "${project_path}" && swiftlint lint --quiet 2>/dev/null | grep -c "Cyclomatic Complexity" | tr -d '\n' || echo 0)
  fi

  cat <<EOF
{
  "project": "${project_name}",
  "complexity_violations": ${complexity_violations},
  "avg_complexity": ${avg_file_complexity}
}
EOF
}

# Generate analytics report
generate_report() {
  info "Generating analytics report..."

  local timestamp=$(date +%s)
  local report_file="${METRICS_DIR}/reports/analytics_$(date +%Y%m%d_%H%M%S).json"

  # Collect all metrics
  local projects=("${WORKSPACE_ROOT}/Projects/"*)
  local code_metrics="[]"
  local coverage_metrics="[]"
  local complexity_metrics="[]"

  for project in "${projects[@]}"; do
    [[ ! -d "$project" ]] && continue

    local pname=$(basename "$project")
    [[ "$pname" == "Tools" || "$pname" == "scripts" || "$pname" == "Config" ]] && continue

    # Collect metrics
    local code_m=$(collect_code_metrics "$project")
    local cov_m=$(collect_coverage_metrics "$project")
    local comp_m=$(collect_complexity_metrics "$project")

    # Append to arrays (simplified - would use jq in production)
    code_metrics="${code_m}"
    coverage_metrics="${cov_m}"
    complexity_metrics="${comp_m}"
  done

  # Build full report
  cat >"${report_file}" <<EOF
{
  "timestamp": ${timestamp},
  "date": "$(date -Iseconds)",
  "workspace": "${WORKSPACE_ROOT}",
  "code_metrics": ${code_m},
  "build_metrics": $(collect_build_metrics),
  "coverage_metrics": ${cov_m},
  "complexity_metrics": ${comp_m},
  "agent_metrics": $(collect_agent_metrics)
}
EOF

  success "Report generated: ${report_file}"

  # Save to monthly analytics
  cp "${report_file}" "${ANALYTICS_DATA}"

  # Publish to MCP
  if command -v curl &>/dev/null; then
    curl -s -X POST "${MCP_URL}/metrics" \
      -H "Content-Type: application/json" \
      -d "@${report_file}" &>/dev/null || warning "Failed to publish metrics to MCP"
  fi

  echo "${report_file}"
}

# Generate dashboard-friendly summary
generate_dashboard_summary() {
  local report_file="$1"

  if [[ ! -f "${report_file}" ]]; then
    error "Report file not found: ${report_file}"
    return 1
  fi

  info "Generating dashboard summary..."

  # Extract key metrics for dashboard
  python3 <<PYTHON
import json
import sys

try:
    with open('${report_file}', 'r') as f:
        data = json.load(f)

    summary = {
        "timestamp": data.get("timestamp"),
        "date": data.get("date"),
        "overview": {
            "total_agents": data.get("agent_metrics", {}).get("total_agents", 0),
            "active_agents": data.get("agent_metrics", {}).get("active_agents", 0),
            "total_builds": data.get("build_metrics", {}).get("total_builds_7d", 0),
            "agent_health": "healthy" if data.get("agent_metrics", {}).get("agent_availability", 0) > 0.8 else "degraded"
        },
        "code_quality": {
            "swift_files": data.get("code_metrics", {}).get("swift_files", 0),
            "total_lines": data.get("code_metrics", {}).get("total_lines", 0),
            "comment_ratio": round(data.get("code_metrics", {}).get("comment_ratio", 0), 2),
            "complexity_violations": data.get("complexity_metrics", {}).get("complexity_violations", 0)
        },
        "testing": {
            "coverage_percent": data.get("coverage_metrics", {}).get("coverage_percent", 0),
            "has_tests": data.get("coverage_metrics", {}).get("has_tests", False)
        }
    }

    with open('${METRICS_DIR}/dashboard_summary.json', 'w') as f:
        json.dump(summary, f, indent=2)

    print(json.dumps(summary, indent=2))

except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    exit(1)
PYTHON

  success "Dashboard summary generated: ${METRICS_DIR}/dashboard_summary.json"
}

# Main agent loop
main() {
  log "Analytics Agent starting..."
  update_agent_status "agent_analytics.sh" "starting" $$ ""

  # Create PID file
  echo $$ >"${AGENTS_DIR}/${AGENT_NAME}.pid"

  # Register with MCP
  if command -v curl &>/dev/null; then
    curl -s -X POST "${MCP_URL}/register" \
      -H "Content-Type: application/json" \
      -d "{\"agent\": \"${AGENT_NAME}\", \"capabilities\": [\"analytics\", \"metrics\", \"reporting\"]}" \
      &>/dev/null || warning "Failed to register with MCP"
  fi

  update_agent_status "agent_analytics.sh" "available" $$ ""
  success "Analytics Agent ready"

  # Main loop - collect metrics every 5 minutes
  while true; do
    update_agent_status "agent_analytics.sh" "running" $$ ""

    # Generate full analytics report
    local report_file=$(generate_report)

    # Generate dashboard summary
    if [[ -f "${report_file}" ]]; then
      generate_dashboard_summary "${report_file}"
    fi

    # Archive old reports (keep last 30 days)
    find "${METRICS_DIR}/reports" -name "analytics_*.json" -mtime +30 -delete 2>/dev/null || true

    update_agent_status "agent_analytics.sh" "available" $$ ""
    success "Analytics cycle complete. Next run in 5 minutes."

    # Send heartbeat to MCP
    if command -v curl &>/dev/null; then
      curl -s -X POST "${MCP_URL}/heartbeat" \
        -H "Content-Type: application/json" \
        -d "{\"agent\": \"${AGENT_NAME}\", \"status\": \"available\"}" \
        &>/dev/null || true
    fi

    # Sleep for 5 minutes
    sleep 300
  done
}

# Trap signals for graceful shutdown
trap 'update_agent_status "agent_analytics.sh" "stopped" $$ ""; log "Analytics Agent stopping..."; exit 0' SIGTERM SIGINT

# Run main loop
main "$@"
