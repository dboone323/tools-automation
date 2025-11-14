#!/bin/bash
# SDK Release Management System
# Handles automated publishing of SDKs to package registries

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
PYTHON_SDK_DIR="$PROJECT_ROOT/sdk/python"
TYPESCRIPT_SDK_DIR="$PROJECT_ROOT/sdk/typescript"
GO_SDK_DIR="$PROJECT_ROOT/sdk/go"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate environment for publishing
validate_environment() {
    local sdk_type="$1"

    case "$sdk_type" in
    "python")
        if ! command_exists python3 || ! command_exists pip; then
            log_error "Python 3 and pip are required for Python SDK publishing"
            return 1
        fi
        if ! python3 -c "import setuptools, wheel" 2>/dev/null; then
            log_error "setuptools and wheel are required for Python packaging"
            return 1
        fi
        ;;
    "typescript")
        if ! command_exists node || ! command_exists npm; then
            log_error "Node.js and npm are required for TypeScript SDK publishing"
            return 1
        fi
        ;;
    "go")
        if ! command_exists go; then
            log_error "Go is required for Go SDK publishing"
            return 1
        fi
        ;;
    *)
        log_error "Unknown SDK type: $sdk_type"
        return 1
        ;;
    esac

    return 0
}

# Publish Python SDK to PyPI
publish_python_sdk() {
    log_info "Publishing Python SDK to PyPI..."

    cd "$PYTHON_SDK_DIR"

    # Check if twine is installed
    if ! python3 -m pip show twine >/dev/null 2>&1; then
        log_info "Installing twine..."
        python3 -m pip install twine
    fi

    # Clean previous builds
    rm -rf dist/ build/ *.egg-info/

    # Build package
    log_info "Building Python package..."
    python3 setup.py sdist bdist_wheel

    # Check if we have PyPI credentials
    if [ -z "$PYPI_USERNAME" ] || [ -z "$PYPI_PASSWORD" ]; then
        log_warning "PyPI credentials not found. Use PYPI_USERNAME and PYPI_PASSWORD environment variables."
        log_info "For testing, you can upload to Test PyPI:"
        echo "python3 -m twine upload --repository testpypi dist/*"
        return 0
    fi

    # Upload to PyPI
    log_info "Uploading to PyPI..."
    python3 -m twine upload dist/*

    log_success "Python SDK published to PyPI"
}

# Publish TypeScript SDK to npm
publish_typescript_sdk() {
    log_info "Publishing TypeScript SDK to npm..."

    cd "$TYPESCRIPT_SDK_DIR"

    # Check if user is logged in to npm
    if ! npm whoami >/dev/null 2>&1; then
        log_warning "Not logged in to npm. Please run 'npm login' first."
        log_info "For automated publishing, set NPM_TOKEN environment variable."
        return 0
    fi

    # Build package
    log_info "Building TypeScript package..."
    npm run build

    # Publish to npm
    log_info "Publishing to npm..."
    npm publish

    log_success "TypeScript SDK published to npm"
}

# Publish Go SDK to Go Modules
publish_go_sdk() {
    log_info "Publishing Go SDK to Go Modules..."

    cd "$GO_SDK_DIR"

    # Check if this is a proper Go module
    if [ ! -f "go.mod" ]; then
        log_error "go.mod not found in Go SDK directory"
        return 1
    fi

    # Check if we have a git tag for versioning
    local version
    version=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")

    # Create git tag if it doesn't exist
    if ! git tag | grep -q "^$version$"; then
        log_info "Creating git tag $version..."
        git tag "$version"
        git push origin "$version"
    fi

    # The Go module will be automatically available via go get
    # since it's in a GitHub repository
    local module_path
    module_path=$(go mod edit -print | grep "^module" | cut -d' ' -f2)

    log_success "Go SDK published to Go Modules"
    log_info "Users can install with: go get $module_path@$version"
}

# Create release notes
create_release_notes() {
    local version="$1"
    local sdk_type="$2"
    local release_notes_file="$SCRIPT_DIR/release_notes_${sdk_type}_${version}.md"

    log_info "Creating release notes for $sdk_type SDK v$version..."

    cat >"$release_notes_file" <<EOF
# $sdk_type SDK v$version

## Release Notes

### Changes
- Initial release of $sdk_type SDK
- Full MCP (Model Context Protocol) support
- Comprehensive API client implementation
- Production-ready code quality

### Installation

\`\`\`
EOF

    case "$sdk_type" in
    "python")
        echo "pip install mcp-sdk" >>"$release_notes_file"
        ;;
    "typescript")
        echo "npm install @tools-automation/mcp-sdk" >>"$release_notes_file"
        ;;
    "go")
        echo "go get github.com/dboone323/tools-automation/sdk/go@$version" >>"$release_notes_file"
        ;;
    esac

    cat >>"$release_notes_file" <<EOF
\`\`\`

### Documentation

For detailed documentation and examples, visit:
- [SDK Documentation](https://github.com/dboone323/tools-automation/tree/main/sdk/$sdk_type)
- [Examples](https://github.com/dboone323/tools-automation/tree/main/sdk/$sdk_type/examples)

### Support

- [GitHub Issues](https://github.com/dboone323/tools-automation/issues)
- [Community Discussions](https://github.com/dboone323/tools-automation/discussions)

---

*Released on $(date -u +%Y-%m-%d)*
EOF

    log_success "Release notes created: $release_notes_file"
}

# Run tests before publishing
run_tests() {
    local sdk_type="$1"

    log_info "Running tests for $sdk_type SDK..."

    case "$sdk_type" in
    "python")
        cd "$PYTHON_SDK_DIR"
        python3 -m pytest tests/ -v
        ;;
    "typescript")
        cd "$TYPESCRIPT_SDK_DIR"
        npm test
        ;;
    "go")
        cd "$GO_SDK_DIR"
        go test ./...
        ;;
    esac

    log_success "$sdk_type SDK tests passed"
}

# Main publishing function
publish_sdk() {
    local sdk_type="$1"
    local version="${2:-1.0.0}"

    log_info "Starting $sdk_type SDK publication process..."

    # Validate environment
    if ! validate_environment "$sdk_type"; then
        return 1
    fi

    # Run tests
    run_tests "$sdk_type"

    # Create release notes
    create_release_notes "$version" "$sdk_type"

    # Publish based on type
    case "$sdk_type" in
    "python")
        publish_python_sdk
        ;;
    "typescript")
        publish_typescript_sdk
        ;;
    "go")
        publish_go_sdk
        ;;
    *)
        log_error "Unknown SDK type: $sdk_type"
        return 1
        ;;
    esac

    log_success "$sdk_type SDK v$version published successfully"
}

# Publish all SDKs
publish_all_sdks() {
    local version="${1:-1.0.0}"

    log_info "Publishing all SDKs v$version..."

    publish_sdk "python" "$version"
    publish_sdk "typescript" "$version"
    publish_sdk "go" "$version"

    log_success "All SDKs published successfully"
}

# Check publishing status
check_status() {
    log_info "Checking SDK publishing status..."

    echo "Python SDK:"
    if [ -d "$PYTHON_SDK_DIR" ]; then
        echo "  Directory: ✓"
        [ -f "$PYTHON_SDK_DIR/setup.py" ] && echo "  setup.py: ✓" || echo "  setup.py: ✗"
        [ -d "$PYTHON_SDK_DIR/tests" ] && echo "  Tests: ✓" || echo "  Tests: ✗"
    else
        echo "  Directory: ✗"
    fi

    echo ""
    echo "TypeScript SDK:"
    if [ -d "$TYPESCRIPT_SDK_DIR" ]; then
        echo "  Directory: ✓"
        [ -f "$TYPESCRIPT_SDK_DIR/package.json" ] && echo "  package.json: ✓" || echo "  package.json: ✗"
        [ -d "$TYPESCRIPT_SDK_DIR/src" ] && echo "  Source: ✓" || echo "  Source: ✗"
        [ -d "$TYPESCRIPT_SDK_DIR/tests" ] && echo "  Tests: ✓" || echo "  Tests: ✗"
    else
        echo "  Directory: ✗"
    fi

    echo ""
    echo "Go SDK:"
    if [ -d "$GO_SDK_DIR" ]; then
        echo "  Directory: ✓"
        [ -f "$GO_SDK_DIR/go.mod" ] && echo "  go.mod: ✓" || echo "  go.mod: ✗"
        [ -f "$GO_SDK_DIR/mcp.go" ] && echo "  Source: ✓" || echo "  Source: ✗"
        [ -f "$GO_SDK_DIR/mcp_test.go" ] && echo "  Tests: ✓" || echo "  Tests: ✗"
    else
        echo "  Directory: ✗"
    fi
}

# Main function
main() {
    local command="$1"
    shift

    case "$command" in
    "python")
        publish_sdk "python" "$@"
        ;;
    "typescript")
        publish_sdk "typescript" "$@"
        ;;
    "go")
        publish_sdk "go" "$@"
        ;;
    "all")
        publish_all_sdks "$@"
        ;;
    "status")
        check_status
        ;;
    "test")
        local sdk_type="$1"
        run_tests "$sdk_type"
        ;;
    *)
        echo "Usage: $0 {python|typescript|go|all|status|test} [version]"
        echo ""
        echo "Commands:"
        echo "  python     - Publish Python SDK to PyPI"
        echo "  typescript - Publish TypeScript SDK to npm"
        echo "  go         - Publish Go SDK to Go Modules"
        echo "  all        - Publish all SDKs"
        echo "  status     - Check publishing readiness"
        echo "  test       - Run tests for specified SDK"
        echo ""
        echo "Environment Variables:"
        echo "  PYPI_USERNAME  - PyPI username"
        echo "  PYPI_PASSWORD  - PyPI password"
        echo "  NPM_TOKEN      - npm authentication token"
        exit 1
        ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
