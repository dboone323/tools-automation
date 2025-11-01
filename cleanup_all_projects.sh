#!/bin/bash

# Automated Cleanup Script for All Projects
# Removes duplicate file references from all Xcode projects in the workspace

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${SCRIPT_DIR}/../.."
PROJECTS_DIR="${WORKSPACE_ROOT}/Projects"
CLEANUP_SCRIPT="${SCRIPT_DIR}/cleanup_duplicate_references.py"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Duplicate Reference Cleanup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Ensure Python script is executable
chmod +x "${CLEANUP_SCRIPT}"

# Projects to clean
PROJECTS=(
    "HabitQuest"
    "PlannerApp"
    "AvoidObstaclesGame"
    "MomentumFinance"
)

# First, scan for duplicates
echo -e "${YELLOW}📊 Scanning projects for duplicates...${NC}"
echo ""

for project in "${PROJECTS[@]}"; do
    proj_path="${PROJECTS_DIR}/${project}/${project}.xcodeproj"

    if [ ! -d "$proj_path" ]; then
        echo -e "${YELLOW}⚠️  ${project}: No .xcodeproj found, skipping${NC}"
        continue
    fi

    echo -e "${BLUE}=== ${project} ===${NC}"
    count=$(xcodebuild -project "$proj_path" -list 2>&1 | grep -c "member of multiple groups" || echo "0")

    if [ "$count" -gt 0 ]; then
        echo -e "${RED}❌ Found ${count} duplicate file references${NC}"
        echo -e "${YELLOW}   Will clean this project${NC}"
    else
        echo -e "${GREEN}✅ Clean - no duplicates${NC}"
    fi
    echo ""
done

echo -e "${BLUE}========================================${NC}"
echo ""

# Ask for confirmation
read -p "$(echo -e ${YELLOW}Do you want to proceed with automated cleanup? [y/N]: ${NC})" -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cleanup cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}🚀 Starting automated cleanup...${NC}"
echo ""

# Close Xcode if running
if pgrep -x "Xcode" >/dev/null; then
    echo -e "${YELLOW}⚠️  Xcode is running. Please close Xcode before continuing.${NC}"
    read -p "Press Enter when Xcode is closed..."
fi

# Clean each project
CLEANED=0
FAILED=0

for project in "${PROJECTS[@]}"; do
    proj_path="${PROJECTS_DIR}/${project}/${project}.xcodeproj"

    if [ ! -d "$proj_path" ]; then
        continue
    fi

    # Check if project has duplicates
    count=$(xcodebuild -project "$proj_path" -list 2>&1 | grep -c "member of multiple groups" || echo "0")

    if [ "$count" -eq 0 ]; then
        echo -e "${GREEN}✅ ${project}: Already clean, skipping${NC}"
        continue
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Cleaning: ${project}${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Run Python cleanup script
    if python3 "${CLEANUP_SCRIPT}" "$proj_path"; then
        echo -e "${GREEN}✅ ${project}: Successfully cleaned${NC}"
        CLEANED=$((CLEANED + 1))
    else
        echo -e "${RED}❌ ${project}: Cleanup failed${NC}"
        FAILED=$((FAILED + 1))
    fi

    echo ""
done

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Cleanup Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Projects cleaned: ${GREEN}${CLEANED}${NC}"
echo -e "Projects failed:  ${RED}${FAILED}${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}⚠️  Some projects failed to clean. Check logs above.${NC}"
    echo -e "${YELLOW}   Backups (.pbxproj.backup) were created for safety.${NC}"
else
    echo -e "${GREEN}✅ All projects cleaned successfully!${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Next Steps${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "1. ${YELLOW}Open each project in Xcode to verify${NC}"
echo -e "2. ${YELLOW}Build each project to ensure it works${NC}"
echo -e "3. ${YELLOW}Commit cleaned projects to Git${NC}"
echo -e "4. ${YELLOW}Re-run coverage audit:${NC}"
echo -e "   bash Tools/Automation/run_coverage_audit.sh"
echo ""

# Verification
echo -e "${YELLOW}📋 Quick verification of cleaned projects:${NC}"
echo ""

for project in "${PROJECTS[@]}"; do
    proj_path="${PROJECTS_DIR}/${project}/${project}.xcodeproj"

    if [ ! -d "$proj_path" ]; then
        continue
    fi

    count=$(xcodebuild -project "$proj_path" -list 2>&1 | grep -c "member of multiple groups" || echo "0")

    if [ "$count" -eq 0 ]; then
        echo -e "${GREEN}✅ ${project}: Verified clean (0 duplicates)${NC}"
    else
        echo -e "${RED}❌ ${project}: Still has ${count} duplicates${NC}"
    fi
done

echo ""
echo -e "${GREEN}Cleanup process complete!${NC}"
