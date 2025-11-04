#!/usr/bin/env bash
# Quick test generation for first 5 high-priority files in MomentumFinance

set -euo pipefail

WORKSPACE_ROOT="/Users/danielstevens/Desktop/Quantum-workspace"
MOMENTUM_PATH="${WORKSPACE_ROOT}/Projects/MomentumFinance"
TEST_DIR="${MOMENTUM_PATH}/MomentumFinanceTests"
OLLAMA_MODEL="qwen2.5-coder:1.5b"
OLLAMA_URL="http://localhost:11434"

echo "🚀 Quick Test Generation - MomentumFinance (First 5 Files)"
echo "═══════════════════════════════════════════════════════════"

# Check Ollama
if ! curl -s "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
    echo "❌ Ollama not running"
    exit 1
fi
echo "✅ Ollama available"

# Find first 5 high-priority files
mapfile -t files < <(find "$MOMENTUM_PATH" -name "*.swift" \
    -not -path "*/Tests/*" \
    -not -path "*/UITests/*" \
    -not -path "*/.build/*" \
    -not -name "*Tests.swift" \
    2>/dev/null | head -10)

echo "📁 Found ${#files[@]} files to process"
mkdir -p "$TEST_DIR"

count=0
generated=0

for source_file in "${files[@]}"; do
    count=$((count + 1))
    filename=$(basename "$source_file" .swift)
    test_file="$TEST_DIR/${filename}Tests.swift"

    # Skip if test exists
    if [[ -f "$test_file" ]]; then
        echo "[$count] ⏭️  $filename (test exists)"
        continue
    fi

    # Skip system files
    if [[ "$filename" =~ ^(main|App|Package|ContentView)$ ]]; then
        echo "[$count] ⏭️  $filename (system file)"
        continue
    fi

    echo "[$count] 🔨 Generating test for $filename..."

    # Read source (handle SIGPIPE gracefully)
    source_code=$(head -100 "$source_file" 2>/dev/null || true)

    # Generate with Ollama
    prompt="Generate comprehensive XCTest unit tests for this Swift file.

File: ${filename}.swift
Code preview:
${source_code}

Requirements:
- Import XCTest and @testable import MomentumFinance
- Test all public methods
- Use real test data, no TODOs
- Multiple assertions per test
- Proper setup/tearDown"

    response=$(curl -s -X POST "${OLLAMA_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"${OLLAMA_MODEL}\",
            \"prompt\": $(jq -n --arg p "$prompt" '$p'),
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.2,
                \"num_predict\": 800
            }
        }" 2>&1)

    test_code=$(echo "$response" | jq -r '.response' 2>/dev/null || echo "")

    if [[ -n "$test_code" ]] && [[ "$test_code" != "null" ]]; then
        # Clean and write
        echo "$test_code" | sed -e 's/^```swift//g' -e 's/^```//g' >"$test_file"
        echo "[$count] ✅ Generated $test_file"
        generated=$((generated + 1))
    else
        echo "[$count] ❌ Failed to generate test"
    fi

    # Rate limit
    sleep 1
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Complete: Generated $generated tests from $count files"
echo "📁 Tests saved to: $TEST_DIR"
echo ""
echo "Next: Review and add to Xcode project"
