#!/bin/bash
# Quality Gate Enforcement Tool
# Analyzes codebase for quality gate violations and generates actionable reports

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
QUALITY_CONFIG="${WORKSPACE_ROOT}/quality-config.yaml"
OUTPUT_DIR="${WORKSPACE_ROOT}/Reports/QualityGates"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Quality gate thresholds (from quality-config.yaml)
MAX_LINES_PER_FILE=500
MAX_CYCLOMATIC_COMPLEXITY=10

# Create output directory
mkdir -p "${OUTPUT_DIR}"

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

# Analyze file size violations
analyze_file_sizes() {
    local report_file="${OUTPUT_DIR}/large_files_${TIMESTAMP}.txt"

    print_header "Analyzing File Sizes"

    echo "Files exceeding ${MAX_LINES_PER_FILE} lines:" >"${report_file}"
    echo "Generated: $(date)" >>"${report_file}"
    echo "" >>"${report_file}"

    local violation_count=0
    local total_lines=0

    # Find the 20 largest files by line count
    while IFS= read -r file; do
        # Count lines
        local line_count
        line_count
        line_count=$(wc -l <"$file" 2>/dev/null || echo 0)

        if [ "$line_count" -gt "$MAX_LINES_PER_FILE" ]; then
            local excess=$((line_count - MAX_LINES_PER_FILE))
            echo "$(printf '%5d' $line_count) lines (+$(printf '%4d' $excess)) | ${file#$WORKSPACE_ROOT/}" >>"${report_file}"
            ((violation_count++))
            ((total_lines += line_count))
        fi
    done < <(find "${WORKSPACE_ROOT}/Projects" -name "*.swift" -type f ! -path "*/.*" ! -path "*/build/*" ! -path "*/DerivedData/*")

    echo "" >>"${report_file}"
    echo "Total violations: ${violation_count}" >>"${report_file}"
    echo "Average lines per violating file: $((total_lines / violation_count))" >>"${report_file}"

    if [ "$violation_count" -gt 0 ]; then
        print_warning "Found ${violation_count} files exceeding ${MAX_LINES_PER_FILE} lines"
        echo "Report: ${report_file}"
    else
        print_success "All files comply with line count limit"
    fi

    echo "${violation_count}"
}

# Generate refactoring recommendations
generate_refactoring_recommendations() {
    local report_file="${OUTPUT_DIR}/refactoring_recommendations_${TIMESTAMP}.md"

    print_header "Generating Refactoring Recommendations"

    cat >"${report_file}" <<'EOF'
# File Size Refactoring Recommendations

## Strategy for Breaking Down Large Files

### 1. **Extract Related Types**
Large files often contain multiple types that can be separated:
- Move structs/enums to their own files
- Group related extensions together
- Separate protocols and their conformances

### 2. **Feature-Based Organization**
```
OriginalLargeFile.swift (1000+ lines)
├── OriginalLargeFile+CoreLogic.swift
├── OriginalLargeFile+UI.swift
├── OriginalLargeFile+Networking.swift
└── OriginalLargeFile+Models.swift
```

### 3. **Protocol-Oriented Design**
- Extract protocols to separate files
- Move implementations to extensions
- Create protocol composition for complex behaviors

### 4. **MVVM Pattern Enhancement**
```
Feature/
├── FeatureView.swift           (UI only, ~150 lines)
├── FeatureViewModel.swift      (Business logic, ~200 lines)
├── FeatureModels.swift         (Data structures, ~100 lines)
└── FeatureServices.swift       (External dependencies, ~150 lines)
```

## Automated Refactoring Checklist

- [ ] Identify logical boundaries in large files
- [ ] Extract reusable components
- [ ] Move view-related code to separate files
- [ ] Separate data models from view models
- [ ] Extract utility functions to shared modules
- [ ] Split large classes using partial class pattern (extensions)

## Priority Files for Refactoring

EOF

    # Add top 20 largest files
    echo "### Top 20 Largest Files" >>"${report_file}"
    echo "" >>"${report_file}"

    find "${WORKSPACE_ROOT}/Projects" -name "*.swift" -type f ! -path "*/.*" ! -path "*/build/*" |
        while IFS= read -r file; do
            local lines=$(wc -l <"$file" 2>/dev/null || echo 0)
            if [ "$lines" -gt "$MAX_LINES_PER_FILE" ]; then
                echo "${lines}|${file#$WORKSPACE_ROOT/}"
            fi
        done | sort -rn -t'|' -k1 | head -20 |
        while IFS='|' read -r lines file; do
            echo "- **${file}** (${lines} lines)" >>"${report_file}"
        done

    print_success "Refactoring recommendations generated"
    echo "Report: ${report_file}"
}

# Analyze complexity
analyze_complexity() {
    local report_file="${OUTPUT_DIR}/complexity_analysis_${TIMESTAMP}.txt"

    print_header "Analyzing Code Complexity"

    if ! command -v lizard &>/dev/null; then
        print_warning "Lizard not installed. Skipping complexity analysis."
        print_warning "Install with: pip install lizard"
        return
    fi

    echo "Complexity Analysis Report" >"${report_file}"
    echo "Generated: $(date)" >>"${report_file}"
    echo "" >>"${report_file}"

    lizard "${WORKSPACE_ROOT}/Projects" \
        -l swift \
        -w \
        -T nloc=50 \
        -T cyclomatic_complexity=${MAX_CYCLOMATIC_COMPLEXITY} \
        >>"${report_file}" 2>/dev/null || true

    print_success "Complexity analysis complete"
    echo "Report: ${report_file}"
}

# Generate summary dashboard
generate_summary() {
    local summary_file="${OUTPUT_DIR}/quality_gates_summary_${TIMESTAMP}.md"
    local violations=$1

    cat >"${summary_file}" <<EOF
# Quality Gates Summary

**Generated:** $(date)

## File Size Compliance

- **Threshold:** ${MAX_LINES_PER_FILE} lines per file
- **Violations:** ${violations} files
- **Status:** $([ "$violations" -eq 0 ] && echo "✅ PASSED" || echo "⚠️  NEEDS ATTENTION")

## Recommendations

$(
        [ "$violations" -gt 0 ] && cat <<'REC'
### Immediate Actions Required

1. **Review Priority Files**
   - Focus on files with 1000+ lines
   - Identify natural separation boundaries
   - Plan refactoring sprints

2. **Establish Refactoring Strategy**
   - Use feature-based file organization
   - Apply MVVM pattern consistently
   - Extract reusable components

3. **Implement Gradual Improvements**
   - Refactor on feature changes
   - Add file size checks to CI/CD
   - Track progress over time

### Long-term Quality Improvements

- Enforce file size limits in code reviews
- Create shared component libraries
- Implement modular architecture patterns
REC
    )

## Next Steps

- [ ] Review detailed reports in ${OUTPUT_DIR}
- [ ] Prioritize files for refactoring
- [ ] Create refactoring tickets
- [ ] Update coding standards documentation
- [ ] Schedule refactoring sprints

## Additional Resources

- Refactoring recommendations: ${OUTPUT_DIR}/refactoring_recommendations_${TIMESTAMP}.md
- Detailed file list: ${OUTPUT_DIR}/large_files_${TIMESTAMP}.txt

EOF

    print_success "Quality gates summary generated"
    echo "Summary: ${summary_file}"
}

# Main execution
main() {
    print_header "Quality Gate Enforcement Analysis"
    echo "Workspace: ${WORKSPACE_ROOT}"
    echo "Timestamp: ${TIMESTAMP}"
    echo ""

    # Run analyses
    local violations=$(analyze_file_sizes)
    generate_refactoring_recommendations
    analyze_complexity
    generate_summary "${violations}"

    echo ""
    print_header "Analysis Complete"

    if [ "$violations" -gt 0 ]; then
        print_warning "${violations} files need attention"
        print_warning "Review reports in: ${OUTPUT_DIR}"
    else
        print_success "All quality gates passed!"
    fi

    echo ""
    echo "Reports generated:"
    ls -lh "${OUTPUT_DIR}"/*"${TIMESTAMP}"* 2>/dev/null || true
}

# Run main function
main "$@"
