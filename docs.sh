#!/bin/bash

# Tools Automation Documentation Manager
# Manages MkDocs documentation site

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
    echo -e "${BLUE}[DOCS]${NC} $1"
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

# Check if MkDocs is installed
check_mkdocs() {
    if ! command -v mkdocs >/dev/null 2>&1; then
        print_error "MkDocs is not installed."
        print_status "Install MkDocs:"
        echo "  pip: pip install mkdocs mkdocs-material"
        echo "  pipenv: pipenv install mkdocs mkdocs-material"
        return 1
    fi

    if ! mkdocs --version | grep -q "material"; then
        print_warning "MkDocs Material theme not installed. Install with: pip install mkdocs-material"
    fi
}

# Start development server
serve_docs() {
    local port="${1:-8000}"
    local host="${2:-localhost}"

    print_status "Starting MkDocs development server..."
    print_status "Access at: http://${host}:${port}"

    cd "${PROJECT_ROOT}"
    mkdocs serve -a "${host}:${port}"
}

# Build documentation
build_docs() {
    local clean="${1:-false}"

    print_status "Building documentation site..."

    cd "${PROJECT_ROOT}"

    if [[ "${clean}" == "true" ]]; then
        print_status "Cleaning previous build..."
        rm -rf site/
    fi

    mkdocs build

    print_success "Documentation built successfully"
    print_status "Output directory: ${PROJECT_ROOT}/site"
}

# Deploy to GitHub Pages
deploy_docs() {
    print_status "Deploying to GitHub Pages..."

    cd "${PROJECT_ROOT}"

    # Check if git remote is configured
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_error "Git remote 'origin' not configured"
        exit 1
    fi

    # Check if gh-pages branch exists, create if not
    if ! git show-ref --verify --quiet refs/heads/gh-pages; then
        print_status "Creating gh-pages branch..."
        git checkout --orphan gh-pages
        git reset --hard
        git commit --allow-empty -m "Initial gh-pages commit"
        git checkout main
    fi

    mkdocs gh-deploy

    print_success "Documentation deployed to GitHub Pages"
    print_status "View at: https://dboone323.github.io/tools-automation"
}

# Create new documentation page
create_page() {
    local path="$1"
    local title="$2"

    if [[ -z "${path}" ]] || [[ -z "${title}" ]]; then
        print_error "Usage: $0 create <path> <title>"
        echo "Example: $0 create tutorials/custom-setup.md \"Custom Setup Guide\""
        exit 1
    fi

    local full_path="docs/${path}"

    # Create directory if it doesn't exist
    mkdir -p "$(dirname "${full_path}")"

    if [[ -f "${full_path}" ]]; then
        print_warning "File already exists: ${full_path}"
        return 1
    fi

    print_status "Creating documentation page: ${full_path}"

    # Create page with frontmatter
    cat >"${full_path}" <<EOF
---
title: ${title}
description: ${title}
author: Tools Automation Team
date: $(date +%Y-%m-%d)
---

# ${title}

## Overview

Brief description of this documentation page.

## Contents

Add your content here.

## Related Documentation

- [Getting Started](../getting-started/quick-start.md)
- [API Reference](../api/metrics.md)

---

*Last updated: $(date)*
EOF

    print_success "Documentation page created: ${full_path}"
    print_status "Edit the file and then run: mkdocs serve"
}

# Validate documentation
validate_docs() {
    print_status "Validating documentation..."

    cd "${PROJECT_ROOT}"

    # Check for broken links
    if command -v linkchecker >/dev/null 2>&1; then
        print_status "Checking for broken links..."
        linkchecker site/ 2>/dev/null || print_warning "Some links may be broken"
    else
        print_warning "linkchecker not installed. Install with: pip install linkchecker"
    fi

    # Check for dead Markdown links
    print_status "Checking Markdown links..."
    find docs/ -name "*.md" -exec grep -l "\[.*\](\." {} \; | while read -r file; do
        print_warning "Relative link found in: ${file}"
    done

    print_success "Documentation validation completed"
}

# Show usage
show_usage() {
    echo "📚 Tools Automation Documentation Manager"
    echo ""
    echo "Usage: $0 {serve [port] [host]|build [clean]|deploy|create <path> <title>|validate}"
    echo ""
    echo "Commands:"
    echo "  serve [port] [host]  # Start development server (default: 8000, localhost)"
    echo "  build [clean]        # Build documentation site (clean: true/false)"
    echo "  deploy               # Deploy to GitHub Pages"
    echo "  create <path> <title># Create new documentation page"
    echo "  validate             # Validate documentation for issues"
    echo ""
    echo "Examples:"
    echo "  $0 serve              # Start dev server on localhost:8000"
    echo "  $0 serve 9000         # Start dev server on localhost:9000"
    echo "  $0 build true         # Clean build"
    echo "  $0 create tutorials/setup.md \"Setup Tutorial\""
    echo ""
    exit 1
}

# Main execution
main() {
    local command="$1"
    local arg1="$2"
    local arg2="$3"

    check_mkdocs

    case "${command}" in
    "serve")
        serve_docs "${arg1:-8000}" "${arg2:-localhost}"
        ;;
    "build")
        build_docs "${arg1:-false}"
        ;;
    "deploy")
        deploy_docs
        ;;
    "create")
        create_page "${arg1}" "${arg2}"
        ;;
    "validate")
        validate_docs
        ;;
    *)
        show_usage
        ;;
    esac
}

main "$@"
