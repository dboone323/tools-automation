#!/bin/bash

# Git Workflow Manager - Enhanced version control workflows
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
	echo -e "${BLUE}[GIT]${NC} $1"
}

print_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

# Smart commit with pre-commit checks
smart_commit() {
	local project_name="$1"
	local commit_message="$2"
	local project_path="$CODE_DIR/Projects/$project_name"

	if [[ ! -d $project_path ]]; then
		print_error "Project $project_name not found"
		return 1
	fi

	if [[ -z $commit_message ]]; then
		print_error "Commit message required"
		echo "Usage: smart_commit <project> <commit_message>"
		return 1
	fi

	print_status "Running smart commit workflow for $project_name..."
	cd "$project_path"

	# Check if we're in a git repository
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		print_error "Not a git repository. Initialize with: git init"
		return 1
	fi

	# Step 1: Check for uncommitted changes
	if git diff-index --quiet HEAD --; then
		print_warning "No changes to commit"
		return 0
	fi

	# Step 2: Format code before commit
	print_status "1. Formatting code..."
	if command -v swiftformat &>/dev/null; then
		swiftformat . --config "$CODE_DIR/.swiftformat"
		print_success "Code formatted"
	fi

	# Step 3: Lint code
	print_status "2. Linting code..."
	if command -v swiftlint &>/dev/null; then
		if ! swiftlint --quiet; then
			print_warning "Linting issues found - continuing with commit"
		else
			print_success "Linting passed"
		fi
	fi

	# Step 4: Add changes
	print_status "3. Adding changes..."
	git add .

	# Step 5: Commit with enhanced message
	local enhanced_message="$commit_message

- Auto-formatted with SwiftFormat
- Linted with SwiftLint
- Committed via smart workflow"

	print_status "4. Committing changes..."
	if git commit -m "$enhanced_message"; then
		print_success "Successfully committed: $commit_message"

		# Show commit summary
		echo ""
		git log --oneline -1
		git diff --stat HEAD~1
	else
		print_error "Commit failed"
		return 1
	fi
}

# Feature branch workflow
feature_branch() {
	local project_name="$1"
	local branch_name="$2"
	local project_path="$CODE_DIR/Projects/$project_name"

	if [[ ! -d $project_path ]]; then
		print_error "Project $project_name not found"
		return 1
	fi

	if [[ -z $branch_name ]]; then
		print_error "Branch name required"
		echo "Usage: feature_branch <project> <branch_name>"
		return 1
	fi

	print_status "Creating feature branch '$branch_name' in $project_name..."
	cd "$project_path"

	# Ensure we're on main/master
	local main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
	if [[ -z $main_branch ]]; then
		main_branch="main"
	fi

	print_status "Switching to $main_branch and pulling latest..."
	git checkout "$main_branch"
	git pull origin "$main_branch" 2>/dev/null || print_warning "Could not pull from remote"

	# Create and switch to feature branch
	print_status "Creating feature branch..."
	if git checkout -b "feature/$branch_name"; then
		print_success "Created and switched to feature/$branch_name"
		print_status "Ready for development!"
	else
		print_error "Failed to create feature branch"
		return 1
	fi
}

# Release workflow
release_workflow() {
	local project_name="$1"
	local version="$2"
	local project_path="$CODE_DIR/Projects/$project_name"

	if [[ ! -d $project_path ]]; then
		print_error "Project $project_name not found"
		return 1
	fi

	if [[ -z $version ]]; then
		print_error "Version required"
		echo "Usage: release_workflow <project> <version>"
		return 1
	fi

	print_status "Starting release workflow for $project_name v$version..."
	cd "$project_path"

	# Ensure clean working directory
	if ! git diff-index --quiet HEAD --; then
		print_error "Working directory not clean. Commit or stash changes first."
		return 1
	fi

	# Create release branch
	local main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
	print_status "Creating release branch from $main_branch..."
	git checkout "$main_branch"
	git pull origin "$main_branch" 2>/dev/null || true
	git checkout -b "release/v$version"

	# Run comprehensive checks
	print_status "Running pre-release checks..."

	# Format and lint
	if command -v swiftformat &>/dev/null; then
		swiftformat . --config "$CODE_DIR/.swiftformat"
	fi

	if command -v swiftlint &>/dev/null; then
		swiftlint --quiet || print_warning "Linting issues found"
	fi

	# Build project
	if [[ -f "*.xcodeproj/project.pbxproj" ]]; then
		print_status "Building project for release..."
		if xcodebuild -scheme "$project_name" -configuration Release build; then
			print_success "Release build successful"
		else
			print_error "Release build failed"
			return 1
		fi
	fi

	# Commit any formatting changes
	if ! git diff-index --quiet HEAD --; then
		git add .
		git commit -m "chore: prepare release v$version

- Format code for release
- Final linting pass"
	fi

	# Create tag
	print_status "Creating release tag..."
	git tag -a "v$version" -m "Release version $version"

	print_success "Release v$version prepared!"
	print_status "Next steps:"
	echo "  1. Test the release branch thoroughly"
	echo "  2. Merge to $main_branch: git checkout $main_branch && git merge release/v$version"
	echo "  3. Push with tags: git push origin $main_branch --tags"
	echo "  4. Deploy using: fastlane release (if configured)"
}

# Status overview across all projects
git_status_all() {
	print_status "Git status overview for all projects..."
	echo ""

	for project_dir in "$CODE_DIR/Projects"/*; do
		if [[ -d $project_dir ]]; then
			local project_name=$(basename "$project_dir")
			cd "$project_dir"

			if git rev-parse --git-dir >/dev/null 2>&1; then
				echo "📁 $project_name"

				# Current branch
				local current_branch=$(git branch --show-current)
				echo "   Branch: $current_branch"

				# Status
				local status=$(git status --porcelain)
				if [[ -z $status ]]; then
					echo "   Status: ✅ Clean"
				else
					local modified=$(echo "$status" | grep "^ M" | wc -l | tr -d ' ')
					local added=$(echo "$status" | grep "^A" | wc -l | tr -d ' ')
					local untracked=$(echo "$status" | grep "^??" | wc -l | tr -d ' ')
					echo "   Status: 📝 $modified modified, $added staged, $untracked untracked"
				fi

				# Last commit
				local last_commit=$(git log --oneline -1 2>/dev/null)
				echo "   Last: $last_commit"

				echo ""
			else
				echo "📁 $project_name - ❌ Not a git repository"
				echo ""
			fi
		fi
	done
}

# Help function
show_help() {
	echo "🌿 Git Workflow Manager"
	echo ""
	echo "Usage: $0 <command> [arguments]"
	echo ""
	echo "Commands:"
	echo "  smart-commit <project> <message>  # Smart commit with pre-commit checks"
	echo "  feature <project> <branch_name>   # Create feature branch workflow"
	echo "  release <project> <version>       # Release workflow with tagging"
	echo "  status                            # Git status overview for all projects"
	echo "  help                              # Show this help"
	echo ""
	echo "Examples:"
	echo "  $0 smart-commit CodingReviewer \"Add new feature\""
	echo "  $0 feature HabitQuest user-dashboard"
	echo "  $0 release MomentumFinance 1.2.0"
	echo ""
}

# Main execution
case "${1-}" in
"smart-commit")
	if [[ -n ${2-} ]] && [[ -n ${3-} ]]; then
		smart_commit "$2" "$3"
	else
		print_error "Usage: $0 smart-commit <project> <commit_message>"
		exit 1
	fi
	;;
"feature")
	if [[ -n ${2-} ]] && [[ -n ${3-} ]]; then
		feature_branch "$2" "$3"
	else
		print_error "Usage: $0 feature <project> <branch_name>"
		exit 1
	fi
	;;
"release")
	if [[ -n ${2-} ]] && [[ -n ${3-} ]]; then
		release_workflow "$2" "$3"
	else
		print_error "Usage: $0 release <project> <version>"
		exit 1
	fi
	;;
"status")
	git_status_all
	;;
"help" | *)
	show_help
	;;
esac
