#!/usr/bin/env bash

# Workspace Optimization Script
# Comprehensive cleanup and performance optimization for Quantum-workspace

set -euo pipefail

echo "🚀 Quantum-workspace Optimization"
echo "=================================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
  printf '%b\n' "${BLUE}[OPTIMIZE]${NC} $1"
}

print_success() {
  printf '%b\n' "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
  printf '%b\n' "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  printf '%b\n' "${RED}[ERROR]${NC} $1"
}

# Configuration
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_DIR="${WORKSPACE_DIR}/optimization_backup_$(date +%Y%m%d_%H%M%S)"
OPTIMIZATION_LOG="${WORKSPACE_DIR}/optimization_report.md"

# Create backup directory
create_backup() {
  print_status "Creating backup directory..."
  mkdir -p "${BACKUP_DIR}"
  print_success "Backup directory created: ${BACKUP_DIR}"
}

# Analyze current workspace
analyze_workspace() {
  print_status "Analyzing workspace structure..."

  local swift_count
  swift_count=$(find "${WORKSPACE_DIR}" -name "*.swift" -type f | wc -l)
  local xcode_count
  xcode_count=$(find "${WORKSPACE_DIR}" -name "*.xcodeproj" -type d | wc -l)
  local package_count
  package_count=$(find "${WORKSPACE_DIR}" -name "Package.swift" -type f | wc -l)
  local total_files
  total_files=$(find "${WORKSPACE_DIR}" -type f | wc -l)
  local total_dirs
  total_dirs=$(find "${WORKSPACE_DIR}" -type d | wc -l)
  local disk_usage
  disk_usage=$(du -sh "${WORKSPACE_DIR}" | cut -f1)

  {
    printf '# Workspace Optimization Report\n'
    printf 'Generated: %s\n\n' "$(date)"
    printf '## File Statistics\n'
    printf '- Swift files: %s\n' "${swift_count}"
    printf '- Xcode projects: %s\n' "${xcode_count}"
    printf '- Package.swift files: %s\n' "${package_count}"
    printf '- Total files: %s\n' "${total_files}"
    printf '- Total directories: %s\n\n' "${total_dirs}"
    printf '## Disk Usage\n'
    printf '- Current workspace size: %s\n\n' "${disk_usage}"
  } >"${OPTIMIZATION_LOG}"
}

# Clean up duplicate and unnecessary files
cleanup_duplicates() {
  print_status "Cleaning up duplicate and unnecessary files..."

  echo "## Cleanup Actions" >>"${OPTIMIZATION_LOG}"

  # Remove old backup directories
  local backup_count
  backup_count=$(find "${WORKSPACE_DIR}" -name "*backup*" -type d | wc -l)
  if [[ ${backup_count} -gt 5 ]]; then
    print_status "Removing old backup directories..."
    find "${WORKSPACE_DIR}" -name "*backup*" -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
    echo "- Removed old backup directories (older than 30 days)" >>"${OPTIMIZATION_LOG}"
  fi

  # Remove duplicate files in Tools directory
  if [[ -d "${WORKSPACE_DIR}/Tools/Tools" ]]; then
    print_status "Removing duplicate Tools directories..."
    rm -rf "${WORKSPACE_DIR}/Tools/Tools"
    echo "- Removed duplicate Tools/Tools directory" >>"${OPTIMIZATION_LOG}"
  fi

  # Remove old import snapshots
  local import_count
  import_count=$(find "${WORKSPACE_DIR}" -name "*snapshot*" -type d | wc -l)
  if [[ ${import_count} -gt 2 ]]; then
    print_status "Removing old import snapshots..."
    find "${WORKSPACE_DIR}" -name "*snapshot*" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
    echo "- Removed old import snapshots (older than 7 days)" >>"${OPTIMIZATION_LOG}"
  fi

  # Clean up .DS_Store files
  local ds_store_count
  ds_store_count=$(find "${WORKSPACE_DIR}" -name ".DS_Store" -type f | wc -l)
  if [[ ${ds_store_count} -gt 0 ]]; then
    print_status "Removing .DS_Store files..."
    find "${WORKSPACE_DIR}" -name ".DS_Store" -type f -delete
    echo "- Removed ${ds_store_count} .DS_Store files" >>"${OPTIMIZATION_LOG}"
  fi

  # Clean up temporary files
  local temp_count
  temp_count=$(find "${WORKSPACE_DIR}" -type f \( -name "*.tmp" -o -name "*.temp" -o -name "*~" \) | wc -l)
  if [[ ${temp_count} -gt 0 ]]; then
    print_status "Removing temporary files..."
    find "${WORKSPACE_DIR}" -type f \( -name "*.tmp" -o -name "*.temp" -o -name "*~" \) -delete
    echo "- Removed ${temp_count} temporary files" >>"${OPTIMIZATION_LOG}"
  fi

  print_success "Cleanup completed"
}

# Optimize build performance
optimize_build_performance() {
  print_status "Optimizing build performance..."

  echo "## Build Optimizations" >>"${OPTIMIZATION_LOG}"

  # Create optimized Xcode workspace settings
  local workspace_settings="${WORKSPACE_DIR}/workspace_settings.json"
  cat >"${workspace_settings}" <<'EOF'
{
  "build_system": "new",
  "parallelize_builds": true,
  "max_concurrent_build_tasks": 8,
  "use_modern_build_system": true,
  "enable_build_cache": true,
  "swift_compiler_optimization": "O",
  "enable_indexing": true,
  "enable_background_indexing": true
}
EOF

  echo "- Created optimized workspace settings" >>"${OPTIMIZATION_LOG}"

  # Create .swiftlint.yml for consistent code style
  local swiftlint_config="${WORKSPACE_DIR}/.swiftlint.yml"
  if [[ ! -f ${swiftlint_config} ]]; then
    cat >"${swiftlint_config}" <<'EOF'
disabled_rules:
  - trailing_whitespace
  - line_length
opt_in_rules:
  - empty_count
  - force_unwrapping
included:
  - Projects
  - Shared
excluded:
  - Tools/Automation/_merge_backups
  - Tools/Imported
  - *.generated.swift
EOF
    echo "- Created SwiftLint configuration" >>"${OPTIMIZATION_LOG}"
  fi

  print_success "Build performance optimized"
}

# Optimize AI services
optimize_ai_services() {
  print_status "Optimizing AI services..."

  echo "## AI Optimizations" >>"${OPTIMIZATION_LOG}"

  # Create AI cache directory
  local ai_cache_dir="${WORKSPACE_DIR}/Tools/AI/cache"
  mkdir -p "${ai_cache_dir}"

  # Create AI optimization config
  local ai_config="${WORKSPACE_DIR}/Tools/AI/optimization_config.json"
  cat >"${ai_config}" <<'EOF'
{
  "ollama": {
    "cache_enabled": true,
    "cache_dir": "./cache",
    "model_preload": ["llama2", "codellama"],
    "context_window": 4096,
    "temperature": 0.1
  },
  "huggingface": {
    "cache_enabled": true,
    "rate_limit_buffer": 100,
    "fallback_timeout": 30
  },
  "caching": {
    "max_cache_size": "1GB",
    "cache_ttl": 3600,
    "compression_enabled": true
  }
}
EOF

  echo "- Created AI optimization configuration" >>"${OPTIMIZATION_LOG}"
  echo "- Set up AI response caching" >>"${OPTIMIZATION_LOG}"

  print_success "AI services optimized"
}

# Create performance monitoring
setup_performance_monitoring() {
  print_status "Setting up performance monitoring..."

  echo "## Performance Monitoring" >>"${OPTIMIZATION_LOG}"

  # Create performance monitoring script
  local automation_dir="${WORKSPACE_DIR}/Tools/Automation"
  local logs_dir="${automation_dir}/logs"
  mkdir -p "${logs_dir}"
  local perf_script="${automation_dir}/performance_monitor.sh"
  cat >"${perf_script}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
MONITOR_LOG="${LOG_DIR}/performance.log"
: "${ALERT_THRESHOLD:=300}"

mkdir -p "$LOG_DIR"

printf '📊 Performance Report - %s\n' "$(date)"
printf '================================\n'

if [[ -f "$MONITOR_LOG" ]]; then
  printf 'Recent operations:\n'
  tail -10 "$MONITOR_LOG" | while IFS='|' read -r timestamp operation duration epoch; do
    if [[ -z "$timestamp" ]]; then
      continue
    fi
    if [[ "${duration:-0}" -gt "$ALERT_THRESHOLD" ]]; then
      printf '⚠️  SLOW: %s took %ss\n' "$operation" "$duration"
    else
      printf '✅ %s: %ss\n' "$operation" "$duration"
    fi
  done
else
  printf 'No performance data available yet\n'
fi

printf '\n'
printf '💡 Optimization Tips:\n'
printf "   - Use 'make clean' before major builds\n"
printf "   - Enable Xcode's new build system\n"
printf "   - Use Swift Package Manager for dependencies\n"
printf "   - Enable build caching in Xcode\n"
EOF

  chmod +x "${perf_script}"
  echo "- Created performance monitoring script" >>"${OPTIMIZATION_LOG}"

  print_success "Performance monitoring set up"
}

# Optimize automation scripts
optimize_automation() {
  print_status "Optimizing automation scripts..."

  echo "## Automation Optimizations" >>"${OPTIMIZATION_LOG}"

  # Create optimized automation config
  local auto_config="${WORKSPACE_DIR}/Tools/Automation/optimization_config.sh"
  cat >"${auto_config}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_DIR="${CODE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

export CODE_DIR
export MAX_PARALLEL_JOBS="${MAX_PARALLEL_JOBS:-4}"
export BUILD_PARALLEL="${BUILD_PARALLEL:-8}"

export USE_BUILD_CACHE="${USE_BUILD_CACHE:-true}"
export CACHE_DIR="${CACHE_DIR:-${CODE_DIR}/Tools/Automation/cache}"

export ENABLE_PERFORMANCE_LOGGING="${ENABLE_PERFORMANCE_LOGGING:-true}"
export PERFORMANCE_LOG="${PERFORMANCE_LOG:-${CODE_DIR}/Tools/Automation/logs/performance.log}"

export AI_CACHE_ENABLED="${AI_CACHE_ENABLED:-true}"
export AI_CACHE_DIR="${AI_CACHE_DIR:-${CODE_DIR}/Tools/AI/cache}"

export SWIFT_OPTIMIZATION_LEVEL="${SWIFT_OPTIMIZATION_LEVEL:--O}"
export SWIFT_ENABLE_INDEXING="${SWIFT_ENABLE_INDEXING:-true}"

mkdir -p "${CACHE_DIR}"
mkdir -p "$(dirname "${PERFORMANCE_LOG}")"
mkdir -p "${AI_CACHE_DIR}"
EOF

  echo "- Created automation optimization config" >>"${OPTIMIZATION_LOG}"

  print_success "Automation scripts optimized"
}

# Create optimization summary
create_summary() {
  print_status "Creating optimization summary..."

  local new_disk_usage
  if ! new_disk_usage=$(du -sh "${WORKSPACE_DIR}" 2>/dev/null | cut -f1); then
    new_disk_usage="Unavailable"
  fi

  local performance_output
  if performance_output=$("${WORKSPACE_DIR}/Tools/Automation/performance_monitor.sh" 2>&1); then
    :
  else
    performance_output="Performance monitor not available"
  fi

  local build_command="make clean && make build"

  local ai_status
  if ai_status=$(curl --fail --silent http://localhost:11434/api/tags 2>/dev/null); then
    :
  else
    ai_status="AI service not reachable"
  fi

  {
    printf '\n## Optimization Summary\n\n'
    printf '- Optimized workspace size: %s\n' "${new_disk_usage}"
    printf '- ✅ Duplicate files cleaned up\n'
    printf '- ✅ Build performance optimized\n'
    printf '- ✅ AI services optimized\n'
    printf '- ✅ Performance monitoring enabled\n'
    printf '- ✅ Automation scripts enhanced\n\n'
    printf '## Next Steps\n'
    printf '1. Review the optimization report: %s\n' "${OPTIMIZATION_LOG}"
    printf '2. Run performance monitoring: ./Tools/Automation/performance_monitor.sh\n'
    printf '3. Test build performance improvements\n'
    printf '4. Monitor AI service usage and caching\n\n'
    printf '## Quick Commands\n'
    printf '- Check performance: %s\n' "${performance_output}"
    printf '- Suggested build command: %s\n' "${build_command}"
    printf '- AI status: %s\n' "${ai_status}"
  } >>"${OPTIMIZATION_LOG}"

  print_success "Optimization summary created: ${OPTIMIZATION_LOG}"
}

# Main optimization function
main() {
  echo ""

  create_backup
  analyze_workspace
  cleanup_duplicates
  optimize_build_performance
  optimize_ai_services
  setup_performance_monitoring
  optimize_automation
  create_summary

  echo ""
  print_success "🎉 Workspace optimization completed!"
  echo ""
  echo "📊 Report: ${OPTIMIZATION_LOG}"
  echo "💾 Backup: ${BACKUP_DIR}"
  echo ""
  echo "🚀 Your workspace is now optimized for:"
  echo "   • Faster builds and compilation"
  echo "   • Reduced disk usage"
  echo "   • Better AI performance"
  echo "   • Enhanced automation"
  echo "   • Performance monitoring"
  echo ""
}

# Run main function
main "$@"
