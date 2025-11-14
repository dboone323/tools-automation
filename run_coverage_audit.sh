#!/bin/bash

# Coverage Audit Script for Comprehensive Build & Test Infrastructure
# Runs coverage analysis on all 5 projects with proper simulator/platform configuration

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
IOS_SIMULATOR="iPhone 16 Test"
COVERAGE_RESULTS_DIR="${WORKSPACE_ROOT}/coverage_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Project configurations (name|path|scheme|platform)
# NOTE: Avoid bash associative arrays for cross-platform compatibility
PROJECTS_LIST=(
    "AvoidObstaclesGame|${WORKSPACE_ROOT}/Projects/AvoidObstaclesGame|AvoidObstaclesGame|iOS"
    "CodingReviewer|${WORKSPACE_ROOT}/Projects/CodingReviewer|CodingReviewer|macOS"
    "PlannerApp|${WORKSPACE_ROOT}/Projects/PlannerApp|PlannerApp|macOS"
    "MomentumFinance|${WORKSPACE_ROOT}/Projects/MomentumFinance|MomentumFinance|macOS"
    "HabitQuest|${WORKSPACE_ROOT}/Projects/HabitQuest|HabitQuest|iOS"
)

# Create coverage results directory
mkdir -p "${COVERAGE_RESULTS_DIR}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Coverage Audit - Started${NC}"
echo -e "${BLUE}  Timestamp: ${TIMESTAMP}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Summary tracking (use temp files instead of associative arrays)
SUMMARY_DIR="${COVERAGE_RESULTS_DIR}/.summary_${TIMESTAMP}"
mkdir -p "${SUMMARY_DIR}"
COVERAGE_SUMMARY_FILE="${SUMMARY_DIR}/coverage_summary.tsv" # project\tcoverage
BUILD_TIMES_FILE="${SUMMARY_DIR}/build_times.tsv"           # project\ttime
TEST_TIMES_FILE="${SUMMARY_DIR}/test_times.tsv"             # project\ttests
# Initialize summary files (use no-op to satisfy ShellCheck SC2188)
: >"${COVERAGE_SUMMARY_FILE}" || true
: >"${BUILD_TIMES_FILE}" || true
: >"${TEST_TIMES_FILE}" || true
TOTAL_PROJECTS=0
SUCCESSFUL_PROJECTS=0
FAILED_PROJECTS=0

# Function to run coverage for a project
run_coverage() {
    local project_name=$1
    local project_path=$2
    local scheme=$3
    local platform=$4

    echo -e "${YELLOW}----------------------------------------${NC}"
    echo -e "${YELLOW}Project: ${project_name}${NC}"
    echo -e "${YELLOW}Platform: ${platform}${NC}"
    echo -e "${YELLOW}----------------------------------------${NC}"

    TOTAL_PROJECTS=$((TOTAL_PROJECTS + 1))

    # Set destination based on platform (with fallback if iOS simulators unavailable)
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

    # Determine build mode: Xcode project vs SPM (workspace/scheme only)
    local spm_mode="false"
    local has_xcodeproj="false"
    if [[ -d "${project_name}.xcodeproj" ]]; then
        has_xcodeproj="true"
    elif [[ -f "Package.swift" ]]; then
        spm_mode="true"
    fi

    if [[ "${has_xcodeproj}" != "true" && "${spm_mode}" != "true" ]]; then
        echo -e "${RED}✗ No Xcode project or Swift Package found for ${project_name}${NC}"
        FAILED_PROJECTS=$((FAILED_PROJECTS + 1))
        printf "%s\t%s\n" "${project_name}" "ERROR: No project/package" >>"${COVERAGE_SUMMARY_FILE}"
        return 1
    fi

    echo "Building and testing with coverage..."
    local start_time
    start_time=$(date +%s)

    # Run tests with coverage
    # Build command: include -project only when an .xcodeproj exists; otherwise rely on SPM workspace
    local xcb_cmd=(xcodebuild test -scheme "${scheme}" -destination "${destination}" -enableCodeCoverage YES -resultBundlePath "${project_result_dir}/TestResults.xcresult")
    if [[ "${has_xcodeproj}" == "true" ]]; then
        xcb_cmd=(xcodebuild test -project "${project_name}.xcodeproj" -scheme "${scheme}" -destination "${destination}" -enableCodeCoverage YES -resultBundlePath "${project_result_dir}/TestResults.xcresult")
    fi

    # If platform requested is iOS but no iOS Simulator destinations are available, fallback to macOS
    if [[ "$platform" == "iOS" ]]; then
        local showdest_cmd=(xcodebuild -showdestinations -scheme "${scheme}")
        if [[ "${has_xcodeproj}" == "true" ]]; then
            showdest_cmd=(xcodebuild -project "${project_name}.xcodeproj" -showdestinations -scheme "${scheme}")
        fi
        if ! "${showdest_cmd[@]}" 2>/dev/null | grep -q "iOS Simulator"; then
            echo -e "${YELLOW}⚠ No iOS Simulator destination available for ${project_name}/${scheme}. Falling back to macOS destination.${NC}"
            destination="platform=macOS"
            if [[ "${has_xcodeproj}" == "true" ]]; then
                xcb_cmd=(xcodebuild test -project "${project_name}.xcodeproj" -scheme "${scheme}" -destination "${destination}" -enableCodeCoverage YES -resultBundlePath "${project_result_dir}/TestResults.xcresult")
            else
                xcb_cmd=(xcodebuild test -scheme "${scheme}" -destination "${destination}" -enableCodeCoverage YES -resultBundlePath "${project_result_dir}/TestResults.xcresult")
            fi
        fi
    fi

    if "${xcb_cmd[@]}" >"${project_result_dir}/build.log" 2>&1; then

        local end_time
        local duration
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        printf "%s\t%s\n" "${project_name}" "${duration}s" >>"${BUILD_TIMES_FILE}"

        echo -e "${GREEN}✓ Build and tests completed (${duration}s)${NC}"

        # Extract coverage data
        if [[ -d "${project_result_dir}/TestResults.xcresult" ]]; then
            echo "Extracting coverage data..."

            # Use xcrun to extract coverage report
            xcrun xccov view --report --json "${project_result_dir}/TestResults.xcresult" \
                >"${project_result_dir}/coverage.json" 2>/dev/null || true

            # Parse coverage percentage
            if [[ -f "${project_result_dir}/coverage.json" ]]; then
                local coverage
                coverage=$(python3 -c "
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
                printf "%s\t%s%%\n" "${project_name}" "${coverage}" >>"${COVERAGE_SUMMARY_FILE}"
                echo -e "${GREEN}✓ Coverage: ${coverage}%${NC}"

                # Generate human-readable report
                xcrun xccov view --report "${project_result_dir}/TestResults.xcresult" \
                    >"${project_result_dir}/coverage_report.txt" 2>/dev/null || true
            else
                printf "%s\t%s\n" "${project_name}" "N/A" >>"${COVERAGE_SUMMARY_FILE}"
                echo -e "${YELLOW}⚠ Coverage data extraction failed${NC}"
            fi

            # Count test results
            local test_count
            local test_time
            test_count=$(grep -o "Test Case.*passed" "${project_result_dir}/build.log" | wc -l || echo "0")
            test_time=$(grep "Test Suite.*passed" "${project_result_dir}/build.log" | tail -1 | grep -o "[0-9.]*seconds" || echo "0s")
            printf "%s\t%s tests in %s\n" "${project_name}" "${test_count}" "${test_time}" >>"${TEST_TIMES_FILE}"

        else
            printf "%s\t%s\n" "${project_name}" "N/A (no results)" >>"${COVERAGE_SUMMARY_FILE}"
            echo -e "${YELLOW}⚠ No test results bundle generated${NC}"
        fi

        SUCCESSFUL_PROJECTS=$((SUCCESSFUL_PROJECTS + 1))
    else
        local end_time
        local duration
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        printf "%s\t%s\n" "${project_name}" "${duration}s (failed)" >>"${BUILD_TIMES_FILE}"

        echo -e "${RED}✗ Build or tests failed${NC}"
        FAILED_PROJECTS=$((FAILED_PROJECTS + 1))
        printf "%s\t%s\n" "${project_name}" "FAILED" >>"${COVERAGE_SUMMARY_FILE}"

        # Extract error information
        if [[ -f "${project_result_dir}/build.log" ]]; then
            echo -e "${RED}Last 20 lines of build log:${NC}"
            tail -20 "${project_result_dir}/build.log"
        fi
    fi

    echo ""
}

# Run coverage for all projects
for entry in "${PROJECTS_LIST[@]}"; do
    IFS='|' read -r name path scheme platform <<<"${entry}"
    run_coverage "${name}" "${path}" "${scheme}" "${platform}"
done

# Generate comprehensive summary report
SUMMARY_FILE="${COVERAGE_RESULTS_DIR}/coverage_audit_summary_${TIMESTAMP}.md"

cat >"${SUMMARY_FILE}" <<EOF
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
for project in $(printf "%s\n" "${PROJECTS_LIST[@]}" | cut -d'|' -f1 | sort); do
    coverage=$(grep -E "^${project}\t" "${COVERAGE_SUMMARY_FILE}" | tail -1 | cut -f2 2>/dev/null || echo "N/A")
    build_time=$(grep -E "^${project}\t" "${BUILD_TIMES_FILE}" | tail -1 | cut -f2 2>/dev/null || echo "N/A")
    test_time=$(grep -E "^${project}\t" "${TEST_TIMES_FILE}" | tail -1 | cut -f2- 2>/dev/null || echo "N/A")

    status=
    if [[ "$coverage" == "FAILED" ]] || [[ "$coverage" == "ERROR:"* ]]; then
        status="❌ Failed"
    elif [[ "$coverage" == "N/A"* ]]; then
        status="⚠️ No Coverage"
    else
        # Parse coverage percentage
        cov_num=$(echo "$coverage" | grep -o "[0-9.]*" || echo "0")
        if (($(echo "$cov_num >= 85" | bc -l))); then
            status="✅ Passing"
        elif (($(echo "$cov_num >= 70" | bc -l))); then
            status="⚠️ Warning"
        else
            status="❌ Below Target"
        fi
    fi

    echo "| ${project} | ${coverage} | ${build_time} | ${test_time} | ${status} |" >>"${SUMMARY_FILE}"
done

cat >>"${SUMMARY_FILE}" <<EOF

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
for project in $(printf "%s\n" "${PROJECTS_LIST[@]}" | cut -d'|' -f1 | sort); do
    coverage=$(grep -E "^${project}\t" "${COVERAGE_SUMMARY_FILE}" | tail -1 | cut -f2 2>/dev/null || echo "N/A")
    if [[ "$coverage" == "FAILED" ]] || [[ "$coverage" == "ERROR:"* ]]; then
        echo "- **${project}**: Build/test failure - requires immediate attention" >>"${SUMMARY_FILE}"
    elif [[ "$coverage" == "N/A"* ]]; then
        echo "- **${project}**: No coverage data available - test infrastructure may be missing" >>"${SUMMARY_FILE}"
    else
        cov_num=$(echo "$coverage" | grep -o "[0-9.]*" || echo "0")
        if (($(echo "$cov_num < 85" | bc -l))); then
            gap=$(echo "85 - $cov_num" | bc)
            echo "- **${project}**: Coverage ${coverage} is ${gap}% below minimum (85%)" >>"${SUMMARY_FILE}"
        fi
    fi
done

cat >>"${SUMMARY_FILE}" <<EOF

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
for project in $(printf "%s\n" "${PROJECTS_LIST[@]}" | cut -d'|' -f1 | sort); do
    coverage=$(grep -E "^${project}\t" "${COVERAGE_SUMMARY_FILE}" | tail -1 | cut -f2 2>/dev/null || echo "N/A")
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

# Cleanup temp summary directory marker (keep files for inspection)
echo "Intermediate summary files in: ${SUMMARY_DIR}"
