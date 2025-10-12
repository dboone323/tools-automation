#!/bin/bash
# Code Coverage Setup and Reporting Tool
# Configures projects for coverage collection and generates reports

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REPORTS_DIR="${WORKSPACE_ROOT}/Reports/Coverage"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Coverage thresholds
MINIMUM_COVERAGE=70
TARGET_COVERAGE=85

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Create reports directory
mkdir -p "${REPORTS_DIR}"

# Enable code coverage in Xcode schemes
enable_coverage_for_project() {
    local project_dir=$1
    local project_name=$(basename "$project_dir")

    print_header "Configuring Coverage: ${project_name}"

    # Find xcodeproj file
    local xcodeproj
    xcodeproj=$(find "$project_dir" -maxdepth 1 -name "*.xcodeproj" | head -1)

    if [ -z "$xcodeproj" ]; then
        print_warning "No Xcode project found in ${project_name}"
        return 1
    fi

    # Find scheme files
    local schemes_dir="${xcodeproj}/xcshareddata/xcschemes"

    if [ ! -d "$schemes_dir" ]; then
        print_warning "No shared schemes found for ${project_name}"
        return 1
    fi

    # Enable coverage in all schemes
    for scheme_file in "$schemes_dir"/*.xcscheme; do
        if [ -f "$scheme_file" ]; then
            local scheme_name=$(basename "$scheme_file" .xcscheme)

            # Check if coverage is already enabled
            if grep -q 'codeCoverageEnabled = "YES"' "$scheme_file"; then
                print_success "Coverage already enabled: ${scheme_name}"
            else
                # Enable coverage by modifying the scheme file
                if grep -q 'TestAction' "$scheme_file"; then
                    # Backup original
                    cp "$scheme_file" "${scheme_file}.backup"

                    # Add coverage flag
                    sed -i '' 's/buildConfiguration = "Debug"/buildConfiguration = "Debug"\n      codeCoverageEnabled = "YES"/' "$scheme_file"

                    print_success "Enabled coverage: ${scheme_name}"
                else
                    print_warning "No TestAction found in ${scheme_name}"
                fi
            fi
        fi
    done

    return 0
}

# Run tests with coverage for a project
run_tests_with_coverage() {
    local project_dir=$1
    local project_name=$(basename "$project_dir")

    print_header "Running Tests: ${project_name}"

    cd "$project_dir" || return 1

    # Find xcodeproj
    local xcodeproj
    xcodeproj=$(find . -maxdepth 1 -name "*.xcodeproj" | head -1)

    if [ -z "$xcodeproj" ]; then
        print_warning "No Xcode project found"
        return 1
    fi

    # Determine platform
    local sdk="iphonesimulator"
    local destination="platform=iOS Simulator,name=iPhone 15"

    if grep -q "MACOSX_DEPLOYMENT_TARGET" "${xcodeproj}/project.pbxproj" 2>/dev/null; then
        sdk="macosx"
        destination="platform=macOS"
    fi

    # Run tests with coverage
    local scheme
    scheme=$(basename "$xcodeproj" .xcodeproj)

    print_success "Running tests for ${scheme} (${sdk})..."

    xcodebuild test \
        -scheme "$scheme" \
        -sdk "$sdk" \
        -destination "$destination" \
        -enableCodeCoverage YES \
        -derivedDataPath "./DerivedData" \
        -resultBundlePath "${REPORTS_DIR}/${project_name}_${TIMESTAMP}.xcresult" \
        2>&1 | grep -E "(Test Suite|passed|failed|Coverage)" || true

    return 0
}

# Extract coverage data from xcresult
extract_coverage_report() {
    local project_name=$1
    local xcresult="${REPORTS_DIR}/${project_name}_${TIMESTAMP}.xcresult"

    if [ ! -d "$xcresult" ]; then
        print_warning "No test results found for ${project_name}"
        return 1
    fi

    print_header "Extracting Coverage: ${project_name}"

    # Use xcrun to extract coverage
    local coverage_json="${REPORTS_DIR}/${project_name}_coverage_${TIMESTAMP}.json"

    xcrun xccov view --report --json "$xcresult" >"$coverage_json" 2>/dev/null || {
        print_warning "Failed to extract coverage data"
        return 1
    }

    # Parse coverage percentage
    local coverage
    coverage=$(python3 -c "
import json
import sys

try:
    with open('$coverage_json') as f:
        data = json.load(f)
        coverage = data.get('lineCoverage', 0) * 100
        print(f'{coverage:.2f}')
except Exception as e:
    print('0.00')
" 2>/dev/null || echo "0.00")

    echo "$coverage"
}

# Generate coverage summary report
generate_coverage_summary() {
    local summary_file="${REPORTS_DIR}/coverage_summary_${TIMESTAMP}.md"

    print_header "Generating Coverage Summary"

    cat >"$summary_file" <<EOF
# Code Coverage Summary

**Generated:** $(date)
**Minimum Threshold:** ${MINIMUM_COVERAGE}%
**Target Coverage:** ${TARGET_COVERAGE}%

## Project Coverage

EOF

    local total_projects=0
    local passing_projects=0

    # Iterate through all projects
    for project_dir in "${WORKSPACE_ROOT}"/Projects/*/; do
        if [ -d "$project_dir" ]; then
            local project_name
            project_name=$(basename "$project_dir")

            # Find coverage report
            local latest_coverage
            latest_coverage=$(find "${REPORTS_DIR}" -name "${project_name}_coverage_*.json" -type f | sort -r | head -1)

            if [ -n "$latest_coverage" ]; then
                local coverage
                coverage=$(python3 -c "
import json
try:
    with open('$latest_coverage') as f:
        data = json.load(f)
        coverage = data.get('lineCoverage', 0) * 100
        print(f'{coverage:.2f}')
except:
    print('N/A')
" 2>/dev/null || echo "N/A")

                local status="⚠️  BELOW TARGET"
                if [ "$coverage" != "N/A" ]; then
                    if (($(echo "$coverage >= $TARGET_COVERAGE" | bc -l))); then
                        status="✅ EXCELLENT"
                        ((passing_projects++))
                    elif (($(echo "$coverage >= $MINIMUM_COVERAGE" | bc -l))); then
                        status="✅ PASSING"
                        ((passing_projects++))
                    else
                        status="❌ BELOW MINIMUM"
                    fi
                fi

                ((total_projects++))

                echo "### ${project_name}" >>"$summary_file"
                echo "" >>"$summary_file"
                echo "- **Coverage:** ${coverage}%" >>"$summary_file"
                echo "- **Status:** ${status}" >>"$summary_file"
                echo "" >>"$summary_file"
            fi
        fi
    done

    cat >>"$summary_file" <<EOF

## Summary Statistics

- **Total Projects Analyzed:** ${total_projects}
- **Meeting Minimum (${MINIMUM_COVERAGE}%):** ${passing_projects}
- **Pass Rate:** $((total_projects > 0 ? (passing_projects * 100 / total_projects) : 0))%

## Recommendations

EOF

    if [ "$passing_projects" -lt "$total_projects" ]; then
        cat >>"$summary_file" <<'EOF'
### Improve Test Coverage

1. **Write Unit Tests for Core Logic**
   - Focus on business logic and algorithms
   - Test edge cases and error conditions
   - Aim for 80%+ coverage on critical paths

2. **Add Integration Tests**
   - Test component interactions
   - Validate data flow
   - Test API integrations

3. **Implement UI Tests**
   - Test critical user flows
   - Validate navigation
   - Test accessibility

4. **Use Test-Driven Development (TDD)**
   - Write tests before implementation
   - Ensures testable code design
   - Improves coverage naturally

EOF
    else
        echo "- ✅ All projects meeting or exceeding minimum coverage threshold" >>"$summary_file"
        echo "- Continue maintaining high coverage standards" >>"$summary_file"
        echo "- Focus on improving toward ${TARGET_COVERAGE}% target" >>"$summary_file"
    fi

    print_success "Coverage summary generated: $summary_file"
}

# Main execution
main() {
    print_header "Code Coverage Setup and Reporting"
    echo "Workspace: ${WORKSPACE_ROOT}"
    echo "Reports: ${REPORTS_DIR}"
    echo ""

    # Enable coverage for all projects
    for project_dir in "${WORKSPACE_ROOT}"/Projects/*/; do
        if [ -d "$project_dir" ]; then
            enable_coverage_for_project "$project_dir" || true
        fi
    done

    echo ""
    print_header "Test Execution and Coverage Collection"
    echo ""

    # Run tests for each project
    for project_dir in "${WORKSPACE_ROOT}"/Projects/*/; do
        if [ -d "$project_dir" ]; then
            local project_name
            project_name=$(basename "$project_dir")
            run_tests_with_coverage "$project_dir" || print_warning "Tests failed or not available for ${project_name}"
            extract_coverage_report "$project_name" || true
        fi
    done

    echo ""
    generate_coverage_summary

    print_header "Coverage Setup Complete"
    print_success "Reports available in: ${REPORTS_DIR}"
}

main "$@"
