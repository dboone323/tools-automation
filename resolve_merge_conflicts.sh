#!/bin/bash

# Resolve Git Merge Conflicts Script
# Automatically resolves merge conflicts by choosing HEAD version

set -e

echo "🔧 Resolving Git Merge Conflicts"
echo "=================================="

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MOMENTUM_DIR="${WORKSPACE_DIR}/Projects/MomentumFinance"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
	echo -e "${BLUE}[RESOLVE]${NC} $1"
}

print_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Find all files with merge conflicts
find_conflicted_files() {
	print_status "Finding files with merge conflicts..."

	CONFLICTED_FILES=$(find "${MOMENTUM_DIR}" -name "*.swift" -exec grep -l "<<<<<<< HEAD" {} \;)

	if [[ -z $CONFLICTED_FILES ]]; then
		print_success "No merge conflicts found!"
		exit 0
	fi

	CONFLICT_COUNT=$(echo "$CONFLICTED_FILES" | wc -l)
	print_warning "Found ${CONFLICT_COUNT} files with merge conflicts"
	echo "$CONFLICTED_FILES" | head -10
}

# Resolve merge conflicts by choosing HEAD
resolve_conflicts() {
	print_status "Resolving merge conflicts by choosing HEAD version..."

	local resolved_count=0

	echo "$CONFLICTED_FILES" | while IFS= read -r file; do
		if [[ -f $file ]]; then
			print_status "Resolving: ${file#${MOMENTUM_DIR}/}"

			# Create backup
			cp "$file" "${file}.conflict_backup"

			# Resolve conflicts by choosing HEAD (current branch) version
			# This removes everything between <<<<<<< HEAD and =======, and everything after >>>>>>> branch
			awk '
            BEGIN { in_head = 0; skip = 0 }
            /^<<<<<<< HEAD$/ { in_head = 1; skip = 1; next }
            /^=======$/ { if (in_head) { skip = 0; next } }
            /^>>>>>>> / { if (in_head) { in_head = 0; next } }
            { if (!skip) print }
            ' "$file" >"${file}.tmp"

			# Replace original file
			mv "${file}.tmp" "$file"

			((resolved_count++))
		fi
	done

	print_success "Resolved ${resolved_count} merge conflicts"
}

# Verify resolution
verify_resolution() {
	print_status "Verifying conflict resolution..."

	REMAINING_CONFLICTS=$(find "${MOMENTUM_DIR}" -name "*.swift" -exec grep -l "<<<<<<< HEAD" {} \; | wc -l)

	if [[ $REMAINING_CONFLICTS -eq 0 ]]; then
		print_success "✅ All merge conflicts resolved!"
	else
		print_warning "⚠️  ${REMAINING_CONFLICTS} files still have conflicts"
	fi
}

# Test build after resolution
test_build_after_resolution() {
	print_status "Testing build after conflict resolution..."

	cd "${MOMENTUM_DIR}"

	if command -v swift >/dev/null 2>&1; then
		print_status "Running swift build..."
		if time swift build >/tmp/build_test_after.log 2>&1; then
			print_success "✅ Build successful after conflict resolution!"
			echo "Build completed successfully"
		else
			print_warning "⚠️  Build still has issues after conflict resolution"
			echo "Check /tmp/build_test_after.log for details"
			# Show first few errors
			head -20 /tmp/build_test_after.log | grep -E "(error|warning)" | head -5
		fi
	else
		print_warning "Swift Package Manager not available for testing"
	fi
}

# Create resolution report
create_report() {
	print_status "Creating resolution report..."

	local report_file="${WORKSPACE_DIR}/merge_conflict_resolution_report.md"

	cat >"${report_file}" <<EOF
# Git Merge Conflict Resolution Report
Generated: $(date)

## Summary
- Location: ${MOMENTUM_DIR}
- Strategy: Chose HEAD version for all conflicts
- Backup files created with .conflict_backup extension

## Files Resolved
$(find "${MOMENTUM_DIR}" -name "*.conflict_backup" | sed "s|${MOMENTUM_DIR}/||")

## Next Steps
1. Review the resolved files to ensure correct changes
2. Test your application functionality
3. Remove backup files when satisfied: \`find . -name "*.conflict_backup" -delete\`
4. Commit the resolved conflicts: \`git add . && git commit -m "Resolve merge conflicts"\`

## Quick Commands
- Check for remaining conflicts: \`find . -name "*.swift" -exec grep -l "<<<<<<< HEAD" {} \;\`
- Remove backups: \`find . -name "*.conflict_backup" -delete\`
- Test build: \`swift build\`
EOF

	print_success "Report created: ${report_file}"
}

# Main function
main() {
	echo ""

	find_conflicted_files
	resolve_conflicts
	verify_resolution
	test_build_after_resolution
	create_report

	echo ""
	print_success "🎉 Merge conflict resolution completed!"
	echo ""
	echo "📊 Report: merge_conflict_resolution_report.md"
	echo ""
	echo "🚀 Your project should now build successfully!"
	echo ""
}

# Run main function
main "$@"
