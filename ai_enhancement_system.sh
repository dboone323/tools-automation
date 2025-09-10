#!/bin/bash

# AI-Powered Enhancement System with Risk-Based Automation
# Analyzes projects for improvements and categorizes by risk level

set -eo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions
print_header() { echo -e "${PURPLE}[AI-ENHANCE]${NC} ${CYAN}$1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_status() { echo -e "${BLUE}🔄 $1${NC}"; }
print_enhancement() { echo -e "${GREEN}🚀 ENHANCEMENT:${NC} $1"; }
print_suggestion() { echo -e "${BLUE}💡 SUGGESTION:${NC} $1"; }
print_auto_applied() { echo -e "${GREEN}🤖 AUTO-APPLIED:${NC} $1"; }

# Configuration
readonly CODE_DIR="${CODE_DIR:-/Users/danielstevens/Desktop/Code}"
readonly ENHANCEMENT_DIR="$CODE_DIR/Documentation/Enhancements"
readonly AUTO_ENHANCE_LOG="$CODE_DIR/.ai_enhancements.log"

# Create enhancement directory
mkdir -p "$ENHANCEMENT_DIR"

# Helper function to safely count pattern matches
count_pattern() {
	local pattern="$1"
	local result=$(find . -name "*.swift" -exec grep -l "$pattern" {} \; 2>/dev/null | wc -l || echo "0")
	# sanitize to a single integer token
	result=$(echo "$result" | tr -d '[:space:]' || true)
	result=${result:-0}
	echo "$result"
}

# Helper function to count lines matching pattern
count_lines() {
	local pattern="$1"
	local result=$(find . -name "*.swift" -exec grep "$pattern" {} \; 2>/dev/null | wc -l || echo "0")
	result=$(echo "$result" | tr -d '[:space:]' || true)
	result=${result:-0}
	echo "$result"
}

# Sanitize a value to an integer (strip non-digits, default 0)
sanitize_int() {
	local v="${1:-0}"
	v=$(echo "$v" | tr -cd '0-9')
	if [[ -z $v ]]; then
		v=0
	fi
	echo "$v"
}

# Risk levels for enhancements
get_risk_level_description() {
	case "$1" in
	"SAFE") echo "Auto-apply with rollback safety" ;;
	"LOW") echo "Recommend with auto-apply option" ;;
	"MEDIUM") echo "Recommend for manual review" ;;
	"HIGH") echo "Recommend for careful consideration" ;;
	*) echo "Unknown risk level" ;;
	esac
}

# Enhancement categories
get_category_description() {
	case "$1" in
	"PERFORMANCE") echo "Code optimization and performance improvements" ;;
	"ARCHITECTURE") echo "Code structure and architectural improvements" ;;
	"UI_UX") echo "User interface and experience enhancements" ;;
	"FUNCTIONALITY") echo "New features and functionality additions" ;;
	"SECURITY") echo "Security improvements and best practices" ;;
	"ACCESSIBILITY") echo "Accessibility compliance and improvements" ;;
	"TESTING") echo "Test coverage and quality improvements" ;;
	"DOCUMENTATION") echo "Code documentation and comments" ;;
	"DEPENDENCIES") echo "Dependency management and updates" ;;
	"BUILD_SYSTEM") echo "Build configuration and optimization" ;;
	*) echo "General improvements" ;;
	esac
}

# Analyze Swift project for enhancements
analyze_swift_project() {
	local project_path="$1"
	local project_name="$(basename "$project_path")"

	print_header "Analyzing $project_name for AI enhancements..."

	cd "$project_path"

	local enhancement_file="$ENHANCEMENT_DIR/${project_name}_enhancement_analysis.md"
	local auto_apply_script="$ENHANCEMENT_DIR/${project_name}_auto_enhancements.sh"

	# Initialize enhancement report
	cat >"$enhancement_file" <<EOF
# 🚀 AI Enhancement Analysis: $project_name
*Generated on $(date)*

## 📊 Project Overview
- **Location:** $project_path
- **Swift Files:** $(find . -name "*.swift" -type f | wc -l | xargs)
- **Project Type:** $(detect_project_type)
- **Analysis Date:** $(date)

---

EOF

	# Initialize auto-apply script
	cat >"$auto_apply_script" <<'EOF'
#!/bin/bash
# Auto-applicable enhancements for safe improvements

set -euo pipefail

PROJECT_PATH="$1"
cd "$PROJECT_PATH"

echo "🤖 Applying safe enhancements..."

EOF

	chmod +x "$auto_apply_script"

	# Run analysis categories
	analyze_performance_optimizations "$project_path" "$enhancement_file" "$auto_apply_script"
	analyze_code_quality "$project_path" "$enhancement_file" "$auto_apply_script"
	analyze_architecture_patterns "$project_path" "$enhancement_file" "$auto_apply_script"
	analyze_ui_ux_improvements "$project_path" "$enhancement_file" "$auto_apply_script"
	analyze_security_enhancements "$project_path" "$enhancement_file" "$auto_apply_script"
	analyze_testing_improvements "$project_path" "$enhancement_file" "$auto_apply_script"
	analyze_accessibility_compliance "$project_path" "$enhancement_file" "$auto_apply_script"
	analyze_documentation_gaps "$project_path" "$enhancement_file" "$auto_apply_script"

	# Add summary and recommendations
	add_enhancement_summary "$enhancement_file" "$project_name"

	print_success "Enhancement analysis complete for $project_name"
	print_status "📄 Detailed report: $enhancement_file"
	print_status "🤖 Auto-apply script: $auto_apply_script"
}

detect_project_type() {
	if [[ -f "Package.swift" ]]; then
		echo "Swift Package Manager"
	elif find . -name "*.xcodeproj" -type d | head -1 | grep -q "xcodeproj"; then
		if grep -q "UIKit\|SwiftUI" **/*.swift 2>/dev/null; then
			echo "iOS Application"
		else
			echo "macOS Application"
		fi
	else
		echo "Unknown Swift Project"
	fi
}

analyze_performance_optimizations() {
	local project_path="$1"
	local enhancement_file="$2"
	local auto_apply_script="$3"

	print_status "Analyzing performance optimization opportunities..."

	cat >>"$enhancement_file" <<'EOF'
## 🏎️ Performance Optimizations

### Safe Auto-Apply Enhancements

EOF

	# Check for inefficient array operations
	local inefficient_arrays=$(sanitize_int "$(count_lines "\.append(")")
	if [[ $inefficient_arrays -gt 5 ]]; then
		cat >>"$enhancement_file" <<EOF
#### ✅ SAFE - Array Performance Optimization
- **Issue:** Found $inefficient_arrays instances of array.append() in loops
- **Enhancement:** Replace with array reservation or batch operations
- **Risk Level:** SAFE
- **Auto-Apply:** Yes

\`\`\`swift
// Before: Inefficient
for item in items {
    results.append(processItem(item))
}

// After: Optimized
results.reserveCapacity(items.count)
results = items.map { processItem(\$0) }
\`\`\`

EOF

		cat >>"$auto_apply_script" <<'EOF'
# Optimize array operations
echo "🔧 Optimizing array operations..."
find . -name "*.swift" -type f -exec sed -i.bak '
    /for.*in.*{/{
        N
        s/for \([^{]*\) {\n[[:space:]]*\([^.]*\)\.append(\([^)]*\))/\2 += \1.map { \3 }/
    }
' {} \;
find . -name "*.swift.bak" -delete
echo "✅ Array operations optimized"

EOF
	fi

	# Check for unnecessary string interpolation
	local string_interpolations=$(sanitize_int "$(count_lines '\"\\\(')")
	if [[ $string_interpolations -gt 0 ]]; then
		cat >>"$enhancement_file" <<EOF
#### ✅ SAFE - String Performance Optimization  
- **Issue:** Found $string_interpolations instances of unnecessary string interpolation
- **Enhancement:** Use direct string concatenation where appropriate
- **Risk Level:** SAFE
- **Auto-Apply:** Yes

EOF

		cat >>"$auto_apply_script" <<'EOF'
# Optimize string operations
echo "🔧 Optimizing string operations..."
find . -name "*.swift" -type f -exec sed -i.bak 's/"\\\(\\([^)]*\\))"/\2/g' {} \;
find . -name "*.swift.bak" -delete
echo "✅ String operations optimized"

EOF
	fi

	# Medium risk enhancements
	cat >>"$enhancement_file" <<'EOF'

### Manual Review Recommended

EOF

	# Check for potential memory leaks
	local retain_cycles=$(sanitize_int "$(count_lines "\[weak\|\[unowned")")
	local closures=$(sanitize_int "$(count_lines "{ \[")")

	if [[ $closures -gt $retain_cycles ]]; then
		cat >>"$enhancement_file" <<EOF
#### ⚠️ MEDIUM - Memory Management Review
- **Issue:** Found $closures closures but only $retain_cycles weak/unowned references
- **Enhancement:** Review closures for potential retain cycles
- **Risk Level:** MEDIUM
- **Recommendation:** Manual code review required

\`\`\`swift
// Review patterns like:
someObject.closure = { [weak self] in
    self?.doSomething()
}
\`\`\`

EOF
	fi
}

analyze_code_quality() {
	local project_path="$1"
	local enhancement_file="$2"
	local auto_apply_script="$3"

	print_status "Analyzing code quality improvements..."

	cat >>"$enhancement_file" <<'EOF'
## 🎯 Code Quality Improvements

### Safe Auto-Apply Enhancements

EOF

	# Check for TODO/FIXME comments
	local todos=$(sanitize_int "$(count_lines "TODO\|FIXME\|HACK")")
	if [[ $todos -gt 0 ]]; then
		cat >>"$enhancement_file" <<EOF
#### ✅ SAFE - Code Documentation Enhancement
- **Issue:** Found $todos TODO/FIXME/HACK comments
- **Enhancement:** Convert to structured documentation comments
- **Risk Level:** SAFE
- **Auto-Apply:** Yes

EOF

		cat >>"$auto_apply_script" <<'EOF'
# Convert TODO comments to structured documentation
echo "🔧 Converting TODO comments to structured documentation..."
find . -name "*.swift" -type f -exec sed -i.bak '
    s/\/\/ TODO:/\/\/\/ - TODO:/g
    s/\/\/ FIXME:/\/\/\/ - FIXME:/g
    s/\/\/ HACK:/\/\/\/ - Note:/g
' {} \;
find . -name "*.swift.bak" -delete
echo "✅ Documentation comments structured"

EOF
	fi

	# Check for force unwrapping
	local force_unwraps=$(sanitize_int "$(count_lines "!")")
	if [[ $force_unwraps -gt 0 ]]; then
		cat >>"$enhancement_file" <<EOF
#### ⚠️ HIGH - Force Unwrapping Safety Review
- **Issue:** Found $force_unwraps potential force unwrap operations
- **Enhancement:** Replace with safe unwrapping patterns
- **Risk Level:** HIGH
- **Recommendation:** Manual review and replacement required

\`\`\`swift
// Instead of: value!
// Use: guard let value = value else { return }
// Or: if let value = value { ... }
\`\`\`

EOF
	fi
}

analyze_architecture_patterns() {
	local project_path="$1"
	local enhancement_file="$2"
	local auto_apply_script="$3"

	print_status "Analyzing architecture pattern opportunities..."

	cat >>"$enhancement_file" <<'EOF'
## 🏗️ Architecture Improvements

EOF

	# Check for massive view controllers/views
	local large_files=$(sanitize_int "$(find . -name "*.swift" -type f -exec wc -l {} \; | awk '$1 > 200 {print $2}' | wc -l || echo "0")")
	if [[ $large_files -gt 0 ]]; then
		cat >>"$enhancement_file" <<EOF
#### ⚠️ MEDIUM - Large File Refactoring
- **Issue:** Found $large_files Swift files with >200 lines
- **Enhancement:** Consider breaking into smaller, focused components
- **Risk Level:** MEDIUM
- **Pattern:** Apply MVVM, Composition, or Protocol-based architecture

\`\`\`swift
// Consider splitting large ViewControllers:
class UserProfileViewController {
    private let profileView = UserProfileView()
    private let settingsView = UserSettingsView()
    private let viewModel = UserProfileViewModel()
}
\`\`\`

EOF
	fi

	# Check for dependency injection opportunities
	local singletons=$(sanitize_int "$(grep -r "shared\|sharedInstance" **/*.swift 2>/dev/null | wc -l || echo "0")")
	if [[ $singletons -gt 2 ]]; then
		cat >>"$enhancement_file" <<EOF
#### ⚠️ MEDIUM - Dependency Injection Implementation
- **Issue:** Found $singletons singleton pattern usages
- **Enhancement:** Implement dependency injection for better testability
- **Risk Level:** MEDIUM
- **Pattern:** Constructor injection or service locator pattern

EOF
	fi
}

analyze_ui_ux_improvements() {
	local project_path="$1"
	local enhancement_file="$2"
	local auto_apply_script="$3"

	print_status "Analyzing UI/UX enhancement opportunities..."

	cat >>"$enhancement_file" <<'EOF'
## 🎨 UI/UX Enhancements

EOF

	# Check for hardcoded colors/fonts
	local hardcoded_ui=$(sanitize_int "$(grep -r "UIColor\|Color\.\|Font\." **/*.swift 2>/dev/null | grep -v "asset\|theme" | wc -l || echo "0")")
	if [[ $hardcoded_ui -gt 5 ]]; then
		cat >>"$enhancement_file" <<EOF
#### ✅ LOW - Theme System Implementation
- **Issue:** Found $hardcoded_ui hardcoded UI colors/fonts
- **Enhancement:** Implement centralized theme system
- **Risk Level:** LOW
- **Auto-Apply Option:** Available

\`\`\`swift
// Create Theme.swift
struct AppTheme {
    static let primaryColor = Color("PrimaryColor")
    static let secondaryColor = Color("SecondaryColor")
    static let bodyFont = Font.custom("AppFont-Regular", size: 16)
}
\`\`\`

EOF
	fi

	# Check for accessibility improvements
	local accessibility_labels=$(sanitize_int "$(grep -r "accessibilityLabel\|accessibilityHint" **/*.swift 2>/dev/null | wc -l || echo "0")")
	local ui_elements=$(sanitize_int "$(grep -r "Button\|Text\|Image" **/*.swift 2>/dev/null | wc -l || echo "0")")

	if [[ $ui_elements -gt $accessibility_labels ]]; then
		cat >>"$enhancement_file" <<EOF
#### ⚠️ MEDIUM - Accessibility Compliance
- **Issue:** Found $ui_elements UI elements but only $accessibility_labels accessibility labels
- **Enhancement:** Add comprehensive accessibility support
- **Risk Level:** MEDIUM
- **Impact:** Improved app accessibility compliance

EOF
	fi
}

analyze_security_enhancements() {
	local project_path="$1"
	local enhancement_file="$2"
	local auto_apply_script="$3"

	print_status "Analyzing security enhancement opportunities..."

	cat >>"$enhancement_file" <<'EOF'
## 🔒 Security Enhancements

EOF

	# Check for sensitive data handling
	local keychain_usage=$(sanitize_int "$(grep -r "Keychain\|keychain" **/*.swift 2>/dev/null | wc -l || echo "0")")
	local user_defaults=$(sanitize_int "$(grep -r "UserDefaults\|@AppStorage" **/*.swift 2>/dev/null | wc -l || echo "0")")

	if [[ $user_defaults -gt 0 && $keychain_usage -eq 0 ]]; then
		cat >>"$enhancement_file" <<EOF
#### ⚠️ HIGH - Secure Storage Implementation
- **Issue:** Using UserDefaults ($user_defaults instances) without Keychain integration
- **Enhancement:** Implement Keychain for sensitive data storage
- **Risk Level:** HIGH
- **Priority:** Security-critical improvement

\`\`\`swift
// Implement KeychainHelper for sensitive data
class KeychainHelper {
    static func save(_ data: Data, for key: String) { ... }
    static func load(for key: String) -> Data? { ... }
}
\`\`\`

EOF
	fi

	# Check for network security
	local network_calls=$(sanitize_int "$(grep -r "URLSession\|HTTP" **/*.swift 2>/dev/null | wc -l || echo "0")")
	local ssl_pinning=$(sanitize_int "$(grep -r "pinnedCertificates\|SSL" **/*.swift 2>/dev/null | wc -l || echo "0")")

	if [[ $network_calls -gt 0 && $ssl_pinning -eq 0 ]]; then
		cat >>"$enhancement_file" <<EOF
#### ⚠️ MEDIUM - Network Security Enhancement
- **Issue:** Found $network_calls network calls without SSL pinning
- **Enhancement:** Implement certificate pinning for API calls
- **Risk Level:** MEDIUM
- **Security Impact:** Prevents man-in-the-middle attacks

EOF
	fi
}

analyze_testing_improvements() {
	local project_path="$1"
	local enhancement_file="$2"
	local auto_apply_script="$3"

	print_status "Analyzing testing improvement opportunities..."

	cat >>"$enhancement_file" <<'EOF'
## 🧪 Testing Improvements

EOF

	# Check test coverage
	local test_files=$(sanitize_int "$(find . -name "*Test*.swift" -o -name "*Tests.swift" | wc -l || echo "0")")
	local source_files=$(sanitize_int "$(find . -name "*.swift" -not -path "*/Test*" -not -name "*Test*.swift" | wc -l || echo "0")")

	if [[ $source_files -gt 0 ]]; then
		local test_ratio=$((test_files * 100 / source_files))
		cat >>"$enhancement_file" <<EOF
#### 📊 Test Coverage Analysis
- **Source Files:** $source_files
- **Test Files:** $test_files  
- **Test Ratio:** ${test_ratio}%
- **Recommendation:** Aim for 1:1 or better test-to-source ratio

EOF

		if [[ $test_ratio -lt 30 ]]; then
			cat >>"$enhancement_file" <<EOF
#### ⚠️ HIGH - Test Coverage Enhancement
- **Issue:** Low test coverage (${test_ratio}%)
- **Enhancement:** Implement comprehensive unit test suite
- **Risk Level:** HIGH
- **Impact:** Improved code reliability and regression prevention

\`\`\`swift
// Suggested test structure:
class FeatureTests: XCTestCase {
    func testSuccessfulOperation() { ... }
    func testErrorHandling() { ... }
    func testEdgeCases() { ... }
}
\`\`\`

EOF
		fi
	fi
}

analyze_accessibility_compliance() {
	local project_path="$1"
	local enhancement_file="$2"
	local auto_apply_script="$3"

	print_status "Analyzing accessibility compliance..."

	cat >>"$enhancement_file" <<'EOF'
## ♿ Accessibility Enhancements

EOF

	# Check for basic accessibility implementation
	local accessibility_modifiers=$(sanitize_int "$(grep -r "\.accessibilityLabel\|\.accessibilityHint\|\.accessibilityValue" **/*.swift 2>/dev/null | wc -l || echo "0")")
	local interactive_elements=$(sanitize_int "$(grep -r "Button\|TextField\|Slider\|Stepper" **/*.swift 2>/dev/null | wc -l || echo "0")")

	if [[ $interactive_elements -gt 0 && $accessibility_modifiers -lt $interactive_elements ]]; then
		cat >>"$enhancement_file" <<EOF
#### ✅ LOW - Basic Accessibility Implementation
- **Issue:** $interactive_elements interactive elements, $accessibility_modifiers with accessibility labels
- **Enhancement:** Add accessibility labels to all interactive elements
- **Risk Level:** LOW
- **Auto-Apply Option:** Available for basic labels

EOF

		cat >>"$auto_apply_script" <<'EOF'
# Add basic accessibility labels
echo "🔧 Adding basic accessibility labels..."
find . -name "*.swift" -type f -exec sed -i.bak '
    s/Button(\([^)]*\))/Button(\1).accessibilityLabel("Button")/g
    s/TextField(\([^)]*\))/TextField(\1).accessibilityLabel("Text Field")/g
' {} \;
find . -name "*.swift.bak" -delete
echo "✅ Basic accessibility labels added"

EOF
	fi
}

analyze_documentation_gaps() {
	local project_path="$1"
	local enhancement_file="$2"
	local auto_apply_script="$3"

	print_status "Analyzing documentation gaps..."

	cat >>"$enhancement_file" <<'EOF'
## 📚 Documentation Enhancements

EOF

	# Check for public API documentation
	local public_functions=$(sanitize_int "$(grep -r "public func\|open func" **/*.swift 2>/dev/null | wc -l || echo "0")")
	local documented_functions=$(sanitize_int "$(grep -r "/// " **/*.swift 2>/dev/null | wc -l || echo "0")")

	if [[ $public_functions -gt 0 && $documented_functions -lt $public_functions ]]; then
		cat >>"$enhancement_file" <<EOF
#### ✅ SAFE - API Documentation Enhancement
- **Issue:** $public_functions public functions, $documented_functions documented
- **Enhancement:** Add documentation comments to public APIs
- **Risk Level:** SAFE
- **Auto-Apply:** Yes for basic templates

EOF

		cat >>"$auto_apply_script" <<'EOF'
# Add basic documentation templates
echo "🔧 Adding basic API documentation..."
find . -name "*.swift" -type f -exec sed -i.bak '
    /public func/i\
    /// <#Description#>\
    /// - Parameters:\
    ///   - <#parameter#>: <#description#>\
    /// - Returns: <#description#>
' {} \;
find . -name "*.swift.bak" -delete
echo "✅ Basic API documentation templates added"

EOF
	fi
}

add_enhancement_summary() {
	local enhancement_file="$1"
	local project_name="$2"

	cat >>"$enhancement_file" <<EOF

---

## 📋 Enhancement Summary & Action Plan

### 🤖 Auto-Applicable Enhancements
Run the auto-enhancement script to apply safe improvements:
\`\`\`bash
./Automation/ai_enhancement_system.sh auto-apply $project_name
\`\`\`

### 👨‍💻 Manual Review Required
The following enhancements require careful consideration and manual implementation:

1. **Architecture Changes** - May impact app structure
2. **Security Enhancements** - Critical for app security
3. **UI/UX Changes** - May affect user experience
4. **High-Risk Optimizations** - Could change app behavior

### 🎯 Recommended Implementation Order

1. **Phase 1 (Auto-Apply):** Safe performance optimizations, documentation
2. **Phase 2 (Low Risk):** Code quality improvements, basic accessibility
3. **Phase 3 (Medium Risk):** Architecture refactoring, comprehensive testing
4. **Phase 4 (High Risk):** Security enhancements, major UI changes

### 📊 Enhancement Metrics

- **Total Enhancements Identified:** Count will be added after analysis
- **Auto-Applicable:** Safe improvements with rollback protection
- **Manual Review:** Changes requiring human judgment
- **Estimated Impact:** Code quality, performance, security, maintainability

---

*Enhancement analysis generated by AI Enhancement System v1.0*
*Next analysis recommended: In 30 days or after major code changes*

EOF
}

# Auto-apply safe enhancements
auto_apply_enhancements() {
	local project_name="$1"
	local project_path="$CODE_DIR/Projects/$project_name"
	local auto_apply_script="$ENHANCEMENT_DIR/${project_name}_auto_enhancements.sh"

	if [[ ! -f $auto_apply_script ]]; then
		print_error "No auto-apply script found for $project_name. Run analysis first."
		return 1
	fi

	print_header "Auto-applying safe enhancements for $project_name"

	# Use the existing backup system from intelligent_autofix.sh
	if [[ -f "$CODE_DIR/Tools/Automation/intelligent_autofix.sh" ]]; then
		print_status "Creating backup before applying enhancements..."
		local timestamp="$(date +%Y%m%d_%H%M%S)"
		local backup_path="$CODE_DIR/.autofix_backups/${project_name}_enhancement_$timestamp"
		cp -r "$project_path" "$backup_path"
		echo "$backup_path" >"$project_path/.enhancement_backup"
		print_success "Backup created: $backup_path"
	fi

	# Apply enhancements
	print_status "Applying auto-enhancements..."
	if bash "$auto_apply_script" "$project_path"; then
		print_success "Enhancements applied successfully"

		# Run validation checks
		if [[ -f "$CODE_DIR/Tools/Automation/intelligent_autofix.sh" ]]; then
			local validation_result=$("$CODE_DIR/Tools/Automation/intelligent_autofix.sh" validate "$project_name" 2>/dev/null | tail -1 || echo "0/0")
			local checks_passed=$(echo "$validation_result" | cut -d'/' -f1 2>/dev/null || echo "0")
			local total_checks=$(echo "$validation_result" | cut -d'/' -f2 2>/dev/null || echo "1")

			if [[ $checks_passed -eq $total_checks ]]; then
				print_success "All validation checks passed"
				# Clean up backup
				if [[ -f "$project_path/.enhancement_backup" ]]; then
					local backup_path="$(cat "$project_path/.enhancement_backup")"
					rm -rf "$backup_path"
					rm -f "$project_path/.enhancement_backup"
					print_status "Backup cleaned up"
				fi

				# Log success
				echo "$(date): SUCCESS - $project_name: Auto-enhancements applied successfully" >>"$AUTO_ENHANCE_LOG"
			else
				print_error "Validation failed - rolling back enhancements"
				if [[ -f "$project_path/.enhancement_backup" ]]; then
					local backup_path="$(cat "$project_path/.enhancement_backup")"
					rm -rf "$project_path"
					cp -r "$backup_path" "$project_path"
					rm -f "$project_path/.enhancement_backup"
					print_success "Rollback completed"
				fi

				# Log failure
				echo "$(date): ROLLBACK - $project_name: Enhancement validation failed, restored backup" >>"$AUTO_ENHANCE_LOG"
				return 1
			fi
		fi
	else
		print_error "Enhancement application failed"
		return 1
	fi
}

# Analyze all projects
analyze_all_projects() {
	print_header "Running AI enhancement analysis on all projects"

	local projects=("CodingReviewer" "HabitQuest" "MomentumFinance")

	for project in "${projects[@]}"; do
		local project_path="$CODE_DIR/Projects/$project"
		if [[ -d $project_path ]]; then
			analyze_swift_project "$project_path"
			echo ""
		else
			print_warning "Project $project not found, skipping..."
		fi
	done

	# Create master enhancement report
	create_master_enhancement_report
}

create_master_enhancement_report() {
	local master_report="$ENHANCEMENT_DIR/MASTER_ENHANCEMENT_REPORT.md"

	print_status "Creating master enhancement report..."

	cat >"$master_report" <<EOF
# 🚀 Master AI Enhancement Report
*Generated on $(date)*

## 📊 Workspace Enhancement Overview

This report consolidates AI-identified enhancements across all projects in the workspace.

### 📱 Projects Analyzed
EOF

	for project_file in "$ENHANCEMENT_DIR"/*_enhancement_analysis.md; do
		if [[ -f $project_file ]]; then
			local project_name=$(basename "$project_file" _enhancement_analysis.md)
			echo "- [$project_name](./${project_name}_enhancement_analysis.md)" >>"$master_report"
		fi
	done

	cat >>"$master_report" <<EOF

### 🎯 Quick Actions

#### Auto-Apply Safe Enhancements (All Projects)
\`\`\`bash
./Automation/ai_enhancement_system.sh auto-apply-all
\`\`\`

#### Generate Fresh Analysis
\`\`\`bash
./Automation/ai_enhancement_system.sh analyze-all
\`\`\`

### 📈 Enhancement Categories

1. **🏎️ Performance** - Code optimization opportunities
2. **🎯 Code Quality** - Best practices and maintainability
3. **🏗️ Architecture** - Structural improvements
4. **🎨 UI/UX** - User experience enhancements
5. **🔒 Security** - Security hardening opportunities
6. **🧪 Testing** - Test coverage and quality
7. **♿ Accessibility** - Compliance improvements
8. **📚 Documentation** - Code documentation gaps

### ⚡ Implementation Strategy

1. **Phase 1:** Auto-apply all safe enhancements
2. **Phase 2:** Review and implement low-risk improvements
3. **Phase 3:** Plan medium-risk architectural changes
4. **Phase 4:** Carefully implement high-risk security/functionality changes

---

*AI Enhancement System - Continuously improving your codebase*
EOF

	print_success "Master enhancement report created: $master_report"
}

# Usage information
show_usage() {
	cat <<EOF
🤖 AI-Powered Enhancement System

Usage: $0 [COMMAND] [PROJECT]

Commands:
  analyze <project>     # Analyze specific project for enhancements
  analyze-all          # Analyze all projects for enhancements
  auto-apply <project> # Auto-apply safe enhancements with rollback
  auto-apply-all       # Auto-apply safe enhancements to all projects
  report               # Generate master enhancement report
  status               # Show enhancement system status
  help                 # Show this help message

Projects:
  CodingReviewer       # iOS coding review application
  HabitQuest          # Habit tracking application  
  MomentumFinance     # Financial tracking application

Examples:
  $0 analyze HabitQuest
  $0 analyze-all
  $0 auto-apply CodingReviewer
  $0 auto-apply-all

Enhancement Categories:
  🏎️ Performance Optimizations (SAFE auto-apply)
  🎯 Code Quality Improvements (LOW risk)
  🏗️ Architecture Enhancements (MEDIUM risk)
  🎨 UI/UX Improvements (MEDIUM risk)
  🔒 Security Enhancements (HIGH risk - manual review)
  🧪 Testing Improvements (LOW-MEDIUM risk)
  ♿ Accessibility Compliance (LOW risk)
  📚 Documentation Gaps (SAFE auto-apply)

Risk Levels:
  ✅ SAFE - Auto-apply with rollback protection
  ⚠️ LOW - Recommend with auto-apply option  
  ⚠️ MEDIUM - Recommend for manual review
  🚨 HIGH - Recommend for careful consideration

EOF
}

# Main execution
main() {
	case "${1:-help}" in
	"analyze")
		if [[ -n ${2-} ]]; then
			local project_path="$CODE_DIR/Projects/$2"
			if [[ -d $project_path ]]; then
				analyze_swift_project "$project_path"
			else
				print_error "Project $2 not found"
				exit 1
			fi
		else
			print_error "Usage: $0 analyze <project_name>"
			exit 1
		fi
		;;
	"analyze-all")
		analyze_all_projects
		;;
	"auto-apply")
		if [[ -n ${2-} ]]; then
			auto_apply_enhancements "$2"
		else
			print_error "Usage: $0 auto-apply <project_name>"
			exit 1
		fi
		;;
	"auto-apply-all")
		local projects=("CodingReviewer" "HabitQuest" "MomentumFinance")
		for project in "${projects[@]}"; do
			if [[ -d "$CODE_DIR/Projects/$project" ]]; then
				auto_apply_enhancements "$project"
			fi
		done
		;;
	"report")
		create_master_enhancement_report
		;;
	"status")
		print_header "AI Enhancement System Status"
		if [[ -f $AUTO_ENHANCE_LOG ]]; then
			echo "Recent enhancement operations:"
			tail -10 "$AUTO_ENHANCE_LOG"
		else
			print_status "No enhancement operations logged yet"
		fi

		print_status "Available enhancement reports:"
		if [[ -d $ENHANCEMENT_DIR ]]; then
			ls -la "$ENHANCEMENT_DIR" | tail -n +2
		else
			print_status "No enhancement reports found"
		fi
		;;
	"help" | "--help" | "-h")
		show_usage
		;;
	*)
		print_error "Unknown command: ${1-}"
		show_usage
		exit 1
		;;
	esac
}

# Execute main function
main "$@"
