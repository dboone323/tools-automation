#!/bin/bash

# Enhanced Workflow Manager with New Tools Integration
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[WORKFLOW]${NC} $1"
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

# Pre-commit workflow: format, lint, and test
pre_commit() {
    local project_name="$1"
    local project_path="$CODE_DIR/Projects/$project_name"
    
    if [[ ! -d "$project_path" ]]; then
        print_error "Project $project_name not found"
        return 1
    fi
    
    print_status "Running pre-commit workflow for $project_name..."
    cd "$project_path"
    
    # Step 1: Format code
    print_status "1. Formatting Swift code..."
    if command -v swiftformat &> /dev/null; then
        swiftformat . --config "$CODE_DIR/.swiftformat"
        print_success "Code formatting completed"
    else
        print_warning "SwiftFormat not available, skipping..."
    fi
    
    # Step 2: Lint code
    print_status "2. Linting Swift code..."
    if command -v swiftlint &> /dev/null; then
        if swiftlint; then
            print_success "Linting passed"
        else
            print_warning "Linting found issues (non-blocking)"
        fi
    else
        print_warning "SwiftLint not available, skipping..."
    fi
    
    # Step 3: Build project
    print_status "3. Building project..."
    if [[ -f "*.xcodeproj/project.pbxproj" ]] || [[ -f "*.xcworkspace" ]]; then
        if command -v xcodebuild &> /dev/null; then
            local scheme_name="$project_name"
            if xcodebuild -scheme "$scheme_name" -destination 'platform=macOS' build; then
                print_success "Build successful"
            else
                print_error "Build failed"
                return 1
            fi
        else
            print_warning "Xcode build tools not available"
        fi
    elif [[ -f "Package.swift" ]]; then
        if swift build; then
            print_success "Swift package build successful"
        else
            print_error "Swift package build failed"
            return 1
        fi
    fi
    
    # Step 4: Run tests
    print_status "4. Running tests..."
    if [[ -f "*.xcodeproj/project.pbxproj" ]] || [[ -f "*.xcworkspace" ]]; then
        if xcodebuild test -scheme "$scheme_name" -destination 'platform=macOS'; then
            print_success "Tests passed"
        else
            print_warning "Some tests failed (check output)"
        fi
    elif [[ -f "Package.swift" ]]; then
        if swift test; then
            print_success "Swift package tests passed"
        else
            print_warning "Some Swift package tests failed"
        fi
    fi
    
    print_success "Pre-commit workflow completed for $project_name"
}

# Setup iOS deployment with Fastlane
setup_ios_deployment() {
    local project_name="$1"
    local project_path="$CODE_DIR/Projects/$project_name"
    
    if [[ ! -d "$project_path" ]]; then
        print_error "Project $project_name not found"
        return 1
    fi
    
    print_status "Setting up iOS deployment for $project_name..."
    cd "$project_path"
    
    # Initialize Fastlane if not exists
    if [[ ! -d "fastlane" ]]; then
        print_status "Initializing Fastlane..."
        if command -v fastlane &> /dev/null; then
            fastlane init
            print_success "Fastlane initialized"
        else
            print_error "Fastlane not available"
            return 1
        fi
    fi
    
    # Create basic Fastfile if needed
    if [[ ! -f "fastlane/Fastfile" ]] || [[ ! -s "fastlane/Fastfile" ]]; then
        print_status "Creating enhanced Fastfile..."
        cat > fastlane/Fastfile << 'FASTFILE_EOF'
default_platform(:ios)

platform :ios do
  desc "Run tests"
  lane :test do
    run_tests(scheme: ENV["SCHEME_NAME"] || "App")
  end

  desc "Build for development"
  lane :dev_build do
    gym(
      scheme: ENV["SCHEME_NAME"] || "App",
      configuration: "Debug",
      export_method: "development"
    )
  end

  desc "Build for App Store"
  lane :release do
    gym(
      scheme: ENV["SCHEME_NAME"] || "App", 
      configuration: "Release",
      export_method: "app-store"
    )
  end

  desc "Deploy to TestFlight"
  lane :beta do
    gym(
      scheme: ENV["SCHEME_NAME"] || "App",
      configuration: "Release",
      export_method: "app-store"
    )
    upload_to_testflight
  end
end
FASTFILE_EOF
        print_success "Enhanced Fastfile created"
    fi
    
    print_success "iOS deployment setup completed for $project_name"
}

# Quality assurance workflow
qa_workflow() {
    local project_name="$1"
    local project_path="$CODE_DIR/Projects/$project_name"
    
    if [[ ! -d "$project_path" ]]; then
        print_error "Project $project_name not found"
        return 1
    fi
    
    print_status "Running quality assurance workflow for $project_name..."
    cd "$project_path"
    
    # Code metrics
    print_status "Analyzing code metrics..."
    local swift_files=$(find . -name "*.swift" | wc -l | tr -d ' ')
    local total_lines=$(find . -name "*.swift" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
    local test_files=$(find . -name "*Test*.swift" -o -name "*test*.swift" | wc -l | tr -d ' ')
    
    echo "  📊 Swift files: $swift_files"
    echo "  📄 Total lines: $total_lines"
    echo "  🧪 Test files: $test_files"
    
    # Code quality checks
    if command -v swiftlint &> /dev/null; then
        print_status "Running comprehensive SwiftLint analysis..."
        swiftlint --reporter json > swiftlint_report.json 2>/dev/null || true
        local warnings=$(grep -o '"severity":"warning"' swiftlint_report.json 2>/dev/null | wc -l | tr -d ' ')
        local errors=$(grep -o '"severity":"error"' swiftlint_report.json 2>/dev/null | wc -l | tr -d ' ')
        echo "  ⚠️  Warnings: $warnings"
        echo "  ❌ Errors: $errors"
        rm -f swiftlint_report.json
    fi
    
    print_success "Quality assurance workflow completed"
}

# Dependency management workflow
manage_dependencies() {
    local project_name="$1"
    local project_path="$CODE_DIR/Projects/$project_name"
    
    if [[ ! -d "$project_path" ]]; then
        print_error "Project $project_name not found"
        return 1
    fi
    
    print_status "Managing dependencies for $project_name..."
    cd "$project_path"
    
    # CocoaPods
    if [[ -f "Podfile" ]]; then
        print_status "Updating CocoaPods dependencies..."
        if command -v pod &> /dev/null; then
            pod install --repo-update
            print_success "CocoaPods dependencies updated"
        else
            print_warning "CocoaPods not available"
        fi
    fi
    
    # Swift Package Manager
    if [[ -f "Package.swift" ]]; then
        print_status "Updating Swift Package Manager dependencies..."
        swift package update
        print_success "Swift Package Manager dependencies updated"
    fi
    
    # Check for outdated dependencies
    if [[ -f "Podfile.lock" ]]; then
        print_status "Checking for outdated CocoaPods..."
        pod outdated || true
    fi
    
    print_success "Dependency management completed"
}

# Help function
show_help() {
    echo "🔧 Enhanced Workflow Manager"
    echo ""
    echo "Usage: $0 <command> <project_name>"
    echo ""
    echo "Commands:"
    echo "  pre-commit <project>     # Run pre-commit workflow (format, lint, build, test)"
    echo "  ios-setup <project>      # Setup iOS deployment with Fastlane"
    echo "  qa <project>            # Run quality assurance workflow"
    echo "  deps <project>          # Manage project dependencies"
    echo "  help                    # Show this help"
    echo ""
}

# Main execution
case "${1:-}" in
    "pre-commit")
        if [[ -n "${2:-}" ]]; then
            pre_commit "$2"
        else
            print_error "Usage: $0 pre-commit <project_name>"
            exit 1
        fi
        ;;
    "ios-setup")
        if [[ -n "${2:-}" ]]; then
            setup_ios_deployment "$2"
        else
            print_error "Usage: $0 ios-setup <project_name>"
            exit 1
        fi
        ;;
    "qa")
        if [[ -n "${2:-}" ]]; then
            qa_workflow "$2"
        else
            print_error "Usage: $0 qa <project_name>"
            exit 1
        fi
        ;;
    "deps")
        if [[ -n "${2:-}" ]]; then
            manage_dependencies "$2"
        else
            print_error "Usage: $0 deps <project_name>"
            exit 1
        fi
        ;;
    "help"|*)
        show_help
        ;;
esac
