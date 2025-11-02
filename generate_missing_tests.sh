#!/bin/bash

# generate_missing_tests.sh
# Auto-generates test stubs for untested Swift files using Ollama

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORKSPACE_ROOT="/Users/danielstevens/Desktop/Quantum-workspace"
OLLAMA_MODEL="qwen2.5-coder:1.5b"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         🧪 Test Generation System (Ollama-Powered)            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check Ollama availability
if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo -e "${RED}❌ Ollama is not running${NC}"
    echo -e "${YELLOW}Start Ollama with: ollama serve${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Ollama is ready${NC}"
echo ""

# Function to generate test for a Swift file
generate_swift_test() {
    local source_file=$1
    local project_name=$2
    local relative_path=$3

    local filename=$(basename "$source_file" .swift)
    local test_filename="${filename}Tests.swift"

    # Determine test directory
    local test_dir
    if [[ "$project_name" == "HabitQuest" ]]; then
        test_dir="$WORKSPACE_ROOT/Projects/HabitQuest/HabitQuestTests"
    elif [[ "$project_name" == "MomentumFinance" ]]; then
        test_dir="$WORKSPACE_ROOT/Projects/MomentumFinance/MomentumFinanceTests"
    elif [[ "$project_name" == "PlannerApp" ]]; then
        test_dir="$WORKSPACE_ROOT/Projects/PlannerApp/PlannerAppTests"
    elif [[ "$project_name" == "AvoidObstaclesGame" ]]; then
        test_dir="$WORKSPACE_ROOT/Projects/AvoidObstaclesGame/AvoidObstaclesGameTests"
    elif [[ "$project_name" == "CodingReviewer" ]]; then
        test_dir="$WORKSPACE_ROOT/Projects/CodingReviewer/Tests/CodingReviewerTests"
    else
        echo -e "${RED}Unknown project: $project_name${NC}"
        return 1
    fi

    local test_file="$test_dir/$test_filename"

    # Skip if test already exists
    if [ -f "$test_file" ]; then
        echo -e "  ${YELLOW}⏭️  Skipping $filename (test exists)${NC}"
        return 0
    fi

    # Skip certain files
    if [[ "$filename" == "main" ]] || [[ "$filename" == "Package" ]] || [[ "$filename" == "App" ]] || [[ "$filename" == "ContentView" ]]; then
        echo -e "  ${YELLOW}⏭️  Skipping $filename (system file)${NC}"
        return 0
    fi

    echo -e "  ${BLUE}🔨 Generating test for $filename...${NC}"

    # Read source file
    local source_code=$(cat "$source_file" 2>/dev/null || echo "")

    if [ -z "$source_code" ]; then
        echo -e "  ${RED}❌ Could not read source file${NC}"
        return 1
    fi

    # Generate test using Ollama
    local prompt="Generate comprehensive XCTest unit tests for the following Swift code. Include tests for:
- All public methods and functions
- Edge cases and error conditions
- State management if applicable
- Follow Swift testing best practices
- Use @MainActor where needed for SwiftUI ViewModels
- Include setup/teardown if needed

Source code:
\`\`\`swift
${source_code:0:4000}
\`\`\`

Generate ONLY the test file code with proper imports. Start with:
import XCTest
@testable import $project_name"

    local test_code=$(curl -s -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$OLLAMA_MODEL\",
            \"prompt\": $(echo "$prompt" | jq -Rs .),
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.3,
                \"num_predict\": 1000
            }
        }" | jq -r '.response' 2>/dev/null || echo "")

    if [ -z "$test_code" ]; then
        echo -e "  ${RED}❌ Failed to generate test${NC}"
        return 1
    fi

    # Create test file
    mkdir -p "$test_dir"

    # Clean up and format the generated code
    echo "$test_code" | sed '/```/d' >"$test_file"

    echo -e "  ${GREEN}✅ Created $test_filename${NC}"

    return 0
}

# Function to generate tests for a project
generate_project_tests() {
    local project_name=$1
    local project_path=$2
    local max_tests=${3:-10} # Limit number of tests to generate

    echo -e "${YELLOW}📱 Generating tests for $project_name (max: $max_tests)...${NC}"
    echo ""

    local count=0

    # Find Swift files without tests
    find "$project_path" -name "*.swift" \
        ! -path "*/Tests/*" \
        ! -path "*/UITests/*" \
        ! -name "*Tests.swift" \
        ! -name "*.generated.swift" \
        2>/dev/null | while read -r file && [ $count -lt $max_tests ]; do

        local filename=$(basename "$file" .swift)
        local test_file="${filename}Tests.swift"

        # Check if test exists
        if ! find "$project_path" -name "$test_file" 2>/dev/null | grep -q .; then
            local relative_path=$(echo "$file" | sed "s|$project_path/||")
            generate_swift_test "$file" "$project_name" "$relative_path"
            count=$((count + 1))

            # Small delay to avoid overwhelming Ollama
            sleep 1
        fi
    done

    echo ""
    echo -e "${GREEN}✅ Generated $count tests for $project_name${NC}"
    echo ""
}

# Main execution
echo -e "${YELLOW}Select project to generate tests for:${NC}"
echo "1) HabitQuest (Current: 40%, Target: 85%)"
echo "2) MomentumFinance (Current: 4%, Target: 85%) - CRITICAL"
echo "3) PlannerApp (Current: 8%, Target: 85%)"
echo "4) AvoidObstaclesGame (Current: 32%, Target: 85%)"
echo "5) CodingReviewer (Current: 68%, Target: 85%)"
echo "6) All projects (batch mode - 5 tests per project)"
echo ""
read -p "Enter choice [1-6]: " choice

case $choice in
1)
    generate_project_tests "HabitQuest" "$WORKSPACE_ROOT/Projects/HabitQuest" 15
    ;;
2)
    generate_project_tests "MomentumFinance" "$WORKSPACE_ROOT/Projects/MomentumFinance" 20
    ;;
3)
    generate_project_tests "PlannerApp" "$WORKSPACE_ROOT/Projects/PlannerApp" 15
    ;;
4)
    generate_project_tests "AvoidObstaclesGame" "$WORKSPACE_ROOT/Projects/AvoidObstaclesGame" 15
    ;;
5)
    generate_project_tests "CodingReviewer" "$WORKSPACE_ROOT/Projects/CodingReviewer" 10
    ;;
6)
    echo -e "${YELLOW}Running batch mode (5 tests per project)...${NC}"
    echo ""
    generate_project_tests "HabitQuest" "$WORKSPACE_ROOT/Projects/HabitQuest" 5
    generate_project_tests "MomentumFinance" "$WORKSPACE_ROOT/Projects/MomentumFinance" 5
    generate_project_tests "PlannerApp" "$WORKSPACE_ROOT/Projects/PlannerApp" 5
    generate_project_tests "AvoidObstaclesGame" "$WORKSPACE_ROOT/Projects/AvoidObstaclesGame" 5
    generate_project_tests "CodingReviewer" "$WORKSPACE_ROOT/Projects/CodingReviewer" 5
    ;;
*)
    echo -e "${RED}Invalid choice${NC}"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✅ Test Generation Complete!                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review generated tests and fix any compilation errors"
echo "2. Run tests: xcodebuild test -scheme <ProjectName>"
echo "3. Refine tests as needed for edge cases"
echo "4. Run coverage analysis: ./Tools/Automation/analyze_coverage.sh"
echo ""
