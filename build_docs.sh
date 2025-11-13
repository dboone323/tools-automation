#!/bin/bash
# Documentation Build and Serve Script
# Builds and serves the comprehensive documentation site

set -e # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DOCS_DIR="docs"
BUILD_DIR="site"
PORT=8000
HOST="localhost"

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo -e "${PURPLE}🚀 $1${NC}"
    echo "=================================================="
}

# Check if MkDocs is installed
check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v mkdocs &>/dev/null; then
        log_error "MkDocs is not installed!"
        echo "Install with: pip install mkdocs mkdocs-material"
        exit 1
    fi

    if ! command -v python3 &>/dev/null; then
        log_error "Python 3 is not installed!"
        exit 1
    fi

    log_success "Dependencies check passed"
}

# Validate documentation structure
validate_docs() {
    log_info "Validating documentation structure..."

    # Check required directories
    required_dirs=(
        "$DOCS_DIR"
        "$DOCS_DIR/getting-started"
        "$DOCS_DIR/reference"
        "$DOCS_DIR/api"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Required directory missing: $dir"
            exit 1
        fi
    done

    # Check required files
    required_files=(
        "$DOCS_DIR/index.md"
        "$DOCS_DIR/getting-started/onboarding.md"
        "$DOCS_DIR/reference/troubleshooting.md"
        "$DOCS_DIR/reference/configuration.md"
        "$DOCS_DIR/api/index.html"
        "mkdocs.yml"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required file missing: $file"
            exit 1
        fi
    done

    log_success "Documentation structure validated"
}

# Build the documentation site
build_docs() {
    log_header "Building Documentation Site"

    log_info "Building MkDocs site..."
    if mkdocs build --clean; then
        log_success "Documentation built successfully"
        log_info "Build output: $BUILD_DIR/"
    else
        log_error "Failed to build documentation"
        exit 1
    fi
}

# Serve the documentation site
serve_docs() {
    local port=$1
    local host=$2

    log_header "Serving Documentation Site"

    local url="http://$host:$port"

    log_info "Starting MkDocs development server..."
    log_info "URL: $url"
    log_info "Press Ctrl+C to stop"

    # Open browser
    if command -v open &>/dev/null; then
        (sleep 2 && open "$url") &
    elif command -v xdg-open &>/dev/null; then
        (sleep 2 && xdg-open "$url") &
    fi

    mkdocs serve --dev-addr="$host:$port"
}

# Clean build artifacts
clean_docs() {
    log_info "Cleaning documentation build artifacts..."

    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
        log_success "Cleaned build directory: $BUILD_DIR"
    else
        log_warning "Build directory not found: $BUILD_DIR"
    fi
}

# Show usage information
show_usage() {
    cat <<EOF
Documentation Build and Serve Script

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    build       Build the documentation site
    serve       Serve the documentation site (default)
    clean       Clean build artifacts
    validate    Validate documentation structure
    help        Show this help message

OPTIONS:
    --port PORT     Port to serve on (default: $PORT)
    --host HOST     Host to bind to (default: $HOST)
    --no-browser    Don't open browser automatically

EXAMPLES:
    $0 build                    # Build documentation
    $0 serve                    # Serve on localhost:8000
    $0 serve --port 3000        # Serve on localhost:3000
    $0 serve --host 0.0.0.0     # Serve on all interfaces
    $0 clean                    # Clean build artifacts
    $0 validate                 # Validate documentation

EOF
}

# Main function
main() {
    local command="serve"
    local port=$PORT
    local host=$HOST
    local open_browser=true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        build | serve | clean | validate | help)
            command=$1
            shift
            ;;
        --port)
            port="$2"
            shift 2
            ;;
        --host)
            host="$2"
            shift 2
            ;;
        --no-browser)
            open_browser=false
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        esac
    done

    # Handle help command
    if [[ "$command" == "help" ]]; then
        show_usage
        exit 0
    fi

    # Validate port
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        log_error "Invalid port: $port (must be 1-65535)"
        exit 1
    fi

    # Run command
    case $command in
    build)
        check_dependencies
        validate_docs
        build_docs
        ;;
    serve)
        check_dependencies
        validate_docs
        serve_docs "$port" "$host"
        ;;
    clean)
        clean_docs
        ;;
    validate)
        check_dependencies
        validate_docs
        ;;
    *)
        log_error "Unknown command: $command"
        show_usage
        exit 1
        ;;
    esac
}

# Run main function with all arguments
main "$@"
