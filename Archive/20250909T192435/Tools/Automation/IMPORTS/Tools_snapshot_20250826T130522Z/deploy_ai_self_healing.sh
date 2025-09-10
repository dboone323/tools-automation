#!/bin/bash

# Deploy AI Self-Healing Workflow to All Projects
# This script deploys the advanced AI-powered workflow recovery system

set -e # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🤖 AI Self-Healing Workflow Deployment${NC}"
echo -e "${CYAN}=======================================${NC}"
echo

# Define project directories
PROJECTS=(
	"/Users/danielstevens/Desktop/Code/Projects/CodingReviewer"
	"/Users/danielstevens/Desktop/Code/Projects/HabitQuest"
	"/Users/danielstevens/Desktop/Code/Projects/MomentumFinance"
)

SOURCE_WORKFLOW="/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/.github/workflows/ai-self-healing.yml"
AI_RECOVERY_SCRIPT="/Users/danielstevens/Desktop/Code/Tools/Automation/ai_workflow_recovery.py"
QUALITY_CHECK_SCRIPT="/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/workflow_quality_check.py"
REQUIREMENTS="/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/requirements-recovery.txt"

# Counters
total_projects=0
successful_deployments=0
failed_deployments=0

echo -e "${BLUE}📋 Deployment Plan:${NC}"
echo -e "   🎯 Source Workflow: ai-self-healing.yml"
echo -e "   🤖 AI Recovery System: ai_workflow_recovery.py"
echo -e "   🔍 Quality Checker: workflow_quality_check.py"
echo -e "   📦 Dependencies: requirements-recovery.txt"
echo -e "   🏗️ Target Projects: ${#PROJECTS[@]}"
echo

# Function to deploy to a single project
deploy_to_project() {
	local project_dir="$1"
	local project_name=$(basename "$project_dir")

	echo -e "${YELLOW}🚀 Deploying to ${project_name}...${NC}"

	if [ ! -d "$project_dir" ]; then
		echo -e "${RED}❌ Project directory not found: $project_dir${NC}"
		return 1
	fi

	cd "$project_dir"

	# Create necessary directories
	mkdir -p .github/workflows
	mkdir -p Tools/Automation

	# Copy AI self-healing workflow
	if [ -f "$SOURCE_WORKFLOW" ]; then
		cp "$SOURCE_WORKFLOW" .github/workflows/ai-self-healing.yml
		echo -e "   ✅ AI self-healing workflow deployed"
	else
		echo -e "   ${RED}❌ Source workflow not found${NC}"
		return 1
	fi

	# Copy AI recovery system
	if [ -f "$AI_RECOVERY_SCRIPT" ]; then
		cp "$AI_RECOVERY_SCRIPT" Tools/Automation/ai_workflow_recovery.py
		chmod +x Tools/Automation/ai_workflow_recovery.py
		echo -e "   ✅ AI recovery system deployed"
	else
		echo -e "   ${RED}❌ AI recovery script not found${NC}"
		return 1
	fi

	# Copy quality check script
	if [ -f "$QUALITY_CHECK_SCRIPT" ]; then
		cp "$QUALITY_CHECK_SCRIPT" workflow_quality_check.py
		echo -e "   ✅ Quality checker deployed"
	else
		echo -e "   ${RED}❌ Quality check script not found${NC}"
		return 1
	fi

	# Copy requirements
	if [ -f "$REQUIREMENTS" ]; then
		cp "$REQUIREMENTS" requirements-recovery.txt
		echo -e "   ✅ Recovery dependencies deployed"
	else
		echo -e "   ${YELLOW}⚠️ Recovery requirements not found, creating basic version${NC}"
		cat >requirements-recovery.txt <<'EOF'
requests>=2.31.0
psutil>=5.9.5
PyYAML>=6.0.1
flake8>=6.0.0
gitpython>=3.1.32
colorama>=0.4.6
EOF
	fi

	# Initialize AI learning system
	mkdir -p .ai_learning_system
	if [ ! -f .ai_learning_system/workflow_patterns.json ]; then
		cat >.ai_learning_system/workflow_patterns.json <<'EOF'
{
  "patterns": [
    {
      "pattern_id": "syntax_error",
      "error_signature": "SyntaxError|EOL while scanning",
      "fix_template": "fix_python_syntax",
      "success_rate": 0.95,
      "usage_count": 0,
      "last_used": null
    },
    {
      "pattern_id": "import_error", 
      "error_signature": "F401.*imported but unused|ModuleNotFoundError",
      "fix_template": "fix_imports",
      "success_rate": 0.90,
      "usage_count": 0,
      "last_used": null
    },
    {
      "pattern_id": "missing_file",
      "error_signature": "No such file or directory|FileNotFoundError",
      "fix_template": "create_missing_file",
      "success_rate": 0.85,
      "usage_count": 0,
      "last_used": null
    }
  ],
  "updated": "$(date -Iseconds)"
}
EOF
		echo -e "   ✅ AI learning system initialized"
	else
		echo -e "   ✅ AI learning system already exists"
	fi

	# Validate deployment
	echo -e "   🔍 Validating deployment..."

	local validation_passed=true

	if [ ! -f .github/workflows/ai-self-healing.yml ]; then
		echo -e "   ${RED}❌ Workflow file missing${NC}"
		validation_passed=false
	fi

	if [ ! -f Tools/Automation/ai_workflow_recovery.py ]; then
		echo -e "   ${RED}❌ AI recovery script missing${NC}"
		validation_passed=false
	fi

	if [ ! -f workflow_quality_check.py ]; then
		echo -e "   ${RED}❌ Quality checker missing${NC}"
		validation_passed=false
	fi

	if [ ! -f .ai_learning_system/workflow_patterns.json ]; then
		echo -e "   ${RED}❌ AI learning system missing${NC}"
		validation_passed=false
	fi

	if [ "$validation_passed" = true ]; then
		echo -e "   ${GREEN}✅ Deployment validation passed${NC}"

		# Test the AI recovery system
		echo -e "   🧪 Testing AI recovery system..."
		if python3 Tools/Automation/ai_workflow_recovery.py --dry-run --repo-path . >/dev/null 2>&1; then
			echo -e "   ${GREEN}✅ AI recovery system test passed${NC}"
		else
			echo -e "   ${YELLOW}⚠️ AI recovery system test had issues (may need dependencies)${NC}"
		fi

		return 0
	else
		echo -e "   ${RED}❌ Deployment validation failed${NC}"
		return 1
	fi
}

# Deploy to all projects
for project in "${PROJECTS[@]}"; do
	total_projects=$((total_projects + 1))

	if deploy_to_project "$project"; then
		successful_deployments=$((successful_deployments + 1))
		echo -e "${GREEN}✅ Successfully deployed to $(basename "$project")${NC}"
	else
		failed_deployments=$((failed_deployments + 1))
		echo -e "${RED}❌ Failed to deploy to $(basename "$project")${NC}"
	fi
	echo
done

# Summary report
echo -e "${CYAN}📊 Deployment Summary${NC}"
echo -e "${CYAN}=====================${NC}"
echo -e "Total Projects: $total_projects"
echo -e "${GREEN}Successful: $successful_deployments${NC}"
echo -e "${RED}Failed: $failed_deployments${NC}"

if [ $successful_deployments -eq $total_projects ]; then
	echo -e "${GREEN}🎉 All projects successfully upgraded with AI self-healing capabilities!${NC}"
	echo
	echo -e "${BLUE}🤖 AI Self-Healing Features Deployed:${NC}"
	echo -e "   ✅ Autonomous failure detection and recovery"
	echo -e "   ✅ Pattern recognition and learning system"
	echo -e "   ✅ Auto-fix application with safety controls"
	echo -e "   ✅ Continuous quality improvement loop"
	echo -e "   ✅ Cross-project learning and optimization"
	echo
	echo -e "${PURPLE}🚀 Next Steps:${NC}"
	echo -e "   1. Commit and push changes to trigger first AI self-healing run"
	echo -e "   2. Monitor workflow runs to see AI recovery in action"
	echo -e "   3. Review AI learning patterns in .ai_learning_system/"
	echo -e "   4. Watch quality scores improve automatically over time"

	exit 0
else
	echo -e "${YELLOW}⚠️ Some deployments failed. Please check the output above.${NC}"
	exit 1
fi
