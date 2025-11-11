#!/bin/bash

# Tools Automation Dependency Security Scanner
# Uses Snyk for dependency vulnerability management

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
    echo -e "${BLUE}[DEPENDENCY]${NC} $1"
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

# Check if Snyk is installed
check_snyk() {
    if ! command -v snyk >/dev/null 2>&1; then
        print_error "Snyk is not installed."
        print_status "Install Snyk:"
        echo "  npm: npm install -g snyk"
        echo "  brew: brew install snyk"
        echo "  curl: curl -sL https://snyk.io/install | bash"
        exit 1
    fi
}

# Authenticate with Snyk (if not already authenticated)
authenticate_snyk() {
    if ! snyk auth --help >/dev/null 2>&1; then
        print_warning "Snyk authentication required"
        print_status "Run: snyk auth"
        print_status "Or set SNYK_TOKEN environment variable"
        return 1
    fi

    if [[ -z "${SNYK_TOKEN}" ]]; then
        print_warning "SNYK_TOKEN environment variable not set"
        print_status "Set it with: export SNYK_TOKEN=your_token_here"
        return 1
    fi
}

# Test for vulnerabilities
test_vulnerabilities() {
    local path="${1:-.}"
    local severity="${2:-high}"

    print_status "Testing for vulnerabilities in: ${path}"

    snyk test \
        --severity-threshold="${severity}" \
        --json \
        "${path}" 2>/dev/null || {
        print_warning "Vulnerabilities found. Run 'snyk test' for details."
        return 1
    }

    print_success "No ${severity} or higher severity vulnerabilities found"
}

# Monitor dependencies
monitor_dependencies() {
    local path="${1:-.}"

    print_status "Monitoring dependencies: ${path}"

    if ! snyk monitor "${path}"; then
        print_error "Failed to monitor dependencies"
        return 1
    fi

    print_success "Dependencies are now being monitored"
}

# Fix vulnerabilities automatically
fix_vulnerabilities() {
    local path="${1:-.}"
    local dry_run="${2:-true}"

    print_status "Analyzing vulnerabilities for fixes: ${path}"

    if [[ "${dry_run}" == "true" ]]; then
        print_status "Running in dry-run mode (no changes will be made)"
        snyk wizard --dry-run "${path}"
    else
        print_warning "This will attempt to fix vulnerabilities automatically"
        read -p "Continue? (y/N): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            snyk wizard "${path}"
            print_success "Vulnerability fixes applied"
        else
            print_status "Fix cancelled"
        fi
    fi
}

# Generate dependency report
generate_report() {
    local output_file="${1:-dependency_report_$(date +%Y%m%d_%H%M%S).md}"

    print_status "Generating dependency report: ${output_file}"

    {
        echo "# Dependency Security Report"
        echo ""
        echo "Generated: $(date)"
        echo "Tool: Snyk $(snyk version 2>/dev/null || echo 'Unknown')"
        echo ""

        echo "## Vulnerability Test Results"
        echo ""
        echo "\`\`\`json"
        snyk test --json . 2>/dev/null || echo '{"error": "Failed to run vulnerability test"}'
        echo "\`\`\`"
        echo ""

        echo "## Recommendations"
        echo ""
        echo "1. Run regular vulnerability scans: \`snyk test\`"
        echo "2. Monitor dependencies: \`snyk monitor\`"
        echo "3. Fix vulnerabilities: \`snyk wizard\`"
        echo "4. Update dependencies regularly"
        echo "5. Use Snyk in CI/CD pipeline"
        echo ""

        echo "## Integration with CI/CD"
        echo ""
        echo "Add to GitHub Actions:"
        echo ""
        echo "\`\`\`yaml"
        echo "- name: Run Snyk to check for vulnerabilities"
        echo "  uses: snyk/actions/node@master"
        echo "  env:"
        echo "    SNYK_TOKEN: \${{ secrets.SNYK_TOKEN }}"
        echo "  with:"
        echo "    args: --severity-threshold=high"
        echo "\`\`\`"
        echo ""

    } >"${output_file}"

    print_success "Dependency report generated: ${output_file}"
}

# Check for outdated dependencies
check_outdated() {
    print_status "Checking for outdated dependencies..."

    # For Python
    if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -f "Pipfile" ]]; then
        print_status "Python dependencies:"
        if command -v pip-review >/dev/null 2>&1; then
            pip-review --local 2>/dev/null || print_warning "Install pip-review: pip install pip-review"
        else
            print_warning "Install pip-review for detailed Python dependency updates"
        fi
    fi

    # For Node.js
    if [[ -f "package.json" ]]; then
        print_status "Node.js dependencies:"
        if command -v npm >/dev/null 2>&1; then
            npm outdated 2>/dev/null || print_warning "Run 'npm update' to update dependencies"
        fi
    fi

    # For Ruby
    if [[ -f "Gemfile" ]]; then
        print_status "Ruby dependencies:"
        if command -v bundle >/dev/null 2>&1; then
            bundle outdated 2>/dev/null || print_warning "Run 'bundle update' to update dependencies"
        fi
    fi
}

# Show usage
show_usage() {
    echo "📦 Tools Automation Dependency Security Scanner"
    echo ""
    echo "Usage: $0 {test [path] [severity]|monitor [path]|fix [path] [dry-run]|report [output_file]|outdated}"
    echo ""
    echo "Commands:"
    echo "  test [path] [sev]    # Test for vulnerabilities (default: .) (default: high)"
    echo "  monitor [path]       # Monitor dependencies for new vulnerabilities"
    echo "  fix [path] [dry]     # Fix vulnerabilities (dry-run: true/false, default: true)"
    echo "  report [file]        # Generate dependency security report"
    echo "  outdated             # Check for outdated dependencies"
    echo ""
    echo "Severity levels: low, medium, high, critical"
    echo ""
    echo "Environment Variables:"
    echo "  SNYK_TOKEN           # Snyk authentication token"
    echo ""
    exit 1
}

# Main execution
main() {
    local command="$1"
    local arg1="$2"
    local arg2="$3"

    check_snyk

    case "${command}" in
    "test")
        test_vulnerabilities "${arg1:-.}" "${arg2:-high}"
        ;;
    "monitor")
        authenticate_snyk && monitor_dependencies "${arg1:-.}"
        ;;
    "fix")
        fix_vulnerabilities "${arg1:-.}" "${arg2:-true}"
        ;;
    "report")
        generate_report "${arg1}"
        ;;
    "outdated")
        check_outdated
        ;;
    *)
        show_usage
        ;;
    esac
}

main "$@"
