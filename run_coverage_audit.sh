#!/bin/bash

# Coverage Audit Script for Comprehensive Build & Test Infrastructure
# Runs coverage analysis on all 5 projects with proper simulator/platform configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE_ROOT="/Users/danielstevens/Desktop/Quantum-workspace"
IOS_SIMULATOR="iPhone 17"
COVERAGE_RESULTS_DIR="${WORKSPACE_ROOT}/coverage_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Project configurations (name, path, scheme, platform)
declare -A PROJECTS=(
    ["AvoidObstaclesGame"]="${WORKSPACE_ROOT}/Projects/AvoidObstaclesGame|AvoidObstaclesGame|iOS"
    ["CodingReviewer"]="${WORKSPACE_ROOT}/Projects/CodingReviewer|CodingReviewer|macOS"
    ["PlannerApp"]="${WORKSPACE_ROOT}/Projects/PlannerApp|PlannerApp|macOS"
    ["MomentumFinance"]="${WORKSPACE_ROOT}/Projects/MomentumFinance|MomentumFinance|macOS"
    ["HabitQuest"]="${WORKSPACE_ROOT}/Projects/HabitQuest|HabitQuest|iOS"
)

# Create coverage results directory
mkdir -p "${COVERAGE_RESULTS_DIR}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Coverage Audit - Started${NC}"
echo -e "${BLUE}  Timestamp: ${TIMESTAMP}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Summary tracking
declare -A COVERAGE_SUMMARY
declare -A BUILD_TIMES
declare -A TEST_TIMES
TOTAL_PROJECTS=0
SUCCESSFUL_PROJECTS=0
FAILED_PROJECTS=0

# Function to run coverage for a project
run_coverage() {
    local project_name=$1
    local project_info=${PROJECTS[$project_name]}
    IFS='|' read -r project_path scheme platform <<< "$project_info"
    
    echo -e "${YELLOW}----------------------------------------${NC}"
    echo -e "${YELLOW}Project: ${project_name}${NC}"
    echo -e "${YELLOW}Platform: ${platform}${NC}"
    echo -e "${YELLOW}----------------------------------------${NC}"
    
    TOTAL_PROJECTS=$((TOTAL_PROJECTS + 1))
    
    # Set destination based on platform
    local destination
    if [[ "$platform" == "iOS" ]]; then
        destination="platform=iOS Simulator,name=${IOS_SIMULATOR},OS=latest"
    else
        destination="platform=macOS"
    fi
    
    # Project-specific directory
    local project_result_dir="${COVERAGE_RESULTS_DIR}/${project_name}_${TIMESTAMP}"
    mkdir -p "${project_result_dir}"
    
    cd "${project_path}"
    
    # Check if xcodeproj exists
    if [[ ! -d "${project_name}.xcodeproj" ]]; then
        echo -e "${RED}✗ No Xcode project found for ${project_name}${NC}"
        FAILED_PROJECTS=$((FAILED_PROJECTS + 1))
        COVERAGE_SUMMARY[$project_name]="ERROR: No Xcode project"
        return 1
    fi
    
    echo "Building and testing with coverage..."
    local start_time=$(date +%s)
    
    # Run tests with coverage
    if xcodebuild test \
        -project "${project_name}.xcodeproj" \
        -scheme "${scheme}" \
        -destination "${destination}" \
        -enableCodeCoverage YES \
        -resultBundlePath "${project_result_dir}/TestResults.xcresult" \
        > "${project_result_dir}/build.log" 2>&1; then
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        BUILD_TIMES[$project_name]=$duration
        
        echo -e "${GREEN}✓ Build and tests completed (${duration}s)${NC}"
        
        # Extract coverage data
        if [[ -d "${project_result_dir}/TestResults.xcresult" ]]; then
            echo "Extracting coverage data..."
            
            # Use xcrun to extract coverage report
            xcrun xccov view --report --json "${project_result_dir}/TestResults.xcresult" \
                > "${project_result_dir}/coverage.json" 2>/dev/null || true
            
            # Parse coverage percentage
            if [[ -f "${project_result_dir}/coverage.json" ]]; then
                local coverage=$(python3 -c "
import json, sys
try:
    with open('${project_result_dir}/coverage.json') as f:
        data = json.load(f)
        if 'lineCoverage' in data:
            print(f\"{data['lineCoverage'] * 100:.2f}\")
        else:
            print('0.00')
except:
    print('0.00')
")
                COVERAGE_SUMMARY[$project_name]="${coverage}%"
                echo -e "${GREEN}✓ Coverage: ${coverage}%${NC}"
                
                # Generate human-readable report
                xcrun xccov view --report "${project_result_dir}/TestResults.xcresult" \
                    > "${project_result_dir}/coverage_report.txt" 2>/dev/null || true
            else
                COVERAGE_SUMMARY[$project_name]="N/A"
                echo -e "${YELLOW}⚠ Coverage data extraction failed${NC}"
            fi
            
            # Count test results
            local test_count=$(grep -o "Test Case.*passed" "${project_result_dir}/build.log" | wc -l || echo "0")
            local test_time=$(grep "Test Suite.*passed" "${project_result_dir}/build.log" | tail -1 | grep -o "[0-9.]*seconds" || echo "0s")
            TEST_TIMES[$project_name]="${test_count} tests in ${test_time}"
            
        else
            COVERAGE_SUMMARY[$project_name]="N/A (no results)"
            echo -e "${YELLOW}⚠ No test results bundle generated${NC}"
        fi
        
        SUCCESSFUL_PROJECTS=$((SUCCESSFUL_PROJECTS + 1))
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        BUILD_TIMES[$project_name]="${duration}s (failed)"
        
        echo -e "${RED}✗ Build or tests failed${NC}"
        FAILED_PROJECTS=$((FAILED_PROJECTS + 1))
        COVERAGE_SUMMARY[$project_name]="FAILED"
        
        # Extract error information
        if [[ -f "${project_result_dir}/build.log" ]]; then
            echo -e "${RED}Last 20 lines of build log:${NC}"
            tail -20 "${project_result_dir}/build.log"
        fi
    fi
    
    echo ""
}

# Run coverage for all projects
for project in "${!PROJECTS[@]}"; do
    run_coverage "$project"
done

# Generate comprehensive summary report
SUMMARY_FILE="${COVERAGE_RESULTS_DIR}/coverage_audit_summary_${TIMESTAMP}.md"

cat > "${SUMMARY_FILE}" << EOF
# Coverage Audit Summary

**Date**: $(date -u +'%Y-%m-%d %H:%M:%S UTC')  
**Audit ID**: ${TIMESTAMP}

---

## Executive Summary

- **Total Projects Audited**: ${TOTAL_PROJECTS}
- **Successful Builds**: ${SUCCESSFUL_PROJECTS}
- **Failed Builds**: ${FAILED_PROJECTS}
- **Success Rate**: $(awk "BEGIN {printf \"%.1f\", (${SUCCESSFUL_PROJECTS}/${TOTAL_PROJECTS})*100}")%

---

## Coverage Results by Project

| Project | Coverage | Build Time | Test Results | Status |
|---------|----------|------------|--------------|--------|
EOF

# Add project rows
for project in $(echo "${!PROJECTS[@]}" | tr ' ' '\n' | sort); do
    local coverage="${COVERAGE_SUMMARY[$project]:-N/A}"
    local build_time="${BUILD_TIMES[$project]:-N/A}"
    local test_time="${TEST_TIMES[$project]:-N/A}"
    
    local status
    if [[ "$coverage" == "FAILED" ]] || [[ "$coverage" == "ERROR:"* ]]; then
        status="❌ Failed"
    elif [[ "$coverage" == "N/A"* ]]; then
        status="⚠️ No Coverage"
    else
        # Parse coverage percentage
        local cov_num=$(echo "$coverage" | grep -o "[0-9.]*" || echo "0")
        if (( $(echo "$cov_num >= 85" | bc -l) )); then
            status="✅ Passing"
        elif (( $(echo "$cov_num >= 70" | bc -l) )); then
            status="⚠️ Warning"
        else
            status="❌ Below Target"
        fi
    fi
    
    echo "| ${project} | ${coverage} | ${build_time} | ${test_time} | ${status} |" >> "${SUMMARY_FILE}"
done

cat >> "${SUMMARY_FILE}" << EOF

---

## Coverage Targets

- **Minimum Required**: 85%
- **Target**: 90%
- **Aspirational**: 100%

## Performance Baselines

- **Build Time Target**: <120s per project
- **Test Execution Target**: <30s per project

## Gaps Identified

EOF

# Identify gaps
for project in $(echo "${!PROJECTS[@]}" | tr ' ' '\n' | sort); do
    local coverage="${COVERAGE_SUMMARY[$project]}"
    if [[ "$coverage" == "FAILED" ]] || [[ "$coverage" == "ERROR:"* ]]; then
        echo "- **${project}**: Build/test failure - requires immediate attention" >> "${SUMMARY_FILE}"
    elif [[ "$coverage" == "N/A"* ]]; then
        echo "- **${project}**: No coverage data available - test infrastructure may be missing" >> "${SUMMARY_FILE}"
    else
        local cov_num=$(echo "$coverage" | grep -o "[0-9.]*" || echo "0")
        if (( $(echo "$cov_num < 85" | bc -l) )); then
            local gap=$(echo "85 - $cov_num" | bc)
            echo "- **${project}**: Coverage ${coverage} is ${gap}% below minimum (85%)" >> "${SUMMARY_FILE}"
        fi
    fi
done

cat >> "${SUMMARY_FILE}" << EOF

---

## Next Steps

1. **Address Failed Builds**: Fix compilation/test failures in projects marked as Failed
2. **Add Missing Tests**: Create test infrastructure for projects with N/A coverage
3. **Improve Coverage**: Add tests to projects below 85% minimum threshold
4. **Optimize Performance**: Reduce build times for projects exceeding 120s target

## Detailed Results

Individual project results available in:
\`${COVERAGE_RESULTS_DIR}\`

Each project directory contains:
- \`TestResults.xcresult\`: Complete Xcode test results bundle
- \`coverage.json\`: Machine-readable coverage data
- \`coverage_report.txt\`: Human-readable coverage report
- \`build.log\`: Complete build and test output

EOF

# Print summary to console
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Coverage Audit - Completed${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Summary Report: ${SUMMARY_FILE}${NC}"
echo ""
echo "Coverage Results:"
for project in $(echo "${!PROJECTS[@]}" | tr ' ' '\n' | sort); do
    local coverage="${COVERAGE_SUMMARY[$project]}"
    if [[ "$coverage" == "FAILED" ]] || [[ "$coverage" == "ERROR:"* ]]; then
        echo -e "  ${RED}✗ ${project}: ${coverage}${NC}"
    elif [[ "$coverage" == "N/A"* ]]; then
        echo -e "  ${YELLOW}⚠ ${project}: ${coverage}${NC}"
    else
        echo -e "  ${GREEN}✓ ${project}: ${coverage}${NC}"
    fi
done
echo ""
echo -e "${BLUE}Next: Review summary report and address identified gaps${NC}"
