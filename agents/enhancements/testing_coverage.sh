#!/bin/bash
# Testing Enhancement: Code Coverage Tracking
# Generates coverage reports and tracks trends

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
METRICS_DIR="${WORKSPACE_ROOT}/.metrics/coverage"

mkdir -p "${METRICS_DIR}"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [coverage] $*"
}

generate_coverage_report() {
  local project_path="$1"
  local project_name
  project_name=$(basename "${project_path}")
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local report_json="${METRICS_DIR}/coverage_${project_name}_${timestamp}.json"
  local report_html="${METRICS_DIR}/coverage_${project_name}_${timestamp}.html"
  
  log "Generating coverage report for ${project_name}"
  
  cd "${project_path}" || return 1
  
  # Find xcodeproj
  local xcodeproj
  xcodeproj=$(find . -maxdepth 1 -name "*.xcodeproj" | head -1)
  
  if [[ -z ${xcodeproj} ]]; then
    log "No Xcode project found, skipping coverage"
    return 1
  fi
  
  local scheme="${project_name}"
  
  # Run tests with coverage
  log "Running tests with coverage enabled..."
  xcodebuild test \
    -project "${xcodeproj}" \
    -scheme "${scheme}" \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    -enableCodeCoverage YES \
    -resultBundlePath "${METRICS_DIR}/result_${timestamp}.xcresult" \
    2>&1 | tee "${METRICS_DIR}/test_output_${timestamp}.log" || true
  
  # Extract coverage data
  if [[ -d "${METRICS_DIR}/result_${timestamp}.xcresult" ]]; then
    log "Extracting coverage data..."
    
    # Use xcrun to export coverage
    xcrun xccov view --report --json "${METRICS_DIR}/result_${timestamp}.xcresult" > "${report_json}" 2>/dev/null || true
    
    if [[ -s "${report_json}" ]]; then
      # Parse coverage percentage
      local line_coverage
      line_coverage=$(jq -r '.lineCoverage // 0' "${report_json}" 2>/dev/null | awk '{printf "%.1f", $1 * 100}')
      
      log "Code coverage: ${line_coverage}%"
      
      # Store in history
      track_coverage_trends "${project_name}" "${line_coverage}" "${report_json}"
      
      echo "${report_json}"
    else
      log "Failed to extract coverage data"
      return 1
    fi
  else
    log "No test results found"
    return 1
  fi
}

track_coverage_trends() {
  local project_name="$1"
  local coverage="$2"
  local report_file="$3"
  local history_file="${METRICS_DIR}/history.json"
  
  # Initialize history if needed
  if [[ ! -f ${history_file} ]]; then
    echo '{"projects":{}}' > "${history_file}"
  fi
  
  # Add entry to history
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  python3 -c "
import json
import sys

try:
    with open('${history_file}', 'r') as f:
        data = json.load(f)
    
    if 'projects' not in data:
        data['projects'] = {}
    
    if '${project_name}' not in data['projects']:
        data['projects']['${project_name}'] = []
    
    entry = {
        'timestamp': '${timestamp}',
        'coverage': float('${coverage}'),
        'report': '${report_file}'
    }
    
    data['projects']['${project_name}'].append(entry)
    
    # Keep last 30 entries
    if len(data['projects']['${project_name}']) > 30:
        data['projects']['${project_name}'] = data['projects']['${project_name}'][-30:]
    
    with open('${history_file}', 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f'Coverage trend updated for ${project_name}')
except Exception as e:
    print(f'Error updating coverage trend: {e}', file=sys.stderr)
    sys.exit(1)
"
  
  log "Coverage trend updated"
}

enforce_coverage_targets() {
  local project_name="$1"
  local coverage="$2"
  local minimum=70
  local target=85
  
  log "Checking coverage against targets (minimum: ${minimum}%, target: ${target}%)"
  
  if (( $(echo "${coverage} < ${minimum}" | bc -l) )); then
    log "❌ Coverage ${coverage}% is below minimum ${minimum}%"
    return 1
  elif (( $(echo "${coverage} < ${target}" | bc -l) )); then
    log "⚠️  Coverage ${coverage}% is below target ${target}%"
    return 0
  else
    log "✅ Coverage ${coverage}% meets or exceeds target ${target}%"
    return 0
  fi
}

# If called directly, run coverage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <project_path>"
    exit 1
  fi
  
  generate_coverage_report "$1"
fi
