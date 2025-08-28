#!/bin/bash

# Workflow Deployment Verification Script
# Checks that all workflows are properly deployed and committed

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 GitHub Workflows Deployment Verification${NC}"
echo "============================================="
echo ""

# Expected workflows (13 total)
EXPECTED_WORKFLOWS=(
	"ai-enhanced-cicd.yml"
	"ai-excellence.yml"
	"ci-cd-backup.yml"
	"ci-cd.yml"
	"ci.yml"
	"codeql-security.yml"
	"dependency-updates.yml"
	"release.yml"
	"security-monitoring.yml"
	"security.yml"
	"swift.yml"
	"swiftformat.yml"
	"update-dependencies.yml"
)

PROJECTS=("CodingReviewer" "HabitQuest" "MomentumFinance")

for project in "${PROJECTS[@]}"; do
	echo -e "${BLUE}📱 Checking $project workflows...${NC}"
	project_path="/Users/danielstevens/Desktop/Code/Projects/$project"

	if [[ -d "$project_path/.github/workflows" ]]; then
		workflow_count=$(ls "$project_path/.github/workflows"/*.yml 2>/dev/null | wc -l | tr -d ' ')
		echo "   📊 Workflow files found: $workflow_count"

		# Check each expected workflow
		missing_workflows=0
		for workflow in "${EXPECTED_WORKFLOWS[@]}"; do
			if [[ -f "$project_path/.github/workflows/$workflow" ]]; then
				echo -e "   ✅ $workflow"
			else
				echo -e "   ❌ $workflow ${RED}(missing)${NC}"
				((missing_workflows++))
			fi
		done

		# Check git status
		cd "$project_path"
		uncommitted=$(git status --porcelain | wc -l | tr -d ' ')
		if [[ $uncommitted -eq 0 ]]; then
			echo -e "   ✅ Git: ${GREEN}All changes committed${NC}"
		else
			echo -e "   ⚠️  Git: ${YELLOW}$uncommitted uncommitted changes${NC}"
		fi

		# Check if pushed to remote
		local_commit=$(git rev-parse HEAD)
		remote_commit=$(git rev-parse origin/$(git branch --show-current) 2>/dev/null || echo "no-remote")
		if [[ $local_commit == "$remote_commit" ]]; then
			echo -e "   ✅ Remote: ${GREEN}Pushed to GitHub${NC}"
		else
			echo -e "   ⚠️  Remote: ${YELLOW}Local commits not pushed${NC}"
		fi

		echo ""

	else
		echo -e "   ❌ No .github/workflows directory found${NC}"
		echo ""
	fi
done

echo -e "${BLUE}🚀 Automation Verification${NC}"
echo "=========================="

for project in "${PROJECTS[@]}"; do
	project_path="/Users/danielstevens/Desktop/Code/Projects/$project"
	echo -e "${BLUE}📱 $project automation status:${NC}"

	if [[ -f "$project_path/Tools/Automation/automate.sh" ]]; then
		echo "   ✅ Quick automation wrapper available"
	else
		echo "   ❌ Quick automation wrapper missing"
	fi

	if [[ -f "$project_path/Tools/Automation/project_config.sh" ]]; then
		echo "   ✅ Project configuration available"
	else
		echo "   ❌ Project configuration missing"
	fi

	echo ""
done

echo -e "${GREEN}🎉 Verification Complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Check GitHub Actions tab in each repository"
echo "2. Verify workflows are running successfully"
echo "3. Monitor build and test results"
echo "4. Use automation tools for ongoing development"
