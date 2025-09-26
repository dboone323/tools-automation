#!/bin/bash

# AI-Enhanced Master Automation Controller
# Integrates Ollama AI across all workspace operations
# Enhanced by Ollama v0.12 with cloud model support

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_DIR="${CODE_DIR}/Projects"
SHARED_DIR="${CODE_DIR}/Shared"
TOOLS_DIR="${CODE_DIR}/Tools"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_status() {
	echo -e "${BLUE}[AI-AUTOMATION]${NC} $1"
}

print_success() {
	echo -e "${GREEN}[AI-SUCCESS]${NC} $1"
}

print_warning() {
	echo -e "${YELLOW}[AI-WARNING]${NC} $1"
}

print_error() {
	echo -e "${RED}[AI-ERROR]${NC} $1"
}

print_ai() {
	echo -e "${PURPLE}[🤖 OLLAMA]${NC} $1"
}

# Check Ollama connectivity and model availability
check_ollama_health() {
	print_ai "Checking Ollama health and available models..."

	if ! command -v ollama &>/dev/null; then
		print_error "Ollama not found. Please install Ollama v0.12+"
		return 1
	fi

	local version=$(ollama --version 2>/dev/null | grep -o 'ollama version is [0-9.]*' | cut -d' ' -f4)
	print_ai "Ollama version: ${version}"

	# Check server connectivity
	if ! ollama list &>/dev/null; then
		print_error "Ollama server not running. Starting..."
		ollama serve &
		sleep 5
	fi

	# List available models
	print_ai "Available models:"
	ollama list | grep -E "(NAME|cloud)" || true

	# Ensure key models are available
	local required_models=("qwen3-coder:480b-cloud" "codellama:7b")
	for model in "${required_models[@]}"; do
		if ! ollama list | grep -q "${model}"; then
			print_warning "Model ${model} not found. Attempting to pull..."
			if [[ ${model} == *"-cloud" ]]; then
				# Cloud models are pulled on first use
				print_ai "Cloud model ${model} will be pulled on first use"
			else
				ollama pull "${model}" || print_warning "Failed to pull ${model}"
			fi
		fi
	done

	return 0
}

# AI-powered project analysis
analyze_project_with_ai() {
	local project_name="$1"
	local project_path="${PROJECTS_DIR}/${project_name}"

	if [[ ! -d ${project_path} ]]; then
		print_error "Project ${project_name} not found"
		return 1
	fi

	print_ai "Analyzing project ${project_name} with AI..."

	# Count files and gather metrics
	local swift_files=$(find "${project_path}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
	local total_lines=$(find "${project_path}" -name "*.swift" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")

	# Create analysis prompt
	local analysis_prompt="Analyze this Swift project structure and provide recommendations:
Project: ${project_name}
Swift files: ${swift_files}
Total lines: ${total_lines}
Directory structure:
$(find "${project_path}" -type f -name "*.swift" | head -20 | sed 's|.*/||')

Provide:
1. Architecture assessment
2. Potential improvements
3. AI integration opportunities
4. Performance optimization suggestions
5. Testing strategy recommendations"

	# Generate AI analysis
	local ai_analysis=$(echo "${analysis_prompt}" | ollama run qwen3-coder:480b-cloud 2>/dev/null || echo "AI analysis temporarily unavailable")

	# Save analysis
	local analysis_file="${project_path}/AI_ANALYSIS_$(date +%Y%m%d).md"
	echo "# AI Analysis for ${project_name}" >"${analysis_file}"
	echo "Generated: $(date)" >>"${analysis_file}"
	echo "" >>"${analysis_file}"
	echo "${ai_analysis}" >>"${analysis_file}"

	print_success "AI analysis saved to ${analysis_file}"

	# Extract actionable items with AI
	local improvements_prompt="Extract 3 specific, actionable improvements from this analysis that can be implemented immediately:
${ai_analysis}

Format as:
1. [Action]: [Description]
2. [Action]: [Description]
3. [Action]: [Description]"

	local improvements=$(echo "${improvements_prompt}" | ollama run qwen3-coder:480b-cloud 2>/dev/null || echo "Improvements extraction unavailable")

	echo "" >>"${analysis_file}"
	echo "## Immediate Action Items" >>"${analysis_file}"
	echo "${improvements}" >>"${analysis_file}"

	print_ai "Project analysis complete with actionable recommendations"
}

# AI-powered code generation for missing components
generate_missing_components() {
	local project_name="$1"
	local project_path="${PROJECTS_DIR}/${project_name}"

	print_ai "Generating missing components for ${project_name}..."

	# Check for common missing patterns
	local missing_components=()

	# Check for tests
	if [[ ! -d "${project_path}"/*Tests* ]] && [[ ! -d "${project_path}"/Tests ]]; then
		missing_components+=("tests")
	fi

	# Check for documentation
	if [[ ! -f "${project_path}/README.md" ]]; then
		missing_components+=("documentation")
	fi

	# Check for CI/CD
	if [[ ! -d "${project_path}/.github/workflows" ]] || [[ -z $(find "${project_path}/.github/workflows" -name "*.yml" -o -name "*.yaml" | head -1) ]]; then
		missing_components+=("ci_cd")
	fi

	# Generate missing components with AI
	for component in "${missing_components[@]}"; do
		case ${component} in
		"tests")
			generate_test_files "${project_name}" "${project_path}"
			;;
		"documentation")
			generate_project_documentation "${project_name}" "${project_path}"
			;;
		"ci_cd")
			generate_ci_cd_config "${project_name}" "${project_path}"
			;;
		esac
	done
}

# AI-powered test generation
generate_test_files() {
	local project_name="$1"
	local project_path="$2"

	print_ai "Generating test files for ${project_name}..."

	# Find main Swift files
	local main_files=$(find "${project_path}" -name "*.swift" -not -path "*/Tests/*" | head -5)

	for file in ${main_files}; do
		if [[ -f ${file} ]]; then
			local filename=$(basename "${file}" .swift)
			local test_content=$(cat "${file}")

			# Generate test with AI
			local test_prompt="Generate comprehensive XCTest unit tests for this Swift code:

${test_content}

Include:
1. Test class with proper setup/teardown
2. Tests for all public methods
3. Edge cases and error handling
4. Mock data where appropriate
5. Performance tests if relevant

Use XCTest framework and Swift testing best practices."

			local generated_tests=$(echo "${test_prompt}" | ollama run qwen3-coder:480b-cloud 2>/dev/null || echo "// Test generation temporarily unavailable")

			# Create test directory and file
			local test_dir="${project_path}/Tests"
			mkdir -p "${test_dir}"

			local test_file="${test_dir}/${filename}Tests.swift"
			echo "// Generated by AI-Enhanced Automation" >"${test_file}"
			echo "// $(date)" >>"${test_file}"
			echo "" >>"${test_file}"
			echo "${generated_tests}" >>"${test_file}"

			print_success "Generated tests: ${test_file}"
		fi
	done
}

# AI-powered documentation generation
generate_project_documentation() {
	local project_name="$1"
	local project_path="$2"

	print_ai "Generating documentation for ${project_name}..."

	# Analyze project structure
	local swift_files=$(find "${project_path}" -name "*.swift" | head -10)
	local project_structure=""

	for file in ${swift_files}; do
		local relative_path=${file#"${project_path}"/}
		project_structure="${project_structure}\n- ${relative_path}"
	done

	# Generate documentation with AI
	local doc_prompt="Generate comprehensive README.md documentation for this Swift project:

Project Name: ${project_name}
Files:${project_structure}

Include:
1. Project overview and purpose
2. Features list
3. Installation instructions
4. Usage examples
5. Architecture overview
6. Contributing guidelines
7. License information

Make it professional and comprehensive."

	local generated_docs=$(echo "${doc_prompt}" | ollama run gpt-oss:120b-cloud 2>/dev/null || echo "Documentation generation temporarily unavailable")

	local readme_file="${project_path}/README.md"
	echo "# ${project_name}" >"${readme_file}"
	echo "" >>"${readme_file}"
	echo "${generated_docs}" >>"${readme_file}"
	echo "" >>"${readme_file}"
	echo "---" >>"${readme_file}"
	echo "*Documentation generated by AI-Enhanced Automation*" >>"${readme_file}"

	print_success "Generated documentation: ${readme_file}"
}

# AI-powered CI/CD configuration generation
generate_ci_cd_config() {
	local project_name="$1"
	local project_path="$2"

	print_ai "Generating CI/CD configuration for ${project_name}..."

	# Check if CI/CD already exists
	local workflows_dir="${project_path}/.github/workflows"
	if [[ -d ${workflows_dir} ]] && [[ $(find "${workflows_dir}" -name "*.yml" -o -name "*.yaml" | wc -l) -gt 0 ]]; then
		print_warning "CI/CD configuration already exists for ${project_name}, skipping generation"
		return 0
	fi

	# Create .github/workflows directory
	mkdir -p "${workflows_dir}"

	# Generate GitHub Actions workflow
	local workflow_prompt="Generate a comprehensive GitHub Actions CI/CD workflow for this Swift project:

Project: ${project_name}
Type: iOS/macOS Swift application
Tools: Xcode, SwiftLint, SwiftFormat, Ollama (optional)

Include:
1. Build and test on multiple macOS versions
2. Code quality checks (SwiftLint, SwiftFormat)
3. Test execution with coverage reporting
4. Artifact generation and deployment preparation
5. AI-enhanced analysis integration (if Ollama available)
6. Performance benchmarking
7. Security scanning
8. Automated dependency updates

Make it production-ready with proper error handling and notifications."

	local generated_workflow=$(echo "${workflow_prompt}" | ollama run qwen3-coder:480b-cloud 2>/dev/null || echo "# CI/CD workflow generation temporarily unavailable
name: CI/CD Pipeline
on: [push, pull_request]
jobs:
  build-and-test:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - name: Set up Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable
    - name: Build and Test
      run: xcodebuild -project ${project_name}.xcodeproj -scheme ${project_name} -destination 'platform=iOS Simulator,name=iPhone 14' build test")

	local workflow_file="${workflows_dir}/ci.yml"
	echo "# Generated by AI-Enhanced Automation" >"${workflow_file}"
	echo "# $(date)" >>"${workflow_file}"
	echo "" >>"${workflow_file}"
	echo "${generated_workflow}" >>"${workflow_file}"

	# Generate Fastlane configuration if not exists
	if [[ ! -d "${project_path}/fastlane" ]]; then
		mkdir -p "${project_path}/fastlane"

		local fastfile_content="# Generated by AI-Enhanced Automation
# $(date)

platform :ios do
  desc 'Run tests'
  lane :test do
    run_tests(
      project: '${project_name}.xcodeproj',
      scheme: '${project_name}',
      clean: true,
      code_coverage: true
    )
  end

  desc 'Build for development'
  lane :build_dev do
    build_ios_app(
      project: '${project_name}.xcodeproj',
      scheme: '${project_name}',
      configuration: 'Debug',
      clean: true
    )
  end

  desc 'Build for release'
  lane :build_release do
    build_ios_app(
      project: '${project_name}.xcodeproj',
      scheme: '${project_name}',
      configuration: 'Release',
      clean: true,
      export_method: 'app-store'
    )
  end
end"

		echo "${fastfile_content}" >"${project_path}/fastlane/Fastfile"
		print_success "Generated Fastlane configuration: ${project_path}/fastlane/Fastfile"
	fi

	print_success "Generated CI/CD configuration: ${workflow_file}"
}

# AI-powered code review
perform_ai_code_review() {
	local project_name="$1"
	local project_path="${PROJECTS_DIR}/${project_name}"

	print_ai "Performing AI code review for ${project_name}..."

	# Find recent changes or all Swift files
	local files_to_review=$(find "${project_path}" -name "*.swift" | head -10)
	local review_results=""

	for file in ${files_to_review}; do
		if [[ -f ${file} ]]; then
			local file_content=$(head -50 "${file}") # Review first 50 lines
			local filename=$(basename "${file}")

			local review_prompt="Perform a code review for this Swift file:

File: ${filename}
Code:
${file_content}

Analyze for:
1. Code quality issues
2. Performance problems
3. Security vulnerabilities
4. Swift best practices violations
5. Architectural concerns
6. Documentation needs

Provide specific, actionable feedback."

			local file_review=$(echo "${review_prompt}" | ollama run deepseek-v3.1:671b-cloud 2>/dev/null || echo "Review temporarily unavailable")

			review_results="${review_results}\n\n## ${filename}\n${file_review}"
		fi
	done

	# Save review results
	local review_file="${project_path}/AI_CODE_REVIEW_$(date +%Y%m%d).md"
	echo "# AI Code Review for ${project_name}" >"${review_file}"
	echo "Generated: $(date)" >>"${review_file}"
	echo -e "${review_results}" >>"${review_file}"

	print_success "AI code review saved to ${review_file}"
}

# AI-powered performance optimization
optimize_project_performance() {
	local project_name="$1"
	local project_path="${PROJECTS_DIR}/${project_name}"

	print_ai "Analyzing performance optimization opportunities for ${project_name}..."

	# Find files with potential performance issues
	local performance_files=$(grep -r -l "for.*in\|while\|repeat\|\.map\|\.filter\|\.reduce" "${project_path}"/*.swift 2>/dev/null | head -5)

	local optimization_report=""

	for file in ${performance_files}; do
		if [[ -f ${file} ]]; then
			local file_content=$(cat "${file}")
			local filename=$(basename "${file}")

			local optimization_prompt="Analyze this Swift code for performance optimizations:

File: ${filename}
Code:
${file_content}

Identify:
1. Algorithm complexity issues
2. Memory usage problems
3. Unnecessary computations
4. Collection operation optimizations
5. Threading opportunities
6. Caching possibilities

Provide specific optimization suggestions with code examples."

			local optimizations=$(echo "${optimization_prompt}" | ollama run qwen3-coder:480b-cloud 2>/dev/null || echo "Optimization analysis unavailable")

			optimization_report="${optimization_report}\n\n## ${filename}\n${optimizations}"
		fi
	done

	# Save optimization report
	local optimization_file="${project_path}/AI_PERFORMANCE_OPTIMIZATION_$(date +%Y%m%d).md"
	echo "# Performance Optimization Report for ${project_name}" >"${optimization_file}"
	echo "Generated: $(date)" >>"${optimization_file}"
	echo -e "${optimization_report}" >>"${optimization_file}"

	print_success "Performance optimization report saved to ${optimization_file}"
}

# Enhanced project listing with AI insights
list_projects_with_ai() {
	check_ollama_health || return 1

	print_ai "Analyzing all projects with AI insights..."
	echo ""

	for project in "${PROJECTS_DIR}"/*; do
		if [[ -d ${project} ]]; then
			local project_name=$(basename "${project}")
			local swift_files=$(find "${project}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
			local has_tests=""
			local has_docs=""
			local has_ai=""

			# Check for various components
			if [[ -d "${project}"/*Tests* ]] || [[ -d "${project}"/Tests ]]; then
				has_tests=" ✅ Tests"
			else
				has_tests=" ❌ No Tests"
			fi

			if [[ -f "${project}/README.md" ]]; then
				has_docs=" ✅ Docs"
			else
				has_docs=" ❌ No Docs"
			fi

			if [[ -f "${project}"/AI_* ]]; then
				has_ai=" 🤖 AI Enhanced"
			else
				has_ai=" 🤖 Ready for AI"
			fi

			echo "📱 ${project_name}: ${swift_files} Swift files${has_tests}${has_docs}${has_ai}"

			# Quick AI assessment
			if [[ ${swift_files} -gt 0 ]]; then
				local quick_prompt="In one sentence, suggest the most valuable AI enhancement for a Swift project called '${project_name}' with ${swift_files} files:"
				local ai_suggestion=$(echo "${quick_prompt}" | ollama run qwen3-coder:480b-cloud 2>/dev/null | head -1 || echo "AI suggestion unavailable")
				echo "   💡 AI Suggestion: ${ai_suggestion}"
			fi
			echo ""
		fi
	done
}

# Comprehensive AI-powered automation for a project
run_full_ai_automation() {
	local project_name="$1"

	if [[ -z ${project_name} ]]; then
		print_error "Project name required"
		return 1
	fi

	print_ai "Running full AI automation suite for ${project_name}..."

	check_ollama_health || return 1

	# Run all AI automation steps
	analyze_project_with_ai "${project_name}"
	generate_missing_components "${project_name}"
	perform_ai_code_review "${project_name}"
	optimize_project_performance "${project_name}"

	print_success "Full AI automation completed for ${project_name}"

	# Generate summary report
	local summary_file="${PROJECTS_DIR}/${project_name}/AI_AUTOMATION_SUMMARY_$(date +%Y%m%d).md"
	echo "# AI Automation Summary for ${project_name}" >"${summary_file}"
	echo "Completed: $(date)" >>"${summary_file}"
	echo "" >>"${summary_file}"
	echo "## Files Generated:" >>"${summary_file}"
	find "${PROJECTS_DIR}/${project_name}" -name "AI_*" -newer "${summary_file}" >>"${summary_file}" 2>/dev/null
	echo "" >>"${summary_file}"
	echo "## Next Steps:" >>"${summary_file}"
	echo "1. Review generated analyses and recommendations" >>"${summary_file}"
	echo "2. Implement suggested optimizations" >>"${summary_file}"
	echo "3. Run generated tests" >>"${summary_file}"
	echo "4. Update documentation as needed" >>"${summary_file}"

	print_success "Automation summary saved to ${summary_file}"
}

# Run AI automation for all projects
run_ai_automation_all() {
	print_ai "Running AI automation for ALL projects..."

	check_ollama_health || return 1

	for project in "${PROJECTS_DIR}"/*; do
		if [[ -d ${project} ]]; then
			local project_name=$(basename "${project}")
			local swift_files=$(find "${project}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

			if [[ ${swift_files} -gt 0 ]]; then
				print_ai "Processing ${project_name}..."
				run_full_ai_automation "${project_name}"
				echo ""
			else
				print_warning "Skipping ${project_name} (no Swift files found)"
			fi
		fi
	done

	print_success "AI automation completed for all projects"
}

# Show usage information
show_usage() {
	echo "AI-Enhanced Master Automation Controller"
	echo ""
	echo "Usage: $0 [command] [project_name]"
	echo ""
	echo "Commands:"
	echo "  status          - Check Ollama health and workspace status"
	echo "  list            - List all projects with AI insights"
	echo "  analyze <name>  - AI analysis of specific project"
	echo "  review <name>   - AI code review of specific project"
	echo "  optimize <name> - AI performance optimization analysis"
	echo "  generate <name> - Generate missing components (tests, docs)"
	echo "  ai <name>       - Run full AI automation for specific project"
	echo "  ai-all          - Run AI automation for all projects"
	echo "  health          - Check Ollama connectivity and models"
	echo ""
	echo "Examples:"
	echo "  $0 status"
	echo "  $0 list"
	echo "  $0 ai CodingReviewer"
	echo "  $0 ai-all"
}

# Main execution logic - only run if this script is called directly
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
	case "${1-}" in
	"status" | "")
		check_ollama_health
		list_projects_with_ai
		;;
	"list")
		list_projects_with_ai
		;;
	"analyze")
		analyze_project_with_ai "$2"
		;;
	"review")
		perform_ai_code_review "$2"
		;;
	"optimize")
		optimize_project_performance "$2"
		;;
	"generate")
		generate_missing_components "$2"
		;;
	"ai")
		run_full_ai_automation "$2"
		;;
	"ai-all")
		run_ai_automation_all
		;;
	"health")
		check_ollama_health
		;;
	*)
		show_usage
		;;
	esac
fi
