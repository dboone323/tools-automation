#!/usr/bin/env bash
# Batch test generator - generates tests in batches of 20 files
# Continues from where it left off by skipping existing tests

set -eo pipefail # Note: removed 'u' to allow unset counting variables

WORKSPACE_ROOT="/Users/danielstevens/Desktop/Quantum-workspace"
MOMENTUM_PATH="${WORKSPACE_ROOT}/Projects/MomentumFinance"
TEST_DIR="${MOMENTUM_PATH}/MomentumFinanceTests"
OLLAMA_MODEL="qwen2.5-coder:1.5b"
OLLAMA_URL="http://localhost:11434"
BATCH_SIZE=20

echo "🔄 Batch Test Generation - MomentumFinance"
echo "═══════════════════════════════════════════════════════════"
echo "Batch size: $BATCH_SIZE files"
echo ""

# Check Ollama
if ! curl -s "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
    echo "❌ Ollama not running"
    exit 1
fi

mkdir -p "$TEST_DIR"

# Find all source files
mapfile -t all_files < <(find "$MOMENTUM_PATH" -name "*.swift" \
    -not -path "*/Tests/*" \
    -not -path "*/UITests/*" \
    -not -path "*/.build/*" \
    -not -name "*Tests.swift" \
    2>/dev/null)

echo "📁 Total source files: ${#all_files[@]}"

# Filter to files without tests
files_to_test=()
for source_file in "${all_files[@]}"; do
    filename=$(basename "$source_file" .swift)
    test_file="$TEST_DIR/${filename}Tests.swift"

    # Skip if test exists or is system file
    if [[ ! -f "$test_file" ]] && [[ ! "$filename" =~ ^(main|App|Package|ContentView)$ ]]; then
        files_to_test+=("$source_file")
    fi
done

echo "📋 Files needing tests: ${#files_to_test[@]}"
echo "🎯 Will process: $((${#files_to_test[@]} < BATCH_SIZE ? ${#files_to_test[@]} : BATCH_SIZE)) files in this batch"
echo ""

# Process batch
count=0
generated=0
errors=0

for source_file in "${files_to_test[@]}"; do
    if [[ $count -ge $BATCH_SIZE ]]; then
        break
    fi

    count=$((count + 1))
    filename=$(basename "$source_file" .swift)
    test_file="$TEST_DIR/${filename}Tests.swift"

    echo "[$count/$BATCH_SIZE] 🔨 $filename..."

    # Read source
    source_code=$(head -150 "$source_file" 2>/dev/null || true)

    if [[ -z "$source_code" ]]; then
        echo "[$count/$BATCH_SIZE] ⚠️  Empty file, skipping"
        continue
    fi

    # Generate with Ollama
    prompt="Generate comprehensive XCTest unit tests for this Swift file from MomentumFinance.

File: ${filename}.swift
Code:
${source_code}

Requirements:
- Import XCTest and @testable import MomentumFinance
- Use @MainActor for ViewModels
- Test all public methods and properties
- Use real test data with specific values, NO TODOs or placeholders
- Multiple XCTAssert statements per test
- Proper setUp() and tearDown() methods
- GIVEN/WHEN/THEN or Arrange/Act/Assert pattern
- Comments explaining test purpose"

    response=$(curl -s -X POST "${OLLAMA_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"${OLLAMA_MODEL}\",
            \"prompt\": $(jq -n --arg p "$prompt" '$p'),
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.2,
                \"num_predict\": 1000
            }
        }" 2>&1)

    test_code=$(echo "$response" | jq -r '.response' 2>/dev/null || echo "")

    if [[ -n "$test_code" ]] && [[ "$test_code" != "null" ]]; then
        # Clean and write
        echo "$test_code" | sed -e 's/^```swift//g' -e 's/^```//g' >"$test_file"
        echo "[$count/$BATCH_SIZE] ✅ Generated"
        generated=$((generated + 1))
    else
        echo "[$count/$BATCH_SIZE] ❌ Failed"
        errors=$((errors + 1))
    fi

    # Rate limit
    sleep 0.8
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Batch Complete!"
echo "   Generated: $generated tests"
echo "   Errors: $errors"
echo "   Remaining: $((${#files_to_test[@]} - count)) files"
echo ""

if [[ $((${#files_to_test[@]} - count)) -gt 0 ]]; then
    echo "💡 Run this script again to continue with next batch"
fi
