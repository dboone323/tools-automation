#!/bin/bash

# Simple MCP Workflow Test for Projects
# This script works from within project directories

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
	echo -e "${BLUE}[MCP-CHECK]${NC} $1"
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

# Get project name from current directory or parameter
if [[ -n $1 ]]; then
	PROJECT_NAME="$1"
else
	PROJECT_NAME="$(basename "$(pwd)")"
fi

print_status "Checking MCP integration for $PROJECT_NAME"
print_status "Current directory: $(pwd)"

# Check if we're in a project directory
if [[ ! -f "Tools/Automation/project_config.sh" ]]; then
	print_error "Not in a valid project directory (no Tools/Automation/project_config.sh found)"
	exit 1
fi

# Load project configuration
source Tools/Automation/project_config.sh

print_success "Project configuration loaded for $PROJECT_NAME"

# Check for git repository
if [[ ! -d ".git" ]]; then
	print_warning "Not a git repository - initializing..."
	git init
	git add .
	git commit -m "Initial commit" 2>/dev/null || true
	print_success "Git repository initialized"
else
	print_success "Git repository found"
fi

# Check for GitHub workflows
if [[ ! -d ".github/workflows" ]]; then
	print_warning "No GitHub workflows found - creating basic CI workflow..."

	mkdir -p .github/workflows

	cat >.github/workflows/ios-ci.yml <<EOF
name: $PROJECT_NAME CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Xcode
      run: sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer
      
    - name: Cache Dependencies
      uses: actions/cache@v3
      with:
        path: |
          ~/Library/Developer/Xcode/DerivedData
          ~/.cocoapods
        key: \${{ runner.os }}-xcode-\${{ hashFiles('**/*.xcodeproj', '**/*.xcworkspace', '**/Podfile.lock') }}
        
    - name: Install Dependencies
      run: |
        if [ -f "Podfile" ]; then
          pod install
        fi
        
    - name: Build $PROJECT_NAME
      run: |
        if [ -f "*.xcworkspace" ]; then
          xcodebuild -workspace *.xcworkspace -scheme $BUILD_SCHEME -destination 'platform=iOS Simulator,name=$TARGET_DEVICE' build
        elif [ -f "*.xcodeproj" ]; then
          xcodebuild -project *.xcodeproj -scheme $BUILD_SCHEME -destination 'platform=iOS Simulator,name=$TARGET_DEVICE' build
        else
          echo "No Xcode project or workspace found"
          exit 1
        fi
        
    - name: Test $PROJECT_NAME
      run: |
        if [ -f "*.xcworkspace" ]; then
          xcodebuild -workspace *.xcworkspace -scheme $BUILD_SCHEME -destination 'platform=iOS Simulator,name=$TARGET_DEVICE' test
        elif [ -f "*.xcodeproj" ]; then
          xcodebuild -project *.xcodeproj -scheme $BUILD_SCHEME -destination 'platform=iOS Simulator,name=$TARGET_DEVICE' test
        fi
        
    - name: Upload Build Artifacts
      uses: actions/upload-artifact@v3
      if: failure()
      with:
        name: build-logs
        path: |
          ~/Library/Developer/Xcode/DerivedData/**/Logs
EOF

	print_success "Created iOS CI workflow for $PROJECT_NAME"
else
	print_success "GitHub workflows directory found"
	echo "   Workflow files:"
	find .github/workflows -name "*.yml" -o -name "*.yaml" | sed 's/^/   • /'
fi

# Check MCP integration capabilities
print_status "Checking MCP integration capabilities..."

# Check automation scripts
if [[ -f "Tools/Automation/master_automation.sh" ]]; then
	print_success "Master automation script available"
else
	print_warning "Master automation script missing"
fi

if [[ -f "Tools/Automation/ai_enhancement_system.sh" ]]; then
	print_success "AI enhancement system available"
else
	print_warning "AI enhancement system missing"
fi

if [[ -f "Tools/Automation/automate.sh" ]]; then
	print_success "Quick automation wrapper available"
else
	print_warning "Quick automation wrapper missing"
fi

# Test basic automation
print_status "Testing basic automation functionality..."
if ./Tools/Automation/automate.sh help >/dev/null 2>&1; then
	print_success "Automation system functional"
else
	print_warning "Automation system may have issues"
fi

print_status "MCP integration check complete for $PROJECT_NAME"
echo ""
echo "Summary:"
echo "  • Project: $PROJECT_NAME"
echo "  • Git: $([ -d .git ] && echo "✅ Initialized" || echo "❌ Missing")"
echo "  • Workflows: $([ -d .github/workflows ] && echo "✅ Available" || echo "❌ Missing")"
echo "  • Automation: $([ -f Tools/Automation/automate.sh ] && echo "✅ Ready" || echo "❌ Missing")"
echo "  • MCP Ready: $([ -d .github/workflows ] && [ -f Tools/Automation/automate.sh ] && echo "✅ Yes" || echo "❌ No")"
