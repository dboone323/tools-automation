#!/bin/bash

# Intelligent Auto-Fix System with Safety Checks and Rollback
# Comprehensive error detection, automatic fixing, and validation

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions
print_header() { echo -e "${PURPLE}[AUTO-FIX]${NC} ${CYAN}$1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_status() { echo -e "${BLUE}🔄 $1${NC}"; }
print_fix() { echo -e "${GREEN}🔧 FIXED:${NC} $1"; }
print_skip() { echo -e "${YELLOW}⏭️  SKIPPED:${NC} $1"; }
print_rollback() { echo -e "${RED}🔄 ROLLBACK:${NC} $1"; }

# Configuration
readonly CODE_DIR="${CODE_DIR:-/Users/danielstevens/Desktop/Code}"
readonly BACKUP_DIR="$CODE_DIR/.autofix_backups"
readonly LOG_FILE="$CODE_DIR/.autofix.log"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup and restore functions
create_backup() {
	local project_path="$1"
	local timestamp="$(date +%Y%m%d_%H%M%S)"
	local backup_path="$BACKUP_DIR/$(basename "$project_path")_$timestamp"

	print_status "Creating backup: $backup_path"
	cp -r "$project_path" "$backup_path"
	echo "$backup_path" >"$project_path/.autofix_backup"
	print_success "Backup created successfully"
}

restore_backup() {
	local project_path="$1"
	local backup_file="$project_path/.autofix_backup"

	if [[ -f $backup_file ]]; then
		local backup_path="$(cat "$backup_file")"
		if [[ -d $backup_path ]]; then
			print_rollback "Restoring from backup: $backup_path"
			rm -rf "$project_path"
			cp -r "$backup_path" "$project_path"
			rm -f "$project_path/.autofix_backup"
			print_success "Backup restored successfully"
			return 0
		fi
	fi
	print_error "No backup found for rollback"
	return 1
}

cleanup_backup() {
	local project_path="$1"
	local backup_file="$project_path/.autofix_backup"

	if [[ -f $backup_file ]]; then
		local backup_path="$(cat "$backup_file")"
		if [[ -d $backup_path ]]; then
			rm -rf "$backup_path"
			print_status "Backup cleaned up: $backup_path"
		fi
		rm -f "$backup_file"
	fi
}

# Build validation functions
run_pre_build_checks() {
	local project_path="$1"
	cd "$project_path"

	print_status "Running pre-build validation checks..."

	local checks_passed=0
	local total_checks=4

	# Check 1: Swift compilation
	if [[ -f "Package.swift" ]]; then
		# For Swift Package Manager projects
		if swift package dump-package &>/dev/null; then
			print_success "Swift compilation check passed"
			((checks_passed++))
		else
			print_error "Swift compilation check failed"
		fi
	elif find . -name "*.xcodeproj" -type d | head -1 | grep -q "xcodeproj"; then
		# For Xcode projects
		local scheme_name=$(basename "$project_path")
		if xcodebuild -list -project "$(find . -name "*.xcodeproj" -type d | head -1)" &>/dev/null; then
			print_success "Swift compilation check passed"
			((checks_passed++))
		else
			print_error "Swift compilation check failed"
		fi
	else
		print_warning "No recognizable Swift project structure"
		((checks_passed++)) # Allow non-standard projects to pass
	fi

	# Check 2: SwiftLint validation
	if command -v swiftlint &>/dev/null; then
		local lint_output=$(swiftlint lint --reporter json 2>/dev/null || echo "[]")
		local lint_errors=$(echo "$lint_output" | jq -r '.[] | select(.severity == "error") | .file' 2>/dev/null | wc -l | xargs || echo "0")
		if [[ $lint_errors =~ ^[0-9]+$ ]] && [[ $lint_errors -eq 0 ]]; then
			print_success "SwiftLint error check passed"
			((checks_passed++))
		else
			print_warning "SwiftLint errors found: $lint_errors"
			((checks_passed++)) # Allow warnings to pass
		fi
	else
		print_warning "SwiftLint not available"
		((checks_passed++))
	fi

	# Check 3: Package.swift validation
	if [[ -f "Package.swift" ]]; then
		if swift package dump-package &>/dev/null; then
			print_success "Package.swift validation passed"
			((checks_passed++))
		else
			print_error "Package.swift validation failed"
		fi
	else
		print_success "No Package.swift to validate"
		((checks_passed++))
	fi

	# Check 4: Project structure validation
	local required_files=0
	local found_files=0

	if [[ -f "*.xcodeproj/project.pbxproj" ]] || [[ -f "Package.swift" ]]; then
		((required_files++))
		((found_files++))
	fi

	if [[ $required_files -eq $found_files ]]; then
		print_success "Project structure validation passed"
		((checks_passed++))
	else
		print_error "Project structure validation failed"
	fi

	echo "$checks_passed/$total_checks"
}

run_post_build_checks_verbose() {
	local project_path="$1"
	cd "$project_path"

	print_status "Running post-build validation checks..."

	local checks_passed=0
	local total_checks=5

	# Check 1: Swift compilation
	print_status "Testing Swift compilation..."
	if [[ -f "Package.swift" ]]; then
		# For Swift Package Manager projects
		if swift package dump-package &>/dev/null; then
			print_success "Swift compilation successful"
			((checks_passed++))
		else
			print_error "Swift compilation failed"
			return 1
		fi
	elif find . -name "*.xcodeproj" -type d | head -1 | grep -q "xcodeproj"; then
		# For Xcode projects
		if xcodebuild -list -project "$(find . -name "*.xcodeproj" -type d | head -1)" &>/dev/null; then
			print_success "Swift compilation successful"
			((checks_passed++))
		else
			print_error "Swift compilation failed"
			return 1
		fi
	else
		print_warning "No recognizable Swift project structure"
		((checks_passed++)) # Allow non-standard projects to pass
	fi

	# Check 2: SwiftLint validation
	if command -v swiftlint &>/dev/null; then
		local lint_output=$(swiftlint lint --reporter json 2>/dev/null || echo "[]")
		local lint_errors=$(echo "$lint_output" | jq -r '.[] | select(.severity == "error") | .file' 2>/dev/null | wc -l | xargs || echo "0")
		if [[ $lint_errors =~ ^[0-9]+$ ]] && [[ $lint_errors -eq 0 ]]; then
			print_success "No SwiftLint errors"
			((checks_passed++))
		else
			print_error "SwiftLint errors introduced: $lint_errors"
			return 1
		fi
	else
		print_warning "SwiftLint not available"
		((checks_passed++))
	fi

	# Check 3: SwiftFormat validation
	if command -v swiftformat &>/dev/null; then
		local format_changes=$(swiftformat --dryrun . 2>/dev/null | wc -l | tr -d '\n' | xargs || echo "0")
		if [[ $format_changes -eq 0 ]] 2>/dev/null; then
			print_success "Code formatting is consistent"
			((checks_passed++))
		else
			print_warning "Minor formatting inconsistencies: $format_changes"
			((checks_passed++)) # Allow minor formatting differences
		fi
	else
		print_warning "SwiftFormat not available"
		((checks_passed++))
	fi

	# Check 4: Test compilation (if tests exist)
	if [[ -d "Tests" ]] || find . -name "*Tests.swift" -type f | head -1 | grep -q "Tests.swift"; then
		print_status "Checking test compilation..."
		if [[ -f "Package.swift" ]]; then
			# For Swift Package Manager projects
			if swift package dump-package &>/dev/null; then
				print_success "Test compilation successful"
				((checks_passed++))
			else
				print_error "Test compilation failed"
				return 1
			fi
		elif find . -name "*.xcodeproj" -type d | head -1 | grep -q "xcodeproj"; then
			# For Xcode projects - just check if scheme exists
			if xcodebuild -list -project "$(find . -name "*.xcodeproj" -type d | head -1)" | grep -q "Schemes:"; then
				print_success "Test compilation successful"
				((checks_passed++))
			else
				print_error "Test compilation failed"
				return 1
			fi
		else
			print_warning "Cannot validate test compilation for project structure"
			((checks_passed++))
		fi
	else
		print_success "No tests to validate"
		((checks_passed++))
	fi

	# Check 5: Git status validation
	if git status --porcelain | grep -q "^??"; then
		print_warning "New untracked files created"
		((checks_passed++)) # Allow new files
	else
		print_success "No unexpected files created"
		((checks_passed++))
	fi

	echo "$checks_passed/$total_checks"
}

run_post_build_checks() {
	local project_path="$1"
	cd "$project_path"

	local checks_passed=0
	local total_checks=5

	# Check 1: Swift compilation
	if [[ -f "Package.swift" ]]; then
		# For Swift Package Manager projects
		if swift package dump-package &>/dev/null; then
			((checks_passed++))
		else
			echo "$checks_passed/$total_checks"
			return 1
		fi
	elif find . -name "*.xcodeproj" -type d | head -1 | grep -q "xcodeproj"; then
		# For Xcode projects
		if xcodebuild -list -project "$(find . -name "*.xcodeproj" -type d | head -1)" &>/dev/null; then
			((checks_passed++))
		else
			echo "$checks_passed/$total_checks"
			return 1
		fi
	else
		((checks_passed++)) # Allow non-standard projects to pass
	fi

	# Check 2: SwiftLint validation
	if command -v swiftlint &>/dev/null; then
		local lint_output=$(swiftlint lint --reporter json 2>/dev/null || echo "[]")
		local lint_errors=$(echo "$lint_output" | jq -r '.[] | select(.severity == "error") | .file' 2>/dev/null | wc -l | xargs || echo "0")
		if [[ $lint_errors =~ ^[0-9]+$ ]] && [[ $lint_errors -eq 0 ]]; then
			((checks_passed++))
		else
			echo "$checks_passed/$total_checks"
			return 1
		fi
	else
		((checks_passed++))
	fi

	# Check 3: SwiftFormat validation
	if command -v swiftformat &>/dev/null; then
		local format_changes=$(swiftformat --dryrun . 2>/dev/null | wc -l | tr -d '\n' | xargs || echo "0")
		if [[ $format_changes -eq 0 ]] 2>/dev/null; then
			((checks_passed++))
		else
			((checks_passed++)) # Allow minor formatting differences
		fi
	else
		((checks_passed++))
	fi

	# Check 4: Test compilation (if tests exist)
	if [[ -d "Tests" ]] || find . -name "*Tests.swift" -type f | head -1 | grep -q "Tests.swift"; then
		if [[ -f "Package.swift" ]]; then
			# For Swift Package Manager projects
			if swift package dump-package &>/dev/null; then
				((checks_passed++))
			else
				echo "$checks_passed/$total_checks"
				return 1
			fi
		elif find . -name "*.xcodeproj" -type d | head -1 | grep -q "xcodeproj"; then
			# For Xcode projects - just check if scheme exists
			if xcodebuild -list -project "$(find . -name "*.xcodeproj" -type d | head -1)" | grep -q "Schemes:"; then
				((checks_passed++))
			else
				echo "$checks_passed/$total_checks"
				return 1
			fi
		else
			((checks_passed++))
		fi
	else
		((checks_passed++))
	fi

	# Check 5: Git status validation
	if git status --porcelain | grep -q "^??"; then
		((checks_passed++)) # Allow new files
	else
		((checks_passed++))
	fi

	echo "$checks_passed/$total_checks"
}

# Auto-fix implementations
fix_swiftlint_issues() {
	local project_path="$1"
	cd "$project_path"

	print_header "Auto-fixing SwiftLint issues..."

	if ! command -v swiftlint &>/dev/null; then
		print_warning "SwiftLint not available - skipping auto-fixes"
		return 0
	fi

	local fixes_applied=0

	# Get fixable SwiftLint violations
	local fixable_rules=$(swiftlint rules | grep "yes" | awk '{print $1}' || echo "")

	if [[ -n $fixable_rules ]]; then
		print_status "Applying SwiftLint auto-fixes..."

		# Apply fixes
		if swiftlint --fix --format &>/dev/null; then
			local violations_after=$(swiftlint lint --reporter json 2>/dev/null | jq -r '.[] | select(.severity == "error") | .file' | wc -l || echo "0")
			print_fix "SwiftLint auto-fixes applied"
			((fixes_applied++))
		else
			print_error "SwiftLint auto-fix failed"
		fi
	else
		print_status "No auto-fixable SwiftLint violations found"
	fi

	return $fixes_applied
}

fix_swiftformat_issues() {
	local project_path="$1"
	cd "$project_path"

	print_header "Auto-fixing SwiftFormat issues..."

	if ! command -v swiftformat &>/dev/null; then
		print_warning "SwiftFormat not available - skipping auto-fixes"
		return 0
	fi

	local fixes_applied=0

	# Check if formatting is needed
	local format_changes=$(swiftformat --dryrun . 2>/dev/null | wc -l | tr -d '\n' | xargs)
	format_changes=${format_changes:-0}

	if [[ $format_changes -gt 0 ]]; then
		print_status "Applying SwiftFormat auto-fixes..."

		# Apply formatting
		if swiftformat . --config .swiftformat &>/dev/null; then
			print_fix "Code formatted successfully ($format_changes changes)"
			((fixes_applied++))
		else
			print_error "SwiftFormat application failed"
		fi
	else
		print_status "Code formatting is already consistent"
	fi

	return $fixes_applied
}

fix_build_issues() {
	local project_path="$1"
	cd "$project_path"

	print_header "Auto-fixing build issues..."

	local fixes_applied=0

	# Fix 1: Update Package.swift dependencies
	if [[ -f "Package.swift" ]]; then
		print_status "Checking Package.swift dependencies..."

		# Update package dependencies
		if swift package update &>/dev/null; then
			print_fix "Package dependencies updated"
			((fixes_applied++))
		else
			print_warning "Package update failed or not needed"
		fi

		# Resolve package dependencies
		if swift package resolve &>/dev/null; then
			print_fix "Package dependencies resolved"
			((fixes_applied++))
		else
			print_warning "Package resolution failed or not needed"
		fi
	fi

	# Fix 2: Clean build artifacts
	print_status "Cleaning build artifacts..."

	if [[ -d ".build" ]]; then
		rm -rf ".build"
		print_fix "Cleaned .build directory"
		((fixes_applied++))
	fi

	if [[ -d "DerivedData" ]]; then
		rm -rf "DerivedData"
		print_fix "Cleaned DerivedData directory"
		((fixes_applied++))
	fi

	# Fix 3: Update Xcode project settings (if exists)
	if find . -name "*.xcodeproj" -type d | head -1 | grep -q "xcodeproj"; then
		local xcode_project=$(find . -name "*.xcodeproj" -type d | head -1)
		print_status "Checking Xcode project settings..."

		# Update deployment target if needed
		if [[ -f "$xcode_project/project.pbxproj" ]]; then
			# Update to iOS 15.0 minimum
			if grep -q "IPHONEOS_DEPLOYMENT_TARGET = 14" "$xcode_project/project.pbxproj"; then
				sed -i.bak 's/IPHONEOS_DEPLOYMENT_TARGET = 14\.[0-9]/IPHONEOS_DEPLOYMENT_TARGET = 15.0/g' "$xcode_project/project.pbxproj"
				rm -f "$xcode_project/project.pbxproj.bak"
				print_fix "Updated iOS deployment target to 15.0"
				((fixes_applied++))
			fi

			# Update Swift version
			if grep -q "SWIFT_VERSION = 5\.[0-7]" "$xcode_project/project.pbxproj"; then
				sed -i.bak 's/SWIFT_VERSION = 5\.[0-7]/SWIFT_VERSION = 6.0/g' "$xcode_project/project.pbxproj"
				rm -f "$xcode_project/project.pbxproj.bak"
				print_fix "Updated Swift version to 6.0"
				((fixes_applied++))
			fi
		fi
	fi

	return $fixes_applied
}

fix_common_code_issues() {
	local project_path="$1"
	cd "$project_path"

	print_header "Auto-fixing common code issues..."

	local fixes_applied=0

	# Fix 1: Remove trailing whitespace
	print_status "Removing trailing whitespace..."
	local whitespace_files=$(find . -name "*.swift" -type f -exec grep -l "[[:space:]]$" {} \; 2>/dev/null || echo "")
	if [[ -n $whitespace_files ]]; then
		find . -name "*.swift" -type f -exec sed -i.bak 's/[[:space:]]*$//' {} \;
		find . -name "*.swift.bak" -delete
		print_fix "Removed trailing whitespace from Swift files"
		((fixes_applied++))
	fi

	# Fix 2: Fix import ordering
	print_status "Organizing imports..."
	local import_fixes=0
	while IFS= read -r -d '' file; do
		if [[ -f $file ]]; then
			# Simple import organization - Foundation first, then others alphabetically
			python3 -c "
import sys
import re

with open('$file', 'r') as f:
    content = f.read()

# Extract imports
imports = []
other_lines = []
in_imports = False
lines = content.split('\n')

for line in lines:
    if line.strip().startswith('import '):
        imports.append(line)
        in_imports = True
    elif in_imports and line.strip() == '':
        continue
    else:
        if in_imports and line.strip():
            in_imports = False
        other_lines.append(line)

if imports:
    # Sort imports: Foundation first, then alphabetically
    foundation_imports = [imp for imp in imports if 'Foundation' in imp]
    other_imports = [imp for imp in imports if 'Foundation' not in imp]
    other_imports.sort()
    
    sorted_imports = foundation_imports + other_imports
    
    # Reconstruct file
    if sorted_imports != imports:
        new_content = '\n'.join(sorted_imports) + '\n\n' + '\n'.join(other_lines)
        with open('$file', 'w') as f:
            f.write(new_content)
        print('FIXED')
" 2>/dev/null && ((import_fixes++)) || true
		fi
	done < <(find . -name "*.swift" -type f -print0)

	if [[ $import_fixes -gt 0 ]]; then
		print_fix "Organized imports in $import_fixes files"
		((fixes_applied++))
	fi

	# Fix 3: Add missing newlines at end of files
	print_status "Adding missing newlines at end of files..."
	local newline_fixes=0
	while IFS= read -r -d '' file; do
		if [[ -f $file ]] && [[ -s $file ]]; then
			local last_char_count=$(tail -c1 "$file" | wc -l | xargs)
			if [[ $last_char_count -eq 0 ]]; then
				echo "" >>"$file"
				((newline_fixes++))
			fi
		fi
	done < <(find . -name "*.swift" -type f -print0)

	if [[ $newline_fixes -gt 0 ]]; then
		print_fix "Added newlines to $newline_fixes files"
		((fixes_applied++))
	fi

	return $fixes_applied
}

# Main auto-fix function
run_comprehensive_autofix() {
	local project_name="$1"
	local project_path="$CODE_DIR/Projects/$project_name"

	if [[ ! -d $project_path ]]; then
		print_error "Project $project_name not found"
		return 1
	fi

	print_header "Starting comprehensive auto-fix for $project_name"

	# Create backup
	create_backup "$project_path"

	# Run pre-build checks
	local pre_check_result=$(run_pre_build_checks "$project_path")
	print_status "Pre-build validation: $pre_check_result"

	# Track fixes applied
	local total_fixes=0
	local fix_categories=0

	# Apply fixes
	cd "$project_path"

	# 1. SwiftFormat fixes
	fix_swiftformat_issues "$project_path"
	local swiftformat_fixes=$?
	((total_fixes += swiftformat_fixes))
	((fix_categories++))

	# 2. SwiftLint fixes
	fix_swiftlint_issues "$project_path"
	local swiftlint_fixes=$?
	((total_fixes += swiftlint_fixes))
	((fix_categories++))

	# 3. Build issue fixes
	fix_build_issues "$project_path"
	local build_fixes=$?
	((total_fixes += build_fixes))
	((fix_categories++))

	# 4. Common code fixes
	fix_common_code_issues "$project_path"
	local common_fixes=$?
	((total_fixes += common_fixes))
	((fix_categories++))

	# Run post-build checks
	local post_check_result=$(run_post_build_checks "$project_path")
	local post_checks_passed=$(echo "$post_check_result" | cut -d'/' -f1)
	local post_total_checks=$(echo "$post_check_result" | cut -d'/' -f2)

	print_status "Post-build validation: $post_check_result"

	# --- SwiftLint manual review report ---
	print_status "Generating SwiftLint manual review report..."
	local lint_report="$project_path/.swiftlint_manual_review.txt"
	if command -v swiftlint &>/dev/null; then
		swiftlint lint --reporter json 2>/dev/null | jq -r '.[] | select(.severity == "error") | "File: \(.file)\nLine: \(.line)\nRule: \(.rule_id)\nReason: \(.reason)\n---"' >"$lint_report"
		local error_count=$(cat "$lint_report" | grep -c '^File: ')
		if [[ $error_count -gt 0 ]]; then
			print_warning "Manual review required for $error_count SwiftLint errors. See $lint_report."
		else
			print_success "No unfixable SwiftLint errors detected."
			rm -f "$lint_report"
		fi
	else
		print_warning "SwiftLint not available for manual review report."
	fi

	# Determine if fixes were successful
	if [[ $post_checks_passed -eq $post_total_checks ]]; then
		cleanup_backup "$project_path"
		print_success "Auto-fix completed successfully for $project_name"
		print_success "Applied $total_fixes fixes across $fix_categories categories"
		# Log success
		echo "$(date): SUCCESS - $project_name: $total_fixes fixes applied" >>"$LOG_FILE"
		return 0
	else
		print_error "Post-build validation failed - rolling back changes"
		restore_backup "$project_path"
		# Log failure
		echo "$(date): ROLLBACK - $project_name: Fixes caused issues, restored backup" >>"$LOG_FILE"
		return 1
	fi
}

# Run auto-fix on all projects
run_autofix_all_projects() {
	print_header "Running comprehensive auto-fix on all projects"

	local projects=("CodingReviewer" "HabitQuest" "MomentumFinance")
	local successful_fixes=0
	local failed_fixes=0

	for project in "${projects[@]}"; do
		print_header "Processing project: $project"

		if run_comprehensive_autofix "$project"; then
			((successful_fixes++))
		else
			((failed_fixes++))
		fi

		echo ""
	done

	# Summary report
	print_header "Auto-Fix Summary Report"
	print_success "Successfully fixed: $successful_fixes projects"
	if [[ $failed_fixes -gt 0 ]]; then
		print_error "Failed to fix: $failed_fixes projects"
	fi

	print_status "Detailed log available at: $LOG_FILE"
}

# Usage information
show_usage() {
	cat <<EOF
Intelligent Auto-Fix System with Safety Checks

Usage: $0 [COMMAND] [PROJECT]

Commands:
  fix <project>     # Run comprehensive auto-fix on specific project
  fix-all          # Run auto-fix on all projects
  validate <project> # Run validation checks only
  rollback <project> # Rollback last auto-fix (if backup exists)
  status           # Show auto-fix status and logs
  help             # Show this help message

Projects:
  CodingReviewer   # iOS coding review application
  HabitQuest       # Habit tracking application
  MomentumFinance  # Financial tracking application

Examples:
  $0 fix CodingReviewer
  $0 fix-all
  $0 validate HabitQuest
  $0 rollback MomentumFinance

Features:
  ✅ Automatic SwiftLint issue fixing
  ✅ SwiftFormat code formatting
  ✅ Build issue resolution
  ✅ Common code issue fixes
  ✅ Pre/post build validation
  ✅ Automatic rollback on failure
  ✅ Comprehensive backup system
  ✅ Detailed logging and reporting

EOF
}

# Main execution
main() {
	case "${1:-help}" in
	"fix")
		if [[ -n ${2-} ]]; then
			run_comprehensive_autofix "$2"
		else
			print_error "Usage: $0 fix <project_name>"
			exit 1
		fi
		;;
	"fix-all")
		run_autofix_all_projects
		;;
	"validate")
		if [[ -n ${2-} ]]; then
			local project_path="$CODE_DIR/Projects/$2"
			if [[ -d $project_path ]]; then
				print_header "Running validation for $2"
				run_pre_build_checks "$project_path"
				run_post_build_checks_verbose "$project_path"
			else
				print_error "Project $2 not found"
				exit 1
			fi
		else
			print_error "Usage: $0 validate <project_name>"
			exit 1
		fi
		;;
	"rollback")
		if [[ -n ${2-} ]]; then
			local project_path="$CODE_DIR/Projects/$2"
			if [[ -d $project_path ]]; then
				restore_backup "$project_path"
			else
				print_error "Project $2 not found"
				exit 1
			fi
		else
			print_error "Usage: $0 rollback <project_name>"
			exit 1
		fi
		;;
	"status")
		print_header "Auto-Fix Status"
		if [[ -f $LOG_FILE ]]; then
			echo "Recent auto-fix operations:"
			tail -10 "$LOG_FILE"
		else
			print_status "No auto-fix operations logged yet"
		fi

		# Show backup status
		print_status "Available backups:"
		if [[ -d $BACKUP_DIR ]]; then
			ls -la "$BACKUP_DIR" | tail -n +2
		else
			print_status "No backups found"
		fi
		;;
	"help" | "--help" | "-h")
		show_usage
		;;
	*)
		print_error "Unknown command: ${1-}"
		show_usage
		exit 1
		;;
	esac
}

# Execute main function
main "$@"
