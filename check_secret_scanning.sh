#!/bin/bash

# Check Secret Scanning Status via GitHub API
# This script verifies if secret scanning is enabled for the repository

set -e

# GitHub API configuration
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REPO_OWNER="dboone323"
REPO_NAME="Quantum-workspace"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_github_token() {
    if [[ -z "${GITHUB_TOKEN}" ]]; then
        log_warning "GITHUB_TOKEN not set. Secret scanning status check requires authentication."
        echo "To check secret scanning status:"
        echo "1. Set GITHUB_TOKEN environment variable with a personal access token"
        echo "2. Or manually check: https://github.com/${REPO_OWNER}/${REPO_NAME}/settings/security_analysis"
        return 1
    fi
    return 0
}

check_secret_scanning() {
    log_info "Checking secret scanning status for ${REPO_OWNER}/${REPO_NAME}..."

    if [[ -z "${GITHUB_TOKEN}" ]]; then
        log_warning "Cannot check secret scanning status without GITHUB_TOKEN"
        echo ""
        echo "Manual verification required:"
        echo "1. Visit: https://github.com/${REPO_OWNER}/${REPO_NAME}/settings/security_analysis"
        echo "2. Check if 'Secret scanning alerts' is enabled"
        echo "3. Optionally check 'Push protection' status"
        return 0
    fi

    local response
    local http_code

    # Check if secret scanning is enabled
    response=$(curl -s -w "%{http_code}" \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}")

    http_code=$(echo "$response" | tail -c 3)
    response_body=$(echo "$response" | head -n -1)

    if [[ "$http_code" -ne 200 ]]; then
        log_error "Failed to access repository (HTTP $http_code)"
        echo "Response: $response_body"
        return 1
    fi

    # Check security analysis settings (requires admin access)
    log_info "Checking security analysis settings..."
    response=$(curl -s -w "%{http_code}" \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/vulnerability-alerts")

    http_code=$(echo "$response" | tail -c 3)

    case $http_code in
        200)
            log_success "Vulnerability alerts are enabled"
            ;;
        404)
            log_warning "Vulnerability alerts not enabled or insufficient permissions"
            ;;
        403)
            log_warning "Insufficient permissions to check vulnerability alerts"
            ;;
        *)
            log_error "Unexpected response checking vulnerability alerts (HTTP $http_code)"
            ;;
    esac

    # Note: Secret scanning status requires repository admin access via different endpoint
    log_info "Secret scanning status requires repository admin access"
    echo ""
    echo "To enable secret scanning:"
    echo "1. Visit: https://github.com/${REPO_OWNER}/${REPO_NAME}/settings/security_analysis"
    echo "2. Enable: 'Secret scanning alerts'"
    echo "3. Optionally enable: 'Push protection'"
    echo ""
    echo "Manual verification steps:"
    echo "- Check the security tab: https://github.com/${REPO_OWNER}/${REPO_NAME}/security"
    echo "- Look for 'Secret scanning' section"
}

main() {
    echo "🔐 GitHub Secret Scanning Status Check"
    echo "======================================"
    echo ""

    if check_github_token; then
        check_secret_scanning
    else
        echo ""
        check_secret_scanning
    fi

    echo ""
    echo "📋 Next Steps:"
    echo "1. Enable secret scanning in repository settings"
    echo "2. Monitor the security dashboard for alerts"
    echo "3. Configure push protection if desired"
}

# Run main if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi