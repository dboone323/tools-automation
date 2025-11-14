#!/usr/bin/env bash
# Test script to generate a single test file and verify quality
# This will generate a test for DataExporter.swift

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Configuration
readonly OLLAMA_URL="http://localhost:11434"
readonly OLLAMA_MODEL="qwen2.5-coder:1.5b"
SETUP_PATH="$(git rev-parse --show-toplevel 2>/dev/null)/scripts/setup_paths.sh"
if [[ -f "${SETUP_PATH}" ]]; then
    # shellcheck disable=SC1090
    source "${SETUP_PATH}"
fi

readonly SOURCE_FILE="${SOURCE_FILE:-${WORKSPACE_ROOT}/Projects/MomentumFinance/Sources/MomentumFinanceCore/DataExporter.swift}"
readonly OUTPUT_FILE="/tmp/DataExporterTests_generated.swift"

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Single File Test Generation Verification       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Check Ollama
if ! curl -s "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
    echo -e "${RED}❌ Ollama is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Ollama is available${NC}"

# Read source file
echo -e "${BLUE}📖 Reading source file...${NC}"
source_code=$(cat "$SOURCE_FILE" 2>/dev/null || echo "")
if [[ -z "$source_code" ]]; then
    echo -e "${RED}❌ Could not read source file${NC}"
    exit 1
fi
source_code="${source_code:0:4000}" # Limit for API

# Create enhanced prompt
prompt="Generate comprehensive XCTest unit tests for this Swift code:

File: DataExporter.swift
Code:
${source_code}

Generate COMPLETE tests including:
1. Test all public methods and properties
2. Edge cases and error conditions  
3. Async operations with proper await
4. Error handling for invalid formats
5. Test with empty and populated data
6. Test CSV field sanitization
7. Test date range filtering

Requirements:
- Use XCTest framework
- Import @testable import MomentumFinance
- Use @MainActor where needed
- Proper setUp() and tearDown() with test ModelContainer
- Descriptive test names (testMethodName_whenCondition_thenExpectedResult)
- Comments explaining each test
- XCTAssert statements for all checks

CRITICAL - NO PLACEHOLDERS:
- NO TODO comments - write complete test implementations
- NO placeholder code - all assertions must be real XCTAssert* calls with actual values
- NO XCTFail() unless testing expected failures
- NO comments like 'Add more assertions here' - include ALL assertions in test body
- Every test method must have working GIVEN/WHEN/THEN logic
- Use real test data (actual strings, numbers, dates) not generic placeholders
- Create real mock objects with actual implementations
- All assertions must check concrete expected values
- Initialize objects with specific test values, not nil or empty
- Create actual ModelContainer with inMemory configuration for tests
- Create actual FinancialTransaction objects with real property values
- For CSV exports: read file contents with String(contentsOf:), verify row count, check header row
- For date filtering: create transactions with specific dates, verify only correct ones exported
- For field sanitization: test with commas/special characters, verify proper escaping
- Verify file path components, content structure, and data accuracy with multiple XCTAssert calls"

echo -e "${BLUE}🤖 Generating tests with Ollama...${NC}"

# Call Ollama
response=$(curl -s -X POST "${OLLAMA_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"${OLLAMA_MODEL}\",
        \"prompt\": $(jq -n --arg p "$prompt" '$p'),
        \"stream\": false,
        \"options\": {
            \"temperature\": 0.2,
            \"top_p\": 0.9,
            \"num_predict\": 2000
        }
    }" 2>&1)

if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Ollama API call failed${NC}"
    exit 1
fi

# Extract generated code
test_code=$(echo "$response" | jq -r '.response' 2>/dev/null || echo "")

if [[ -z "$test_code" ]] || [[ "$test_code" == "null" ]]; then
    echo -e "${RED}❌ No test code generated${NC}"
    exit 1
fi

# Clean up code
test_code=$(echo "$test_code" | sed -e 's/^```swift//g' -e 's/^```//g')

# Write to file
echo "$test_code" >"$OUTPUT_FILE"

echo -e "${GREEN}✅ Test file generated: $OUTPUT_FILE${NC}"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Generated Test Code:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
cat "$OUTPUT_FILE"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

# Analyze quality
echo ""
echo -e "${BLUE}📊 Quality Analysis:${NC}"

# Count TODOs
todo_count=$(grep -c "TODO" "$OUTPUT_FILE" || echo "0")
if [[ $todo_count -eq 0 ]]; then
    echo -e "${GREEN}✅ No TODO comments found${NC}"
else
    echo -e "${RED}⚠️  Found $todo_count TODO comments${NC}"
fi

# Count XCTFail
fail_count=$(grep -c "XCTFail" "$OUTPUT_FILE" || echo "0")
if [[ $fail_count -eq 0 ]]; then
    echo -e "${GREEN}✅ No XCTFail() statements (good - means tests are implemented)${NC}"
else
    echo -e "${YELLOW}⚠️  Found $fail_count XCTFail() statements${NC}"
fi

# Count assertions
assert_count=$(grep -c "XCTAssert" "$OUTPUT_FILE" || echo "0")
echo -e "${BLUE}ℹ️  Found $assert_count XCTAssert statements${NC}"

# Count test methods
test_method_count=$(grep -c "func test" "$OUTPUT_FILE" || echo "0")
echo -e "${BLUE}ℹ️  Found $test_method_count test methods${NC}"

# Check for placeholders
if grep -qE "(placeholder|testValue|FIXME|IMPLEMENT)" "$OUTPUT_FILE"; then
    echo -e "${RED}⚠️  Found placeholder text in generated code${NC}"
else
    echo -e "${GREEN}✅ No obvious placeholder text found${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Test generation complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
