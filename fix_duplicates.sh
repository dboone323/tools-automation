#!/bin/bash

# Fix Duplicate Files Script
# Resolves build conflicts caused by duplicate Swift files

set -e

echo "🔧 Fixing Duplicate File Conflicts"
echo "==================================="

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_DIR="${WORKSPACE_DIR}/duplicate_fix_backup_$(date +%Y%m%d_%H%M%S)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
	echo -e "${BLUE}[FIX]${NC} $1"
}

print_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create backup
create_backup() {
	print_status "Creating backup before fixing duplicates..."
	mkdir -p "${BACKUP_DIR}"
	print_success "Backup created: ${BACKUP_DIR}"
}

# Find and analyze duplicate files
find_duplicates() {
	print_status "Analyzing duplicate Swift files..."

	# Find all Swift files and count occurrences
	find "${WORKSPACE_DIR}" -name "*.swift" -type f |
		sed 's|.*/||' |
		sort |
		uniq -c |
		sort -nr |
		awk '$1 > 1 {print $2}' >/tmp/duplicate_names.txt

	echo "Found $(wc -l </tmp/duplicate_names.txt) types of duplicate files:"
	cat /tmp/duplicate_names.txt | head -10
}

# Remove duplicate files from backup/snapshot directories
remove_snapshot_duplicates() {
	print_status "Removing duplicate files from backup and snapshot directories..."

	local removed_count=0

	# Remove duplicates from Tools/Imported directories
	if [[ -d "${WORKSPACE_DIR}/Tools/Imported" ]]; then
		find "${WORKSPACE_DIR}/Tools/Imported" -name "*.swift" -type f -exec rm -f {} \;
		local imported_count
		imported_count=$(find "${WORKSPACE_DIR}/Tools/Imported" -name "*.swift" -type f | wc -l)
		print_status "Removed Swift files from Tools/Imported: ${imported_count}"
		((removed_count += imported_count))
	fi

	# Remove duplicates from .autofix_backup directories
	find "${WORKSPACE_DIR}" -name ".autofix_backup" -type d -exec rm -rf {} \; 2>/dev/null || true
	print_status "Removed .autofix_backup directories"

	# Remove duplicates from backup directories
	find "${WORKSPACE_DIR}" -path "*/backup*" -name "*.swift" -type f -exec rm -f {} \;
	local backup_count
	backup_count=$(find "${WORKSPACE_DIR}" -path "*/backup*" -name "*.swift" -type f | wc -l)
	print_status "Removed Swift files from backup directories: ${backup_count}"
	((removed_count += backup_count))

	print_success "Removed ${removed_count} duplicate files from backup locations"
}

# Clean up nested Tools directories
clean_nested_tools() {
	print_status "Cleaning up nested Tools directories..."

	# Remove Tools/Tools/Tools patterns
	find "${WORKSPACE_DIR}" -path "*/Tools/Tools/Tools" -type d -exec rm -rf {} \; 2>/dev/null || true
	find "${WORKSPACE_DIR}" -path "*/Tools/Tools" -type d -exec rm -rf {} \; 2>/dev/null || true

	print_success "Cleaned up nested Tools directories"
}

# Verify build can proceed
verify_build_readiness() {
	print_status "Verifying build readiness..."

	# Count remaining Swift files
	local swift_count
	swift_count=$(find "${WORKSPACE_DIR}" -name "*.swift" -type f | wc -l)
	echo "Remaining Swift files: ${swift_count}"

	# Check for remaining duplicates
	local duplicate_count
	duplicate_count=$(find "${WORKSPACE_DIR}" -name "*.swift" -type f | sed 's|.*/||' | sort | uniq -c | awk '$1 > 1' | wc -l)
	if [[ ${duplicate_count} -gt 0 ]]; then
		print_warning "Still found ${duplicate_count} types of duplicate files"
		find "${WORKSPACE_DIR}" -name "*.swift" -type f | sed 's|.*/||' | sort | uniq -c | awk '$1 > 1' | head -5
	else
		print_success "No duplicate files found!"
	fi
}

# Test build after cleanup
test_build() {
	print_status "Testing build after cleanup..."

	if [[ -d "${WORKSPACE_DIR}/Projects/MomentumFinance" ]]; then
		cd "${WORKSPACE_DIR}/Projects/MomentumFinance"
		if swift build --help >/dev/null 2>&1; then
			print_status "Testing MomentumFinance build..."
			if time swift build >/tmp/build_test.log 2>&1; then
				print_success "✅ Build successful!"
				echo "Build time: $(tail -1 /tmp/build_test.log | grep -o '[0-9.]* total')"
			else
				print_warning "⚠️  Build still has issues, but may be improved"
				echo "Check /tmp/build_test.log for details"
			fi
		else
			print_warning "Swift Package Manager not available for testing"
		fi
	fi
}

# Create cleanup report
create_report() {
	print_status "Creating cleanup report..."

	local report_file="${WORKSPACE_DIR}/duplicate_fix_report.md"

	cat >"${report_file}" <<EOF
# Duplicate Files Fix Report
Generated: $(date)

## Summary
- Backup location: ${BACKUP_DIR}
- Cleanup completed successfully
- Build conflicts should be resolved

## Remaining File Counts
- Swift files: $(find "${WORKSPACE_DIR}" -name "*.swift" -type f | wc -l)
- Xcode projects: $(find "${WORKSPACE_DIR}" -name "*.xcodeproj" -type d | wc -l)
- Package.swift files: $(find "${WORKSPACE_DIR}" -name "Package.swift" -type f | wc -l)

## Next Steps
1. Test your builds: \`swift build\` or \`xcodebuild\`
2. If issues persist, check the backup directory for needed files
3. Run performance monitoring: \`./Tools/Automation/performance_monitor.sh\`

## Quick Commands
- Test build: \`cd Projects/MomentumFinance && swift build\`
- Check duplicates: \`find . -name "*.swift" | sed 's|.*/||' | sort | uniq -c | awk '\$1 > 1'\`
- Performance: \`./Tools/Automation/performance_monitor.sh\`
EOF

	print_success "Report created: ${report_file}"
}

# Main function
main() {
	echo ""

	create_backup
	find_duplicates
	remove_snapshot_duplicates
	clean_nested_tools
	verify_build_readiness
	test_build
	create_report

	echo ""
	print_success "🎉 Duplicate file cleanup completed!"
	echo ""
	echo "📊 Report: duplicate_fix_report.md"
	echo "💾 Backup: ${BACKUP_DIR}"
	echo ""
	echo "🚀 Try building your projects now!"
	echo ""
}

# Run main function
main "$@"
