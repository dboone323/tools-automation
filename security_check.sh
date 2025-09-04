#!/bin/bash

# Security Check Script for Quantum Workspace
# Performs security validation before deployments

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
	echo -e "${BLUE}[SECURITY]${NC} $1"
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

# Check for exposed secrets
check_exposed_secrets() {
	print_status "Checking for exposed secrets..."

	local found_secrets=0

	if grep -r -i "password\|secret\|token\|api_key" "${REPO_ROOT}" \
		--exclude-dir=".git" \
		--exclude-dir="node_modules" \
		--exclude-dir="Pods" \
		--exclude="*.log" \
		--exclude="*.tmp" |
		grep -v "placeholder\|example\|test\|mock" |
		grep -v "Pods/"; then
		print_warning "Potential exposed secrets found"
		found_secrets=1
	fi

	if [[ ${found_secrets} -eq 0 ]]; then
		print_success "No exposed secrets detected"
	fi

	return "${found_secrets}"
}

# Check file permissions
check_file_permissions() {
	print_status "Checking file permissions..."

	local insecure_files=0

	# Check for world-writable files
	if find "${REPO_ROOT}" -type f -perm -002 -not -path "*/.git/*" -not -path "*/node_modules/*" | grep -v ".DS_Store" | head -5; then
		print_warning "Found world-writable files"
		insecure_files=1
	fi

	if [[ ${insecure_files} -eq 0 ]]; then
		print_success "File permissions are secure"
	fi

	return "${insecure_files}"
}

# Check for insecure git configurations
check_git_security() {
	print_status "Checking git security configuration..."

	local git_issues=0

	# Check if we're in a git repository
	if [[ ! -d "${REPO_ROOT}/.git" ]]; then
		print_warning "Not in a git repository"
		return 1
	fi

	# Check git configuration
	if git config --get user.email | grep -q "noreply"; then
		print_warning "Using noreply email - consider using a real email for commits"
		git_issues=1
	fi

	if [[ ${git_issues} -eq 0 ]]; then
		print_success "Git configuration appears secure"
	fi

	return "${git_issues}"
}

# Validate YAML files for security issues
check_yaml_security() {
	print_status "Checking YAML files for security issues..."

	if ! command -v python3 >/dev/null 2>&1; then
		print_warning "Python3 not available for YAML validation"
		return 1
	fi

	local yaml_issues=0

	# Check workflow files with simple validation
	for yaml_file in "${REPO_ROOT}/.github/workflows"/*.yml; do
		if [[ -f ${yaml_file} ]]; then
			if python3 -c "import yaml; yaml.safe_load(open('${yaml_file}'))"; then
				echo "  ✅ $(basename "${yaml_file}"): Valid YAML"
			else
				echo "  ❌ $(basename "${yaml_file}"): Invalid YAML"
				yaml_issues=1
			fi
		fi
	done

	if [[ ${yaml_issues} -eq 0 ]]; then
		print_success "YAML files are valid"
	fi

	return "${yaml_issues}"
}

# Main security check
main() {
	print_status "Starting comprehensive security check..."
	echo

	local total_issues=0

	check_exposed_secrets
	total_issues=$((total_issues + $?))

	echo
	check_file_permissions
	total_issues=$((total_issues + $?))

	echo
	check_git_security
	total_issues=$((total_issues + $?))

	echo
	check_yaml_security
	total_issues=$((total_issues + $?))

	echo
	if [[ ${total_issues} -eq 0 ]]; then
		print_success "🎉 Security check passed! No issues found."
		return 0
	else
		print_error "❌ Security check failed! Found ${total_issues} issue(s)."
		echo
		print_status "Recommendations:"
		echo "  - Review and remove any exposed secrets"
		echo "  - Fix file permissions (scripts should be executable by owner only)"
		echo "  - Clean sensitive data from git history if found"
		echo "  - Validate all YAML configuration files"
		return 1
	fi
}

# Run main function
main "$@"
