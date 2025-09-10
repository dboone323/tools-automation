#!/bin/bash
# Universal development script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_NAME=$(basename "$(pwd)")

print_usage() {
    echo "Universal Development Script for $PROJECT_NAME"
    echo ""
    echo "Usage: ./dev.sh [command]"
    echo ""
    echo "Commands:"
    echo "  build        Build the project"
    echo "  test         Run tests"
    echo "  lint         Run code linting"
    echo "  clean        Clean build artifacts"
    echo "  install      Install dependencies"
    echo "  format       Format code"
    echo "  check        Run all quality checks"
    echo "  run          Run the application"
    echo "  setup        Initial project setup"
    echo ""
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Detect project type
detect_project_type() {
    if [ -f "Package.swift" ]; then
        echo "swift"
    elif [ -f "*.xcodeproj" ] || [ -f "*.xcworkspace" ]; then
        echo "xcode"
    elif [ -f "package.json" ]; then
        echo "node"
    elif [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
        echo "python"
    else
        echo "unknown"
    fi
}

PROJECT_TYPE=$(detect_project_type)

# Command implementations
cmd_build() {
    log_info "Building $PROJECT_NAME ($PROJECT_TYPE)..."
    
    case $PROJECT_TYPE in
        "swift")
            swift build
            ;;
        "xcode")
            if [ -f "*.xcworkspace" ]; then
                xcodebuild -workspace *.xcworkspace -scheme "$PROJECT_NAME" build
            else
                xcodebuild -project *.xcodeproj -scheme "$PROJECT_NAME" build
            fi
            ;;
        "node")
            npm run build
            ;;
        "python")
            python -m build
            ;;
        *)
            log_error "Unknown project type"
            exit 1
            ;;
    esac
    
    log_success "Build completed"
}

cmd_test() {
    log_info "Running tests for $PROJECT_NAME..."
    
    case $PROJECT_TYPE in
        "swift")
            swift test
            ;;
        "xcode")
            if [ -f "*.xcworkspace" ]; then
                xcodebuild test -workspace *.xcworkspace -scheme "$PROJECT_NAME" -destination 'platform=macOS'
            else
                xcodebuild test -project *.xcodeproj -scheme "$PROJECT_NAME" -destination 'platform=macOS'
            fi
            ;;
        "node")
            npm test
            ;;
        "python")
            python -m pytest
            ;;
        *)
            log_error "No test configuration found"
            exit 1
            ;;
    esac
    
    log_success "Tests completed"
}

cmd_lint() {
    log_info "Running linting for $PROJECT_NAME..."
    
    case $PROJECT_TYPE in
        "swift"|"xcode")
            if command -v swiftlint &> /dev/null; then
                swiftlint
            else
                log_error "SwiftLint not installed. Install with: brew install swiftlint"
                exit 1
            fi
            ;;
        "node")
            npx eslint .
            ;;
        "python")
            if command -v flake8 &> /dev/null; then
                flake8 .
            else
                log_error "flake8 not installed. Install with: pip install flake8"
                exit 1
            fi
            ;;
        *)
            log_error "No linting configuration found"
            exit 1
            ;;
    esac
    
    log_success "Linting completed"
}

cmd_clean() {
    log_info "Cleaning $PROJECT_NAME..."
    
    case $PROJECT_TYPE in
        "swift")
            swift package clean
            ;;
        "xcode")
            rm -rf build/
            rm -rf DerivedData/
            ;;
        "node")
            rm -rf node_modules/
            rm -rf dist/
            ;;
        "python")
            rm -rf build/
            rm -rf dist/
            rm -rf *.egg-info/
            find . -type d -name __pycache__ -delete
            ;;
    esac
    
    log_success "Clean completed"
}

cmd_install() {
    log_info "Installing dependencies for $PROJECT_NAME..."
    
    case $PROJECT_TYPE in
        "swift")
            swift package resolve
            ;;
        "node")
            npm install
            ;;
        "python")
            pip install -r requirements.txt 2>/dev/null || log_info "No requirements.txt found"
            ;;
    esac
    
    log_success "Dependencies installed"
}

cmd_format() {
    log_info "Formatting code for $PROJECT_NAME..."
    
    case $PROJECT_TYPE in
        "swift"|"xcode")
            if command -v swiftformat &> /dev/null; then
                swiftformat .
            else
                log_error "SwiftFormat not installed. Install with: brew install swiftformat"
                exit 1
            fi
            ;;
        "node")
            npx prettier --write .
            ;;
        "python")
            if command -v black &> /dev/null; then
                black .
            else
                log_error "black not installed. Install with: pip install black"
                exit 1
            fi
            ;;
    esac
    
    log_success "Code formatted"
}

cmd_check() {
    log_info "Running all quality checks for $PROJECT_NAME..."
    
    cmd_lint
    cmd_test
    cmd_build
    
    log_success "All checks passed"
}

cmd_run() {
    log_info "Running $PROJECT_NAME..."
    
    case $PROJECT_TYPE in
        "swift")
            swift run
            ;;
        "node")
            npm start
            ;;
        "python")
            python main.py 2>/dev/null || python app.py 2>/dev/null || log_error "No main entry point found"
            ;;
        "xcode")
            log_info "For Xcode projects, build and run from Xcode IDE"
            ;;
    esac
}

cmd_setup() {
    log_info "Setting up $PROJECT_NAME development environment..."
    
    # Install dependencies
    cmd_install
    
    # Create necessary directories
    mkdir -p Tests
    mkdir -p Documentation
    
    # Setup git hooks if .git exists
    if [ -d ".git" ]; then
        # This would be called by the universal workflow manager
        log_info "Git repository detected"
    fi
    
    log_success "Setup completed"
}

# Main command dispatcher
case "${1:-help}" in
    "build")
        cmd_build
        ;;
    "test")
        cmd_test
        ;;
    "lint")
        cmd_lint
        ;;
    "clean")
        cmd_clean
        ;;
    "install")
        cmd_install
        ;;
    "format")
        cmd_format
        ;;
    "check")
        cmd_check
        ;;
    "run")
        cmd_run
        ;;
    "setup")
        cmd_setup
        ;;
    "help"|*)
        print_usage
        ;;
esac
