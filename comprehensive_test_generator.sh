#!/usr/bin/env bash
# Comprehensive Test Generator for Low-Coverage Projects
# Targets: MomentumFinance (5%), PlannerApp (4%)
# Goal: Achieve 70%+ test coverage

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
readonly PROJECTS_DIR="${WORKSPACE_ROOT}/Projects"
readonly OLLAMA_MODEL="${OLLAMA_MODEL:-qwen2.5-coder:1.5b}"
readonly OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"

# Statistics
TOTAL_TESTS_GENERATED=0
TOTAL_FILES_PROCESSED=0
ERRORS_COUNT=0

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}"; }

# Check Ollama availability
check_ollama() {
    if ! curl -s "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
        log_error "Ollama is not running on ${OLLAMA_URL}"
        log_info "Start with: ollama serve"
        exit 1
    fi
    log_success "Ollama is available"
}

# Analyze source file to determine test priority
analyze_file_priority() {
    local file=$1
    local priority="medium"

    # High priority patterns
    if grep -qE "(ViewModel|Manager|Service|Controller|Repository)" "$file"; then
        priority="high"
    elif grep -qE "(Model|Entity|struct.*:.*Codable)" "$file"; then
        priority="high"
    elif grep -qE "(@Published|ObservableObject|@State)" "$file"; then
        priority="high"
    elif grep -qE "(CloudKit|CoreData|Persistence)" "$file"; then
        priority="critical"
    fi

    # Low priority patterns
    if grep -qE "(View\.swift|ContentView|Preview)" "$file"; then
        priority="low"
    fi

    echo "$priority"
}

# Generate test using Ollama
generate_test_with_ollama() {
    local source_file=$1
    local project_name=$2
    local test_dir=$3

    local filename=$(basename "$source_file" .swift)
    local test_filename="${filename}Tests.swift"
    local test_path="${test_dir}/${test_filename}"

    # Skip if test already exists
    if [[ -f "$test_path" ]]; then
        log_warn "Test already exists: $test_filename"
        return 0
    fi

    # Skip certain files
    if [[ "$filename" =~ ^(main|App|ContentView|Package)$ ]]; then
        log_info "Skipping $filename (system file)"
        return 0
    fi

    local priority=$(analyze_file_priority "$source_file")
    log_info "Processing $filename (priority: $priority)..."

    # Read source code
    local source_code
    source_code=$(cat "$source_file" 2>/dev/null || echo "")
    if [[ -z "$source_code" ]]; then
        log_error "Could not read $source_file"
        return 1
    fi

    # Limit source code length for API
    source_code="${source_code:0:4000}"

    # Create AI prompt based on file type and priority
    local prompt
    if [[ "$priority" == "critical" ]]; then
        prompt="Generate comprehensive XCTest unit tests for this critical Swift code with CloudKit/persistence:

File: ${filename}.swift
Code:
${source_code}

Generate COMPREHENSIVE tests including:
1. All public methods and properties
2. CloudKit operation tests with mocks
3. Data persistence and retrieval tests
4. Error handling for all failure modes
5. Edge cases and boundary conditions
6. Async/await testing where applicable
7. Integration test scenarios
8. Performance tests for data operations

Requirements:
- Use XCTest framework
- Import @testable import ${project_name}
- Use @MainActor where needed
- Mock CloudKit/CoreData dependencies
- Test success and failure paths
- Include setup() and tearDown()
- Use descriptive test method names
- Add comments explaining test purpose

CRITICAL - NO PLACEHOLDERS:
- NO TODO comments - write complete test implementations
- NO placeholder code - all assertions must be real XCTAssert* calls with actual values
- NO XCTFail() unless testing expected failures
- NO comments like 'Add more assertions' - include ALL assertions needed
- Every test method must have working GIVEN/WHEN/THEN logic
- Use real test data (actual strings, numbers, objects) not placeholders like 'testValue' or 'value'
- Mock dependencies with actual mock implementations, not comments saying 'mock here'
- All async functions must have proper await and error handling
- Create real instances with actual property values
- For file/data exports: verify file exists, check file contents, validate data format
- For error handling: verify specific error types and messages
- For collections: check count, verify specific elements, test empty/populated states
- For computed properties: verify calculation results with concrete expected values"
    else
        prompt="Generate comprehensive XCTest unit tests for this Swift code:

File: ${filename}.swift
Code:
${source_code}

Generate COMPLETE tests including:
1. Test all public methods and properties
2. Edge cases and error conditions
3. State management if ViewModel/ObservableObject
4. Property validation
5. Method return values and side effects
6. Async operations with proper await
7. Error handling

Requirements:
- Use XCTest framework
- Import @testable import ${project_name}
- Use @MainActor for ViewModels
- Proper setUp() and tearDown()
- Descriptive test names (testMethodName_whenCondition_thenExpectedResult)
- Comments explaining each test
- XCTAssert statements for all checks

CRITICAL - NO PLACEHOLDERS:
- NO TODO comments - write complete test implementations
- NO placeholder code - all assertions must be real XCTAssert* calls with actual values
- NO XCTFail() unless testing expected failures
- NO comments like 'Add more assertions' or 'TODO: verify' - include ALL assertions needed
- Every test method must have working GIVEN/WHEN/THEN logic
- Use real test data (actual strings, numbers, dates) not generic placeholders
- Create real mock objects with actual implementations
- All assertions must check concrete expected values
- Initialize objects with specific test values, not nil or empty
- For file operations: verify file exists with FileManager, read contents, validate format
- For async operations: test both success and error paths with specific expectations
- For ViewModels: verify state changes, published properties, and side effects
- For data transformations: check input -> output with multiple concrete examples"
    fi

    # Call Ollama API
    local response
    response=$(curl -s -X POST "${OLLAMA_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"${OLLAMA_MODEL}\",
            \"prompt\": $(jq -n --arg p "$prompt" '$p'),
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.2,
                \"top_p\": 0.9
            }
        }" 2>&1)

    if [[ $? -ne 0 ]] || [[ -z "$response" ]]; then
        log_error "Ollama API call failed for $filename"
        ((ERRORS_COUNT++))
        return 1
    fi

    # Extract generated code
    local test_code
    test_code=$(echo "$response" | jq -r '.response' 2>/dev/null || echo "")

    if [[ -z "$test_code" ]] || [[ "$test_code" == "null" ]]; then
        log_error "No test code generated for $filename"
        ((ERRORS_COUNT++))
        return 1
    fi

    # Clean up code (remove markdown blocks if present)
    test_code=$(echo "$test_code" | sed -e 's/^```swift//g' -e 's/^```//g' | sed '/^$/d')

    # Add header comment if not present
    if ! echo "$test_code" | grep -q "^import XCTest"; then
        test_code="import XCTest
@testable import ${project_name}

${test_code}"
    fi

    # Write test file
    echo "$test_code" >"$test_path"

    if [[ -f "$test_path" ]]; then
        log_success "Generated test: $test_filename"
        ((TOTAL_TESTS_GENERATED++))
        return 0
    else
        log_error "Failed to write test file: $test_filename"
        ((ERRORS_COUNT++))
        return 1
    fi
}

# Process a single project
process_project() {
    local project_path=$1
    local project_name=$(basename "$project_path")

    log_info "
═══════════════════════════════════════════════════
  Processing: $project_name
═══════════════════════════════════════════════════"

    # Determine test directory
    local test_dir
    if [[ "$project_name" == "MomentumFinance" ]]; then
        test_dir="${project_path}/MomentumFinanceTests"
    elif [[ "$project_name" == "PlannerApp" ]]; then
        test_dir="${project_path}/PlannerAppTests"
    else
        test_dir="${project_path}/Tests"
    fi

    mkdir -p "$test_dir"
    log_success "Test directory: $test_dir"

    # Find source files (exclude tests)
    local source_files=()
    while IFS= read -r file; do
        source_files+=("$file")
    done < <(find "$project_path" -name "*.swift" \
        -not -path "*/Tests/*" \
        -not -path "*/UITests/*" \
        -not -path "*/.build/*" \
        -not -path "*/DerivedData/*" \
        -not -name "*Tests.swift" \
        2>/dev/null | head -50) # Limit to first 50 files

    local total_files=${#source_files[@]}
    log_info "Found $total_files source files"

    if [[ $total_files -eq 0 ]]; then
        log_warn "No source files found in $project_name"
        return 0
    fi

    # Sort by priority
    local critical_files=()
    local high_files=()
    local medium_files=()
    local low_files=()

    for file in "${source_files[@]}"; do
        local priority=$(analyze_file_priority "$file")
        case "$priority" in
        critical) critical_files+=("$file") ;;
        high) high_files+=("$file") ;;
        medium) medium_files+=("$file") ;;
        low) low_files+=("$file") ;;
        esac
    done

    log_info "Priority distribution:"
    log_info "  Critical: ${#critical_files[@]}"
    log_info "  High: ${#high_files[@]}"
    log_info "  Medium: ${#medium_files[@]}"
    log_info "  Low: ${#low_files[@]}"

    # Process files by priority
    local all_prioritized_files=("${critical_files[@]}" "${high_files[@]}" "${medium_files[@]}" "${low_files[@]}")

    local count=0
    for file in "${all_prioritized_files[@]}"; do
        ((count++))
        log_info "[$count/$total_files] Processing $(basename "$file")..."

        generate_test_with_ollama "$file" "$project_name" "$test_dir"
        ((TOTAL_FILES_PROCESSED++))

        # Rate limiting - brief pause between API calls
        sleep 0.5
    done

    log_success "Completed $project_name: $count files processed"
    echo ""
}

# Main execution
main() {
    log_info "
╔═══════════════════════════════════════════════════╗
║   Comprehensive Test Generator                    ║
║   Target: 70%+ coverage for low-coverage projects║
╚═══════════════════════════════════════════════════╝
"

    check_ollama

    # Process MomentumFinance (5% coverage - CRITICAL)
    if [[ -d "${PROJECTS_DIR}/MomentumFinance" ]]; then
        process_project "${PROJECTS_DIR}/MomentumFinance"
    else
        log_warn "MomentumFinance project not found"
    fi

    # Process PlannerApp (4% coverage - CRITICAL)
    if [[ -d "${PROJECTS_DIR}/PlannerApp" ]]; then
        process_project "${PROJECTS_DIR}/PlannerApp"
    else
        log_warn "PlannerApp project not found"
    fi

    # Summary
    log_info "
╔═══════════════════════════════════════════════════╗
║                  SUMMARY                          ║
╚═══════════════════════════════════════════════════╝
"
    log_success "Total files processed: $TOTAL_FILES_PROCESSED"
    log_success "Total tests generated: $TOTAL_TESTS_GENERATED"
    if [[ $ERRORS_COUNT -gt 0 ]]; then
        log_warn "Errors encountered: $ERRORS_COUNT"
    fi

    log_info "
Next steps:
1. Add test files to Xcode project test targets
2. Run tests: xcodebuild test -project ProjectName.xcodeproj -scheme SchemeName
3. Generate coverage report
4. Fix any compilation errors in generated tests
5. Enhance tests with additional edge cases
"
}

main "$@"
