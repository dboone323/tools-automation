#!/bin/bash

# analyze_coverage.sh
# Comprehensive coverage analysis for Quantum workspace
# Analyzes Swift projects, Python scripts, and Shell scripts

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

WORKSPACE_ROOT="/Users/danielstevens/Desktop/Quantum-workspace"
COVERAGE_DIR="$HOME/.quantum-workspace/artifacts/coverage"
REPORT_FILE="$COVERAGE_DIR/coverage_report_$(date +%Y%m%d_%H%M%S).md"

mkdir -p "$COVERAGE_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         📊 Quantum Workspace Coverage Analysis                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Initialize report
cat >"$REPORT_FILE" <<'EOF'
# Quantum Workspace Coverage Report
Generated: $(date)

## Executive Summary

### Coverage Targets
- **All Projects**: 85% minimum
- **Agents/Workflows/AI**: 100% target
- **Current Quality Gate**: 85% minimum (blocking)

EOF

# Function to count Swift files and tests
analyze_swift_project() {
    local project_name=$1
    local project_path=$2

    echo -e "${YELLOW}📱 Analyzing $project_name...${NC}"

    # Count source files
    local source_files=$(find "$project_path" -name "*.swift" ! -path "*/Tests/*" ! -path "*/UITests/*" ! -name "*Tests.swift" 2>/dev/null | wc -l | tr -d ' ')

    # Count test files
    local test_files=$(find "$project_path" -name "*Tests.swift" 2>/dev/null | wc -l | tr -d ' ')

    # Calculate test ratio (rough proxy for coverage)
    local test_ratio=0
    if [ "$source_files" -gt 0 ]; then
        test_ratio=$((test_files * 100 / source_files))
    fi

    # List untested files (files without corresponding test files)
    local untested_files=$(find "$project_path" -name "*.swift" ! -path "*/Tests/*" ! -path "*/UITests/*" ! -name "*Tests.swift" ! -name "App.swift" ! -name "ContentView.swift" 2>/dev/null | while read -r file; do
        local filename=$(basename "$file" .swift)
        local test_file="${filename}Tests.swift"
        if ! find "$project_path" -name "$test_file" 2>/dev/null | grep -q .; then
            echo "  - $(basename "$file")"
        fi
    done)

    local status_icon="❌"
    [ "$test_ratio" -ge 85 ] && status_icon="✅"
    [ "$test_ratio" -ge 70 ] && [ "$test_ratio" -lt 85 ] && status_icon="⚠️"

    echo -e "  Source files: $source_files"
    echo -e "  Test files: $test_files"
    echo -e "  Test ratio: ${test_ratio}% $status_icon"

    cat >>"$REPORT_FILE" <<EOF

### $project_name
- **Source Files**: $source_files
- **Test Files**: $test_files
- **Test Coverage Proxy**: ${test_ratio}%
- **Status**: $status_icon $([ "$test_ratio" -ge 85 ] && echo "PASS" || echo "NEEDS IMPROVEMENT")

#### Untested Files
$untested_files

EOF
}

# Function to analyze Python scripts
analyze_python_coverage() {
    echo -e "${YELLOW}🐍 Analyzing Python scripts...${NC}"

    # Collect python files and test files once to avoid nested scans
    local tmp_all py_modules tmp_tests test_modules
    tmp_all=$(mktemp)
    py_modules=$(mktemp)
    tmp_tests=$(mktemp)
    test_modules=$(mktemp)

    # All Python files under Tools (excluding __init__.py for module list)
    find "$WORKSPACE_ROOT/Tools" -type f -name "*.py" 2>/dev/null > "$tmp_all"
    # Derive non-test module basenames
    grep -v "/__init__\.py$" "$tmp_all" | grep -v "/test_.*\.py$" | grep -v "/_test\.py$" | xargs -I{} basename {} | sed 's/\.py$//' | sort -u > "$py_modules"

    # Test files list
    grep -E "/(test_.*\.py|.*_test\.py)$" "$tmp_all" | xargs -I{} basename {} | sort -u > "$tmp_tests"
    # Normalize test names to the module names they test
    # Strip leading 'test_' or trailing '_test' and .py
    awk '{n=$0; sub(/^test_/, "", n); sub(/\.py$/, "", n); sub(/_test$/, "", n); print n}' "$tmp_tests" | sort -u > "$test_modules"

    local python_files python_tests
    python_files=$(wc -l < "$tmp_all" | tr -d ' ')
    python_tests=$(wc -l < "$tmp_tests" | tr -d ' ')

    echo -e "  Python files: $python_files"
    echo -e "  Python tests: $python_tests"

    cat >>"$REPORT_FILE" <<EOF

### Python Scripts (Tools/Automation)
- **Python Files**: $python_files
- **Test Files**: $python_tests
- **Status**: $([ "$python_tests" -ge 3 ] && echo "✅ Good test coverage" || echo "❌ Needs more tests")

#### Python Files Requiring Tests
EOF

    # Compute non-test modules minus tested modules
    comm -23 "$py_modules" "$test_modules" | while read -r mod; do
        # Reconstruct possible source filename
        # Find first match of module name under Tools
        src=$(grep -E "/${mod}\.py$" "$tmp_all" | head -1)
        if [ -n "$src" ]; then
            echo "- $(basename "$src")" >> "$REPORT_FILE"
        fi
    done

    rm -f "$tmp_all" "$py_modules" "$tmp_tests" "$test_modules"
}

# Function to analyze Shell scripts
analyze_shell_coverage() {
    echo -e "${YELLOW}🔧 Analyzing Shell scripts...${NC}"

    local shell_files=$(find "$WORKSPACE_ROOT/Tools/Automation" -name "*.sh" ! -name "test_*.sh" 2>/dev/null | wc -l | tr -d ' ')
    local shell_tests=$(find "$WORKSPACE_ROOT/Tools/Automation" -name "test_*.sh" 2>/dev/null | wc -l | tr -d ' ')

    echo -e "  Shell files: $shell_files"
    echo -e "  Shell tests: $shell_tests"

    cat >>"$REPORT_FILE" <<EOF

### Shell Scripts (Tools/Automation)
- **Shell Files**: $shell_files
- **Test Files**: $shell_tests
- **Status**: $([ "$shell_tests" -ge 5 ] && echo "✅ Good test coverage" || echo "❌ Needs more tests")

#### Critical Shell Scripts Requiring Tests
EOF

    # List critical scripts
    critical_scripts=(
        "local_ci_orchestrator.sh"
        "master_automation.sh"
        "setup_free_only.sh"
    )

    for script in "${critical_scripts[@]}"; do
        if [ -f "$WORKSPACE_ROOT/Tools/Automation/$script" ]; then
            echo "- $script (100% coverage required)" >>"$REPORT_FILE"
        fi
    done
}

# Function to analyze agent scripts
analyze_agents() {
    echo -e "${YELLOW}🤖 Analyzing agent scripts...${NC}"

    local agent_dir="$WORKSPACE_ROOT/Tools/Automation/agents"
    if [ -d "$agent_dir" ]; then
        local agent_files=$(find "$agent_dir" -type f \( -name "*.sh" -o -name "*.py" \) 2>/dev/null | wc -l | tr -d ' ')
        local agent_tests=$(find "$agent_dir" -type f -name "test_*" 2>/dev/null | wc -l | tr -d ' ')

        echo -e "  Agent files: $agent_files"
        echo -e "  Agent tests: $agent_tests"

        cat >>"$REPORT_FILE" <<EOF

### Agent Scripts (100% Coverage Required)
- **Agent Files**: $agent_files
- **Test Files**: $agent_tests
- **Status**: $([ "$agent_tests" -ge "$agent_files" ] && echo "✅ Full coverage" || echo "❌ CRITICAL: Needs 100% coverage")

#### Agent Files Requiring Tests
EOF

        find "$agent_dir" -type f \( -name "*.sh" -o -name "*.py" \) ! -name "test_*" 2>/dev/null | while read -r file; do
            echo "- $(basename "$file")" >>"$REPORT_FILE"
        done
    else
        echo -e "  ${YELLOW}No agent directory found${NC}"
        cat >>"$REPORT_FILE" <<EOF

### Agent Scripts
- **Status**: ⚠️ No agent directory found

EOF
    fi
}

# Analyze each Swift project
echo ""
analyze_swift_project "HabitQuest" "$WORKSPACE_ROOT/Projects/HabitQuest"
echo ""
analyze_swift_project "MomentumFinance" "$WORKSPACE_ROOT/Projects/MomentumFinance"
echo ""
analyze_swift_project "PlannerApp" "$WORKSPACE_ROOT/Projects/PlannerApp"
echo ""
analyze_swift_project "AvoidObstaclesGame" "$WORKSPACE_ROOT/Projects/AvoidObstaclesGame"
echo ""
analyze_swift_project "CodingReviewer" "$WORKSPACE_ROOT/Projects/CodingReviewer"

# Analyze Python and Shell scripts
echo ""
analyze_python_coverage
echo ""
analyze_shell_coverage
echo ""
analyze_agents

# Add recommendations section
cat >>"$REPORT_FILE" <<'EOF'

## Recommendations

### Immediate Actions (Priority 1)
1. **Agents/Workflows**: Achieve 100% test coverage for all agent scripts
2. **HabitQuest**: Add tests for untested components to reach 85%
3. **MomentumFinance**: Add tests for untested components to reach 85%
4. **PlannerApp**: Add tests for untested components to reach 85%

### Short-term Actions (Priority 2)
1. **CodingReviewer**: Improve test coverage from current to 85%
2. **AvoidObstaclesGame**: Add comprehensive game logic tests
3. **Shell Scripts**: Add test scripts for critical automation

### Long-term Actions (Priority 3)
1. **Integration Tests**: Add end-to-end tests for all projects
2. **Performance Tests**: Add benchmark tests with coverage
3. **UI Tests**: Increase UI test coverage to 70%

## Next Steps

1. Run `./Tools/Automation/generate_missing_tests.sh` to auto-generate test stubs
2. Update `quality-config.yaml` to enforce 85% minimum coverage
3. Integrate coverage checks into `local_ci_orchestrator.sh`
4. Set up coverage monitoring in daily cron job

EOF

echo ""
echo -e "${GREEN}✅ Coverage analysis complete!${NC}"
echo -e "${BLUE}📄 Report saved to: $REPORT_FILE${NC}"
echo ""
echo -e "${YELLOW}View report: cat $REPORT_FILE${NC}"
echo ""

# Display summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                    Coverage Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
cat "$REPORT_FILE" | grep -A 4 "^### " | head -50
echo ""
