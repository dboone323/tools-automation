#!/bin/bash

# AI-Enhanced Master Automation Controller
# Enhanced by Ollama v0.12 with local-first strategy
# Local-First: Free Ollama automation with M1 Pro resource limits
# Keychain secrets, offline bootstrap, per-task model selection

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="${CODE_DIR}"

# Local-First Ollama Configuration
OLLAMA_LOCAL_URL="http://localhost:11434"

# Model Configuration - Local-first with registry-based fallbacks
# Models now managed via model_registry.json and ollama_client.sh

# Error tracking for fallback logic (using files instead of arrays)
MODEL_ERRORS_FILE="${CODE_DIR}/model_errors.txt"
MODEL_SUCCESS_FILE="${CODE_DIR}/model_success.txt"
MODEL_TOTAL_FILE="${CODE_DIR}/model_total.txt"

# Initialize tracking files if they don't exist
touch "${MODEL_ERRORS_FILE}" "${MODEL_SUCCESS_FILE}" "${MODEL_TOTAL_FILE}"

# Performance tracking
AI_PERFORMANCE_LOG="${CODE_DIR}/ai_performance_$(date +%Y%m%d).log"

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

# Local-First AI Health Check Function
# Validates local Ollama connectivity and model availability
check_ai_health() {
    print_ai "Checking local Ollama health and model availability..."

    local health_score=0

    # Check local Ollama availability
    print_ai "Checking local Ollama at ${OLLAMA_LOCAL_URL}..."
    if curl -s --max-time 5 "${OLLAMA_LOCAL_URL}/api/tags" >/dev/null 2>&1; then
        print_success "Local Ollama is running"
        ((health_score += 50))
    else
        print_error "Local Ollama is not running or accessible"
        print_error "Run: brew services start ollama"
        return 1
    fi

    # Check model availability
    print_ai "Checking available models..."
    local models
    models=$(curl -s "${OLLAMA_LOCAL_URL}/api/tags" | jq -r '.models[].name' 2>/dev/null || echo "")

    local required_models=("codellama:7b" "llama2" "llama3.2:3b")
    local available_count=0

    for model in "${required_models[@]}"; do
        if echo "${models}" | grep -q "^${model}$"; then
            print_ai "✓ Model ${model} is available locally"
            ((available_count++))
        else
            print_warning "✗ Model ${model} not available locally"
        fi
    done

    # Add model availability to health score
    health_score=$((health_score + available_count * 10))

    # Test model functionality with a quick call
    print_ai "Testing model functionality..."
    local test_result
    test_result=$(echo '{"task": "dashboardSummary", "prompt": "Hello"}' | ./ollama_client.sh 2>/dev/null)
    if [[ $? -eq 0 ]] && [[ -n "$test_result" ]]; then
        local test_text
        test_text=$(echo "$test_result" | jq -r '.text // empty')
        if [[ -n "$test_text" ]]; then
            print_success "Model inference is working"
            ((health_score += 20))
        else
            print_warning "Model inference returned empty response"
        fi
    else
        print_warning "Model inference test failed"
    fi

    # Overall health assessment
    if [[ ${health_score} -ge 80 ]]; then
        print_success "AI Health Score: ${health_score}/100 - Excellent (Local-first ready)"
        return 0
    elif [[ ${health_score} -ge 60 ]]; then
        print_success "AI Health Score: ${health_score}/100 - Good (Functional)"
        return 0
    elif [[ ${health_score} -ge 40 ]]; then
        print_warning "AI Health Score: ${health_score}/100 - Fair (Limited functionality)"
        return 0
    else
        print_error "AI Health Score: ${health_score}/100 - Poor (Setup required)"
        return 1
    fi
}

# Local-First AI Call with Registry-Based Model Selection
# Implements local-only strategy using Ollama adapters with registry fallbacks
call_ai_with_fallback() {
    local task_type="$1"
    local prompt="$2"
    local max_retries="${3:-2}"

    # Map old task types to new registry tasks
    local registry_task
    case "${task_type}" in
    "code_analysis")
        registry_task="codeGen"
        ;;
    "documentation")
        registry_task="dashboardSummary"
        ;;
    "complex_reasoning")
        registry_task="archAnalysis"
        ;;
    "security_analysis")
        registry_task="archAnalysis"
        ;;
    "general")
        registry_task="dashboardSummary"
        ;;
    *)
        registry_task="dashboardSummary"
        ;;
    esac

    # Call the unified Ollama adapter
    local json_input
    json_input=$(jq -n --arg task "$registry_task" --arg prompt "$prompt" '{task: $task, prompt: $prompt}')
    local result
    result=$(echo "$json_input" | ./ollama_client.sh 2>/dev/null)

    if [[ $? -eq 0 ]] && [[ -n "$result" ]]; then
        # Extract text from JSON response
        local text
        text=$(echo "$result" | jq -r '.text // empty')
        if [[ -n "$text" ]]; then
            echo "$text"
            return 0
        fi
    fi

    # Fallback failed
    echo "AI analysis temporarily unavailable - please check Ollama connectivity"
    return 1
}

# Check Ollama connectivity and model availability
check_ollama_health() {
    # Use Phase 7 AI health check infrastructure
    check_ai_health
    return $?
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
    local swift_files
    swift_files=$(find "${project_path}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
    local total_lines
    total_lines=$(find "${project_path}" -name "*.swift" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")

    # Create analysis prompt
    local analysis_prompt
    analysis_prompt="Analyze this Swift project structure and provide recommendations:
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

    # Generate AI analysis using Phase 7 fallback mechanism
    local ai_analysis
    ai_analysis=$(call_ai_with_fallback "general" "${analysis_prompt}")

    # Save analysis
    local analysis_file
    analysis_file="${project_path}/AI_ANALYSIS_$(date +%Y%m%d).md"
    {
        echo "# AI Analysis for ${project_name}"
        echo "Generated: $(date)"
        echo ""
        echo "${ai_analysis}"
    } >"${analysis_file}"

    print_success "AI analysis saved to ${analysis_file}"

    # Extract actionable items with AI
    local improvements_prompt="Extract 3 specific, actionable improvements from this analysis that can be implemented immediately:
${ai_analysis}

Format as:
1. [Action]: [Description]
2. [Action]: [Description]
3. [Action]: [Description]"

    local improvements
    improvements=$(call_ai_with_fallback "general" "${improvements_prompt}")

    {
        echo ""
        echo "## Immediate Action Items"
        echo "${improvements}"
    } >>"${analysis_file}"

    print_ai "Project analysis complete with actionable recommendations"
}

# AI-powered code generation for missing components
generate_missing_components() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"

    print_ai "Generating missing components for ${project_name}..."

    # Check for common missing patterns
    local has_tests=false
    for test_dir in "${project_path}"/*Tests*; do
        if [[ -d ${test_dir} ]]; then
            has_tests=true
            break
        fi
    done
    if [[ -d "${project_path}/Tests" ]]; then
        has_tests=true
    fi

    local missing_components=()

    # Check for tests
    if [[ ${has_tests} == false ]]; then
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
    local main_files
    main_files=$(find "${project_path}" -name "*.swift" -not -path "*/Tests/*" | head -5)

    for file in ${main_files}; do
        if [[ -f ${file} ]]; then
            local filename
            filename=$(basename "${file}" .swift)
            local file_content
            file_content=$(head -100 "${file}") # Read first 100 lines for test generation
            local test_prompt="Generate comprehensive unit tests for this Swift file. Include test cases for all public methods, error conditions, and edge cases:

File: ${filename}.swift
Content:
${file_content}

Generate XCTest-compatible test code with proper setup, assertions, and teardown. Include comments explaining each test case."

            # Generate test with AI using Phase 7 fallback mechanism
            local generated_tests
            generated_tests=$(call_ai_with_fallback "code_analysis" "${test_prompt}")

            # Create test directory and file
            local test_dir="${project_path}/Tests"
            mkdir -p "${test_dir}"

            local test_file="${test_dir}/${filename}Tests.swift"
            {
                echo "// Generated by AI-Enhanced Automation"
                echo "// $(date)"
                echo ""
                echo "${generated_tests}"
            } >"${test_file}"

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
    local swift_files
    swift_files=$(find "${project_path}" -name "*.swift" | head -10)
    local project_structure=""

    for file in ${swift_files}; do
        local relative_path=${file#"${project_path}"/}
        project_structure="${project_structure}\n- ${relative_path}"
    done

    # Generate documentation with AI using Phase 7 fallback mechanism
    local doc_prompt="Generate comprehensive README documentation for this Swift project:

Project: ${project_name}
Structure: ${project_structure}

Include:
1. Project description and purpose
2. Installation and setup instructions
3. Usage examples
4. API documentation for main components
5. Testing instructions
6. Contributing guidelines
7. License information

Format as proper Markdown with clear sections and code examples."

    local generated_docs
    generated_docs=$(call_ai_with_fallback "documentation" "${doc_prompt}")

    local readme_file="${project_path}/README.md"
    {
        echo "# ${project_name}"
        echo ""
        echo "${generated_docs}"
        echo ""
        echo "---"
        echo "*Documentation generated by AI-Enhanced Automation*"
    } >"${readme_file}"

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

    # Generate GitHub Actions workflow using Phase 7 fallback mechanism
    local workflow_prompt="Generate a GitHub Actions CI/CD workflow for this Swift project:

Project: ${project_name}
Platform: iOS/macOS Swift application

Include:
1. Build and test on multiple Xcode versions
2. SwiftLint code quality checks
3. Test coverage reporting
4. Artifact generation for releases
5. Proper caching for dependencies
6. Matrix builds for different iOS versions

Use modern GitHub Actions syntax with proper job dependencies and conditional execution."

    local generated_workflow
    generated_workflow=$(call_ai_with_fallback "code_analysis" "${workflow_prompt}")

    local workflow_file="${workflows_dir}/ci.yml"
    {
        echo "# Generated by AI-Enhanced Automation"
        echo "# $(date)"
        echo ""
        echo "${generated_workflow}"
    } >"${workflow_file}"

    # Generate Fastlane configuration if not exists
    if [[ ! -d "${project_path}/fastlane" ]]; then
        mkdir -p "${project_path}/fastlane"

        local fastfile_content
        fastfile_content="# Generated by AI-Enhanced Automation
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
    local files_to_review
    files_to_review=$(find "${project_path}" -name "*.swift" | head -10)
    local review_results=""

    for file in ${files_to_review}; do
        if [[ -f ${file} ]]; then
            local file_content
            file_content=$(head -50 "${file}") # Review first 50 lines
            local filename
            filename=$(basename "${file}")

            local review_prompt="Perform a comprehensive code review of this Swift file:

File: ${filename}
Content (first 50 lines):
${file_content}

Analyze for:
1. Code quality and best practices
2. Potential bugs or issues
3. Performance optimizations
4. Security concerns
5. Swift style guide compliance
6. Testability improvements
7. Documentation needs

Provide specific, actionable feedback with code examples where applicable."

            local file_review
            file_review=$(call_ai_with_fallback "code_analysis" "${review_prompt}")

            review_results="${review_results}\n\n## ${filename}\n${file_review}"
        fi
    done

    # Save review results
    local review_file
    review_file="${project_path}/AI_CODE_REVIEW_$(date +%Y%m%d).md"
    {
        echo "# AI Code Review for ${project_name}"
        echo "Generated: $(date)"
        echo -e "${review_results}"
    } >"${review_file}"

    print_success "AI code review saved to ${review_file}"
}

# AI-powered performance optimization
optimize_project_performance() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"

    print_ai "Analyzing performance optimization opportunities for ${project_name}..."

    # Find files with potential performance issues
    local performance_files
    performance_files=$(grep -r -l "for.*in\|while\|repeat\|\.map\|\.filter\|\.reduce" "${project_path}"/*.swift 2>/dev/null | head -5)

    local optimization_report=""

    for file in ${performance_files}; do
        if [[ -f ${file} ]]; then
            local file_content
            file_content=$(cat "${file}")
            local filename
            filename=$(basename "${file}")

            local optimization_prompt="Analyze this Swift file for performance optimization opportunities:

File: ${filename}
Content:
${file_content}

Look for:
1. Inefficient algorithms or data structures
2. Memory leaks or retain cycles
3. Unnecessary computations in loops
4. Opportunities for lazy loading or caching
5. UI performance issues (main thread blocking)
6. Database query optimizations
7. Network call improvements

Provide specific code changes with before/after examples and expected performance gains."

            local optimizations
            optimizations=$(call_ai_with_fallback "code_analysis" "${optimization_prompt}")

            optimization_report="${optimization_report}\n\n## ${filename}\n${optimizations}"
        fi
    done

    # Save optimization report
    local optimization_file
    optimization_file="${project_path}/AI_PERFORMANCE_OPTIMIZATION_$(date +%Y%m%d).md"
    {
        echo "# Performance Optimization Report for ${project_name}"
        echo "Generated: $(date)"
        echo -e "${optimization_report}"
    } >"${optimization_file}"

    print_success "Performance optimization report saved to ${optimization_file}"
}

# AI-powered security analysis
analyze_project_security() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"

    print_ai "Analyzing security vulnerabilities for ${project_name}..."

    # Find files with potential security issues
    local security_files
    security_files=$(grep -r -l "password\|key\|token\|secret\|encrypt\|decrypt\|http:\|UserDefaults\|Keychain" "${project_path}"/*.swift 2>/dev/null | head -5)

    local security_report=""

    for file in ${security_files}; do
        if [[ -f ${file} ]]; then
            local file_content
            file_content=$(cat "${file}")
            local filename
            filename=$(basename "${file}")

            local security_prompt="Perform security analysis on this Swift file:

File: ${filename}
Content:
${file_content}

Check for:
1. Input validation vulnerabilities
2. SQL injection risks (if using CoreData/SwiftData)
3. Authentication/authorization issues
4. Data exposure risks
5. Cryptographic weaknesses
6. Network security (HTTPS, certificate pinning)
7. Key management issues
8. Privacy concerns (data collection/storage)

Provide specific security recommendations with code examples."

            local security_issues
            security_issues=$(call_ai_with_fallback "security_analysis" "${security_prompt}")

            security_report="${security_report}\n\n## ${filename}\n${security_issues}"
        fi
    done

    # Save security report
    local security_file
    security_file="${project_path}/AI_SECURITY_ANALYSIS_$(date +%Y%m%d).md"
    {
        echo "# Security Analysis Report for ${project_name}"
        echo "Generated: $(date)"
        echo -e "${security_report}"
    } >"${security_file}"

    print_success "Security analysis report saved to ${security_file}"
}
list_projects_with_ai() {
    print_ai "Analyzing all projects with AI insights..."
    echo ""

    for project in "${PROJECTS_DIR}"/*; do
        if [[ -d ${project} ]]; then
            local project_name
            project_name=$(basename "${project}")
            local swift_files
            swift_files=$(find "${project}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
            local has_tests=""
            local has_docs=""
            local has_ai=""

            # Check for various components
            local has_tests_dir=false
            for test_dir in "${project}"/*Tests*; do
                if [[ -d ${test_dir} ]]; then
                    has_tests_dir=true
                    break
                fi
            done
            if [[ -d "${project}/Tests" ]]; then
                has_tests_dir=true
            fi

            if [[ ${has_tests_dir} == true ]]; then
                has_tests=" ✅ Tests"
            else
                has_tests=" ❌ No Tests"
            fi

            if [[ -f "${project}/README.md" ]]; then
                has_docs=" ✅ Docs"
            else
                has_docs=" ❌ No Docs"
            fi

            local has_ai_files=false
            for ai_file in "${project}"/AI_*; do
                if [[ -f ${ai_file} ]]; then
                    has_ai_files=true
                    break
                fi
            done

            if [[ ${has_ai_files} == true ]]; then
                has_ai=" 🤖 AI Enhanced"
            else
                has_ai=" 🤖 Ready for AI"
            fi

            echo "📱 ${project_name}: ${swift_files} Swift files${has_tests}${has_docs}${has_ai}"

            # Quick AI assessment
            if [[ ${swift_files} -gt 0 ]]; then
                local quick_prompt="Give a one-sentence suggestion for improving this Swift project: ${project_name} with ${swift_files} files."
                local ai_suggestion
                ai_suggestion=$(call_ai_with_fallback "general" "${quick_prompt}")
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
    analyze_project_security "${project_name}"

    print_success "Full AI automation completed for ${project_name}"

    # Generate summary report
    local summary_file
    summary_file="${PROJECTS_DIR}/${project_name}/AI_AUTOMATION_SUMMARY_$(date +%Y%m%d).md"

    # Find AI files before creating summary
    local ai_files
    ai_files=$(find "${PROJECTS_DIR}/${project_name}" -name "AI_*" 2>/dev/null | head -10 || true)

    {
        echo "# AI Automation Summary for ${project_name}"
        echo "Completed: $(date)"
        echo ""
        echo "## Files Generated:"
        if [[ -n ${ai_files} ]]; then
            echo "${ai_files}"
        else
            echo "No AI analysis files found"
        fi
        echo ""
        echo "## Next Steps:"
        echo "1. Review generated analyses and recommendations"
        echo "2. Implement suggested optimizations"
        echo "3. Run generated tests"
        echo "4. Update documentation as needed"
    } >"${summary_file}"

    print_success "Automation summary saved to ${summary_file}"
}

# Run AI automation for all projects
run_ai_automation_all() {
    print_ai "Running AI automation for ALL projects..."

    check_ollama_health || return 1

    for project in "${PROJECTS_DIR}"/*; do
        if [[ -d ${project} ]]; then
            local project_name
            project_name=$(basename "${project}")
            local swift_files
            swift_files=$(find "${project}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

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
    echo "AI-Enhanced Master Automation Controller - Local-First Ollama Strategy"
    echo ""
    echo "Usage: $0 [command] [project_name]"
    echo ""
    echo "Commands:"
    echo "  status          - Check AI health and project statistics"
    echo "  list            - List all projects with AI insights"
    echo "  analyze <name>  - AI analysis of specific project"
    echo "  review <name>   - AI code review of specific project"
    echo "  optimize <name> - AI performance optimization analysis"
    echo "  security <name> - AI security analysis of specific project"
    echo "  generate <name> - Generate missing components (tests, docs)"
    echo "  ai <name>       - Run full AI automation for specific project"
    echo "  ai-all          - Run AI automation for all projects"
    echo "  health          - Check AI connectivity and model availability"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 list"
    echo "  $0 ai CodingReviewer"
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
    "security")
        analyze_project_security "$2"
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
        check_ai_health
        ;;
    *)
        show_usage
        ;;
    esac
fi
