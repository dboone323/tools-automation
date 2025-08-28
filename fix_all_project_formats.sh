#!/bin/bash
# Fix all project formats to be compatible with CI environments

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Fixing all project formats for CI compatibility${NC}"
echo "=============================================="

PROJECTS_DIR="/Users/danielstevens/Desktop/Code/Projects"

# Function to fix a single project
fix_project() {
	local project_dir="$1"
	local project_name=$(basename "$project_dir")

	echo -e "${YELLOW}🔍 Processing $project_name...${NC}"

	if [ ! -d "$project_dir" ]; then
		echo -e "${RED}❌ Project directory not found: $project_dir${NC}"
		return 1
	fi

	cd "$project_dir"

	# Find .xcodeproj directories
	local xcodeproj_files=($(find . -maxdepth 2 -name "*.xcodeproj" -type d))

	if [ ${#xcodeproj_files[@]} -eq 0 ]; then
		echo -e "${YELLOW}⚠️  No Xcode projects found in $project_name${NC}"
		return 0
	fi

	for xcodeproj in "${xcodeproj_files[@]}"; do
		local pbxproj_file="$xcodeproj/project.pbxproj"

		if [ ! -f "$pbxproj_file" ]; then
			echo -e "${YELLOW}⚠️  No project.pbxproj found in $xcodeproj${NC}"
			continue
		fi

		echo "📋 Checking $pbxproj_file..."

		# Backup original
		cp "$pbxproj_file" "$pbxproj_file.backup"

		# Fix object version (77 -> 56 for CI compatibility)
		if grep -q "objectVersion = 77;" "$pbxproj_file"; then
			echo "  🔧 Converting objectVersion 77 -> 56"
			sed -i '' 's/objectVersion = 77;/objectVersion = 56;/' "$pbxproj_file"
		fi

		# Fix macOS deployment target (26.0 -> 15.0 for CI compatibility)
		if grep -q "MACOSX_DEPLOYMENT_TARGET = 26.0;" "$pbxproj_file"; then
			echo "  🔧 Converting macOS deployment target 26.0 -> 15.0"
			sed -i '' 's/MACOSX_DEPLOYMENT_TARGET = 26.0;/MACOSX_DEPLOYMENT_TARGET = 15.0;/' "$pbxproj_file"
		fi

		# Validate the updated file
		if plutil -lint "$pbxproj_file" >/dev/null 2>&1; then
			echo -e "  ✅ Project file validation successful"

			# Test with xcodebuild if possible
			if xcodebuild -list -project "$xcodeproj" >/dev/null 2>&1; then
				echo -e "  ✅ Project is readable by Xcode"
			else
				echo -e "  ⚠️  Warning: Project may have compatibility issues"
			fi
		else
			echo -e "${RED}  ❌ Project file validation failed, restoring backup${NC}"
			mv "$pbxproj_file.backup" "$pbxproj_file"
		fi
	done

	echo -e "${GREEN}✅ $project_name processing completed${NC}"
	echo ""
}

# Process all projects
for project_dir in "$PROJECTS_DIR"/*; do
	if [ -d "$project_dir" ]; then
		fix_project "$project_dir"
	fi
done

echo -e "${GREEN}🎯 All project format fixes completed!${NC}"
