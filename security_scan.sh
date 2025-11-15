#!/bin/bash

# Tools Automation Security Scanner
# Comprehensive security scanning for production readiness
# Includes Trivy vulnerability scans, code analysis, and system security checks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SECURITY_LOG="$PROJECT_ROOT/logs/security_scan_$(date +%Y%m%d_%H%M%S).log"
REPORTS_DIR="$PROJECT_ROOT/security_reports"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$SECURITY_LOG"
}

error() {
    echo -e "${RED}🚨 SECURITY RISK: $*${NC}" >&2
    log "SECURITY RISK: $*"
}

warn() {
    echo -e "${YELLOW}⚠️ SECURITY WARNING: $*${NC}"
    log "SECURITY WARNING: $*"
}

info() {
    echo -e "${BLUE}ℹ️ INFO: $*${NC}"
    log "INFO: $*"
}

success() {
    echo -e "${GREEN}✅ SECURE: $*${NC}"
    log "SECURE: $*"
}

header() {
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${PURPLE}$*${NC}"
    echo -e "${PURPLE}================================================${NC}"
}

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

# Initialize security scanning environment
init_security_scan() {
    header "SECURITY SCANNING INITIALIZATION"

    mkdir -p "$REPORTS_DIR"
    mkdir -p "$PROJECT_ROOT/security"

    info "Security scanning environment initialized"
    info "Security log: $SECURITY_LOG"
}

# Check if Trivy is installed
check_trivy() {
    if ! command -v trivy >/dev/null 2>&1; then
        print_error "Trivy is not installed."
        print_status "Install Trivy:"
        echo "  macOS: brew install trivy"
        echo "  Linux: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
        return 1
    fi
    return 0
}

# Scan filesystem for vulnerabilities
scan_filesystem() {
    local path;
    path="${1:-.}"
    local severity;
    severity="${2:-HIGH,CRITICAL}"

    print_status "Scanning filesystem: ${path}"

    if check_trivy; then
        trivy fs \
            --severity "${severity}" \
            --format table \
            --exit-code 0 \
            "${path}"
    else
        warn "Trivy not available, skipping filesystem scan"
    fi
}

# Scan container image
scan_image() {
    local image;
    image="$1"
    local severity;
    severity="${2:-HIGH,CRITICAL}"

    if [[ -z "${image}" ]]; then
        print_error "Please specify an image to scan"
        echo "Usage: $0 image <image_name> [severity]"
        exit 1
    fi

    print_status "Scanning container image: ${image}"

    if check_trivy; then
        trivy image \
            --severity "${severity}" \
            --format table \
            --exit-code 0 \
            "${image}"
    else
        warn "Trivy not available, skipping image scan"
    fi
}

# Scan running containers
scan_containers() {
    print_status "Scanning running containers..."

    if ! command -v docker >/dev/null 2>&1; then
        warn "Docker not available, skipping container scan"
        return 0
    fi

    # Get running containers
    local containers
    containers=$(docker ps --format "table {{.Names}}\t{{.Image}}" | tail -n +2)

    if [[ -z "${containers}" ]]; then
        print_warning "No running containers found"
        return 0
    fi

    if check_trivy; then
        echo "${containers}" | while read -r line; do
            if [[ -n "${line}" ]]; then
                local name image
                name=$(echo "${line}" | awk '{print $1}')
                image=$(echo "${line}" | awk '{print $2}')

                print_status "Scanning container: ${name} (${image})"
                trivy image \
                    --severity HIGH,CRITICAL \
                    --format table \
                    --exit-code 0 \
                    "${image}"
                echo ""
            fi
        done
    else
        warn "Trivy not available, skipping container scan"
    fi
}

# Scan Docker Compose services
scan_compose() {
    local compose_file;
    compose_file="${1:-docker-compose.monitoring.yml}"
    local severity;
    severity="${2:-HIGH,CRITICAL}"

    if [[ ! -f "${compose_file}" ]]; then
        print_error "Docker Compose file not found: ${compose_file}"
        exit 1
    fi

    print_status "Scanning Docker Compose file: ${compose_file}"

    if check_trivy; then
        # Extract images from compose file
        local images
        images=$(grep "image:" "${compose_file}" | sed 's/.*image:\s*//')

        for image in ${images}; do
            if [[ -n "${image}" ]]; then
                print_status "Scanning image: ${image}"
                trivy image \
                    --severity "${severity}" \
                    --format table \
                    --exit-code 0 \
                    "${image}"
                echo ""
            fi
        done
    else
        warn "Trivy not available, skipping compose scan"
    fi
}

# Scan for hardcoded secrets and sensitive data
scan_hardcoded_secrets() {
    header "HARDCODED SECRETS SCAN"

    local secrets_found;

    secrets_found=0
    local report_file;
    report_file="$REPORTS_DIR/secrets_scan_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "=== HARDCODED SECRETS SCAN ==="
        echo "Timestamp: $(date)"
        echo ""

        echo "=== POTENTIAL API KEYS/TOKENS ==="
        find "$PROJECT_ROOT" -name "*.py" -o -name "*.sh" -o -name "*.json" -o -name "*.yml" | head -20 | xargs grep -l "api[_-]\?key\|token\|secret" 2>/dev/null | head -5 | while read -r file; do
            echo "⚠️  POTENTIAL SECRET FILE: $file"
            ((secrets_found++))
        done
        echo ""

        echo "=== HARDCODED PASSWORDS ==="
        find "$PROJECT_ROOT" -name "*.py" -o -name "*.sh" -o -name "*.json" | head -10 | xargs grep -l "password\|passwd\|pwd" 2>/dev/null | head -3 | while read -r file; do
            echo "⚠️  HARDCODED PASSWORD FILE: $file"
            ((secrets_found++))
        done
        echo ""

        echo "=== PRIVATE KEYS ==="
        grep -r "BEGIN.*PRIVATE KEY\|BEGIN.*RSA PRIVATE\|BEGIN.*DSA PRIVATE" "$PROJECT_ROOT" \
            --include="*" --exclude-dir=".git" -l | while read -r file; do
            echo "🚨 PRIVATE KEY FOUND: $file"
            ((secrets_found++))
        done

    } >"$report_file"

    cat "$report_file"

    if [ $secrets_found -gt 0 ]; then
        error "Found $secrets_found potential hardcoded secrets"
    else
        success "No hardcoded secrets detected"
    fi

    log "Secrets scan completed: $secrets_found secrets found"
}

# Scan Python code for security vulnerabilities
scan_python_security() {
    header "PYTHON CODE SECURITY SCAN"

    local vuln_found;

    vuln_found=0
    local report_file;
    report_file="$REPORTS_DIR/python_security_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "=== PYTHON CODE SECURITY SCAN ==="
        echo "Timestamp: $(date)"
        echo ""

        echo "=== DANGEROUS FUNCTION USAGE ==="
        local dangerous_functions;
        dangerous_functions=("eval" "exec" "input" "pickle.loads" "subprocess.call" "os.system")

        for func in "${dangerous_functions[@]}"; do
            grep -r "$func" "$PROJECT_ROOT" \
                --include="*.py" \
                --exclude-dir=".git" --exclude-dir="__pycache__" \
                -n | head -5 | while read -r line; do
                echo "⚠️  DANGEROUS FUNCTION: $func - $line"
                ((vuln_found++))
            done
        done
        echo ""

        echo "=== INSECURE IMPORTS ==="
        grep -r "^import pickle\|^from pickle import\|^import subprocess\|^from subprocess import" "$PROJECT_ROOT" \
            --include="*.py" --exclude-dir=".git" --exclude-dir="__pycache__" \
            -n | head -5 | while read -r line; do
            echo "⚠️  INSECURE IMPORT: $line"
            ((vuln_found++))
        done

    } >"$report_file"

    cat "$report_file"

    if [ $vuln_found -gt 0 ]; then
        warn "Found $vuln_found Python security vulnerabilities"
    else
        success "No Python security vulnerabilities found"
    fi

    log "Python security scan completed: $vuln_found vulnerabilities found"
}

# Scan file permissions and ownership
scan_file_permissions() {
    header "FILE PERMISSIONS SCAN"

    local issues_found;

    issues_found=0
    local report_file;
    report_file="$REPORTS_DIR/permissions_scan_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "=== FILE PERMISSIONS SECURITY SCAN ==="
        echo "Timestamp: $(date)"
        echo ""

        echo "=== WORLD-WRITABLE FILES ==="
        find "$PROJECT_ROOT" -type f -perm -002 2>/dev/null | while read -r file; do
            if [[ "$file" != *".git"* ]] && [[ "$file" != *"__pycache__"* ]]; then
                echo "⚠️  WORLD-WRITABLE: $file"
                ((issues_found++))
            fi
        done
        echo ""

        echo "=== SENSITIVE FILES WITH LOOSE PERMISSIONS ==="
        local sensitive_files;
        sensitive_files=("agents.db" "*.key" "*.pem" "*secret*" "*password*")
        for pattern in "${sensitive_files[@]}"; do
            find "$PROJECT_ROOT" -name "$pattern" -type f -exec ls -la {} \; 2>/dev/null |
                awk '$1 ~ /^-..w/ {print "⚠️  SENSITIVE FILE WITH GROUP/OTHER WRITE: " $9}' | while read -r line; do
                echo "$line"
                ((issues_found++))
            done
        done

    } >"$report_file"

    cat "$report_file"

    if [ $issues_found -gt 0 ]; then
        warn "Found $issues_found file permission issues"
    else
        success "No file permission issues found"
    fi

    log "File permissions scan completed: $issues_found issues found"
}

# Generate comprehensive security report
generate_report() {
    local output_file;
    output_file="${1:-security_report_$(date +%Y%m%d_%H%M%S).md}"
    local total_issues;
    total_issues=0

    header "SECURITY SCAN REPORT GENERATION"

    # Count issues from all scan reports
    for scan_file in "$REPORTS_DIR"/*_scan_*.txt; do
        if [ -f "$scan_file" ]; then
            local issues
            issues=$(grep -c "⚠️\|🚨\|❌" "$scan_file" 2>/dev/null || echo "0")
            total_issues=$((total_issues + issues))
        fi
    done

    {
        echo "# Security Scan Report"
        echo ""
        echo "## Executive Summary"
        echo "- **Scan Date:** $(date)"
        echo "- **Total Security Issues Found:** $total_issues"
        echo "- **Security Log:** $SECURITY_LOG"
        echo ""

        echo "## Vulnerability Scans"
        echo ""

        # Run Trivy scans if available
        if check_trivy; then
            echo "### Filesystem Vulnerabilities"
            echo "\`\`\`"
            trivy fs --severity HIGH,CRITICAL --format table --exit-code 0 . 2>/dev/null || echo "Trivy scan failed"
            echo "\`\`\`"
            echo ""

            if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
                echo "### Container Vulnerabilities"
                echo "\`\`\`"
                scan_containers
                echo "\`\`\`"
                echo ""
            fi
        else
            echo "### Trivy Not Available"
            echo "Install Trivy for comprehensive vulnerability scanning."
            echo ""
        fi

        # Include results from custom scans
        for scan_file in "$REPORTS_DIR"/*_scan_*.txt; do
            if [ -f "$scan_file" ]; then
                local scan_name
                scan_name=$(basename "$scan_file" | sed 's/_scan_.*\.txt//' | tr '_' ' ' | sed 's/\b\w/\U&/g')
                echo "### $scan_name Scan"
                echo "\`\`\`"
                cat "$scan_file"
                echo "\`\`\`"
                echo ""
            fi
        done

        echo "## Risk Assessment"
        if [ $total_issues -eq 0 ]; then
            echo "🟢 **LOW RISK** - No security issues detected"
        elif [ $total_issues -lt 5 ]; then
            echo "🟡 **MEDIUM RISK** - Minor security issues found, recommend remediation"
        elif [ $total_issues -lt 15 ]; then
            echo "🟠 **HIGH RISK** - Significant security issues found, immediate action required"
        else
            echo "🔴 **CRITICAL RISK** - Multiple severe security issues, immediate lockdown recommended"
        fi
        echo ""

        echo "## Recommendations"
        echo "1. Review and remediate all flagged security issues"
        echo "2. Implement regular automated security scanning"
        echo "3. Use environment variables for secrets instead of hardcoding"
        echo "4. Keep dependencies updated and scan for vulnerabilities"
        echo "5. Implement proper access controls and authentication"
        echo "6. Regular security training for development team"
        echo ""

    } >"$output_file"

    success "Comprehensive security report generated: $output_file"

    # Print summary
    echo
    header "SECURITY SCAN SUMMARY"
    echo "Total Security Issues Found: $total_issues"
    echo "Detailed Report: $output_file"

    if [ $total_issues -gt 0 ]; then
        warn "Security issues detected - review report and take action"
    else
        success "Security scan completed - no issues found"
    fi
}

# Run comprehensive security audit
audit_security() {
    print_status "Running comprehensive security audit..."

    echo "========================================"
    echo "🔒 Tools Automation Security Audit"
    echo "========================================"
    echo ""

    init_security_scan

    # Run all security scans
    scan_file_permissions
    scan_hardcoded_secrets
    scan_python_security

    # Run Trivy scans if available
    if check_trivy; then
        print_status "Running filesystem vulnerability scan..."
        scan_filesystem .

        if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
            print_status "Running container security scan..."
            scan_containers
        else
            print_warning "Docker not available, skipping container scan"
        fi
    else
        warn "Trivy not available, skipping vulnerability scans"
    fi

    echo ""
    generate_report
    print_success "Security audit completed"
}

# Show usage
show_usage() {
    echo "🔒 Tools Automation Security Scanner"
    echo ""
    echo "Usage: $0 {fs [path] [severity]|image <image> [severity]|containers|compose [file] [severity]|report [output_file]|audit|permissions|secrets|python}"
    echo ""
    echo "Commands:"
    echo "  fs [path] [sev]     # Scan filesystem (default: .) (default severity: HIGH,CRITICAL)"
    echo "  image <img> [sev]   # Scan container image"
    echo "  containers          # Scan all running containers"
    echo "  compose [file] [sev]# Scan Docker Compose file (default: docker-compose.monitoring.yml)"
    echo "  report [file]       # Generate comprehensive security report"
    echo "  audit               # Run comprehensive security audit (all scans)"
    echo "  permissions         # Scan file permissions and ownership"
    echo "  secrets             # Scan for hardcoded secrets"
    echo "  python              # Scan Python code for security issues"
    echo ""
    echo "Severity levels: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
    echo "Multiple levels: HIGH,CRITICAL"
    echo ""
    exit 1
}

# Main execution
main() {
    local command;
    command="${1:-}"
    local arg1;
    arg1="${2:-}"
    local arg2;
    arg2="${3:-}"

    case "${command}" in
    "fs")
        scan_filesystem "${arg1:-.}" "${arg2:-HIGH,CRITICAL}"
        ;;
    "image")
        scan_image "${arg1}" "${arg2:-HIGH,CRITICAL}"
        ;;
    "containers")
        scan_containers
        ;;
    "compose")
        scan_compose "${arg1:-docker-compose.monitoring.yml}" "${arg2:-HIGH,CRITICAL}"
        ;;
    "report")
        init_security_scan
        generate_report "${arg1}"
        ;;
    "audit")
        audit_security
        ;;
    "permissions")
        init_security_scan
        scan_file_permissions
        ;;
    "secrets")
        init_security_scan
        scan_hardcoded_secrets
        ;;
    "python")
        init_security_scan
        scan_python_security
        ;;
    "")
        show_usage
        ;;
    *)
        show_usage
        ;;
    esac
}

main "$@"
