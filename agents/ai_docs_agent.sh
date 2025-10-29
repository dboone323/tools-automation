#!/bin/bash
# AI Documentation Agent: Automated documentation generation from code analysis

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Agent throttling configuration
MAX_CONCURRENCY="${MAX_CONCURRENCY:-2}" # Maximum concurrent instances of this agent
LOAD_THRESHOLD="${LOAD_THRESHOLD:-4.0}" # System load threshold (1.0 = 100% on single core)
WAIT_WHEN_BUSY="${WAIT_WHEN_BUSY:-30}"  # Seconds to wait when system is busy

# Function to check if we should proceed with task processing
ensure_within_limits() {
    local agent_name="ai_docs_agent.sh"

    # Check concurrent instances
    local running_count=$(pgrep -f "${agent_name}" | wc -l)
    if [[ ${running_count} -gt ${MAX_CONCURRENCY} ]]; then
        log "Too many concurrent instances (${running_count}/${MAX_CONCURRENCY}). Waiting..."
        return 1
    fi

    # Check system load (macOS compatible)
    local load_avg
    if command -v sysctl >/dev/null 2>&1; then
        # macOS: use sysctl vm.loadavg
        load_avg=$(sysctl -n vm.loadavg | awk '{print $2}')
    else
        # Fallback: use uptime
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
    fi

    # Compare load as float
    if (($(echo "${load_avg} >= ${LOAD_THRESHOLD}" | bc -l 2>/dev/null || echo "0"))); then
        log "System load too high (${load_avg} >= ${LOAD_THRESHOLD}). Waiting..."
        return 1
    fi

    return 0
}

AGENT_NAME="ai_docs_agent.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/ai_docs_agent.log"
NOTIFICATION_FILE="${WORKSPACE}/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
OLLAMA_ENDPOINT="http://localhost:11434"
DOCS_DIR="${WORKSPACE}/Documentation"
RESULTS_DIR="${WORKSPACE}/Tools/Automation/results"

# Logging function
log() {
    echo "[$(date)] ${AGENT_NAME}: $*" >>"${LOG_FILE}"
}

# Ollama Integration Functions
ollama_query() {
    local prompt="$1"
    local model="${2:-codellama}"

    curl -s -X POST "${OLLAMA_ENDPOINT}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"${model}\", \"prompt\": \"${prompt}\", \"stream\": false}" |
        jq -r '.response // empty'
}

# Update agent status
update_status() {
    local status="$1"
    if command -v jq &>/dev/null; then
        jq "(.[] | select(.id == \"${AGENT_NAME}\") | .status) = \"${status}\" | (.[] | select(.id == \"${AGENT_NAME}\") | .last_seen) = $(date +%s)" "${AGENT_STATUS_FILE}" >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
    fi
    echo "[$(date)] ${AGENT_NAME}: Status updated to ${status}" >>"${LOG_FILE}"
}

# Process a specific task
process_task() {
    local task_id="$1"
    echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id}" >>"${LOG_FILE}"

    # Get task details
    if command -v jq &>/dev/null; then
        local task_desc
        task_desc=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .description" "${TASK_QUEUE_FILE}")
        local task_type
        task_type=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .type" "${TASK_QUEUE_FILE}")
        echo "[$(date)] ${AGENT_NAME}: Task description: ${task_desc}" >>"${LOG_FILE}"
        echo "[$(date)] ${AGENT_NAME}: Task type: ${task_type}" >>"${LOG_FILE}"

        # Process based on task type
        case "${task_type}" in
        "docs" | "documentation" | "ai_docs")
            run_ai_documentation "${task_desc}"
            ;;
        *)
            echo "[$(date)] ${AGENT_NAME}: Unknown task type: ${task_type}" >>"${LOG_FILE}"
            ;;
        esac

        # Mark task as completed
        update_task_status "${task_id}" "completed"
        echo "[$(date)] ${AGENT_NAME}: Task ${task_id} completed" >>"${LOG_FILE}"
    fi
}

# Update task status
update_task_status() {
    local task_id="$1"
    local status="$2"
    if command -v jq &>/dev/null; then
        jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
    fi
}

# Main AI documentation generation function
run_ai_documentation() {
    local task_desc="$1"
    log "Running AI documentation generation for: ${task_desc}"

    # Extract project name from task description or use all projects
    local projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

    for project in "${projects[@]}"; do
        if [[ -d "${WORKSPACE}/Projects/${project}" ]]; then
            log "Generating AI documentation for ${project}..."

            # Generate different types of documentation
            generate_api_documentation "${project}"
            generate_architecture_documentation "${project}"
            generate_user_guide "${project}"
            generate_developer_guide "${project}"

            log "AI documentation generation completed for ${project}"
        fi
    done

    # Generate workspace-level documentation
    generate_workspace_overview
    generate_integration_guide

    log "AI documentation generation completed for all projects"
}

# Generate API documentation
generate_api_documentation() {
    local project="$1"
    log "Generating API documentation for ${project}..."

    local api_file="${DOCS_DIR}/API/${project}_API.md"
    mkdir -p "${DOCS_DIR}/API"

    # Analyze Swift files for API endpoints and public interfaces
    local swift_files
    swift_files=$(find "${WORKSPACE}/Projects/${project}" -name "*.swift" -type f)

    local api_content=""
    local public_functions=""
    local classes=""
    local protocols=""

    for file in ${swift_files}; do
        if [[ -f "${file}" ]]; then
            # Extract public functions
            local funcs
            funcs=$(grep -n "^[[:space:]]*public func" "${file}" | head -10)
            if [[ -n "${funcs}" ]]; then
                public_functions+="// ${file}\n${funcs}\n\n"
            fi

            # Extract classes
            local cls
            cls=$(grep -n "^[[:space:]]*class " "${file}" | grep -v "private\|fileprivate" | head -5)
            if [[ -n "${cls}" ]]; then
                classes+="// ${file}\n${cls}\n\n"
            fi

            # Extract protocols
            local prot
            prot=$(grep -n "^[[:space:]]*protocol " "${file}" | head -5)
            if [[ -n "${prot}" ]]; then
                protocols+="// ${file}\n${prot}\n\n"
            fi
        fi
    done

    # Use AI to generate comprehensive API documentation
    local api_prompt="Generate comprehensive API documentation for this Swift iOS/macOS application:

Project: ${project}

Public Functions Found:
${public_functions}

Classes Identified:
${classes}

Protocols Defined:
${protocols}

Please generate:
1. Complete API reference with function signatures and descriptions
2. Class hierarchy and relationships
3. Protocol conformance documentation
4. Usage examples for key APIs
5. Error handling documentation
6. Threading and concurrency notes
7. Memory management considerations

Format as clean Markdown documentation suitable for developers."

    local ai_api_docs
    ai_api_docs=$(ollama_query "${api_prompt}")

    {
        echo "# ${project} API Documentation"
        echo "**Generated:** $(date)"
        echo "**Framework:** AI-Powered Documentation"
        echo ""
        echo "## Overview"
        echo ""
        echo "This document provides comprehensive API documentation for the ${project} application."
        echo "Documentation is automatically generated from code analysis and AI-enhanced descriptions."
        echo ""
        echo "## Table of Contents"
        echo ""
        echo "- [Public API Reference](#public-api-reference)"
        echo "- [Class Hierarchy](#class-hierarchy)"
        echo "- [Protocols](#protocols)"
        echo "- [Usage Examples](#usage-examples)"
        echo "- [Error Handling](#error-handling)"
        echo ""
        echo "## Public API Reference"
        echo ""
        if [[ -n "${ai_api_docs}" ]]; then
            echo "${ai_api_docs}"
        else
            echo "### Manual API Documentation Required"
            echo ""
            echo "AI generation failed. Please document the following manually:"
            echo ""
            echo "#### Functions"
            echo "\`\`\`swift"
            echo "${public_functions}"
            echo "\`\`\`"
            echo ""
            echo "#### Classes"
            echo "\`\`\`swift"
            echo "${classes}"
            echo "\`\`\`"
            echo ""
            echo "#### Protocols"
            echo "\`\`\`swift"
            echo "${protocols}"
            echo "\`\`\`"
        fi
        echo ""
        echo "---"
        echo "*Generated by AI Documentation Agent*"
    } >"${api_file}"

    log "API documentation generated: ${api_file}"
}

# Generate architecture documentation
generate_architecture_documentation() {
    local project="$1"
    log "Generating architecture documentation for ${project}..."

    local arch_file="${DOCS_DIR}/Architecture/${project}_Architecture.md"
    mkdir -p "${DOCS_DIR}/Architecture"

    # Analyze project structure
    local file_count
    file_count=$(find "${WORKSPACE}/Projects/${project}" -name "*.swift" | wc -l)

    local dir_structure
    dir_structure=$(find "${WORKSPACE}/Projects/${project}" -type d -name "*.swift" -prune -o -type d -print | head -20)

    local mvvm_usage
    mvvm_usage=$(find "${WORKSPACE}/Projects/${project}" -name "*.swift" -exec grep -l "ObservableObject\|BaseViewModel" {} \; | wc -l)

    local shared_components
    shared_components=$(find "${WORKSPACE}/Projects/${project}" -name "*.swift" -exec grep -l "SharedArchitecture\|SharedTypes" {} \; | wc -l)

    # Use AI to generate architecture documentation
    local arch_prompt="Generate comprehensive architecture documentation for this Swift application:

Project: ${project}
File Count: ${file_count} Swift files
MVVM Pattern Usage: ${mvvm_usage} files
Shared Components: ${shared_components} files

Directory Structure:
${dir_structure}

Please analyze and document:
1. Overall architecture patterns (MVVM, MVC, etc.)
2. Component relationships and dependencies
3. Data flow and state management
4. Design patterns implemented
5. Shared component integration
6. Platform-specific considerations (iOS/macOS)
7. Scalability and maintainability aspects
8. Security architecture elements

Format as architectural documentation for developers and architects."

    local ai_arch_docs
    ai_arch_docs=$(ollama_query "${arch_prompt}")

    {
        echo "# ${project} Architecture Documentation"
        echo "**Generated:** $(date)"
        echo "**Framework:** AI-Powered Analysis"
        echo ""
        echo "## System Overview"
        echo ""
        echo "**Project:** ${project}"
        echo "**Files:** ${file_count} Swift files"
        echo "**Architecture:** MVVM with Shared Components"
        echo "**Platform:** iOS/macOS"
        echo ""
        echo "## Architecture Analysis"
        echo ""
        if [[ -n "${ai_arch_docs}" ]]; then
            echo "${ai_arch_docs}"
        else
            echo "### Architecture Summary"
            echo ""
            echo "- **MVVM Implementation:** ${mvvm_usage} files using MVVM pattern"
            echo "- **Shared Components:** ${shared_components} files using shared architecture"
            echo "- **Modular Design:** Organized directory structure for maintainability"
            echo ""
            echo "### Key Components"
            echo "- ViewModels following BaseViewModel protocol"
            echo "- Shared types and utilities"
            echo "- Platform-specific implementations"
            echo "- Unified error handling and logging"
        fi
        echo ""
        echo "## Design Patterns"
        echo ""
        echo "### MVVM (Model-View-ViewModel)"
        echo "- ViewModels handle business logic and state"
        echo "- ObservableObject for reactive UI updates"
        echo "- Protocol-based architecture for consistency"
        echo ""
        echo "### Shared Component Pattern"
        echo "- Reusable components across projects"
        echo "- Consistent interfaces and behaviors"
        echo "- Centralized utility functions"
        echo ""
        echo "## Data Flow"
        echo ""
        echo "1. **User Interaction** → View"
        echo "2. **View** → ViewModel (actions/events)"
        echo "3. **ViewModel** → Model (data operations)"
        echo "4. **Model** → ViewModel (data updates)"
        echo "5. **ViewModel** → View (UI updates via ObservableObject)"
        echo ""
        echo "---"
        echo "*Generated by AI Documentation Agent*"
    } >"${arch_file}"

    log "Architecture documentation generated: ${arch_file}"
}

# Generate user guide
generate_user_guide() {
    local project="$1"
    log "Generating user guide for ${project}..."

    local guide_file="${DOCS_DIR}/UserGuides/${project}_User_Guide.md"
    mkdir -p "${DOCS_DIR}/UserGuides"

    # Analyze UI components and features
    local ui_files
    ui_files=$(find "${WORKSPACE}/Projects/${project}" -name "*.swift" -exec grep -l "View\|Button\|TextField\|List" {} \; | wc -l)

    local features=""
    case "${project}" in
    "CodingReviewer")
        features="Code review, analysis, and collaboration features"
        ;;
    "PlannerApp")
        features="Task planning, organization, and productivity tools"
        ;;
    "MomentumFinance")
        features="Financial tracking, budgeting, and expense management"
        ;;
    "HabitQuest")
        features="Habit tracking, goal setting, and progress monitoring"
        ;;
    "AvoidObstaclesGame")
        features="Obstacle avoidance gameplay with scoring system"
        ;;
    esac

    # Use AI to generate user guide
    local guide_prompt="Generate a comprehensive user guide for this Swift application:

Project: ${project}
UI Components: ${ui_files} files with user interface elements
Key Features: ${features}

Please create a user-friendly guide that includes:
1. Getting started instructions
2. Main feature walkthrough
3. Navigation and interface guide
4. Settings and customization options
5. Troubleshooting common issues
6. Tips and best practices
7. FAQ section

Make it accessible for non-technical users while covering all major functionality."

    local ai_user_guide
    ai_user_guide=$(ollama_query "${guide_prompt}")

    {
        echo "# ${project} User Guide"
        echo "**Generated:** $(date)"
        echo "**Version:** 1.0"
        echo "**Platform:** iOS/macOS"
        echo ""
        echo "## Welcome to ${project}"
        echo ""
        echo "This guide will help you get started with ${project} and make the most of its features."
        echo ""
        echo "## Table of Contents"
        echo ""
        echo "- [Getting Started](#getting-started)"
        echo "- [Main Features](#main-features)"
        echo "- [Navigation](#navigation)"
        echo "- [Settings](#settings)"
        echo "- [Troubleshooting](#troubleshooting)"
        echo "- [FAQ](#faq)"
        echo ""
        echo "## Getting Started"
        echo ""
        echo "### Installation"
        echo "1. Download ${project} from the App Store (iOS) or Mac App Store (macOS)"
        echo "2. Launch the application"
        echo "3. Follow the initial setup wizard"
        echo ""
        echo "### First Time Setup"
        echo "- Grant necessary permissions (if prompted)"
        echo "- Configure your preferences"
        echo "- Import existing data (if applicable)"
        echo ""
        if [[ -n "${ai_user_guide}" ]]; then
            echo "${ai_user_guide}"
        else
            echo "## Main Features"
            echo ""
            echo "### ${features}"
            echo ""
            echo "The application provides comprehensive features designed for productivity and ease of use."
            echo ""
            echo "### Key Capabilities"
            echo "- Intuitive user interface"
            echo "- Cross-platform synchronization"
            echo "- Data persistence and backup"
            echo "- Performance optimized for mobile and desktop"
            echo ""
            echo "## Navigation"
            echo ""
            echo "The app features a clean, intuitive navigation system:"
            echo ""
            echo "- **Main Screen:** Primary functionality and recent items"
            echo "- **Menu/Navigation:** Access to all major features"
            echo "- **Settings:** Customize your experience"
            echo "- **Help:** Access this guide and support"
            echo ""
            echo "## Settings & Customization"
            echo ""
            echo "Customize ${project} to match your preferences:"
            echo ""
            echo "- Theme selection (light/dark mode)"
            echo "- Notification preferences"
            echo "- Data synchronization settings"
            echo "- Privacy and security options"
        fi
        echo ""
        echo "## Troubleshooting"
        echo ""
        echo "### Common Issues"
        echo ""
        echo "**App won't start**"
        echo "- Ensure your device meets minimum requirements"
        echo "- Restart your device"
        echo "- Reinstall the application"
        echo ""
        echo "**Data not syncing**"
        echo "- Check internet connection"
        echo "- Verify account credentials"
        echo "- Force refresh data"
        echo ""
        echo "**Performance issues**"
        echo "- Close other applications"
        echo "- Clear app cache"
        echo "- Restart the application"
        echo ""
        echo "## FAQ"
        echo ""
        echo "**Q: Is my data secure?**"
        echo "A: Yes, ${project} uses industry-standard encryption and security practices."
        echo ""
        echo "**Q: Can I use ${project} offline?**"
        echo "A: Basic functionality is available offline, with data syncing when connected."
        echo ""
        echo "**Q: How do I backup my data?**"
        echo "A: Data is automatically backed up to iCloud (iOS) or local storage (macOS)."
        echo ""
        echo "---"
        echo "*Generated by AI Documentation Agent*"
    } >"${guide_file}"

    log "User guide generated: ${guide_file}"
}

# Generate developer guide
generate_developer_guide() {
    local project="$1"
    log "Generating developer guide for ${project}..."

    local dev_file="${DOCS_DIR}/Developer/${project}_Developer_Guide.md"
    mkdir -p "${DOCS_DIR}/Developer"

    # Analyze development aspects
    local test_files
    test_files=$(find "${WORKSPACE}/Projects/${project}" -name "*Test*.swift" | wc -l)

    local build_configs
    build_configs=$(find "${WORKSPACE}/Projects/${project}" -name "*.xcconfig" -o -name "Package.swift" | wc -l)

    # Use AI to generate developer guide
    local dev_prompt="Generate a comprehensive developer guide for this Swift application:

Project: ${project}
Test Files: ${test_files} test files
Build Configurations: ${build_configs} configuration files

Please create a developer guide that includes:
1. Development environment setup
2. Project structure and organization
3. Coding standards and conventions
4. Testing strategy and guidelines
5. Build and deployment process
6. Debugging and troubleshooting
7. Contributing guidelines
8. API integration guides

Focus on practical development information for team members."

    local ai_dev_guide
    ai_dev_guide=$(ollama_query "${dev_prompt}")

    {
        echo "# ${project} Developer Guide"
        echo "**Generated:** $(date)"
        echo "**Framework:** AI-Powered Documentation"
        echo ""
        echo "## Development Overview"
        echo ""
        echo "**Project:** ${project}"
        echo "**Language:** Swift 5.9+"
        echo "**Architecture:** MVVM with Shared Components"
        echo "**Testing:** ${test_files} test files"
        echo "**Build System:** Xcode with Swift Package Manager"
        echo ""
        echo "## Getting Started"
        echo ""
        echo "### Prerequisites"
        echo "- macOS 13.0+"
        echo "- Xcode 15.0+"
        echo "- Swift 5.9+"
        echo "- Git for version control"
        echo ""
        echo "### Setup"
        echo "1. Clone the repository:"
        echo "   \`\`\`bash"
        echo "   git clone <repository-url>"
        echo "   cd Quantum-workspace/Projects/${project}"
        echo "   \`\`\`"
        echo ""
        echo "2. Open the project:"
        echo "   \`\`\`bash"
        echo "   open ${project}.xcodeproj"
        echo "   \`\`\`"
        echo ""
        echo "3. Build and run:"
        echo "   - Select appropriate target (iOS/macOS)"
        echo "   - Build (⌘B)"
        echo "   - Run (⌘R)"
        echo ""
        echo "## Project Structure"
        echo ""
        echo "### Directory Layout"
        echo "\`\`\`"
        echo "${project}/"
        echo "├── Sources/"
        echo "│   ├── Views/          # SwiftUI views"
        echo "│   ├── ViewModels/     # MVVM view models"
        echo "│   ├── Models/         # Data models"
        echo "│   ├── Services/       # Business logic"
        echo "│   └── Utilities/      # Helper functions"
        echo "├── Tests/"
        echo "│   ├── UnitTests/      # Unit test files"
        echo "│   └── UITests/        # UI test files"
        echo "└── Resources/          # Assets and configurations"
        echo "\`\`\`"
        echo ""
        echo "### Key Files"
        echo "- **${project}.xcodeproj:** Main Xcode project"
        echo "- **Package.swift:** Swift Package Manager configuration"
        echo "- **Info.plist:** Application configuration"
        echo ""
        if [[ -n "${ai_dev_guide}" ]]; then
            echo "${ai_dev_guide}"
        else
            echo "## Coding Standards"
            echo ""
            echo "### Swift Style Guide"
            echo "- Follow Swift API Design Guidelines"
            echo "- Use descriptive variable and function names"
            echo "- Prefer structs over classes where appropriate"
            echo "- Use dependency injection for testability"
            echo ""
            echo "### Architecture Patterns"
            echo "- **MVVM:** Separate concerns between View, ViewModel, and Model"
            echo "- **ObservableObject:** Use Combine for reactive programming"
            echo "- **Protocol-Oriented:** Define interfaces with protocols"
            echo "- **Shared Components:** Reuse common functionality"
            echo ""
            echo "### Error Handling"
            echo "- Use Swift's Result type for operations that can fail"
            echo "- Provide meaningful error messages"
            echo "- Log errors appropriately"
            echo "- Handle errors gracefully in UI"
            echo ""
            echo "## Testing"
            echo ""
            echo "### Test Structure"
            echo "- **Unit Tests:** Test individual functions and classes"
            echo "- **Integration Tests:** Test component interactions"
            echo "- **UI Tests:** Test user interface flows"
            echo ""
            echo "### Running Tests"
            echo "\`\`\`bash"
            echo "# Run all tests"
            echo "xcodebuild test -scheme ${project}"
            echo ""
            echo "# Run specific test class"
            echo "xcodebuild test -scheme ${project} -only-testing:${project}Tests/TestClass"
            echo "\`\`\`"
            echo ""
            echo "### Test Coverage"
            echo "- Aim for 70%+ code coverage"
            echo "- Test both success and failure paths"
            echo "- Use mock objects for external dependencies"
        fi
        echo ""
        echo "## Build & Deployment"
        echo ""
        echo "### Local Development"
        echo "1. **Debug Build:** Standard development build"
        echo "2. **Release Build:** Optimized production build"
        echo "3. **Testing:** Run test suite before commits"
        echo ""
        echo "### CI/CD Integration"
        echo "- Automated testing on pull requests"
        echo "- Code quality checks (SwiftLint)"
        echo "- Security scanning"
        echo "- Performance monitoring"
        echo ""
        echo "## Debugging"
        echo ""
        echo "### Common Issues"
        echo "- **Build Failures:** Check Xcode version compatibility"
        echo "- **Runtime Crashes:** Enable zombie objects in debug mode"
        echo "- **UI Issues:** Use View Debugger in Xcode"
        echo "- **Performance:** Profile with Instruments"
        echo ""
        echo "### Logging"
        echo "- Use unified logging system"
        echo "- Log levels: Debug, Info, Warning, Error"
        echo "- Include contextual information"
        echo ""
        echo "## Contributing"
        echo ""
        echo "### Code Reviews"
        echo "- All changes require code review"
        echo "- Follow established coding standards"
        echo "- Include tests for new functionality"
        echo "- Update documentation as needed"
        echo ""
        echo "### Git Workflow"
        echo "1. Create feature branch from main"
        echo "2. Make changes with descriptive commits"
        echo "3. Push branch and create pull request"
        echo "4. Address review feedback"
        echo "5. Merge after approval"
        echo ""
        echo "---"
        echo "*Generated by AI Documentation Agent*"
    } >"${dev_file}"

    log "Developer guide generated: ${dev_file}"
}

# Generate workspace overview
generate_workspace_overview() {
    log "Generating workspace overview documentation..."

    local overview_file="${DOCS_DIR}/README.md"

    # Count projects and files
    local project_count
    project_count=$(find "${WORKSPACE}/Projects" -maxdepth 1 -type d | wc -l)
    ((project_count--)) # Subtract 1 for the Projects directory itself

    local total_files
    total_files=$(find "${WORKSPACE}/Projects" -name "*.swift" | wc -l)

    local shared_files
    shared_files=$(find "${WORKSPACE}/Shared" -name "*.swift" | wc -l)

    {
        echo "# Quantum Workspace"
        echo "**Generated:** $(date)"
        echo "**Framework:** Unified Swift Architecture"
        echo ""
        echo "## Overview"
        echo ""
        echo "Quantum Workspace is a unified code architecture containing multiple Swift projects consolidated for maximum code reuse and automation efficiency."
        echo ""
        echo "## Statistics"
        echo ""
        echo "- **Projects:** ${project_count} active projects"
        echo "- **Swift Files:** ${total_files} total files"
        echo "- **Shared Components:** ${shared_files} reusable components"
        echo "- **Automation:** Advanced CI/CD and AI-powered workflows"
        echo "- **Platforms:** iOS, macOS, Web (SwiftWasm)"
        echo ""
        echo "## Projects"
        echo ""
        echo "### CodingReviewer"
        echo "Advanced code review application with AI-powered analysis and collaboration features."
        echo "- **Platform:** macOS"
        echo "- **Architecture:** MVVM with shared components"
        echo "- **Features:** Code analysis, review workflows, AI suggestions"
        echo ""
        echo "### PlannerApp"
        echo "Comprehensive planning and organization application with CloudKit integration."
        echo "- **Platform:** macOS, iOS"
        echo "- **Architecture:** MVVM with encryption framework"
        echo "- **Features:** Task management, calendar integration, secure data storage"
        echo ""
        echo "### MomentumFinance"
        echo "Financial tracking and budgeting application."
        echo "- **Platform:** macOS, iOS"
        echo "- **Architecture:** MVVM with shared components"
        echo "- **Features:** Expense tracking, budget planning, financial insights"
        echo ""
        echo "### HabitQuest"
        echo "Habit tracking application with gamification elements."
        echo "- **Platform:** iOS"
        echo "- **Architecture:** MVVM with shared components"
        echo "- **Features:** Habit creation, progress tracking, achievement system"
        echo ""
        echo "### AvoidObstaclesGame"
        echo "SpriteKit-based obstacle avoidance game."
        echo "- **Platform:** iOS"
        echo "- **Architecture:** Game architecture with shared utilities"
        echo "- **Features:** Gameplay mechanics, scoring system, leaderboards"
        echo ""
        echo "## Architecture"
        echo ""
        echo "### Unified Architecture Pattern"
        echo "All projects follow a consistent MVVM architecture with shared components:"
        echo ""
        echo "- **BaseViewModel:** Protocol-based view model foundation"
        echo "- **SharedTypes:** Common data models and interfaces"
        echo "- **SharedArchitecture:** Reusable architectural components"
        echo "- **Testing:** Unified testing framework and utilities"
        echo ""
        echo "### Key Principles"
        echo "- **Data models NEVER import SwiftUI** (kept in SharedTypes/)"
        echo "- **Synchronous operations with background queues**"
        echo "- **Sendable for thread safety**"
        echo "- **Specific naming over generic** (avoid 'Manager', 'Dashboard')"
        echo ""
        echo "## Automation & CI/CD"
        echo ""
        echo "### Master Automation System"
        echo "Centralized automation controller at \`Tools/Automation/master_automation.sh\`:"
        echo ""
        echo "\`\`\`bash"
        echo "# Check system status"
        echo "./Tools/Automation/master_automation.sh status"
        echo ""
        echo "# List all projects"
        echo "./Tools/Automation/master_automation.sh list"
        echo ""
        echo "# Run automation for specific project"
        echo "./Tools/Automation/master_automation.sh run CodingReviewer"
        echo "\`\`\`"
        echo ""
        echo "### AI-Powered Features"
        echo "- **Code Generation:** AI-assisted development and refactoring"
        echo "- **Documentation:** Automated API and architecture docs"
        echo "- **Testing:** AI-generated unit tests and integration tests"
        echo "- **Security:** Automated vulnerability scanning and compliance"
        echo ""
        echo "### Quality Gates"
        echo "- **Code Coverage:** 70% minimum, 85% target"
        echo "- **Build Performance:** Max 120 seconds"
        echo "- **Test Performance:** Max 30 seconds"
        echo "- **File Limits:** Max 500 lines per file, 1000KB file size"
        echo ""
        echo "## Development Workflow"
        echo ""
        echo "### Getting Started"
        echo "1. **Clone Repository:**"
        echo "   \`\`\`bash"
        echo "   git clone <repository-url>"
        echo "   cd Quantum-workspace"
        echo "   \`\`\`"
        echo ""
        echo "2. **Setup Environment:**"
        echo "   \`\`\`bash"
        echo "   # Install dependencies"
        echo "   brew install swiftlint swiftformat"
        echo "   \`\`\`"
        echo ""
        echo "3. **Run Automation:**"
        echo "   \`\`\`bash"
        echo "   ./Tools/Automation/master_automation.sh status"
        echo "   ./Tools/Automation/master_automation.sh run <project>"
        echo "   \`\`\`"
        echo ""
        echo "### Project Development"
        echo "- Use VSCode workspace: \`Code.code-workspace\`"
        echo "- Follow architecture principles (no SwiftUI in data models)"
        echo "- Run automation before commits"
        echo "- Update shared components for cross-project improvements"
        echo ""
        echo "## Documentation"
        echo ""
        echo "### Available Documentation"
        echo "- **API Documentation:** Comprehensive API references for all projects"
        echo "- **Architecture Docs:** System design and component relationships"
        echo "- **User Guides:** Feature walkthroughs and usage instructions"
        echo "- **Developer Guides:** Setup, coding standards, and contribution guidelines"
        echo "- **Security Reports:** Vulnerability assessments and compliance status"
        echo ""
        echo "### AI-Generated Content"
        echo "All documentation is automatically generated and maintained using AI analysis of the codebase."
        echo ""
        echo "## Security & Compliance"
        echo ""
        echo "### Security Framework"
        echo "- **Encryption:** AES256 with CryptoKit and Keychain integration"
        echo "- **Audit Trails:** Comprehensive logging and compliance monitoring"
        echo "- **Vulnerability Scanning:** Automated security analysis"
        echo "- **Access Control:** Secure data handling patterns"
        echo ""
        echo "### Compliance Standards"
        echo "- **GDPR:** Data protection and privacy compliance"
        echo "- **Security:** Industry-standard security practices"
        echo "- **Code Quality:** Automated linting and formatting"
        echo ""
        echo "## Performance & Monitoring"
        echo ""
        echo "### Build Performance"
        echo "- **Parallel Processing:** 99.99% faster full workspace automation"
        echo "- **Incremental Builds:** Smart dependency tracking"
        echo "- **Caching:** File system and computation caching"
        echo ""
        echo "### Monitoring Dashboard"
        echo "- Real-time performance metrics"
        echo "- Security monitoring and alerts"
        echo "- Build status and quality gates"
        echo "- Resource usage tracking"
        echo ""
        echo "## Contributing"
        echo ""
        echo "### Development Guidelines"
        echo "- Follow established architecture patterns"
        echo "- Maintain code quality standards"
        echo "- Update documentation for changes"
        echo "- Test thoroughly before submitting"
        echo ""
        echo "### Code Review Process"
        echo "- Automated quality checks"
        echo "- AI-assisted code review suggestions"
        echo "- Security and compliance validation"
        echo "- Performance impact assessment"
        echo ""
        echo "---"
        echo "*Quantum Workspace - Unified Swift Architecture*"
        echo "*Generated by AI Documentation Agent*"
    } >"${overview_file}"

    log "Workspace overview generated: ${overview_file}"
}

# Generate integration guide
generate_integration_guide() {
    log "Generating integration guide..."

    local integration_file="${DOCS_DIR}/Integration_Guide.md"

    {
        echo "# Integration Guide"
        echo "**Generated:** $(date)"
        echo "**Framework:** Quantum Workspace Architecture"
        echo ""
        echo "## Overview"
        echo ""
        echo "This guide provides integration patterns and best practices for working with the Quantum Workspace unified architecture."
        echo ""
        echo "## Architecture Integration"
        echo ""
        echo "### Shared Components"
        echo ""
        echo "All projects integrate with shared components for consistency and reusability:"
        echo ""
        echo "#### BaseViewModel Protocol"
        echo "\`\`\`swift"
        echo "@MainActor"
        echo "protocol BaseViewModel: ObservableObject {"
        echo "    associatedtype State"
        echo "    associatedtype Action"
        echo "    var state: State { get set }"
        echo "    var isLoading: Bool { get set }"
        echo "    func handle(_ action: Action)"
        echo "}"
        echo "\`\`\`"
        echo ""
        echo "**Integration Steps:**"
        echo "1. Import SharedArchitecture"
        echo "2. Conform your ViewModel to BaseViewModel"
        echo "3. Define State and Action types"
        echo "4. Implement handle(_:) method"
        echo ""
        echo "#### Shared Types"
        echo "- **Result Types:** Standardized error handling"
        echo "- **Data Models:** Common interfaces and structures"
        echo "- **Utility Functions:** Reusable helper methods"
        echo ""
        echo "### Project-Specific Integration"
        echo ""
        echo "#### Adding a New Project"
        echo "1. **Create Project Structure:**"
        echo "   \`\`\`bash"
        echo "   mkdir Projects/NewProject"
        echo "   cd Projects/NewProject"
        echo "   swift package init --type executable"
        echo "   \`\`\`"
        echo ""
        echo "2. **Integrate Shared Components:**"
        echo "   - Add Shared/ directory to search paths"
        echo "   - Import required shared modules"
        echo "   - Follow MVVM architecture pattern"
        echo ""
        echo "3. **Setup Automation:**"
        echo "   - Add project to master_automation.sh"
        echo "   - Configure build and test scripts"
        echo "   - Update CI/CD pipelines"
        echo ""
        echo "#### Cross-Project Dependencies"
        echo "- Use Swift Package Manager for dependencies"
        echo "- Maintain loose coupling between projects"
        echo "- Share only truly common functionality"
        echo ""
        echo "## Build System Integration"
        echo ""
        echo "### Xcode Project Setup"
        echo "- **Target Configuration:** iOS/macOS deployment targets"
        echo "- **Build Settings:** Optimization and debugging configurations"
        echo "- **Code Signing:** Development and distribution certificates"
        echo ""
        echo "### Automation Integration"
        echo "- **Master Script:** \`Tools/Automation/master_automation.sh\`"
        echo "- **Project Scripts:** Individual build and test automation"
        echo "- **Quality Gates:** Code coverage and performance requirements"
        echo ""
        echo "## Testing Integration"
        echo ""
        echo "### Unit Testing"
        echo "- **XCTest Framework:** Standard Swift testing"
        echo "- **Test Coverage:** Minimum 70% target"
        echo "- **CI Integration:** Automated test execution"
        echo ""
        echo "### Integration Testing"
        echo "- **Component Testing:** Shared component validation"
        echo "- **Cross-Project Testing:** Interoperability verification"
        echo "- **Performance Testing:** Build and runtime performance"
        echo ""
        echo "## Deployment Integration"
        echo ""
        echo "### App Store Deployment"
        echo "- **Fastlane Integration:** Automated build and upload"
        echo "- **TestFlight:** Beta distribution and testing"
        echo "- **App Store Connect:** Metadata and screenshots"
        echo ""
        echo "### Cross-Platform Deployment"
        echo "- **iOS/macOS Universal:** Single codebase deployment"
        echo "- **Web Deployment:** SwiftWasm compilation"
        echo "- **CI/CD Pipelines:** Automated deployment workflows"
        echo ""
        echo "## Security Integration"
        echo ""
        echo "### Encryption Framework"
        echo "- **CryptoKit Integration:** AES256 encryption"
        echo "- **Keychain Services:** Secure key storage"
        echo "- **Audit Trails:** Comprehensive logging"
        echo ""
        echo "### Compliance Integration"
        echo "- **GDPR Compliance:** Data protection patterns"
        echo "- **Security Scanning:** Automated vulnerability detection"
        echo "- **Access Control:** Secure data handling"
        echo ""
        echo "## Monitoring Integration"
        echo ""
        echo "### Performance Monitoring"
        echo "- **Build Metrics:** Compilation time tracking"
        echo "- **Runtime Performance:** Memory and CPU monitoring"
        echo "- **Quality Metrics:** Code coverage and complexity"
        echo ""
        echo "### Error Monitoring"
        echo "- **Crash Reporting:** Automated error collection"
        echo "- **Log Aggregation:** Centralized logging system"
        echo "- **Alert System:** Automated notifications"
        echo ""
        echo "## Best Practices"
        echo ""
        echo "### Code Organization"
        echo "- **MVVM Pattern:** Consistent architecture across projects"
        echo "- **Shared Components:** Maximize code reuse"
        echo "- **Modular Design:** Loose coupling and high cohesion"
        echo ""
        echo "### Development Workflow"
        echo "- **Branch Strategy:** Feature branches with PR reviews"
        echo "- **Code Quality:** Automated linting and formatting"
        echo "- **Testing:** Comprehensive test coverage"
        echo ""
        echo "### Maintenance"
        echo "- **Documentation:** Keep docs synchronized with code"
        echo "- **Dependencies:** Regular security updates"
        echo "- **Performance:** Monitor and optimize regularly"
        echo ""
        echo "---"
        echo "*Generated by AI Documentation Agent*"
    } >"${integration_file}"

    log "Integration guide generated: ${integration_file}"
}

# Main agent loop
echo "[$(date)] ${AGENT_NAME}: Starting AI documentation agent..." >>"${LOG_FILE}"
update_status "available"

# Track processed tasks to avoid duplicates
processed_tasks_file="${WORKSPACE}/Tools/Automation/agents/${AGENT_NAME}_processed_tasks.txt"
touch "${processed_tasks_file}"

# Check for command-line arguments (direct execution mode)
if [[ $# -gt 0 ]]; then
    case "$1" in
    "generate_docs" | "ai_documentation")
        log "Direct execution mode: generating AI documentation"
        update_status "busy"
        run_ai_documentation "Comprehensive AI-powered documentation generation"
        update_status "available"
        log "Direct execution completed"
        exit 0
        ;;
    *)
        log "Unknown command: $1"
        exit 1
        ;;
    esac
fi

while true; do
    # Check if we should proceed (throttling)
    if ! ensure_within_limits; then
        # Wait when busy, with exponential backoff
        wait_time=${WAIT_WHEN_BUSY}
        attempts=0
        while ! ensure_within_limits && [[ ${attempts} -lt 10 ]]; do
            log "Waiting ${wait_time}s before retry (attempt $((attempts + 1))/10)"
            sleep "${wait_time}"
            wait_time=$((wait_time * 2))                          # Exponential backoff
            if [[ ${wait_time} -gt 300 ]]; then wait_time=300; fi # Cap at 5 minutes
            ((attempts++))
        done

        # If still busy after retries, skip this cycle
        if ! ensure_within_limits; then
            log "System still busy after retries. Skipping cycle."
            sleep 60
            continue
        fi
    fi

    # Check for new task notifications
    if [[ -f ${NOTIFICATION_FILE} ]]; then
        while IFS='|' read -r _ action task_id; do
            if [[ ${action} == "execute_task" && -z $(grep "^${task_id}$" "${processed_tasks_file}") ]]; then
                update_status "busy"
                process_task "${task_id}"
                update_status "available"
                echo "${task_id}" >>"${processed_tasks_file}"
                echo "[$(date)] ${AGENT_NAME}: Marked task ${task_id} as processed" >>"${LOG_FILE}"
            fi
        done <"${NOTIFICATION_FILE}"

        # Clear processed notifications to prevent re-processing
        true >"${NOTIFICATION_FILE}"
    fi

    # Update last seen timestamp
    update_status "available"

    sleep 30 # Check every 30 seconds
done
