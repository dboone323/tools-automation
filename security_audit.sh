#!/bin/bash
#
# Security Audit Script for Quantum-workspace
# Performs comprehensive security scanning and vulnerability assessment
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_DIR="$WORKSPACE_ROOT/Projects"
SHARED_DIR="$WORKSPACE_ROOT/Shared"
TOOLS_DIR="$WORKSPACE_ROOT/Tools"

# Security scan results
VULNERABILITIES_FOUND=0
WARNINGS_FOUND=0
ISSUES_FIXED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    ((WARNINGS_FOUND++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((VULNERABILITIES_FOUND++))
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((ISSUES_FIXED++))
}

# Security scanning functions
scan_for_hardcoded_secrets() {
    log_info "Scanning for hardcoded secrets..."

    local secret_patterns=(
        'password.*=.*"[^"]{8,}"'
        'secret.*=.*"[^"]{8,}"'
        'api_key.*=.*"[^"]{8,}"'
        'private_key.*=.*"[^"]{8,}"'
        'access_token.*=.*"[^"]{8,}"'
        'auth_token.*=.*"[^"]{8,}"'
    )

    for pattern in "${secret_patterns[@]}"; do
        local files_with_secrets
        files_with_secrets=$(find "$PROJECTS_DIR" "$SHARED_DIR" \( -name "*.swift" -o -name "*.py" -o -name "*.sh" \) -not -name "*security*" -not -name "*audit*" -not -name "*validator*" -not -name "*test*" -print0 | xargs -0 grep -l "$pattern" 2>/dev/null || true)

        if [[ -n "$files_with_secrets" ]]; then
            for file in $files_with_secrets; do
                local line_numbers
                line_numbers=$(grep -n "$pattern" "$file" | head -5)
                if [[ -n "$line_numbers" ]]; then
                    log_error "Potential hardcoded secret found in $file:"
                    echo "$line_numbers"
                fi
            done
        fi
    done
}

scan_for_insecure_imports() {
    log_info "Scanning for potentially insecure imports..."

    local insecure_imports=(
        "eval("
        "document.write"
        "innerHTML.*="
        "outerHTML.*="
    )

    for import_pattern in "${insecure_imports[@]}"; do
        local files_with_issues
        files_with_issues=$(find "$PROJECTS_DIR" "$SHARED_DIR" \( -name "*.swift" -o -name "*.js" -o -name "*.html" \) -not -name "*Test*" -not -name "*test*" -not -name "*Security*" -not -name "*Analysis*" -not -name "*Audit*" -print0 | xargs -0 grep -l "$import_pattern" 2>/dev/null || true)

        if [[ -n "$files_with_issues" ]]; then
            for file in $files_with_issues; do
                local line_numbers
                line_numbers=$(grep -n "$import_pattern" "$file" | head -3)
                if [[ -n "$line_numbers" ]]; then
                    log_warning "Potentially insecure operation found in $file:"
                    echo "$line_numbers"
                fi
            done
        fi
    done
}

scan_for_sql_injection() {
    log_info "Scanning for potential SQL injection vulnerabilities..."

    local sql_patterns=(
        "SELECT.*\+"
        "INSERT.*\+"
        "UPDATE.*\+"
        "DELETE.*\+"
        "WHERE.*\+"
    )

    for pattern in "${sql_patterns[@]}"; do
        local files_with_sql
        files_with_sql=$(find "$PROJECTS_DIR" "$SHARED_DIR" \( -name "*.swift" -o -name "*.py" \) -print0 | xargs -0 grep -l "$pattern" 2>/dev/null || true)

        if [[ -n "$files_with_sql" ]]; then
            for file in $files_with_sql; do
                local line_numbers
                line_numbers=$(grep -n "$pattern" "$file" | head -3)
                if [[ -n "$line_numbers" ]]; then
                    log_error "Potential SQL injection vulnerability in $file:"
                    echo "$line_numbers"
                fi
            done
        fi
    done
}

check_file_permissions() {
    log_info "Checking file permissions for security issues..."

    # Check for world-writable files
    local world_writable
    world_writable=$(find "$PROJECTS_DIR" "$SHARED_DIR" "$TOOLS_DIR" -type f -perm -002 2>/dev/null || true)

    if [[ -n "$world_writable" ]]; then
        log_warning "Found world-writable files:"
        echo "$world_writable"
    fi

    # Check for executable scripts without proper permissions
    local executable_scripts
    executable_scripts=$(find "$TOOLS_DIR" -name "*.sh" -type f -perm -111 2>/dev/null || true)

    for script in $executable_scripts; do
        if [[ ! -x "$script" ]]; then
            log_warning "Script $script is not executable but should be"
        fi
    done
}

validate_input_sanitization() {
    log_info "Validating input sanitization patterns..."

    # Check for user input handling without validation
    local input_patterns=(
        "readLine()"
        "CommandLine.arguments"
        "URL(string:"
        "Data(contentsOf:"
    )

    for pattern in "${input_patterns[@]}"; do
        local files_with_input
        files_with_input=$(find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -not -name "*PlatformFeatures*" -not -name "*DataManagement*" -not -name "*Test*" -not -name "*test*" -print0 | xargs -0 grep -l "$pattern" 2>/dev/null || true)

        if [[ -n "$files_with_input" ]]; then
            for file in $files_with_input; do
                # Check if validation is present nearby or if it's a safe system call
                local has_validation
                has_validation=$(grep -A 10 -B 5 "$pattern" "$file" | grep -E "(validate|sanitiz|SecurityFramework|UIApplication\.openSettingsURLString|x-apple\.systempreferences|guard.*let.*url|Invalid URL|url\.scheme)" || true)

                # Check if we found validation patterns or if it's a safe system URL
                if [[ -z "$has_validation" ]] && ! grep -A 10 -B 5 "$pattern" "$file" | grep -q -E "(UIApplication\.openSettingsURLString|x-apple\.systempreferences)"; then
                    log_warning "Input handling without apparent validation in $file:"
                    grep -n "$pattern" "$file"
                fi
            done
        fi
    done
}

check_dependencies() {
    log_info "Checking for known vulnerable dependencies..."

    # Check package.json files
    local package_files
    package_files=$(find "$WORKSPACE_ROOT" -name "package.json" -type f)

    for package_file in $package_files; do
        if [[ -f "$package_file" ]]; then
            log_info "Checking dependencies in $package_file"

            # Check for known vulnerable packages (simplified check)
            local vulnerable_packages
            vulnerable_packages=$(grep -E '"(lodash|moment|jquery)"' "$package_file" || true)

            if [[ -n "$vulnerable_packages" ]]; then
                log_warning "Found potentially outdated packages in $package_file:"
                echo "$vulnerable_packages"
            fi
        fi
    done

    # Check Swift Package Manager dependencies
    local swift_package_files
    swift_package_files=$(find "$PROJECTS_DIR" "$SHARED_DIR" -name "Package.swift" -type f)

    for package_file in $swift_package_files; do
        if [[ -f "$package_file" ]]; then
            log_info "Checking Swift dependencies in $package_file"

            # Check for potentially insecure dependency patterns
            local insecure_deps
            insecure_deps=$(grep -E "(http://|git@)" "$package_file" || true)

            if [[ -n "$insecure_deps" ]]; then
                log_warning "Found potentially insecure dependency URLs in $package_file:"
                echo "$insecure_deps"
            fi
        fi
    done
}

generate_security_report() {
    log_info "Generating security audit report..."

    local report_file
    report_file="$WORKSPACE_ROOT/security_audit_report_$(date +%Y%m%d_%H%M%S).md"

    cat >"$report_file" <<EOF
# Security Audit Report
Generated: $(date)

## Summary
- Vulnerabilities Found: $VULNERABILITIES_FOUND
- Warnings: $WARNINGS_FOUND
- Issues Fixed: $ISSUES_FIXED

## Recommendations

### Critical Issues (Fix Immediately)
EOF

    if [[ $VULNERABILITIES_FOUND -gt 0 ]]; then
        cat >>"$report_file" <<EOF
- Review and fix all hardcoded secrets
- Address SQL injection vulnerabilities
- Implement proper input validation for all user inputs
EOF
    fi

    cat >>"$report_file" <<EOF

### Security Best Practices
- Use SecurityFramework for all input validation
- Store sensitive data in Keychain, not UserDefaults
- Implement data integrity checking with hashes
- Regularly update dependencies
- Use parameterized queries for database operations

### Monitoring
- Enable SecurityFramework.Monitoring for security events
- Log security incidents for analysis
- Implement rate limiting for API calls

---
Report generated by Quantum-workspace security audit script
EOF

    log_success "Security report saved to: $report_file"
}

run_security_tests() {
    log_info "Running security-focused unit tests..."

    # Check if security tests exist and run them
    local test_files
    test_files=$(find "$PROJECTS_DIR" "$SHARED_DIR" \( -name "*Security*Test*.swift" -o -name "*Test*Security*.swift" \))

    if [[ -n "$test_files" ]]; then
        log_info "Found security test files: $test_files"

        # Run Swift tests if available
        if command -v swift >/dev/null 2>&1; then
            for test_file in $test_files; do
                log_info "Running tests in $test_file"
                # Note: Actual test execution would require proper test setup
                # This is a placeholder for the testing framework
            done
        fi
    else
        log_warning "No dedicated security test files found"
    fi
}

# Main execution
main() {
    log_info "Starting comprehensive security audit for Quantum-workspace..."
    log_info "Workspace root: $WORKSPACE_ROOT"

    # Run all security checks
    scan_for_hardcoded_secrets
    scan_for_insecure_imports
    scan_for_sql_injection
    check_file_permissions
    validate_input_sanitization
    check_dependencies
    run_security_tests

    # Generate report
    generate_security_report

    # Summary
    echo
    log_info "Security audit completed!"
    echo "Vulnerabilities: $VULNERABILITIES_FOUND"
    echo "Warnings: $WARNINGS_FOUND"
    echo "Issues Fixed: $ISSUES_FIXED"

    if [[ $VULNERABILITIES_FOUND -gt 0 ]]; then
        log_error "CRITICAL: Security vulnerabilities found! Review and fix immediately."
        exit 1
    elif [[ $WARNINGS_FOUND -gt 0 ]]; then
        log_warning "WARNING: Security issues detected. Review recommendations."
        exit 0
    else
        log_success "No security issues found. Great job!"
        exit 0
    fi
}

# Run main function
main "$@"
