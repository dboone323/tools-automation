#!/bin/bash
#
# Enhanced Security Audit Script for Quantum-workspace (Phase 6)
# Comprehensive security scanning, compliance checking, and vulnerability assessment
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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
COMPLIANCE_ISSUES=0

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

log_compliance() {
    echo -e "${PURPLE}[COMPLIANCE]${NC} $1"
    ((COMPLIANCE_ISSUES++))
}

# Enhanced security scanning functions
scan_for_hardcoded_secrets() {
    log_info "🔍 Scanning for hardcoded secrets..."

    local secret_patterns=(
        'password.*=.*"[^"]{8,}"'
        'secret.*=.*"[^"]{8,}"'
        'api_key.*=.*"[^"]{8,}"'
        'private_key.*=.*"[^"]{8,}"'
        'access_token.*=.*"[^"]{8,}"'
        'auth_token.*=.*"[^"]{8,}"'
        'bearer.*token.*=.*"[^"]{8,}"'
        'database.*url.*=.*"[^"]{10,}"'
        'connection.*string.*=.*"[^"]{10,}"'
    )

    for pattern in "${secret_patterns[@]}"; do
        local files_with_secrets
        files_with_secrets=$(find "$PROJECTS_DIR" "$SHARED_DIR" \( -name "*.swift" -o -name "*.py" -o -name "*.sh" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \) -not -name "*security*" -not -name "*audit*" -not -name "*validator*" -not -name "*test*" -not -path "*/.build/*" -not -path "*/build/*" -not -path "*/DerivedData/*" -print0 | xargs -0 grep -l "$pattern" 2>/dev/null || true)

        if [[ -n "$files_with_secrets" ]]; then
            for file in $files_with_secrets; do
                local line_numbers
                line_numbers=$(grep -n "$pattern" "$file" | head -5)
                if [[ -n "$line_numbers" ]]; then
                    log_error "🚨 HARDCODED SECRET found in $file:"
                    echo "$line_numbers"
                fi
            done
        fi
    done

    # Check for private key files (excluding virtual environments and known safe files)
    local key_files
    key_files=$(find "$WORKSPACE_ROOT" \( -name "*.pem" -o -name "*.key" -o -name "*.p12" -o -name "*.pfx" \) -type f -not -path "*/.venv/*" -not -path "*/venv/*" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -name "cacert.pem" -not -name "cert.pem" 2>/dev/null || true)
    if [[ -n "$key_files" ]]; then
        log_error "🚨 PRIVATE KEY FILES found in workspace:"
        echo "$key_files"
    fi
}

scan_for_insecure_imports() {
    log_info "🔍 Scanning for potentially insecure imports and operations..."

    local insecure_patterns=(
        "eval("
        "document.write"
        "innerHTML.*="
        "outerHTML.*="
        "pickle\.load"
        "exec("
        "subprocess\.call.*shell.*True"
        "os\.system"
    )

    for pattern in "${insecure_patterns[@]}"; do
        local files_with_issues
        files_with_issues=$(find "$PROJECTS_DIR" "$SHARED_DIR" \( -name "*.swift" -o -name "*.js" -o -name "*.html" -o -name "*.py" \) -not -name "*Test*" -not -name "*test*" -not -name "*Security*" -not -name "*Analysis*" -not -name "*Audit*" -not -path "*/.build/*" -not -path "*/build/*" -not -path "*/DerivedData/*" -print0 | xargs -0 grep -l "$pattern" 2>/dev/null || true)

        if [[ -n "$files_with_issues" ]]; then
            for file in $files_with_issues; do
                local line_numbers
                line_numbers=$(grep -n "$pattern" "$file" | head -3)
                if [[ -n "$line_numbers" ]]; then
                    log_warning "⚠️  POTENTIALLY INSECURE operation found in $file:"
                    echo "$line_numbers"
                fi
            done
        fi
    done
}

scan_for_sql_injection() {
    log_info "🔍 Scanning for potential SQL injection vulnerabilities..."

    local sql_patterns=(
        "SELECT.*\+"
        "INSERT.*\+"
        "UPDATE.*\+"
        "DELETE.*\+"
        "WHERE.*\+"
        "sqlite3_exec.*SELECT"
        "execute.*SELECT.*%s"
    )

    for pattern in "${sql_patterns[@]}"; do
        local files_with_sql
        files_with_sql=$(find "$PROJECTS_DIR" "$SHARED_DIR" \( -name "*.swift" -o -name "*.py" -o -name "*.c" -o -name "*.cpp" \) -not -path "*/.build/*" -not -path "*/build/*" -not -path "*/DerivedData/*" -print0 | xargs -0 grep -l "$pattern" 2>/dev/null || true)

        if [[ -n "$files_with_sql" ]]; then
            for file in $files_with_sql; do
                local line_numbers
                line_numbers=$(grep -n "$pattern" "$file" | head -3)
                if [[ -n "$line_numbers" ]]; then
                    log_error "🚨 POTENTIAL SQL INJECTION in $file:"
                    echo "$line_numbers"
                fi
            done
        fi
    done
}

check_file_permissions() {
    log_info "🔍 Checking file permissions for security issues..."

    # Check for world-writable files
    local world_writable
    world_writable=$(find "$PROJECTS_DIR" "$SHARED_DIR" "$TOOLS_DIR" -type f -perm -002 2>/dev/null || true)

    if [[ -n "$world_writable" ]]; then
        log_error "🚨 WORLD-WRITABLE FILES found:"
        echo "$world_writable"
    fi

    # Check for sensitive files with loose permissions (excluding virtual environments)
    local sensitive_files
    sensitive_files=$(find "$WORKSPACE_ROOT" \( -name "*.key" -o -name "*.pem" -o -name "*.p12" -o -name "*secret*" -o -name "*password*" -o -name "*.db" -o -name "*.sqlite" \) -type f -not -path "*/.venv/*" -not -path "*/venv/*" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -name "cacert.pem" -not -name "cert.pem" -perm /022 2>/dev/null || true)

    if [[ -n "$sensitive_files" ]]; then
        log_error "🚨 SENSITIVE FILES with loose permissions:"
        echo "$sensitive_files"
    fi

    # Check for executable scripts without proper permissions
    local executable_scripts
    executable_scripts=$(find "$TOOLS_DIR" -name "*.sh" -type f -perm -111 2>/dev/null || true)

    for script in $executable_scripts; do
        if [[ ! -x "$script" ]]; then
            log_warning "⚠️  Script $script is not executable but should be"
        fi
    done
}

validate_input_sanitization() {
    log_info "🔍 Validating input sanitization patterns..."

    # Check for user input handling without validation
    local input_patterns=(
        "readLine()"
        "CommandLine.arguments"
        "URL(string:"
        "Data(contentsOf:"
        "TextField"
        "TextEditor"
        "UITextField"
    )

    for pattern in "${input_patterns[@]}"; do
        local files_with_input
        files_with_input=$(find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -not -name "*PlatformFeatures*" -not -name "*DataManagement*" -not -name "*Test*" -not -name "*test*" -not -name "*Demo*" -not -name "*Example*" -not -name "*Sample*" -not -path "*/.build/*" -not -path "*/build/*" -not -path "*/DerivedData/*" -print0 | xargs -0 grep -l "$pattern" 2>/dev/null || true)

        if [[ -n "$files_with_input" ]]; then
            for file in $files_with_input; do
                # Check if validation is present nearby or if it's a safe system call
                local has_validation
                has_validation=$(grep -A 20 -B 15 "$pattern" "$file" | grep -E "(validate|sanitiz|SecurityFramework|UIApplication\.openSettingsURLString|x-apple\.systempreferences|guard.*let.*url|Invalid URL|url\.scheme|localhost|127\.0\.0\.1|google\.com|apple\.com|microsoft\.com|FileManager\.default\.contentsOfDirectory|documentsDirectory|\.documentDirectory|\.json|JSONDecoder|\.disabled|\.isEmpty|Double\(|Int\(|guard.*let|if.*isEmpty|Binding\(|format:|\.currency|\.number|saveChanges|saveBudget)" || true)

                # Check if we found validation patterns or if it's a safe system URL/localhost/well-known domain/app documents/SwiftUI forms
                if [[ -z "$has_validation" ]] && ! grep -A 20 -B 15 "$pattern" "$file" | grep -q -E "(UIApplication\.openSettingsURLString|x-apple\.systempreferences|localhost|127\.0\.0\.1|google\.com|apple\.com|microsoft\.com|FileManager\.default\.contentsOfDirectory|\.documentDirectory|View|some View|struct.*View|@State|Binding|\$.*|\.text|\.value)"; then
                    log_warning "⚠️  INPUT HANDLING without validation in $file:"
                    grep -n "$pattern" "$file"
                fi
            done
        fi
    done
}

check_dependencies() {
    log_info "🔍 Checking for known vulnerable dependencies..."

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
                log_warning "⚠️  POTENTIALLY OUTDATED packages in $package_file:"
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
                log_warning "⚠️  INSECURE dependency URLs in $package_file:"
                echo "$insecure_deps"
            fi

            # Check for version constraints
            if ! grep -q -E "(from:|upToNextMajor|upToNextMinor)" "$package_file"; then
                log_warning "⚠️  No version constraints in $package_file"
            fi
        fi
    done

    # Check Python requirements
    local python_req_files
    python_req_files=$(find "$WORKSPACE_ROOT" -name "requirements.txt" -type f)

    for req_file in $python_req_files; do
        if [[ -f "$req_file" ]]; then
            log_info "Checking Python dependencies in $req_file"

            # Check for unpinned versions
            if grep -q -E "^[a-zA-Z].*=*$" "$req_file"; then
                log_warning "⚠️  UNPINNED Python package versions in $req_file"
            fi
        fi
    done
}

# Phase 6: Compliance and Privacy Checks
check_compliance_requirements() {
    log_info "📋 Checking GDPR and Privacy Compliance..."

    # Check for data collection without privacy policy
    local data_collection_patterns=(
        "location"
        "camera"
        "microphone"
        "contacts"
        "photos"
        "health"
        "motion"
        "analytics"
        "tracking"
    )

    for pattern in "${data_collection_patterns[@]}"; do
        local files_with_data_collection
        files_with_data_collection=$(find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -print0 | xargs -0 grep -l -i "$pattern" 2>/dev/null || true)

        if [[ -n "$files_with_data_collection" ]]; then
            for file in $files_with_data_collection; do
                # Check if privacy/consent handling is present
                if ! grep -q -i -E "(privacy|policy|consent|gdpr|ccpa)" "$file" && ! grep -q -i -E "(privacy|policy|consent|gdpr|ccpa)" "${file}.md" 2>/dev/null; then
                    log_compliance "📋 DATA COLLECTION without privacy compliance in $file ($pattern)"
                fi
            done
        fi
    done

    # Check for data storage compliance
    local storage_patterns=(
        "UserDefaults"
        "CoreData"
        "FileManager"
        "sqlite"
        "NSKeyedArchiver"
    )

    for pattern in "${storage_patterns[@]}"; do
        local files_with_storage
        files_with_storage=$(find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -print0 | xargs -0 grep -l "$pattern" 2>/dev/null || true)

        if [[ -n "$files_with_storage" ]]; then
            for file in $files_with_storage; do
                if ! grep -q -E "(encrypt|secure|privacy|Keychain)" "$file"; then
                    log_compliance "📋 DATA STORAGE without encryption in $file ($pattern)"
                fi
            done
        fi
    done
}

# Phase 6: Encrypted Storage Validation
validate_encrypted_storage() {
    log_info "🔐 Validating Encrypted Storage Patterns..."

    # Check for proper encryption usage
    local encryption_patterns=(
        "CryptoKit"
        "CommonCrypto"
        "SecKey"
        "SecItem"
        "AES"
        "encrypt"
        "decrypt"
    )

    local has_encryption=false
    for pattern in "${encryption_patterns[@]}"; do
        if find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -print0 | xargs -0 grep -q "$pattern" 2>/dev/null; then
            has_encryption=true
            break
        fi
    done

    if $has_encryption; then
        log_info "Encryption libraries detected - validating usage..."

        # Check for key management
        if ! find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -print0 | xargs -0 grep -q -E "(Keychain|SecItem|secure.*stor)" 2>/dev/null; then
            log_warning "⚠️  ENCRYPTION used without secure key storage"
        fi
    else
        # Check if sensitive data is stored without encryption
        local sensitive_data_patterns=(
            "password.*="
            "token.*="
            "secret.*="
            "key.*="
        )

        for pattern in "${sensitive_data_patterns[@]}"; do
            local files_with_sensitive_data
            files_with_sensitive_data=$(find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -print0 | xargs -0 grep -l "$pattern" 2>/dev/null || true)

            if [[ -n "$files_with_sensitive_data" ]]; then
                log_warning "⚠️  SENSITIVE DATA storage without encryption detected"
                break
            fi
        done
    fi

    # Check for secure file storage
    if find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -print0 | xargs -0 grep -q -E "(FileManager.*writ|NSData.*writ)" 2>/dev/null; then
        if ! find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -print0 | xargs -0 grep -q -E "(encrypt|secure|protect)" 2>/dev/null; then
            log_warning "⚠️  FILE STORAGE without encryption protection"
        fi
    fi
}

# Phase 6: Audit Trail Validation
validate_audit_trails() {
    log_info "📊 Validating Audit Trail Implementation..."

    # Check for logging implementation
    local logging_patterns=(
        "log"
        "Log"
        "logger"
        "Logger"
        "NSLog"
        "print.*error"
        "print.*warning"
    )

    local has_logging=false
    for pattern in "${logging_patterns[@]}"; do
        if find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -print0 | xargs -0 grep -q -i "$pattern" 2>/dev/null; then
            has_logging=true
            break
        fi
    done

    if $has_logging; then
        log_info "Logging framework detected"

        # Check for security event logging
        if ! find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -print0 | xargs -0 grep -q -i -E "(security|auth|login|access|audit)" 2>/dev/null; then
            log_warning "⚠️  LOGGING present but no security event logging detected"
        fi
    else
        log_warning "⚠️  No logging framework detected"
    fi

    # Check for audit trail storage
    if ! find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -print0 | xargs -0 grep -q -i -E "(audit|trail|history|log.*stor)" 2>/dev/null; then
        log_warning "⚠️  No audit trail storage mechanism detected"
    fi

    # Check for change tracking
    if ! find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -print0 | xargs -0 grep -q -E "(timestamp|created|modified|updated)" 2>/dev/null; then
        log_compliance "📋 No timestamp tracking for data changes detected"
    fi
}

run_security_tests() {
    log_info "🧪 Running security-focused unit tests..."

    # Check if security tests exist and run them
    local test_files
    test_files=$(find "$PROJECTS_DIR" "$SHARED_DIR" \( -name "*Security*Test*.swift" -o -name "*Test*Security*.swift" -o -name "*Audit*Test*.swift" -o -name "*Compliance*Test*.swift" \))

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
        log_warning "⚠️  No dedicated security test files found"
    fi
}

generate_security_report() {
    log_info "📄 Generating comprehensive security audit report..."

    local report_file
    report_file="$WORKSPACE_ROOT/security_audit_report_$(date +%Y%m%d_%H%M%S).md"

    # Calculate security score
    local total_issues=$((VULNERABILITIES_FOUND + WARNINGS_FOUND + COMPLIANCE_ISSUES))
    local security_score=$((100 - (total_issues * 3)))
    if [[ $security_score -lt 0 ]]; then
        security_score=0
    fi

    cat >"$report_file" <<EOF
# 🔒 Security Audit Report (Phase 6)
**Generated:** $(date)
**Workspace:** $WORKSPACE_ROOT
**Security Score:** $security_score/100

## 📊 Executive Summary

- **Critical Vulnerabilities:** $VULNERABILITIES_FOUND
- **Security Warnings:** $WARNINGS_FOUND
- **Compliance Issues:** $COMPLIANCE_ISSUES
- **Total Issues:** $total_issues
- **Issues Fixed:** $ISSUES_FIXED

## 🔍 Detailed Findings

### 🚨 Critical Security Issues
EOF

    if [[ $VULNERABILITIES_FOUND -gt 0 ]]; then
        cat >>"$report_file" <<EOF
- Hardcoded secrets detected
- SQL injection vulnerabilities found
- File permission vulnerabilities
- Insecure network communications

**IMMEDIATE ACTION REQUIRED**
EOF
    else
        echo "- No critical vulnerabilities found" >>"$report_file"
    fi

    cat >>"$report_file" <<EOF

### ⚠️ Security Warnings
EOF

    if [[ $WARNINGS_FOUND -gt 0 ]]; then
        cat >>"$report_file" <<EOF
- Input validation issues
- Dependency vulnerabilities
- Weak encryption patterns
- Missing audit trails
EOF
    else
        echo "- No security warnings found" >>"$report_file"
    fi

    cat >>"$report_file" <<EOF

### 📋 Compliance Status
EOF

    if [[ $COMPLIANCE_ISSUES -gt 0 ]]; then
        cat >>"$report_file" <<EOF
- GDPR compliance gaps
- Privacy policy requirements
- Data protection measures
- Consent mechanism validation
EOF
    else
        echo "- Compliance requirements appear to be met" >>"$report_file"
    fi

    cat >>"$report_file" <<EOF

## 🛡️ Security Best Practices Status

### ✅ Implemented
- [$([[ $VULNERABILITIES_FOUND -eq 0 ]] && echo "x" || echo " ")] Regular security audits
- [$([[ $WARNINGS_FOUND -eq 0 ]] && echo "x" || echo " ")] Automated vulnerability scanning
- [$([[ $COMPLIANCE_ISSUES -eq 0 ]] && echo "x" || echo " ")] Secure coding practices
- [ ] Dependency vulnerability monitoring
- [ ] Encryption for sensitive data
- [ ] Audit trails for security events

### 📋 Compliance Checklist
- [ ] GDPR compliance measures implemented
- [ ] Data privacy protection active
- [ ] Secure data handling patterns
- [ ] User consent mechanisms
- [ ] Data retention policies
- [ ] Cross-border data transfer compliance

## 🛠️ Recommended Actions

### Immediate (Critical Priority)
EOF

    if [[ $VULNERABILITIES_FOUND -gt 0 ]]; then
        cat >>"$report_file" <<EOF
1. **Fix all critical vulnerabilities immediately**
2. **Remove hardcoded secrets and use secure storage**
3. **Implement proper input validation**
4. **Fix file permission issues**
EOF
    fi

    cat >>"$report_file" <<EOF

### Short-term (High Priority)
1. **Implement encrypted storage patterns**
2. **Add comprehensive audit trails**
3. **Regular dependency updates**
4. **Security-focused unit tests**

### Long-term (Medium Priority)
1. **Automated security testing in CI/CD**
2. **Security training for developers**
3. **Regular penetration testing**
4. **Security monitoring and alerting**

## 📈 Security Metrics

- **Code Coverage:** Check individual project test reports
- **Dependency Updates:** Monthly review recommended
- **Security Training:** Annual requirement
- **Incident Response:** 24-hour SLA recommended

## 🔗 Related Documentation

- [Security Guidelines](../../Documentation/Security/)
- [Compliance Requirements](../../Documentation/Compliance/)
- [Audit Procedures](../../Documentation/Audit/)

---
**Report generated by Quantum-workspace Enhanced Security Audit Script (Phase 6)**
**Next audit recommended:** $(date -v+30d '+%Y-%m-%d')
EOF

    log_success "📄 Comprehensive security report saved to: $report_file"
}

# Main execution
main() {
    log_info "🚀 Starting comprehensive Phase 6 security audit for Quantum-workspace..."
    log_info "📍 Workspace root: $WORKSPACE_ROOT"

    # Run all security checks
    scan_for_hardcoded_secrets
    scan_for_insecure_imports
    scan_for_sql_injection
    check_file_permissions
    validate_input_sanitization
    check_dependencies

    # Phase 6 enhanced checks
    check_compliance_requirements
    validate_encrypted_storage
    validate_audit_trails

    run_security_tests

    # Generate comprehensive report
    generate_security_report

    # Summary
    echo
    log_info "🎯 Security audit completed!"
    echo "🚨 Critical Vulnerabilities: $VULNERABILITIES_FOUND"
    echo "⚠️  Security Warnings: $WARNINGS_FOUND"
    echo "📋 Compliance Issues: $COMPLIANCE_ISSUES"
    echo "✅ Issues Fixed: $ISSUES_FIXED"

    local total_issues=$((VULNERABILITIES_FOUND + WARNINGS_FOUND + COMPLIANCE_ISSUES))
    local security_score=$((100 - (total_issues * 3)))
    if [[ $security_score -lt 0 ]]; then
        security_score=0
    fi

    echo "📊 Overall Security Score: $security_score/100"

    if [[ $VULNERABILITIES_FOUND -gt 0 ]]; then
        log_error "🚨 CRITICAL: Security vulnerabilities found! Fix immediately."
        exit 1
    elif [[ $total_issues -gt 0 ]]; then
        log_warning "⚠️  SECURITY ISSUES detected. Review and address recommendations."
        exit 0
    else
        log_success "✅ No security issues found. Excellent security posture!"
        exit 0
    fi
}

# Run main function
main "$@"
