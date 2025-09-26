#!/bin/bash

# Unified AI Enhancement System for Quantum-workspace
# Consolidates analysis, reporting, and safe auto-application of enhancements

set -euo pipefail

# Workspace directories
WORKSPACE_ROOT="/Users/danielstevens/Desktop/Quantum-workspace"
PROJECTS_DIR="${WORKSPACE_ROOT}/Projects"
TOOLS_DIR="${WORKSPACE_ROOT}/Tools"
DOCS_DIR="${WORKSPACE_ROOT}/Documentation"
ENHANCEMENT_DIR="${DOCS_DIR}/Enhancements"

# Colors for consistent output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
AUTO_ENHANCE_LOG="${WORKSPACE_ROOT}/.ai_enhancements.log"
QUANTUM_MODE="${QUANTUM_MODE:-true}"

# Output functions
print_header() {
  echo -e "${PURPLE}[AI-ENHANCE]${NC} ${CYAN}$1${NC}"
}

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_status() {
  echo -e "${BLUE}🔄 $1${NC}"
}

print_enhancement() {
  echo -e "${GREEN}🚀 ENHANCEMENT:${NC} $1"
}

print_suggestion() {
  echo -e "${BLUE}💡 SUGGESTION:${NC} $1"
}

print_auto_applied() {
  echo -e "${GREEN}🤖 AUTO-APPLIED:${NC} $1"
}

# Create enhancement directory
create_enhancement_dir() {
  mkdir -p "$ENHANCEMENT_DIR"
}

# Helper function to safely count pattern matches
count_pattern() {
  local pattern="$1"
  local result
  result=$(find . -name "*.swift" -exec grep -l "$pattern" {} \; 2>/dev/null | wc -l | tr -d '[:space:]' || echo "0")
  echo "${result:-0}"
}

# Helper function to count lines matching pattern
count_lines() {
  local pattern="$1"
  local result
  result=$(find . -name "*.swift" -exec grep "$pattern" {} \; 2>/dev/null | wc -l | tr -d '[:space:]' || echo "0")
  echo "${result:-0}"
}

# Risk levels for enhancements
get_risk_level() {
  case "$1" in
  "SAFE") echo "Auto-apply with rollback safety" ;;
  "LOW") echo "Recommend with auto-apply option" ;;
  "MEDIUM") echo "Recommend for manual review" ;;
  "HIGH") echo "Recommend for careful consideration" ;;
  *) echo "Unknown risk level" ;;
  esac
}

# Enhancement categories
get_category_description() {
  case "$1" in
  "PERFORMANCE") echo "Code optimization and performance improvements" ;;
  "ARCHITECTURE") echo "Code structure and architectural improvements" ;;
  "UI_UX") echo "User interface and experience enhancements" ;;
  "FUNCTIONALITY") echo "New features and functionality additions" ;;
  "SECURITY") echo "Security improvements and best practices" ;;
  "ACCESSIBILITY") echo "Accessibility compliance and improvements" ;;
  "TESTING") echo "Test coverage and quality improvements" ;;
  "DOCUMENTATION") echo "Code documentation and comments" ;;
  "DEPENDENCIES") echo "Dependency management and updates" ;;
  "BUILD_SYSTEM") echo "Build configuration and optimization" ;;
  *) echo "General improvements" ;;
  esac
}

# Analyze Swift project for enhancements
analyze_project() {
  local project_name="$1"
  local project_path="${PROJECTS_DIR}/${project_name}"

  if [[ ! -d "$project_path" ]]; then
    print_error "Project $project_name not found"
    return 1
  fi

  print_header "Analyzing $project_name for AI enhancements..."

  cd "$project_path"

  local enhancement_file="${ENHANCEMENT_DIR}/${project_name}_enhancement_analysis.md"
  local auto_apply_script="${ENHANCEMENT_DIR}/${project_name}_safe_enhancements.sh"

  # Count basic metrics
  local swift_files
  swift_files=$(find . -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
  local total_lines
  total_lines=$(find . -name "*.swift" -exec wc -l {} \; 2>/dev/null | awk '{sum += $1} END {print sum}' || echo "0")
  local test_files
  test_files=$(find . -name "*Test*.swift" -o -name "*test*.swift" 2>/dev/null | wc -l | tr -d ' ')

  print_status "Project metrics: $swift_files Swift files, $total_lines lines, $test_files test files"

  # Generate comprehensive analysis report
  {
    echo "# AI Enhancement Analysis: $project_name"
    echo ""
    echo "## Project Overview"
    echo "- **Swift Files**: $swift_files"
    echo "- **Total Lines**: $total_lines"
    echo "- **Test Files**: $test_files"
    echo "- **Analysis Date**: $(date)"
    echo ""

    # Architecture Analysis
    echo "## Architecture Analysis"
    echo ""

    # Check for common patterns and suggest improvements
    analyze_architecture_patterns "$project_name"

    # Performance Analysis
    echo "## Performance Analysis"
    echo ""
    analyze_performance_patterns "$project_name"

    # UI/UX Analysis
    echo "## UI/UX Analysis"
    echo ""
    analyze_ui_patterns "$project_name"

    # Testing Analysis
    echo "## Testing Analysis"
    echo ""
    analyze_testing_patterns "$project_name"

    # Security Analysis
    echo "## Security Analysis"
    echo ""
    analyze_security_patterns "$project_name"

    # Generate safe enhancements script
    generate_safe_enhancements_script "$project_name" "$auto_apply_script"

    echo "## Summary"
    echo ""
    echo "Analysis completed. Review suggestions above and consider running:"
    echo "\`\`\`bash"
    echo "bash \"$auto_apply_script\""
    echo "\`\`\`"
    echo ""
    echo "For safe auto-application of recommended enhancements."

  } >"$enhancement_file"

  print_success "Analysis report generated: $enhancement_file"
  print_success "Safe enhancements script: $auto_apply_script"

  # Log the analysis
  echo "$(date): Analyzed $project_name - $swift_files files, $total_lines lines" >>"$AUTO_ENHANCE_LOG"
}

# Analyze architecture patterns
analyze_architecture_patterns() {
  local project_name="$1"

  # Check for protocol-oriented programming
  local protocols
  protocols=$(count_lines "^protocol ")
  local structs
  structs=$(count_lines "^struct ")
  local classes
  classes=$(count_lines "^class ")

  echo "### Code Structure"
  echo "- Protocols: $protocols"
  echo "- Structs: $structs"
  echo "- Classes: $classes"
  echo ""

  if [[ $protocols -gt 0 ]]; then
    print_enhancement "Protocol-oriented design detected ($protocols protocols)"
  fi

  # Check for dependency injection patterns
  local dependency_injection
  dependency_injection=$(count_lines "init.*:.*Protocol")
  if [[ $dependency_injection -gt 0 ]]; then
    print_enhancement "Dependency injection pattern usage detected"
  else
    print_suggestion "Consider implementing dependency injection for better testability"
  fi

  # Check for singleton patterns (often anti-patterns)
  local singletons
  singletons=$(count_lines "static let shared\\|static var shared")
  if [[ $singletons -gt 2 ]]; then
    print_warning "Multiple singleton patterns detected ($singletons) - consider dependency injection"
  fi
}

# Analyze performance patterns
analyze_performance_patterns() {
  # Check for array operations that could be optimized
  local array_operations
  array_operations=$(count_lines "\\.append\\|\\+=.*\\[")

  echo "### Array Operations"
  echo "- Potential optimizations: $array_operations operations detected"
  echo ""

  if [[ $array_operations -gt 10 ]]; then
    print_suggestion "Consider using more efficient array operations or data structures"
  fi

  # Check for force unwrapping
  local force_unwraps
  force_unwraps=$(count_lines "!")
  if [[ $force_unwraps -gt 5 ]]; then
    print_warning "High number of force unwraps detected ($force_unwraps) - consider optional binding"
  fi
}

# Analyze UI patterns
analyze_ui_patterns() {
  # Check for accessibility labels
  local accessibility_labels
  accessibility_labels=$(count_lines "accessibilityLabel")

  echo "### Accessibility"
  echo "- Accessibility labels: $accessibility_labels"
  echo ""

  if [[ $accessibility_labels -eq 0 ]]; then
    print_suggestion "Add accessibility labels to UI components for better accessibility"
  fi

  # Check for TODO comments in UI code
  local todo_comments
  todo_comments=$(count_lines "// TODO")
  if [[ $todo_comments -gt 0 ]]; then
    print_suggestion "Address $todo_comments TODO comments in UI code"
  fi
}

# Analyze testing patterns
analyze_testing_patterns() {
  local test_files
  test_files=$(find . -name "*Test*.swift" -o -name "*test*.swift" 2>/dev/null | wc -l | tr -d ' ')

  echo "### Test Coverage"
  echo "- Test files: $test_files"
  echo ""

  if [[ $test_files -eq 0 ]]; then
    print_suggestion "Add unit tests to improve code reliability"
  elif [[ $test_files -lt 3 ]]; then
    print_suggestion "Consider adding more comprehensive test coverage"
  fi

  # Check for async test patterns
  local async_tests
  async_tests=$(count_lines "func test.*async")
  if [[ $async_tests -gt 0 ]]; then
    print_enhancement "Async testing patterns detected"
  fi
}

# Analyze security patterns
analyze_security_patterns() {
  # Check for potential security issues
  local print_statements
  print_statements=$(count_lines "print\\|debugPrint")
  local api_keys
  api_keys=$(count_lines "API_KEY\\|SECRET\\|TOKEN")

  echo "### Security Considerations"
  echo "- Debug print statements: $print_statements"
  echo "- Potential API keys: $api_keys"
  echo ""

  if [[ $print_statements -gt 5 ]]; then
    print_warning "High number of debug print statements - remove for production"
  fi

  if [[ $api_keys -gt 0 ]]; then
    print_warning "Potential hardcoded API keys detected - use secure storage"
  fi
}

# Generate safe enhancements script
generate_safe_enhancements_script() {
  local project_name="$1"
  local script_path="$2"

  {
    echo "#!/bin/bash"
    echo "# Safe auto-applicable enhancements for $project_name"
    echo ""
    echo "set -euo pipefail"
    echo ""
    echo "PROJECT_PATH=\"\$1\""
    echo "cd \"\$PROJECT_PATH\""
    echo ""
    echo "echo \"🤖 Applying safe enhancements for $project_name...\""
    echo ""

    # Add safe enhancements based on analysis
    echo "# Convert TODO comments to structured documentation"
    echo "echo \"🔧 Converting TODO comments to structured documentation...\""
    echo "find . -name \"*.swift\" -type f -exec sed -i.bak '"
    echo "    s|// TODO:|/// - TODO:|g"
    echo "    s|// FIXME:|/// - FIXME:|g"
    echo "    s|// HACK:|/// - Note:|g"
    echo "' {} \\;"
    echo "find . -name \"*.swift.bak\" -delete"
    echo "echo \"✅ Documentation comments structured\""
    echo ""

    echo "# Add basic accessibility labels where missing"
    echo "echo \"🔧 Adding basic accessibility labels...\""
    echo "find . -name \"*.swift\" -type f -exec sed -i.bak '"
    echo "    /Button(/,/)/{ /accessibilityLabel/! s/Button(/Button(/g; s/)/).accessibilityLabel(\"Button\")/g }"
    echo "' {} \\;"
    echo "find . -name \"*.swift.bak\" -delete"
    echo "echo \"✅ Basic accessibility labels added\""
    echo ""

    echo "echo \"🎉 Safe enhancements applied successfully!\""
    echo ""

  } >"$script_path"

  chmod +x "$script_path"
}

# Apply safe enhancements to a project
apply_safe_enhancements() {
  local project_name="$1"
  local project_path="${PROJECTS_DIR}/${project_name}"

  if [[ ! -d "$project_path" ]]; then
    print_error "Project $project_name not found"
    return 1
  fi

  local script_path="${ENHANCEMENT_DIR}/${project_name}_safe_enhancements.sh"

  if [[ ! -f "$script_path" ]]; then
    print_error "Safe enhancements script not found: $script_path"
    print_status "Run analysis first: $0 analyze $project_name"
    return 1
  fi

  print_header "Applying safe enhancements to $project_name..."

  # Create backup before applying changes
  local backup_dir
  backup_dir="${project_path}.backup.$(date +%Y%m%d_%H%M%S)"
  print_status "Creating backup: $backup_dir"
  cp -r "$project_path" "$backup_dir"

  # Apply enhancements
  bash "$script_path" "$project_path"

  print_success "Safe enhancements applied to $project_name"
  print_status "Backup created at: $backup_dir"

  # Log the application
  echo "$(date): Applied safe enhancements to $project_name" >>"$AUTO_ENHANCE_LOG"
}

# Analyze all projects
analyze_all_projects() {
  print_header "Analyzing all projects for AI enhancements..."

  for project in "${PROJECTS_DIR}"/*; do
    if [[ -d "$project" ]]; then
      local project_name
      project_name=$(basename "$project")

      # Skip non-project directories
      if [[ "$project_name" == "Tools" ]] || [[ "$project_name" == "scripts" ]] || [[ "$project_name" == "Config" ]]; then
        continue
      fi

      analyze_project "$project_name"
      echo ""
    fi
  done

  print_success "Analysis completed for all projects"
}

# Apply safe enhancements to all projects
apply_all_safe_enhancements() {
  print_header "Applying safe enhancements to all projects..."

  for project in "${PROJECTS_DIR}"/*; do
    if [[ -d "$project" ]]; then
      local project_name
      project_name=$(basename "$project")

      # Skip non-project directories
      if [[ "$project_name" == "Tools" ]] || [[ "$project_name" == "scripts" ]] || [[ "$project_name" == "Config" ]]; then
        continue
      fi

      apply_safe_enhancements "$project_name"
      echo ""
    fi
  done

  print_success "Safe enhancements applied to all projects"
}

# Generate comprehensive report
generate_report() {
  local report_file="${ENHANCEMENT_DIR}/MASTER_ENHANCEMENT_REPORT.md"

  print_header "Generating comprehensive enhancement report..."

  {
    echo "# Master AI Enhancement Report"
    echo ""
    echo "## Overview"
    echo "- Generated: $(date)"
    echo "- Projects analyzed: $(find "${PROJECTS_DIR}" -maxdepth 1 -type d | tail -n +2 | wc -l | tr -d ' ')"
    echo ""

    echo "## Project Status Summary"
    echo ""

    for project in "${PROJECTS_DIR}"/*; do
      if [[ -d "$project" ]]; then
        local project_name
        project_name=$(basename "$project")

        # Skip non-project directories
        if [[ "$project_name" == "Tools" ]] || [[ "$project_name" == "scripts" ]] || [[ "$project_name" == "Config" ]]; then
          continue
        fi

        local analysis_file="${ENHANCEMENT_DIR}/${project_name}_enhancement_analysis.md"
        local enhancement_script="${ENHANCEMENT_DIR}/${project_name}_safe_enhancements.sh"

        echo "### $project_name"
        if [[ -f "$analysis_file" ]]; then
          echo "- ✅ Analysis completed"
        else
          echo "- ❌ Analysis pending"
        fi

        if [[ -f "$enhancement_script" ]]; then
          echo "- ✅ Safe enhancements available"
        else
          echo "- ❌ Safe enhancements not generated"
        fi
        echo ""
      fi
    done

    echo "## Recommendations"
    echo ""
    echo "1. Run analysis for projects marked as pending"
    echo "2. Review enhancement suggestions in individual project reports"
    echo "3. Apply safe enhancements where appropriate"
    echo "4. Manually review medium/high-risk suggestions"
    echo ""

  } >"$report_file"

  print_success "Report generated: $report_file"
}

# Show status of AI enhancement system
show_status() {
  print_header "AI Enhancement System Status"

  create_enhancement_dir

  local total_projects=0
  local analyzed_projects=0
  local enhanced_projects=0

  for project in "${PROJECTS_DIR}"/*; do
    if [[ -d "$project" ]]; then
      local project_name
      project_name=$(basename "$project")

      # Skip non-project directories
      if [[ "$project_name" == "Tools" ]] || [[ "$project_name" == "scripts" ]] || [[ "$project_name" == "Config" ]]; then
        continue
      fi

      total_projects=$((total_projects + 1))

      if [[ -f "${ENHANCEMENT_DIR}/${project_name}_enhancement_analysis.md" ]]; then
        analyzed_projects=$((analyzed_projects + 1))
      fi

      if [[ -f "${ENHANCEMENT_DIR}/${project_name}_safe_enhancements.sh" ]]; then
        enhanced_projects=$((enhanced_projects + 1))
      fi
    fi
  done

  echo "📊 Projects: $total_projects total"
  echo "🔍 Analyzed: $analyzed_projects projects"
  echo "🤖 Enhanced: $enhanced_projects projects"
  echo ""

  if [[ -f "$AUTO_ENHANCE_LOG" ]]; then
    echo "📝 Recent Activity:"
    tail -5 "$AUTO_ENHANCE_LOG" 2>/dev/null || true
    echo ""
  fi
}

# Main execution
main() {
  create_enhancement_dir

  case "${1:-}" in
  "analyze")
    if [[ -n "${2:-}" ]]; then
      if [[ "$2" == "all" ]]; then
        analyze_all_projects
      else
        analyze_project "$2"
      fi
    else
      print_error "Usage: $0 analyze <project_name|all>"
      exit 1
    fi
    ;;
  "auto-apply")
    if [[ -n "${2:-}" ]]; then
      if [[ "$2" == "all" ]]; then
        apply_all_safe_enhancements
      else
        apply_safe_enhancements "$2"
      fi
    else
      print_error "Usage: $0 auto-apply <project_name|all>"
      exit 1
    fi
    ;;
  "analyze-all")
    analyze_all_projects
    ;;
  "auto-apply-all")
    apply_all_safe_enhancements
    ;;
  "report")
    generate_report
    ;;
  "status")
    show_status
    ;;
  *)
    print_header "Unified AI Enhancement System"
    echo ""
    echo "🏗️  Quantum Workspace - AI-Powered Enhancement System"
    echo ""
    echo "Usage: $0 <command> [project_name|all]"
    echo ""
    echo "Commands:"
    echo "  analyze <project|all>     # Analyze project(s) for enhancement opportunities"
    echo "  auto-apply <project|all>  # Apply safe enhancements to project(s)"
    echo "  analyze-all               # Analyze all projects"
    echo "  auto-apply-all            # Apply safe enhancements to all projects"
    echo "  report                    # Generate comprehensive enhancement report"
    echo "  status                    # Show current enhancement system status"
    echo ""
    echo "Examples:"
    echo "  $0 analyze MomentumFinance    # Analyze single project"
    echo "  $0 analyze all                # Analyze all projects"
    echo "  $0 auto-apply MomentumFinance # Apply safe enhancements"
    echo "  $0 status                     # Show system status"
    echo ""
    exit 1
    ;;
  esac
}

# Run main function with all arguments
main "$@"
