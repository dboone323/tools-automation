#!/bin/bash

# Comprehensive Test Coverage Baseline Audit Script
# Extracts coverage data from all projects and generates baseline metrics

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$WORKSPACE_ROOT/Tools/Testing/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/coverage_baseline_${TIMESTAMP}.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create report directory
mkdir -p "$REPORT_DIR"

echo -e "${BLUE}🔍 Starting Comprehensive Coverage Audit${NC}"
echo -e "${BLUE}Timestamp: $(date)${NC}\n"

# Projects to audit
PROJECTS=(
    "AvoidObstaclesGame"
    "CodingReviewer"
    "PlannerApp"
    "MomentumFinance"
    "HabitQuest"
)

# Initialize JSON report
cat >"$REPORT_FILE" <<EOF
{
  "audit_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "workspace_root": "$WORKSPACE_ROOT",
  "projects": {}
}
EOF

# Function to extract coverage from xccov
extract_coverage() {
    local project_name=$1
    local project_path="$WORKSPACE_ROOT/Projects/$project_name"

    echo -e "${BLUE}Analyzing $project_name...${NC}"

    # Find the xcodeproj file
    local xcodeproj
    xcodeproj=$(find "$project_path" -name "*.xcodeproj" -maxdepth 2 | head -n 1)

    if [[ -z "$xcodeproj" ]]; then
        echo -e "${YELLOW}⚠️  No Xcode project found for $project_name${NC}"
        return 1
    fi

    # Find test target
    local test_targets
    test_targets=$(xcodebuild -project "$xcodeproj" -list | grep -i "test" || echo "")

    if [[ -z "$test_targets" ]]; then
        echo -e "${YELLOW}⚠️  No test targets found for $project_name${NC}"

        # Add to report as missing tests
        jq --arg project "$project_name" \
            '.projects[$project] = {
                "status": "no_tests",
                "coverage_percent": 0,
                "test_targets": [],
                "test_files_count": 0,
                "gap_analysis": "No test targets found - needs test infrastructure"
            }' "$REPORT_FILE" >"${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"

        return 1
    fi

    # Count test files
    local test_files_count
    test_files_count=$(find "$project_path" -name "*Tests.swift" | wc -l | tr -d ' ')

    # Try to get coverage from most recent DerivedData
    local derived_data="$HOME/Library/Developer/Xcode/DerivedData"
    local coverage_file
    coverage_file=$(find "$derived_data" -name "*.xccovreport" -mtime -7 | head -n 1)

    local coverage_percent=0
    local has_coverage=false

    if [[ -n "$coverage_file" ]]; then
        # Extract coverage percentage from xccov report
        coverage_percent=$(xcrun xccov view --report "$coverage_file" 2>/dev/null |
            grep -E "^\s+[0-9]+\.[0-9]+%" | head -n 1 |
            awk '{print $1}' | tr -d '%' || echo "0")

        if [[ -n "$coverage_percent" ]] && [[ "$coverage_percent" != "0" ]]; then
            has_coverage=true
            echo -e "${GREEN}✅ Coverage: ${coverage_percent}%${NC}"
        fi
    fi

    if [[ "$has_coverage" == false ]]; then
        echo -e "${YELLOW}⚠️  No recent coverage data - need to run tests${NC}"
        coverage_percent=0
    fi

    # Gap analysis
    local gap_analysis=""
    local meets_minimum="false"

    if (($(echo "$coverage_percent < 85" | bc -l))); then
        gap_analysis="Below 85% minimum requirement - needs $(echo "85 - $coverage_percent" | bc)% improvement"
    elif (($(echo "$coverage_percent < 90" | bc -l))); then
        gap_analysis="Meets minimum but below 90% target - $(echo "90 - $coverage_percent" | bc)% to target"
        meets_minimum="true"
    else
        gap_analysis="Exceeds target - excellent coverage"
        meets_minimum="true"
    fi

    # Add to report
    local xcodeproj_basename
    xcodeproj_basename=$(basename "$xcodeproj")
    local test_targets_json
    test_targets_json=$(echo "$test_targets" | jq -R . | jq -s .)

    jq --arg project "$project_name" \
        --arg coverage "$coverage_percent" \
        --arg test_count "$test_files_count" \
        --arg gap "$gap_analysis" \
        --arg meets "$meets_minimum" \
        --arg xcproj "$xcodeproj_basename" \
        --argjson targets "$test_targets_json" \
        '.projects[$project] = {
            "status": "analyzed",
            "coverage_percent": ($coverage | tonumber),
            "meets_minimum": ($meets == "true"),
            "test_files_count": ($test_count | tonumber),
            "gap_analysis": $gap,
            "xcodeproj": $xcproj,
            "test_targets": $targets
        }' "$REPORT_FILE" >"${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"

    echo ""
}

# Audit each project
for project in "${PROJECTS[@]}"; do
    extract_coverage "$project" || true
done

# Calculate aggregate statistics
echo -e "${BLUE}📊 Calculating Aggregate Statistics...${NC}"

total_projects=${#PROJECTS[@]}
projects_with_tests=$(jq '[.projects[] | select(.status == "analyzed")] | length' "$REPORT_FILE")
projects_meeting_minimum=$(jq '[.projects[] | select(.meets_minimum == true)] | length' "$REPORT_FILE")
average_coverage=$(jq '[.projects[] | select(.coverage_percent > 0) | .coverage_percent] | add / length' "$REPORT_FILE" || echo "0")

# Add summary to report
jq --arg total "$total_projects" \
    --arg with_tests "$projects_with_tests" \
    --arg meeting_min "$projects_meeting_minimum" \
    --arg avg_coverage "$average_coverage" \
    '.summary = {
        "total_projects": ($total | tonumber),
        "projects_with_tests": ($with_tests | tonumber),
        "projects_meeting_minimum": ($meeting_min | tonumber),
        "average_coverage": ($avg_coverage | tonumber),
        "compliance_rate": (($meeting_min | tonumber) / ($total | tonumber) * 100)
    }' "$REPORT_FILE" >"${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"

# Print summary
echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 COVERAGE BASELINE AUDIT SUMMARY${NC}"
echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
echo -e "Total Projects:           ${total_projects}"
echo -e "Projects with Tests:      ${projects_with_tests}/${total_projects}"
echo -e "Meeting 85% Minimum:      ${projects_meeting_minimum}/${total_projects}"
echo -e "Average Coverage:         $(printf '%.1f' "$average_coverage")%"
echo -e "Compliance Rate:          $(jq -r '.summary.compliance_rate | floor' "$REPORT_FILE")%"
echo -e "${BLUE}═════════════════════════════════════════════════${NC}\n"

# Print per-project details
echo -e "${BLUE}📋 Per-Project Details:${NC}\n"

for project in "${PROJECTS[@]}"; do
    status=$(jq -r ".projects[\"$project\"].status // \"unknown\"" "$REPORT_FILE")
    coverage=$(jq -r ".projects[\"$project\"].coverage_percent // 0" "$REPORT_FILE")
    test_count=$(jq -r ".projects[\"$project\"].test_files_count // 0" "$REPORT_FILE")
    gap=$(jq -r ".projects[\"$project\"].gap_analysis // \"No data\"" "$REPORT_FILE")

    if [[ "$status" == "analyzed" ]]; then
        if (($(echo "$coverage >= 85" | bc -l))); then
            status_icon="${GREEN}✅${NC}"
        else
            status_icon="${RED}❌${NC}"
        fi
    else
        status_icon="${YELLOW}⚠️${NC}"
    fi

    echo -e "${status_icon} ${BLUE}$project${NC}"
    echo -e "   Coverage:     $(printf '%.1f' "$coverage")%"
    echo -e "   Test Files:   $test_count"
    echo -e "   Gap Analysis: $gap"
    echo ""
done

# Generate recommendations
echo -e "${BLUE}💡 RECOMMENDATIONS:${NC}\n"

projects_needing_tests=$(jq -r '[.projects[] | select(.status == "no_tests")] | length' "$REPORT_FILE")
projects_below_minimum=$(jq -r '[.projects[] | select(.coverage_percent < 85 and .coverage_percent > 0)] | length' "$REPORT_FILE")

if [[ "$projects_needing_tests" -gt 0 ]]; then
    echo -e "${YELLOW}1. Create test infrastructure for projects without tests:${NC}"
    jq -r '.projects | to_entries[] | select(.value.status == "no_tests") | "   - \(.key)"' "$REPORT_FILE"
    echo ""
fi

if [[ "$projects_below_minimum" -gt 0 ]]; then
    echo -e "${YELLOW}2. Improve coverage for projects below 85% minimum:${NC}"
    jq -r '.projects | to_entries[] | select(.value.coverage_percent < 85 and .value.coverage_percent > 0) | "   - \(.key): \(.value.coverage_percent)% (need +\(85 - .value.coverage_percent)%)"' "$REPORT_FILE"
    echo ""
fi

echo -e "${GREEN}3. Maintain and improve coverage for compliant projects${NC}"
echo -e "${GREEN}4. Run tests to generate coverage data where missing${NC}"
echo -e "${GREEN}5. Implement automated coverage tracking in CI/CD${NC}\n"

# Save report path
echo -e "${GREEN}✅ Baseline audit complete!${NC}"
echo -e "${BLUE}Report saved to: $REPORT_FILE${NC}\n"

# Create latest symlink
ln -sf "$REPORT_FILE" "$REPORT_DIR/coverage_baseline_latest.json"

exit 0
