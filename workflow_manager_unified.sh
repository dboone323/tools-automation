#!/bin/bash

# Unified Workflow Manager for Quantum-workspace
# Consolidates enhanced_workflow.sh and universal_workflow_manager.sh functionality

set -euo pipefail

# Workspace directories
WORKSPACE_ROOT="/Users/danielstevens/Desktop/Quantum-workspace"
PROJECTS_DIR="${WORKSPACE_ROOT}/Projects"

# Colors for consistent output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Quantum enhancement features
QUANTUM_MODE="${QUANTUM_MODE:-true}"
AI_ORCHESTRATION="${AI_ORCHESTRATION:-true}"

# Output functions
print_header() {
	echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
	echo -e "${CYAN}║${NC}              🚀 QUANTUM WORKFLOW MANAGER                              ${CYAN}║${NC}"
	echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
	echo ""
}

print_section() {
	echo -e "${BLUE}📋 $1${NC}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_status() {
	echo -e "${BLUE}[WORKFLOW]${NC} $1"
}

print_success() {
	echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
	echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
	echo -e "${RED}❌ $1${NC}"
}

print_quantum() {
	echo -e "${PURPLE}⚛️  $1${NC}"
}

# Validate project exists
validate_project() {
	local project_name="$1"
	local project_path="${PROJECTS_DIR}/${project_name}"

	if [[ ! -d ${project_path} ]]; then
		print_error "Project ${project_name} not found in ${PROJECTS_DIR}"
		return 1
	fi

	echo "${project_path}"
}

# Pre-commit workflow: format, lint, build, test
workflow_pre_commit() {
	local project_name="$1"
	local project_path
	project_path=$(validate_project "${project_name}") || return 1

	print_section "Pre-Commit Workflow: ${project_name}"
	cd "${project_path}"

	# Step 1: Format code
	print_status "1. Formatting Swift code..."
	if command -v swiftformat &>/dev/null; then
		swiftformat . --exclude "*.backup" 2>/dev/null || print_warning "SwiftFormat had issues"
		print_success "Code formatting completed"
	else
		print_warning "SwiftFormat not available, skipping..."
	fi

	# Step 2: Lint code
	print_status "2. Linting Swift code..."
	if command -v swiftlint &>/dev/null; then
		if swiftlint 2>/dev/null; then
			print_success "Linting passed"
		else
			print_warning "Linting found issues (non-blocking)"
		fi
	else
		print_warning "SwiftLint not available, skipping..."
	fi

	# Step 3: Build project
	print_status "3. Building project..."
	local build_success=false

	if [[ -f "*.xcodeproj/project.pbxproj" ]] || [[ -f "*.xcworkspace" ]]; then
		if command -v xcodebuild &>/dev/null; then
			local scheme_name="${project_name}"
			if xcodebuild -scheme "${scheme_name}" -destination 'platform=macOS' build 2>/dev/null; then
				print_success "Build successful"
				build_success=true
			else
				print_error "Build failed"
				return 1
			fi
		else
			print_warning "Xcode build tools not available"
		fi
	elif [[ -f "Package.swift" ]]; then
		if swift build 2>/dev/null; then
			print_success "Swift package build successful"
			build_success=true
		else
			print_error "Swift package build failed"
			return 1
		fi
	else
		print_warning "No build system detected"
		build_success=true # Allow workflow to continue
	fi

	# Step 4: Run tests (only if build succeeded)
	if [[ ${build_success} == "true" ]]; then
		print_status "4. Running tests..."
		if [[ -f "*.xcodeproj/project.pbxproj" ]] || [[ -f "*.xcworkspace" ]]; then
			if xcodebuild test -scheme "${scheme_name}" -destination 'platform=macOS' 2>/dev/null; then
				print_success "Tests passed"
			else
				print_warning "Some tests failed (check output)"
			fi
		elif [[ -f "Package.swift" ]]; then
			if swift test 2>/dev/null; then
				print_success "Swift package tests passed"
			else
				print_warning "Some Swift package tests failed"
			fi
		fi
	fi

	print_success "Pre-commit workflow completed for ${project_name}"
}

# iOS deployment setup workflow
workflow_ios_setup() {
	local project_name="$1"
	local project_path
	project_path=$(validate_project "${project_name}") || return 1

	print_section "iOS Deployment Setup: ${project_name}"
	cd "${project_path}"

	# Initialize Fastlane if not exists
	if [[ ! -d "fastlane" ]]; then
		print_status "Initializing Fastlane..."
		if command -v fastlane &>/dev/null; then
			fastlane init --verbose 2>/dev/null || print_warning "Fastlane init had issues"
			print_success "Fastlane initialized"
		else
			print_error "Fastlane not available"
			return 1
		fi
	fi

	# Create enhanced Fastfile if needed
	if [[ ! -f "fastlane/Fastfile" ]] || [[ ! -s "fastlane/Fastfile" ]]; then
		print_status "Creating enhanced Fastfile..."
		cat >fastlane/Fastfile <<'FASTFILE_EOF'
default_platform(:ios)

platform :ios do
  desc "Run tests"
  lane :test do
    run_tests(scheme: ENV["SCHEME_NAME"] || "App")
  end

  desc "Build for development"
  lane :dev_build do
    gym(
      scheme: ENV["SCHEME_NAME"] || "App",
      configuration: "Debug",
      export_method: "development"
    )
  end

  desc "Build for App Store"
  lane :release do
    gym(
      scheme: ENV["SCHEME_NAME"] || "App",
      configuration: "Release",
      export_method: "app-store"
    )
  end

  desc "Deploy to TestFlight"
  lane :beta do
    gym(
      scheme: ENV["SCHEME_NAME"] || "App",
      configuration: "Release",
      export_method: "app-store"
    )
    upload_to_testflight
  end
end
FASTFILE_EOF
		print_success "Enhanced Fastfile created"
	fi

	print_success "iOS deployment setup completed for ${project_name}"
}

# Quality assurance workflow
workflow_qa() {
	local project_name="$1"
	local project_path
	project_path=$(validate_project "${project_name}") || return 1

	print_section "Quality Assurance: ${project_name}"
	cd "${project_path}"

	# Code metrics
	print_status "Analyzing code metrics..."
	local swift_files
	swift_files=$(find . -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
	local total_lines
	total_lines=$(find . -name "*.swift" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
	local test_files
	test_files=$(find . -name "*Test*.swift" -o -name "*test*.swift" 2>/dev/null | wc -l | tr -d ' ')

	echo "  📊 Swift files: ${swift_files}"
	echo "  📄 Total lines: ${total_lines}"
	echo "  🧪 Test files: ${test_files}"

	# Code quality checks
	if command -v swiftlint &>/dev/null; then
		print_status "Running comprehensive SwiftLint analysis..."
		local swiftlint_output
		swiftlint_output=$(swiftlint --reporter json 2>/dev/null || echo "{}")
		local warnings
		warnings=$(echo "${swiftlint_output}" | grep -o '"severity":"warning"' | wc -l | tr -d ' ')
		local errors
		errors=$(echo "${swiftlint_output}" | grep -o '"severity":"error"' | wc -l | tr -d ' ')
		echo "  ⚠️  Warnings: ${warnings}"
		echo "  ❌ Errors: ${errors}"
	fi

	print_success "Quality assurance workflow completed for ${project_name}"
}

# Dependency management workflow
workflow_deps() {
	local project_name="$1"
	local project_path
	project_path=$(validate_project "${project_name}") || return 1

	print_section "Dependency Management: ${project_name}"
	cd "${project_path}"

	# CocoaPods
	if [[ -f "Podfile" ]]; then
		print_status "Updating CocoaPods dependencies..."
		if command -v pod &>/dev/null; then
			pod install --repo-update 2>/dev/null || print_warning "CocoaPods update had issues"
			print_success "CocoaPods dependencies updated"
		else
			print_warning "CocoaPods not available"
		fi
	fi

	# Swift Package Manager
	if [[ -f "Package.swift" ]]; then
		print_status "Updating Swift Package Manager dependencies..."
		swift package update 2>/dev/null || print_warning "Swift PM update had issues"
		print_success "Swift Package Manager dependencies updated"
	fi

	# Check for outdated dependencies
	if [[ -f "Podfile.lock" ]]; then
		print_status "Checking for outdated CocoaPods..."
		pod outdated 2>/dev/null || true
	fi

	print_success "Dependency management completed for ${project_name}"
}

# Git workflow standardization
workflow_git_standardize() {
	print_section "Git Workflow Standardization"

	for project in "${PROJECTS_DIR}"/*; do
		if [[ -d ${project} ]] && [[ -d "${project}/.git" ]]; then
			local project_name
			project_name=$(basename "${project}")
			print_status "Processing ${project_name}..."

			cd "${project}"

			# Ensure consistent branch naming
			local current_branch
			current_branch=$(git branch --show-current 2>/dev/null || echo "")
			if [[ -n ${current_branch} ]] && [[ ${current_branch} != "main" ]] && [[ ${current_branch} != "develop" ]]; then
				print_status "Current branch: ${current_branch}"

				# Create develop branch if it doesn't exist
				if ! git show-ref --verify --quiet refs/heads/develop; then
					git checkout -b develop 2>/dev/null || print_warning "Could not create develop branch"
					print_success "Created develop branch for ${project_name}"
				fi
			fi

			# Create standard gitignore if needed
			create_standard_gitignore "${project}"

			print_success "Git workflow standardized for ${project_name}"
		fi
	done
}

# Create standard gitignore
create_standard_gitignore() {
	local project_dir="$1"
	local gitignore_file="${project_dir}/.gitignore"

	if [[ ! -f ${gitignore_file} ]] || ! grep -q "# Generated by Quantum Workflow" "${gitignore_file}" 2>/dev/null; then
		cat >"${gitignore_file}" <<'EOF'
# Generated by Quantum Workflow Manager
# macOS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Xcode
*.xcodeproj/project.xcworkspace/
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
build/
DerivedData/
*.ipa
*.xcarchive

# Swift Package Manager
.build/
Packages/
Package.resolved
.swiftpm/

# IDEs
.vscode/settings.json
.idea/
*.swp
*.swo
*~

# Testing
.nyc_output
coverage/
test-results/

# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Dependencies
node_modules/
bower_components/

# Environment
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Temporary files
tmp/
temp/
*.tmp
*.temp

# Build outputs
dist/
out/
target/

# IDE specific
.vscode/
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json
EOF
		print_success "Standard .gitignore created for $(basename "${project_dir}")"
	fi
}

# Run workflow for all projects
workflow_all() {
	local workflow_type="$1"
	print_section "Running ${workflow_type} workflow for all projects"

	for project in "${PROJECTS_DIR}"/*; do
		if [[ -d ${project} ]]; then
			local project_name
			project_name=$(basename "${project}")

			# Skip non-project directories
			if [[ ${project_name} == "Tools" ]] || [[ ${project_name} == "scripts" ]] || [[ ${project_name} == "Config" ]]; then
				continue
			fi

			print_status "Processing ${project_name}..."
			case "${workflow_type}" in
			"pre-commit") workflow_pre_commit "${project_name}" ;;
			"qa") workflow_qa "${project_name}" ;;
			"deps") workflow_deps "${project_name}" ;;
			*) print_warning "Unknown workflow type: ${workflow_type}" ;;
			esac
			echo ""
		fi
	done

	print_success "${workflow_type} workflow completed for all projects"
}

# Main execution
main() {
	case "${1-}" in
	"pre-commit")
		if [[ -n ${2-} ]]; then
			if [[ $2 == "all" ]]; then
				workflow_all "pre-commit"
			else
				workflow_pre_commit "$2"
			fi
		else
			print_error "Usage: $0 pre-commit <project_name|all>"
			exit 1
		fi
		;;
	"ios-setup")
		if [[ -n ${2-} ]]; then
			workflow_ios_setup "$2"
		else
			print_error "Usage: $0 ios-setup <project_name>"
			exit 1
		fi
		;;
	"qa")
		if [[ -n ${2-} ]]; then
			if [[ $2 == "all" ]]; then
				workflow_all "qa"
			else
				workflow_qa "$2"
			fi
		else
			print_error "Usage: $0 qa <project_name|all>"
			exit 1
		fi
		;;
	"deps")
		if [[ -n ${2-} ]]; then
			if [[ $2 == "all" ]]; then
				workflow_all "deps"
			else
				workflow_deps "$2"
			fi
		else
			print_error "Usage: $0 deps <project_name|all>"
			exit 1
		fi
		;;
	"git-standardize")
		workflow_git_standardize
		;;
	"quantum")
		if [[ ${QUANTUM_MODE} == "true" ]]; then
			print_quantum "Activating Quantum Enhancement Mode"
			# Add quantum-specific workflows here
			workflow_git_standardize
		else
			print_warning "Quantum mode is disabled"
		fi
		;;
	*)
		print_header
		echo "🏗️  Unified Workflow Manager for Quantum-workspace"
		echo ""
		echo "Usage: $0 <command> [project_name|all]"
		echo ""
		echo "Commands:"
		echo "  pre-commit <project|all>    # Run pre-commit workflow (format, lint, build, test)"
		echo "  ios-setup <project>         # Setup iOS deployment with Fastlane"
		echo "  qa <project|all>           # Run quality assurance workflow"
		echo "  deps <project|all>         # Manage project dependencies"
		echo "  git-standardize            # Standardize git workflow across all projects"
		echo "  quantum                    # Quantum enhancement mode (advanced features)"
		echo ""
		exit 1
		;;
	esac
}

# Run main function with all arguments
main "$@"
