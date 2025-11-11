#!/bin/bash

# Tools Automation Security Scanner
# Runs Trivy vulnerability scans and other security checks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Check if Trivy is installed
check_trivy() {
    if ! command -v trivy >/dev/null 2>&1; then
        print_error "Trivy is not installed."
        print_status "Install Trivy:"
        echo "  macOS: brew install trivy"
        echo "  Linux: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
        exit 1
    fi
}

# Scan filesystem for vulnerabilities
scan_filesystem() {
    local path="${1:-.}"
    local severity="${2:-HIGH,CRITICAL}"

    print_status "Scanning filesystem: ${path}"

    trivy fs \
        --severity "${severity}" \
        --format table \
        --exit-code 0 \
        "${path}"
}

# Scan container image
scan_image() {
    local image="$1"
    local severity="${2:-HIGH,CRITICAL}"

    if [[ -z "${image}" ]]; then
        print_error "Please specify an image to scan"
        echo "Usage: $0 image <image_name> [severity]"
        exit 1
    fi

    print_status "Scanning container image: ${image}"

    trivy image \
        --severity "${severity}" \
        --format table \
        --exit-code 0 \
        "${image}"
}

# Scan running containers
scan_containers() {
    print_status "Scanning running containers..."

    # Get running containers
    local containers
    containers=$(docker ps --format "table {{.Names}}\t{{.Image}}" | tail -n +2)

    if [[ -z "${containers}" ]]; then
        print_warning "No running containers found"
        return 0
    fi

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
}

# Scan Docker Compose services
scan_compose() {
    local compose_file="${1:-docker-compose.monitoring.yml}"
    local severity="${2:-HIGH,CRITICAL}"

    if [[ ! -f "${compose_file}" ]]; then
        print_error "Docker Compose file not found: ${compose_file}"
        exit 1
    fi

    print_status "Scanning Docker Compose file: ${compose_file}"

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
}

# Generate security report
generate_report() {
    local output_file="${1:-security_report_$(date +%Y%m%d_%H%M%S).md}"

    print_status "Generating security report: ${output_file}"

    {
        echo "# Security Scan Report"
        echo ""
        echo "Generated: $(date)"
        echo "Scanner: Trivy $(trivy version 2>/dev/null | head -1 || echo 'Unknown')"
        echo ""

        echo "## Filesystem Scan"
        echo ""
        echo "\`\`\`"
        scan_filesystem . HIGH,CRITICAL
        echo "\`\`\`"
        echo ""

        echo "## Container Images Scan"
        echo ""
        scan_containers
        echo ""

        echo "## Recommendations"
        echo ""
        echo "1. Review HIGH and CRITICAL severity vulnerabilities"
        echo "2. Update base images regularly"
        echo "3. Use specific image tags instead of 'latest'"
        echo "4. Implement security scanning in CI/CD pipeline"
        echo "5. Monitor for new vulnerabilities regularly"
        echo ""

    } >"${output_file}"

    print_success "Security report generated: ${output_file}"
}

# Run comprehensive security audit
audit_security() {
    print_status "Running comprehensive security audit..."

    echo "========================================"
    echo "🔒 Tools Automation Security Audit"
    echo "========================================"
    echo ""

    # Check for common security issues
    print_status "Checking for exposed secrets..."
    if grep -r "password\|secret\|key\|token" --include="*.sh" --include="*.py" --include="*.yml" --include="*.yaml" . | grep -v ".git" | grep -v "node_modules" >/dev/null 2>&1; then
        print_warning "Potential secrets found in code. Review the following:"
        grep -r "password\|secret\|key\|token" --include="*.sh" --include="*.py" --include="*.yml" --include="*.yaml" . | grep -v ".git" | grep -v "node_modules" | head -10
    else
        print_success "No obvious secrets found in code"
    fi

    echo ""

    # Check file permissions
    print_status "Checking file permissions..."
    find . -name "*.sh" -type f -not -perm 755 | head -5 | while read -r file; do
        print_warning "Script without execute permission: ${file}"
    done

    echo ""

    # Run filesystem scan
    print_status "Running filesystem vulnerability scan..."
    scan_filesystem .

    echo ""

    # Run container scan if Docker is available
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        print_status "Running container security scan..."
        scan_containers
    else
        print_warning "Docker not available, skipping container scan"
    fi

    echo ""
    print_success "Security audit completed"
}

# Show usage
show_usage() {
    echo "🔒 Tools Automation Security Scanner"
    echo ""
    echo "Usage: $0 {fs [path] [severity]|image <image> [severity]|containers|compose [file] [severity]|report [output_file]|audit}"
    echo ""
    echo "Commands:"
    echo "  fs [path] [sev]     # Scan filesystem (default: .) (default severity: HIGH,CRITICAL)"
    echo "  image <img> [sev]   # Scan container image"
    echo "  containers          # Scan all running containers"
    echo "  compose [file] [sev]# Scan Docker Compose file (default: docker-compose.monitoring.yml)"
    echo "  report [file]       # Generate comprehensive security report"
    echo "  audit               # Run comprehensive security audit"
    echo ""
    echo "Severity levels: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
    echo "Multiple levels: HIGH,CRITICAL"
    echo ""
    exit 1
}

# Main execution
main() {
    local command="$1"
    local arg1="$2"
    local arg2="$3"

    check_trivy

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
        generate_report "${arg1}"
        ;;
    "audit")
        audit_security
        ;;
    *)
        show_usage
        ;;
    esac
}

main "$@"
