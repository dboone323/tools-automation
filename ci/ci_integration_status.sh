#!/bin/bash
# CI Integration Status Report
# Validates the complete CI/CD infrastructure and provides comprehensive status

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

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
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║ $1${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Component status tracking
COMPONENT_STATUS=""
COMPONENT_DETAILS=""

# Helper functions for associative array simulation
set_component_status() {
    local component="$1"
    local status="$2"
    COMPONENT_STATUS="${COMPONENT_STATUS}${component}|${status}\n"
}

get_component_status() {
    local component="$1"
    echo "$COMPONENT_STATUS" | grep "^${component}|" | cut -d'|' -f2
}

set_component_details() {
    local component="$1"
    local details="$2"
    COMPONENT_DETAILS="${COMPONENT_DETAILS}${component}|${details}\n"
}

get_component_details() {
    local component="$1"
    echo "$COMPONENT_DETAILS" | grep "^${component}|" | cut -d'|' -f2-
}

# Check if file exists and is executable
check_executable() {
    local file="$1"
    local description="$2"

    if [[ -f "$file" ]]; then
        if [[ -x "$file" ]]; then
            set_component_status "$description" "PASS"
            set_component_details "$description" "Executable at $file"
            return 0
        else
            set_component_status "$description" "WARN"
            set_component_details "$description" "File exists but not executable: $file"
            return 1
        fi
    else
        set_component_status "$description" "FAIL"
        set_component_details "$description" "File not found: $file"
        return 1
    fi
}

# Check if file exists
check_file() {
    local file="$1"
    local description="$2"

    if [[ -f "$file" ]]; then
        set_component_status "$description" "PASS"
        set_component_details "$description" "File exists at $file"
        return 0
    else
        set_component_status "$description" "FAIL"
        set_component_details "$description" "File not found: $file"
        return 1
    fi
}

# Check if directory exists
check_directory() {
    local dir="$1"
    local description="$2"

    if [[ -d "$dir" ]]; then
        set_component_status "$description" "PASS"
        set_component_details "$description" "Directory exists at $dir"
        return 0
    else
        set_component_status "$description" "FAIL"
        set_component_details "$description" "Directory not found: $dir"
        return 1
    fi
}

# Validate CI Orchestrator
validate_ci_orchestrator() {
    header "CI Orchestrator Validation"

    local orchestrator="$SCRIPT_DIR/ci_orchestrator.sh"

    if check_executable "$orchestrator" "CI Orchestrator"; then
        # Test basic functionality
        if "$orchestrator" --help >/dev/null 2>&1 || "$orchestrator" 2>&1 | grep -q "Usage:"; then
            success "CI Orchestrator basic functionality works"
        else
            warning "CI Orchestrator may have issues (help command failed)"
        fi
    fi
}

# Validate Testing Infrastructure
validate_testing_infrastructure() {
    header "Testing Infrastructure Validation"

    check_executable "$SCRIPT_DIR/../Testing/test_timeout_wrapper.sh" "Timeout Wrapper"
    check_executable "$SCRIPT_DIR/../Testing/testing_flaky_detection.sh" "Flaky Test Detection"
    check_file "$WORKSPACE_ROOT/quality-config.yaml" "Quality Configuration"
}

# Validate Performance Monitoring
validate_performance_monitoring() {
    header "Performance Monitoring Validation"

    check_executable "$SCRIPT_DIR/../performance_monitor_advanced.sh" "Performance Monitor"
    check_directory "$SCRIPT_DIR/../.metrics" "Metrics Directory"
}

# Validate Issue Management
validate_issue_management() {
    header "Issue Management Validation"

    check_executable "$SCRIPT_DIR/create_issue.sh" "Issue Creation Script"
}

# Validate GitHub Actions Workflows
validate_workflows() {
    header "GitHub Actions Workflow Validation"

    local workflows=(
        ".github/workflows/pr-parallel-validation.yml"
        ".github/workflows/release-sequential-build.yml"
        ".github/workflows/quantum-enhanced-ci-cd.yml"
    )

    for workflow in "${workflows[@]}"; do
        if check_file "$WORKSPACE_ROOT/$workflow" "Workflow: $(basename "$workflow" .yml)"; then
            # Check if workflow uses CI orchestrator
            if grep -q "ci_orchestrator.sh" "$WORKSPACE_ROOT/$workflow"; then
                success "Workflow $(basename "$workflow") uses CI orchestrator"
            else
                warning "Workflow $(basename "$workflow") does not use CI orchestrator"
            fi
        fi
    done
}

# Validate Project Structure
validate_project_structure() {
    header "Project Structure Validation"

    local projects=("AvoidObstaclesGame" "PlannerApp" "MomentumFinance" "HabitQuest" "CodingReviewer")

    for project in "${projects[@]}"; do
        local project_dir="$WORKSPACE_ROOT/Projects/$project"

        if check_directory "$project_dir" "Project: $project"; then
            # Check for test structure
            if [[ -d "$project_dir/Tests" ]] || [[ -f "$project_dir/Package.swift" ]]; then
                success "Project $project has test structure"
            else
                warning "Project $project missing test structure"
            fi

            # Check for Xcode project or Swift Package
            if [[ -f "$project_dir/${project}.xcodeproj/project.pbxproj" ]] || [[ -f "$project_dir/Package.swift" ]]; then
                success "Project $project has build configuration"
            else
                warning "Project $project missing build configuration"
            fi
        fi
    done
}

# Validate Quality Gates
validate_quality_gates() {
    header "Quality Gates Validation"

    local config="$WORKSPACE_ROOT/quality-config.yaml"

    if [[ -f "$config" ]]; then
        # Check coverage thresholds
        local min_coverage
        min_coverage=$(grep "minimum:" "$config" | grep -o "[0-9]*" | head -1 || echo "")

        if [[ -n "$min_coverage" ]] && [[ "$min_coverage" -ge 70 ]]; then
            success "Coverage minimum threshold: ${min_coverage}%"
        else
            warning "Coverage minimum threshold not properly configured"
        fi

        # Check timeout configurations
        local build_timeout
        build_timeout=$(grep "max_duration_seconds:" "$config" | grep -A1 "build_performance" | tail -1 | grep -o "[0-9]*" | head -1 || echo "")

        if [[ -n "$build_timeout" ]] && [[ "$build_timeout" -gt 0 ]]; then
            success "Build timeout configured: ${build_timeout}s"
        else
            warning "Build timeout not properly configured"
        fi
    else
        error "Quality configuration file missing"
    fi
}

# Generate status report
generate_status_report() {
    header "CI Integration Status Report"

    echo ""
    echo "Component Status Summary:"
    echo "═════════════════════════"

    # Simple parsing - split by newline and process each line
    local total_components=0
    local pass_count=0
    local warn_count=0
    local fail_count=0

    # Process status lines
    while IFS= read -r line; do
        if [[ -n "$line" && "$line" == *\|* ]]; then
            local component
            component=$(echo "$line" | cut -d'|' -f1)
            local status
            status=$(echo "$line" | cut -d'|' -f2)

            # Find details for this component
            local details=""
            while IFS= read -r detail_line; do
                if [[ -n "$detail_line" && "$detail_line" == "${component}|"* ]]; then
                    details=$(echo "$detail_line" | cut -d'|' -f2-)
                    break
                fi
            done <<<"$COMPONENT_DETAILS"

            ((total_components++))

            case "$status" in
            "PASS")
                echo -e "${GREEN}✅ PASS${NC} | $component"
                ((pass_count++))
                ;;
            "WARN")
                echo -e "${YELLOW}⚠️  WARN${NC} | $component"
                ((warn_count++))
                ;;
            "FAIL")
                echo -e "${RED}❌ FAIL${NC} | $component"
                ((fail_count++))
                ;;
            esac

            if [[ -n "$details" ]]; then
                echo "       └─ $details"
            fi
        fi
    done <<<"$COMPONENT_STATUS"

    echo ""
    echo "Summary Statistics:"
    echo "═══════════════════"
    echo "Total Components: $total_components"
    echo -e "Passed: ${GREEN}$pass_count${NC}"
    echo -e "Warnings: ${YELLOW}$warn_count${NC}"
    echo -e "Failed: ${RED}$fail_count${NC}"

    # Overall status
    echo ""
    if [[ $fail_count -eq 0 ]]; then
        if [[ $warn_count -eq 0 ]]; then
            success "🎉 CI Integration: FULLY OPERATIONAL"
            return 0
        else
            warning "⚠️  CI Integration: OPERATIONAL WITH WARNINGS"
            return 0
        fi
    else
        error "❌ CI Integration: ISSUES DETECTED"
        return 1
    fi
}

# Test CI Orchestrator with dry run
test_ci_orchestrator() {
    header "CI Orchestrator Dry Run Test"

    local orchestrator="$SCRIPT_DIR/ci_orchestrator.sh"

    if [[ -x "$orchestrator" ]]; then
        log "Testing CI orchestrator help output..."

        if "$orchestrator" 2>&1 | grep -q "Usage:"; then
            success "CI Orchestrator help command works"
        else
            warning "CI Orchestrator help command may have issues"
        fi

        # Test with invalid arguments (should show usage)
        if "$orchestrator" invalid_project invalid_operation 2>&1 | grep -q "Usage:"; then
            success "CI Orchestrator error handling works"
        else
            warning "CI Orchestrator error handling may have issues"
        fi
    else
        error "CI Orchestrator not executable"
    fi
}

# Main validation function
main() {
    log "Starting CI Integration Status Validation"

    # Run all validations
    validate_ci_orchestrator
    validate_testing_infrastructure
    validate_performance_monitoring
    validate_issue_management
    validate_workflows
    validate_project_structure
    validate_quality_gates

    # Test functionality
    test_ci_orchestrator

    # Generate final report
    generate_status_report

    log "CI Integration Status Validation Complete"
}

main "$@"
