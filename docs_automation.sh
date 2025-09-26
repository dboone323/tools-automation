#!/bin/bash

# Enhanced Documentation Automation System
# Generates comprehensive API documentation, tutorials, and interactive guides

set -euo pipefail

# Configuration
readonly CODE_DIR="${CODE_DIR:-/Users/danielstevens/Desktop/Quantum-workspace}"
readonly DOCS_DIR="${CODE_DIR}/Documentation"
readonly API_DOCS_DIR="${DOCS_DIR}/API"
readonly TUTORIALS_DIR="${DOCS_DIR}/Tutorials"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Logging functions
print_header() { echo -e "${PURPLE}[DOCS]${NC} ${CYAN}$1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_status() { echo -e "${BLUE}🔄 $1${NC}"; }

# Create documentation directories
setup_directories() {
	print_status "Setting up documentation directories..."

	mkdir -p "${API_DOCS_DIR}"
	mkdir -p "${TUTORIALS_DIR}"
	mkdir -p "${DOCS_DIR}/Guides"
	mkdir -p "${DOCS_DIR}/Examples"

	print_success "Documentation directories created"
}

# Generate API documentation from Swift code
generate_api_docs() {
	local project_name="$1"
	local project_path="${CODE_DIR}/Projects/${project_name}"

	if [[ ! -d ${project_path} ]]; then
		print_error "Project ${project_name} not found"
		return 1
	fi

	print_header "Generating API documentation for ${project_name}"

	local api_doc_file="${API_DOCS_DIR}/${project_name}_API.md"

	# Extract public APIs from Swift files
	{
		echo "# ${project_name} API Documentation"
		echo ""
		echo "Generated: $(date)"
		echo "Project: ${project_name}"
		echo "Location: ${project_path}"
		echo ""

		echo "## Overview"
		echo ""
		echo "This document contains the public API reference for ${project_name}."
		echo ""

		# Find all Swift files
		local swift_files
		swift_files=$(find "${project_path}" -name "*.swift" -type f)

		if [[ -z ${swift_files} ]]; then
			echo "No Swift files found in project."
			return 1
		fi

		echo "## Classes and Structs"
		echo ""

		# Extract classes, structs, and their public members
		for file in ${swift_files}; do
			local filename
			filename=$(basename "${file}" .swift)

			echo "### ${filename}"
			echo ""
			echo "File: \`${file}\`"
			echo ""

			# Extract public classes/structs
			local public_types
			public_types=$(grep -n "^public \(class\|struct\|enum\)" "${file}" || true)

			if [[ -n ${public_types} ]]; then
				echo "#### Public Types"
				echo ""
				while IFS=: read -r line_num line; do
					local type_name
					type_name=$(echo "${line}" | sed 's/.*\(class\|struct\|enum\) \([^{]*\).*/\2/' | xargs)
					echo "- **${type_name}** (line ${line_num})"
				done <<<"${public_types}"
				echo ""
			fi

			# Extract public functions
			local public_funcs
			public_funcs=$(grep -n "^[[:space:]]*public func" "${file}" || true)

			if [[ -n ${public_funcs} ]]; then
				echo "#### Public Functions"
				echo ""
				while IFS=: read -r line_num line; do
					local func_signature
					func_signature=$(echo "${line}" | sed 's/^[[:space:]]*public func //' | xargs)
					echo "- \`${func_signature}\` (line ${line_num})"
				done <<<"${public_funcs}"
				echo ""
			fi

			# Extract public properties
			local public_props
			public_props=$(grep -n "^[[:space:]]*public \(var\|let\)" "${file}" || true)

			if [[ -n ${public_props} ]]; then
				echo "#### Public Properties"
				echo ""
				while IFS=: read -r line_num line; do
					local prop_declaration
					prop_declaration=$(echo "${line}" | sed 's/^[[:space:]]*public //' | xargs)
					echo "- \`${prop_declaration}\` (line ${line_num})"
				done <<<"${public_props}"
				echo ""
			fi
		done

		echo "## Dependencies"
		echo ""

		# Check for Package.swift
		if [[ -f "${project_path}/Package.swift" ]]; then
			echo "### Swift Package Manager Dependencies"
			echo ""
			echo "Package.swift location: \`${project_path}/Package.swift\`"
			echo ""

			# Extract dependencies (simplified)
			if grep -q "dependencies:" "${project_path}/Package.swift"; then
				echo "#### External Dependencies"
				grep -A 10 "dependencies:" "${project_path}/Package.swift" | grep -E "\.package\(|url:" | head -10 || true
			fi
		fi

		# Check for Podfile
		if [[ -f "${project_path}/Podfile" ]]; then
			echo "### CocoaPods Dependencies"
			echo ""
			echo "Podfile location: \`${project_path}/Podfile\`"
			echo ""

			echo "#### Pods"
			grep "^pod " "${project_path}/Podfile" | sed 's/^pod /- /' || true
		fi

	} >"${api_doc_file}"

	print_success "API documentation generated: ${api_doc_file}"
}

# Generate tutorial documentation
generate_tutorial() {
	local tutorial_name="$1"
	local tutorial_file="${TUTORIALS_DIR}/${tutorial_name}.md"

	print_header "Generating tutorial: ${tutorial_name}"

	case "${tutorial_name}" in
	"getting_started")
		cat >"${tutorial_file}" <<'EOF'
# Getting Started with Quantum Workspace

This tutorial will guide you through setting up and using the Quantum workspace automation system.

## Prerequisites

- macOS 12.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later
- Git

## Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd Quantum-workspace
   ```

2. **Set up the environment:**
   ```bash
   # Make scripts executable
   chmod +x Tools/Automation/*.sh
   chmod +x Projects/scripts/*.sh
   ```

3. **Verify installation:**
   ```bash
   ./Tools/Automation/master_automation.sh status
   ```

## Your First Automation

Let's run a simple automation task:

```bash
# List all projects
./Tools/Automation/master_automation.sh list

# Run automation for a specific project
./Tools/Automation/master_automation.sh run CodingReviewer

# Run all automations
./Tools/Automation/master_automation.sh all
```

## Next Steps

- Explore the [API Documentation](./../API/)
- Check out the [Developer Tools Guide](./../Guides/DEVELOPER_TOOLS.md)
- Learn about [CI/CD Workflows](./../Guides/CI_CD_GUIDE.md)

## Troubleshooting

If you encounter issues:

1. Check the system status: `./Tools/Automation/master_automation.sh status`
2. View logs in `Tools/Automation/logs/`
3. Run diagnostics: `./Tools/Automation/master_automation.sh validate <project>`

## Getting Help

- Documentation: [Full Documentation Index](./../README.md)
- Issues: Create an issue in the repository
- Discussions: Use GitHub Discussions for questions
EOF
		;;

	"ci_cd_setup")
		cat >"${tutorial_file}" <<'EOF'
# CI/CD Setup Tutorial

Learn how to set up continuous integration and deployment for Quantum workspace projects.

## Overview

The Quantum workspace includes comprehensive CI/CD pipelines using GitHub Actions.

## Prerequisites

- GitHub repository with Actions enabled
- Projects configured with proper build settings
- TestFlight access (for iOS deployment)

## Configuration

### 1. GitHub Actions Setup

Each project includes a `.github/workflows/ci-cd.yml` file with:

- **Build**: Automated compilation for all platforms
- **Test**: Unit and integration tests
- **Lint**: Code quality checks
- **Security**: Security scanning
- **Deploy**: TestFlight deployment

### 2. Required Secrets

Set these in your GitHub repository settings:

```
APP_STORE_CONNECT_PRIVATE_KEY
APP_STORE_CONNECT_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
TESTFLIGHT_EMAIL
```

### 3. Branch Protection

Configure branch protection rules:

1. Go to Settings → Branches
2. Add rule for `main` branch
3. Require status checks to pass
4. Require branches to be up to date

## Workflow Triggers

The CI/CD pipeline runs on:

- Push to main branch
- Pull requests
- Manual workflow dispatch
- Scheduled (weekly security scans)

## Monitoring

### Build Status

Check build status in:
- GitHub Actions tab
- Pull request checks
- Branch protection status

### Test Results

View test results in:
- GitHub Actions logs
- Test summary reports
- Coverage reports (when enabled)

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check Xcode version compatibility
   - Verify code signing certificates
   - Review build logs for specific errors

2. **Test Failures**
   - Run tests locally first
   - Check test environment setup
   - Review test logs for failures

3. **Deployment Issues**
   - Verify App Store Connect credentials
   - Check TestFlight permissions
   - Review deployment logs

### Getting Help

- Check the [CI/CD Guide](./../Guides/CI_CD_GUIDE.md)
- Review workflow logs in GitHub Actions
- Create an issue for persistent problems
EOF
		;;

	"developer_tools")
		cat >"${tutorial_file}" <<'EOF'
# Developer Tools Tutorial

Master the development tools available in the Quantum workspace.

## Code Quality Tools

### SwiftLint

Automated code style and quality checking:

```bash
# Lint all files
swiftlint lint

# Auto-fix issues
swiftlint --fix

# Lint specific file
swiftlint lint path/to/file.swift
```

### SwiftFormat

Code formatting and consistency:

```bash
# Format all files
swiftformat .

# Check formatting without changes
swiftformat --dryrun .

# Format specific file
swiftformat path/to/file.swift
```

## Automation Scripts

### Master Automation Controller

The main automation interface:

```bash
# Show system status
./Tools/Automation/master_automation.sh status

# Run all automations
./Tools/Automation/master_automation.sh all

# Run specific project automation
./Tools/Automation/master_automation.sh run CodingReviewer

# Format code
./Tools/Automation/master_automation.sh format

# Lint code
./Tools/Automation/master_automation.sh lint
```

### Intelligent Auto-Fix

Automatic code issue resolution:

```bash
# Fix all projects
./Tools/Automation/intelligent_autofix.sh fix-all

# Fix specific project
./Tools/Automation/intelligent_autofix.sh fix CodingReviewer

# Validate fixes
./Tools/Automation/intelligent_autofix.sh validate CodingReviewer
```

## Development Workflow

### 1. Daily Development

```bash
# Start with status check
./Tools/Automation/master_automation.sh status

# Make code changes
# ... edit files ...

# Run quality checks
./Tools/Automation/master_automation.sh lint
./Tools/Automation/master_automation.sh format

# Test changes
./Tools/Automation/master_automation.sh run <project>
```

### 2. Before Commit

```bash
# Run comprehensive checks
./Tools/Automation/intelligent_autofix.sh fix-all

# Validate everything
./Tools/Automation/master_automation.sh validate <project>

# Generate documentation
./Projects/scripts/gen_docs.sh
```

### 3. Troubleshooting

```bash
# Check system health
./Tools/Automation/master_automation.sh status

# View logs
tail -f Tools/Automation/logs/*.log

# Run diagnostics
./Tools/Automation/master_automation.sh validate <project>
```

## Advanced Features

### Performance Monitoring

Track build and automation performance:

```bash
# View performance report
./Tools/Automation/performance_monitor.sh

# Check system resources
./Tools/Automation/master_automation.sh status
```

### Security Scanning

Automated security checks:

```bash
# Run security scan
./Tools/Automation/security_check.sh

# Check for exposed secrets
./Tools/Automation/security_check.sh
```

## Customization

### Configuration Files

- `automation_config.yaml`: Main automation settings
- `error_recovery.yaml`: Error handling configuration
- `alerting.yaml`: Email alert settings

### Adding New Tools

1. Create your script in `Tools/Automation/`
2. Add it to `master_automation.sh`
3. Update documentation
4. Test thoroughly

## Best Practices

1. **Always run quality checks** before committing
2. **Use the automation scripts** instead of manual commands
3. **Check system status** regularly
4. **Review logs** when issues occur
5. **Keep tools updated** and configurations current

## Getting Help

- [Developer Tools Guide](./../Guides/DEVELOPER_TOOLS.md)
- [Automation Documentation](./../README.md)
- GitHub Issues for bugs and feature requests
EOF
		;;

	*)
		print_error "Unknown tutorial: ${tutorial_name}"
		return 1
		;;
	esac

	print_success "Tutorial generated: ${tutorial_file}"
}

# Generate interactive documentation index
generate_docs_index() {
	local index_file="${DOCS_DIR}/README.md"

	print_header "Generating documentation index"

	cat >"${index_file}" <<'EOF'
# Quantum Workspace Documentation

Welcome to the comprehensive documentation for the Quantum workspace automation system.

## 📚 Documentation Overview

This workspace provides a complete development environment with automated tools for iOS/macOS development, featuring advanced automation, quality assurance, and deployment capabilities.

## 🚀 Quick Start

- **[Getting Started Tutorial](./Tutorials/getting_started.md)** - Set up your development environment
- **[Developer Tools Tutorial](./Tutorials/developer_tools.md)** - Master the available tools
- **[CI/CD Setup Tutorial](./Tutorials/ci_cd_setup.md)** - Configure continuous integration

## 📖 Guides

### Development
- **[Developer Tools Guide](./Guides/DEVELOPER_TOOLS.md)** - Complete tool reference
- **[CI/CD Guide](./Guides/CI_CD_GUIDE.md)** - Pipeline configuration and management
- **[Architecture Guide](./Guides/ARCHITECTURE.md)** - System design and patterns

### Projects
EOF

	# Add project-specific documentation
	for project_dir in "${CODE_DIR}/Projects"/*; do
		if [[ -d ${project_dir} ]]; then
			local project_name
			project_name=$(basename "${project_dir}")
			echo "- **${project_name}** - [API Reference](./API/${project_name}_API.md)" >>"${index_file}"
		fi
	done

	cat >>"${index_file}" <<'EOF'

## 🛠️ Automation System

### Core Components
- **Master Automation Controller** - Central command interface
- **Intelligent Auto-Fix** - Automatic code issue resolution
- **Performance Monitoring** - Build and system performance tracking
- **Security Scanning** - Automated security validation
- **Email Alerting** - Critical event notifications

### Key Scripts
- `master_automation.sh` - Main automation interface
- `intelligent_autofix.sh` - Code quality and fixing
- `performance_monitor.sh` - Performance monitoring
- `security_check.sh` - Security validation
- `email_alert_system.sh` - Alert notifications

## 🔧 Configuration

### Main Configuration Files
- `Tools/Automation/config/automation_config.yaml` - Core automation settings
- `Tools/Automation/config/error_recovery.yaml` - Error handling configuration
- `Tools/Automation/config/alerting.yaml` - Email alert settings
- `Tools/Automation/config/integration_testing.yaml` - Testing configuration

### Project-Specific Settings
Each project contains its own configuration for:
- Build settings and targets
- Test configurations
- Deployment settings
- Quality gates

## 📊 Monitoring & Analytics

### Dashboards
- **Unified Dashboard** - System-wide status overview
- **Performance Reports** - Build time and resource usage
- **Test Results** - Automated test execution reports
- **Security Reports** - Vulnerability scanning results

### Logs
- `Tools/Automation/logs/` - Automation system logs
- `.autofix.log` - Auto-fix operation logs
- `.alerts.log` - Alert system logs

## 🚨 Troubleshooting

### Common Issues
1. **Build Failures** - Check Xcode version and code signing
2. **Test Failures** - Verify test environment and dependencies
3. **Automation Errors** - Review logs and system status
4. **Performance Issues** - Check resource usage and optimization settings

### Getting Help
1. Check system status: `./Tools/Automation/master_automation.sh status`
2. Review logs in `Tools/Automation/logs/`
3. Run diagnostics: `./Tools/Automation/master_automation.sh validate <project>`
4. Create an issue in the repository

## 📈 Best Practices

### Development Workflow
1. Always run quality checks before committing
2. Use automation scripts instead of manual commands
3. Keep tools and dependencies updated
4. Review changes in pull requests
5. Monitor system performance regularly

### Code Quality
- Follow Swift style guidelines
- Write comprehensive tests
- Document public APIs
- Use meaningful commit messages
- Keep dependencies minimal and updated

### Automation
- Configure alerts for critical events
- Set up branch protection rules
- Monitor CI/CD pipeline health
- Review automation logs regularly
- Update configurations as needed

## 🔄 Continuous Integration

### GitHub Actions
The workspace includes comprehensive CI/CD pipelines with:
- Automated building and testing
- Code quality checks
- Security scanning
- TestFlight deployment
- Performance monitoring

### Quality Gates
- Code formatting compliance
- Test coverage requirements
- Security scan results
- Performance benchmarks
- Documentation updates

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Clone your fork
3. Set up the development environment
4. Create a feature branch
5. Make your changes
6. Run quality checks
7. Submit a pull request

### Code Standards
- Follow existing code style
- Add tests for new features
- Update documentation
- Ensure CI/CD passes
- Get code review approval

## 📞 Support

- **Documentation**: This comprehensive guide
- **Issues**: GitHub Issues for bugs and feature requests
- **Discussions**: GitHub Discussions for questions and ideas
- **Wiki**: Additional guides and examples

---

*Generated automatically on: $(date)*
*Quantum Workspace Automation System v2.0*
EOF

	print_success "Documentation index generated: ${index_file}"
}

# Generate example code documentation
generate_examples() {
	local examples_dir="${DOCS_DIR}/Examples"
	local examples_index="${examples_dir}/README.md"

	print_header "Generating code examples documentation"

	mkdir -p "${examples_dir}"

	cat >"${examples_index}" <<'EOF'
# Code Examples

This directory contains practical code examples for common development tasks in the Quantum workspace.

## 📱 iOS/macOS Development Examples

### Basic App Structure
```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("Hello, Quantum!")
            .padding()
    }
}
```

### SwiftUI View with State Management
```swift
struct TaskListView: View {
    @StateObject private var viewModel = TaskListViewModel()

    var body: some View {
        NavigationView {
            List(viewModel.tasks) { task in
                TaskRow(task: task)
                    .onTapGesture {
                        viewModel.toggleTask(task)
                    }
            }
            .navigationTitle("Tasks")
            .toolbar {
                Button(action: viewModel.addTask) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

class TaskListViewModel: ObservableObject {
    @Published var tasks: [Task] = []

    func addTask() {
        let newTask = Task(title: "New Task", isCompleted: false)
        tasks.append(newTask)
    }

    func toggleTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
        }
    }
}
```

### SwiftData Integration
```swift
import SwiftData

@Model
class Task {
    var id = UUID()
    var title: String
    var isCompleted: Bool
    var createdAt: Date

    init(title: String, isCompleted: Bool = false) {
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }
}

struct PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    init() {
        container = try! ModelContainer(for: Task.self)
    }
}
```

## 🧪 Testing Examples

### Unit Test Example
```swift
import XCTest
@testable import MyApp

class TaskListViewModelTests: XCTestCase {
    var viewModel: TaskListViewModel!

    override func setUp() {
        super.setUp()
        viewModel = TaskListViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testAddTask() {
        let initialCount = viewModel.tasks.count

        viewModel.addTask()

        XCTAssertEqual(viewModel.tasks.count, initialCount + 1)
        XCTAssertEqual(viewModel.tasks.last?.title, "New Task")
        XCTAssertFalse(viewModel.tasks.last?.isCompleted ?? true)
    }

    func testToggleTask() {
        viewModel.addTask()
        let task = viewModel.tasks[0]
        let initialState = task.isCompleted

        viewModel.toggleTask(task)

        XCTAssertNotEqual(viewModel.tasks[0].isCompleted, initialState)
    }
}
```

### UI Test Example
```swift
import XCTest

class MyAppUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launch()
    }

    func testTaskCreation() {
        let addButton = app.buttons["Add Task"]
        XCTAssertTrue(addButton.exists)

        addButton.tap()

        let taskList = app.tables["Task List"]
        XCTAssertTrue(taskList.exists)

        let newTaskCell = taskList.cells.element(boundBy: 0)
        XCTAssertTrue(newTaskCell.exists)
    }

    func testTaskCompletion() {
        // Assuming there's at least one task
        let taskCell = app.tables["Task List"].cells.element(boundBy: 0)
        XCTAssertTrue(taskCell.exists)

        taskCell.tap()

        // Verify task is marked complete
        let completedTask = app.tables["Task List"].cells.element(boundBy: 0)
        XCTAssertTrue(completedTask.exists)
    }
}
```

## 🔧 Automation Script Examples

### Basic Automation Script
```bash
#!/bin/bash

# Basic automation script template
set -euo pipefail

PROJECT_NAME="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z $PROJECT_NAME ]]; then
    echo "Usage: $0 <project_name>"
    exit 1
fi

echo "Running automation for $PROJECT_NAME..."

# Add your automation logic here
echo "✅ Automation completed for $PROJECT_NAME"
```

### Advanced Automation with Error Handling
```bash
#!/bin/bash

# Advanced automation with comprehensive error handling
set -euo pipefail

PROJECT_NAME="${1:-}"
LOG_FILE="/tmp/automation_$(date +%Y%m%d_%H%M%S).log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Validate input
if [[ -z $PROJECT_NAME ]]; then
    error_exit "Project name is required"
fi

log "Starting automation for $PROJECT_NAME"

# Your automation logic here
if your_command_here; then
    log "✅ Automation completed successfully"
else
    error_exit "Automation failed"
fi
```

## 📋 Configuration Examples

### SwiftFormat Configuration (.swiftformat)
```yaml
# SwiftFormat configuration
--indent 4
--maxwidth 120
--wraparguments beforefirst
--wrapparameters beforefirst
--binarygrouping none
--hexgrouping none
--decimalgrouping none
--octalgrouping none
--stripunusedargs closure-only
--disable blankLinesAtStartOfScope,blankLinesAtEndOfScope
```

### SwiftLint Configuration (.swiftlint.yml)
```yaml
disabled_rules:
  - trailing_whitespace
  - vertical_whitespace

opt_in_rules:
  - empty_count
  - force_unwrapping

included:
  - Source

excluded:
  - Carthage
  - Pods
  - Source/ExcludedFolder
  - Source/*/ExcludedFile.swift

line_length: 120
indentation: 4
```

## 🚀 Deployment Examples

### Fastlane Fastfile
```ruby
# Fastfile
default_platform(:ios)

platform :ios do
  desc "Build and deploy to TestFlight"
  lane :beta do
    # Increment build number
    increment_build_number

    # Build the app
    build_app(
      scheme: "MyApp",
      export_method: "app-store"
    )

    # Upload to TestFlight
    upload_to_testflight
  end

  desc "Run tests"
  lane :test do
    run_tests(
      scheme: "MyApp",
      devices: ["iPhone 13"]
    )
  end
end
```

### GitHub Actions Workflow
```yaml
name: CI/CD

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-test:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Set up Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '14.0'

    - name: Build
      run: xcodebuild -scheme MyApp -configuration Release

    - name: Run tests
      run: xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 13'

    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: build-artifacts
        path: build/
```

## 📚 Additional Resources

- [Swift Documentation](https://docs.swift.org)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Xcode Help](https://help.apple.com/xcode)
- [Fastlane Documentation](https://docs.fastlane.tools)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

*Examples are automatically generated and may need adaptation for your specific use case.*
EOF

	print_success "Examples documentation generated: ${examples_index}"
}

# Main function
main() {
	case "${1:-help}" in
	"api")
		if [[ -n ${2-} ]]; then
			setup_directories
			generate_api_docs "$2"
		else
			echo "Usage: $0 api <project_name>"
			exit 1
		fi
		;;
	"tutorial")
		if [[ -n ${2-} ]]; then
			setup_directories
			generate_tutorial "$2"
		else
			echo "Available tutorials: getting_started, ci_cd_setup, developer_tools"
			echo "Usage: $0 tutorial <tutorial_name>"
			exit 1
		fi
		;;
	"examples")
		setup_directories
		generate_examples
		;;
	"all")
		setup_directories
		generate_docs_index

		# Generate API docs for all projects
		for project_dir in "${CODE_DIR}/Projects"/*; do
			if [[ -d ${project_dir} ]]; then
				local project_name
				project_name=$(basename "${project_dir}")
				generate_api_docs "${project_name}" || true
			fi
		done

		# Generate tutorials
		generate_tutorial "getting_started"
		generate_tutorial "ci_cd_setup"
		generate_tutorial "developer_tools"

		# Generate examples
		generate_examples

		print_success "Complete documentation suite generated"
		;;
	"index")
		setup_directories
		generate_docs_index
		;;
	"help" | "-h" | "--help")
		cat <<'EOF'
Enhanced Documentation Automation System

Usage: docs_automation.sh <command> [options]

Commands:
  api <project>        Generate API documentation for a project
  tutorial <name>      Generate a specific tutorial
  examples             Generate code examples documentation
  index                Generate documentation index
  all                  Generate complete documentation suite

Tutorials:
  getting_started      Basic setup and usage tutorial
  ci_cd_setup          CI/CD configuration tutorial
  developer_tools      Developer tools usage tutorial

Examples:
  ./docs_automation.sh api CodingReviewer
  ./docs_automation.sh tutorial getting_started
  ./docs_automation.sh all

Output:
  Documentation is generated in: $CODE_DIR/Documentation/
  - API/           - API reference documentation
  - Tutorials/     - Step-by-step tutorials
  - Guides/        - Detailed guides
  - Examples/      - Code examples and templates

EOF
		;;
	*)
		print_error "Unknown command: ${1-}"
		echo "Use '$0 help' for usage information"
		exit 1
		;;
	esac
}

# Execute main function
main "$@"
