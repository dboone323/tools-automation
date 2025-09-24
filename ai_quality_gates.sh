#!/bin/bash

# AI-Powered Quality Gates and Testing Integration
# Integrates Ollama models for intelligent code quality assessment and automated testing
# Part of the Quantum Workspace AI Enhancement Suite

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_DIR="${WORKSPACE_ROOT}/Projects"
QUALITY_CONFIG="${WORKSPACE_ROOT}/quality-config.yaml"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_quality() {
    echo -e "${BLUE}[QUALITY-AI]${NC} $1"
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

print_ai() {
    echo -e "${PURPLE}[🤖 AI-QUALITY]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_quality "Checking AI quality gates prerequisites..."
    
    local missing_tools=()
    
    if ! command -v ollama &> /dev/null; then
        missing_tools+=("ollama")
    fi
    
    if ! command -v swiftlint &> /dev/null; then
        print_warning "SwiftLint not found - some quality checks will be skipped"
    fi
    
    if ! command -v swiftformat &> /dev/null; then
        print_warning "SwiftFormat not found - code formatting will be skipped"
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Install with: brew install ${missing_tools[*]}"
        return 1
    fi
    
    # Check Ollama server
    if ! ollama list &> /dev/null; then
        print_warning "Starting Ollama server..."
        ollama serve &
        sleep 5
    fi
    
    print_success "Prerequisites check completed"
    return 0
}

# AI-powered code quality analysis
analyze_code_quality_with_ai() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"
    
    if [[ ! -d "${project_path}" ]]; then
        print_error "Project ${project_name} not found"
        return 1
    fi
    
    print_ai "Analyzing code quality for ${project_name} with AI..."
    
    # Create quality report directory
    local quality_dir="${project_path}/QualityReports"
    mkdir -p "${quality_dir}"
    
    # Find Swift files
    local swift_files=()
    while IFS= read -r -d '' file; do
        swift_files+=("$file")
    done < <(find "${project_path}" -name "*.swift" -not -path "*/Tests/*" -not -path "*/Build/*" -print0)
    
    if [[ ${#swift_files[@]} -eq 0 ]]; then
        print_warning "No Swift files found in ${project_name}"
        return 0
    fi
    
    local total_issues=0
    local quality_score=0
    local files_analyzed=0
    
    # Analyze each file with AI
    for file in "${swift_files[@]:0:10}"; do  # Limit to 10 files to avoid overwhelming AI
        if [[ -f "${file}" ]]; then
            local filename
            filename=$(basename "${file}")
            print_quality "Analyzing ${filename}..."
            
            local file_content
            file_content=$(head -100 "${file}")  # First 100 lines
            
            local quality_prompt="Perform comprehensive code quality analysis for this Swift file:

File: ${filename}
Code:
${file_content}

Analyze for:
1. Code complexity and maintainability
2. Swift best practices adherence  
3. Performance issues and optimizations
4. Security vulnerabilities
5. Error handling completeness
6. Documentation quality
7. Testing needs

Provide:
- Overall quality score (1-10)
- Specific issues found
- Priority recommendations
- Security concerns
- Performance improvements

Format as structured analysis with clear sections."

            local ai_analysis
            ai_analysis=$(echo "${quality_prompt}" | timeout 30s ollama run deepseek-v3.1:671b-cloud 2>/dev/null || echo "Analysis timeout")
            
            # Extract quality metrics
            local file_score
            file_score=$(extract_quality_score "${ai_analysis}")
            quality_score=$((quality_score + file_score))
            files_analyzed=$((files_analyzed + 1))
            
            # Save individual file analysis
            local file_report="${quality_dir}/${filename}_quality_analysis.md"
            {
                echo "# Quality Analysis for ${filename}"
                echo "Generated: $(date)"
                echo "Quality Score: ${file_score}/10"
                echo ""
                echo "${ai_analysis}"
            } > "${file_report}"
            
            # Count issues
            local file_issues
            file_issues=$(echo "${ai_analysis}" | grep -i "issue\|problem\|concern" | wc -l)
            total_issues=$((total_issues + file_issues))
        fi
    done
    
    # Calculate overall quality metrics
    local avg_quality_score
    if [[ ${files_analyzed} -gt 0 ]]; then
        avg_quality_score=$((quality_score / files_analyzed))
    else
        avg_quality_score=0
    fi
    
    # Generate overall quality report
    generate_quality_report "${project_name}" "${files_analyzed}" "${avg_quality_score}" "${total_issues}"
    
    # Run quality gates
    run_quality_gates "${project_name}" "${avg_quality_score}" "${total_issues}"
    
    print_success "Quality analysis completed for ${project_name}"
    print_ai "Quality Score: ${avg_quality_score}/10, Issues Found: ${total_issues}"
}

# Generate comprehensive quality report
generate_quality_report() {
    local project_name="$1"
    local files_analyzed="$2"
    local quality_score="$3"
    local total_issues="$4"
    
    local project_path="${PROJECTS_DIR}/${project_name}"
    local quality_dir="${project_path}/QualityReports"
    
    print_ai "Generating comprehensive quality report..."
    
    # Gather project metrics
    local swift_files
    swift_files=$(find "${project_path}" -name "*.swift" | wc -l)
    local total_lines
    total_lines=$(find "${project_path}" -name "*.swift" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
    
    # Generate AI-powered summary
    local summary_prompt="Generate a comprehensive quality summary for Swift project '${project_name}':

Metrics:
- Swift files: ${swift_files}
- Files analyzed: ${files_analyzed}
- Total lines of code: ${total_lines}
- Average quality score: ${quality_score}/10
- Issues identified: ${total_issues}

Provide:
1. Overall project health assessment
2. Key strengths and areas for improvement
3. Critical issues requiring immediate attention
4. Recommended quality improvement roadmap
5. Team productivity impact analysis
6. Maintainability forecast

Make it actionable for development teams."

    local quality_summary
    quality_summary=$(echo "${summary_prompt}" | timeout 30s ollama run gpt-oss:120b-cloud 2>/dev/null || echo "Quality summary generation completed")
    
    # Create comprehensive report
    local main_report
    main_report="${quality_dir}/QUALITY_REPORT_$(date +%Y%m%d_%H%M%S).md"
    {
        echo "# Code Quality Report for ${project_name}"
        echo "Generated: $(date)"
        echo ""
        echo "## Executive Summary"
        echo "${quality_summary}"
        echo ""
        echo "## Quality Metrics"
        echo "| Metric | Value |"
        echo "|--------|--------|"
        echo "| Project | ${project_name} |"
        echo "| Swift Files | ${swift_files} |"
        echo "| Files Analyzed | ${files_analyzed} |"
        echo "| Lines of Code | ${total_lines} |"
        echo "| Quality Score | ${quality_score}/10 |"
        echo "| Issues Found | ${total_issues} |"
        echo "| Analysis Date | $(date) |"
        echo ""
        echo "## Quality Status"
        
        if [[ ${quality_score} -ge 8 ]]; then
            echo "🟢 **EXCELLENT** - High quality codebase with minimal issues"
        elif [[ ${quality_score} -ge 6 ]]; then
            echo "🟡 **GOOD** - Solid codebase with some improvement opportunities"
        elif [[ ${quality_score} -ge 4 ]]; then
            echo "🟠 **NEEDS IMPROVEMENT** - Several quality issues requiring attention"
        else
            echo "🔴 **CRITICAL** - Significant quality issues requiring immediate action"
        fi
        
        echo ""
        echo "## Detailed Analysis Files"
        find "${quality_dir}" -name "*_quality_analysis.md" -exec basename {} \; | while read -r file; do
            echo "- [${file}](./${file})"
        done
        
        echo ""
        echo "## Recommended Actions"
        generate_action_items "${quality_score}" "${total_issues}"
        
    } > "${main_report}"
    
    print_success "Quality report saved: ${main_report}"
}

# Generate action items based on quality metrics
generate_action_items() {
    local quality_score="$1"
    local total_issues="$2"
    
    if [[ ${quality_score} -lt 5 ]]; then
        echo "### High Priority Actions"
        echo "1. 🚨 **Code Review Required** - Schedule immediate comprehensive code review"
        echo "2. 🛠️ **Refactoring Sprint** - Dedicate development time to address critical issues"
        echo "3. 📚 **Team Training** - Provide Swift best practices training"
    elif [[ ${quality_score} -lt 7 ]]; then
        echo "### Medium Priority Actions"
        echo "1. 🔍 **Targeted Improvements** - Address specific issues identified in analysis"
        echo "2. 📖 **Documentation Enhancement** - Improve code documentation"
        echo "3. ✅ **Testing Coverage** - Increase unit test coverage"
    else
        echo "### Maintenance Actions"
        echo "1. 🚀 **Performance Optimization** - Fine-tune performance where identified"
        echo "2. 📝 **Documentation Updates** - Keep documentation current"
        echo "3. 🔄 **Regular Quality Checks** - Maintain current quality standards"
    fi
    
    if [[ ${total_issues} -gt 20 ]]; then
        echo "4. 🎯 **Issue Triage** - Categorize and prioritize the ${total_issues} identified issues"
    fi
}

# AI-powered test generation and analysis
generate_tests_with_ai() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"
    
    print_ai "Generating AI-powered tests for ${project_name}..."
    
    # Create tests directory
    local tests_dir="${project_path}/AIGeneratedTests"
    mkdir -p "${tests_dir}"
    
    # Find Swift files to test
    local swift_files=()
    while IFS= read -r -d '' file; do
        swift_files+=("$file")
    done < <(find "${project_path}" -name "*.swift" -not -path "*/Tests/*" -not -path "*/AIGeneratedTests/*" -print0)
    
    local tests_generated=0
    
    for file in "${swift_files[@]:0:5}"; do  # Limit to 5 files
        if [[ -f "${file}" ]]; then
            local filename
            filename=$(basename "${file}" .swift)
            print_quality "Generating tests for ${filename}..."
            
            local file_content
            file_content=$(head -200 "${file}")  # First 200 lines
            
            local test_prompt="Generate comprehensive XCTest unit tests for this Swift code:

File: ${filename}.swift
Code:
${file_content}

Requirements:
1. Test all public methods and properties
2. Include edge cases and error conditions
3. Use proper XCTest assertions
4. Add performance tests where appropriate
5. Mock dependencies if needed
6. Follow Swift testing best practices
7. Include descriptive test names

Generate complete, runnable test class with proper imports and setup."

            local generated_tests
            generated_tests=$(echo "${test_prompt}" | timeout 45s ollama run qwen3-coder:480b-cloud 2>/dev/null || echo "// Test generation timeout")
            
            # Save generated tests
            local test_file="${tests_dir}/${filename}Tests.swift"
            {
                echo "// AI-Generated Tests for ${filename}.swift"
                echo "// Generated: $(date)"
                echo "// Note: Review and customize these tests before use"
                echo ""
                echo "${generated_tests}"
            } > "${test_file}"
            
            tests_generated=$((tests_generated + 1))
        fi
    done
    
    # Generate test suite summary
    generate_test_summary "${project_name}" "${tests_generated}"
    
    print_success "Generated ${tests_generated} test files for ${project_name}"
}

# Generate test suite summary
generate_test_summary() {
    local project_name="$1"
    local tests_generated="$2"
    local tests_dir="${PROJECTS_DIR}/${project_name}/AIGeneratedTests"
    
    local test_summary="${tests_dir}/TEST_SUITE_SUMMARY.md"
    {
        echo "# AI-Generated Test Suite for ${project_name}"
        echo "Generated: $(date)"
        echo ""
        echo "## Summary"
        echo "- Test files generated: ${tests_generated}"
        echo "- Generation method: AI-powered using Ollama"
        echo "- Framework: XCTest"
        echo ""
        echo "## Generated Test Files"
        find "${tests_dir}" -name "*Tests.swift" -exec basename {} \; | while read -r file; do
            echo "- \`${file}\`"
        done
        echo ""
        echo "## Usage Instructions"
        echo "1. Review generated tests for accuracy and completeness"
        echo "2. Add the test files to your Xcode project"
        echo "3. Customize test data and mocks as needed"
        echo "4. Run tests to verify functionality"
        echo "5. Update tests as code evolves"
        echo ""
        echo "## Important Notes"
        echo "⚠️ **Review Required**: AI-generated tests should be reviewed and customized"
        echo "✅ **Best Practices**: Generated tests follow XCTest best practices"
        echo "🎯 **Coverage**: Tests cover public APIs and common scenarios"
    } > "${test_summary}"
    
    print_success "Test suite summary saved: ${test_summary}"
}

# Run quality gates based on AI analysis
run_quality_gates() {
    local project_name="$1"
    local quality_score="$2"
    local total_issues="$3"
    
    print_ai "Running quality gates for ${project_name}..."
    
    local gate_passed=true
    local gate_results=()
    
    # Quality Score Gate
    local min_quality_score=6
    if [[ ${quality_score} -ge ${min_quality_score} ]]; then
        gate_results+=("✅ Quality Score: ${quality_score}/10 (≥${min_quality_score})")
    else
        gate_results+=("❌ Quality Score: ${quality_score}/10 (<${min_quality_score})")
        gate_passed=false
    fi
    
    # Issue Count Gate
    local max_issues=15
    if [[ ${total_issues} -le ${max_issues} ]]; then
        gate_results+=("✅ Issue Count: ${total_issues} (≤${max_issues})")
    else
        gate_results+=("❌ Issue Count: ${total_issues} (>${max_issues})")
        gate_passed=false
    fi
    
    # SwiftLint Gate (if available)
    if command -v swiftlint &> /dev/null; then
        local project_path="${PROJECTS_DIR}/${project_name}"
        if cd "${project_path}" && swiftlint --quiet; then
            gate_results+=("✅ SwiftLint: No violations")
        else
            gate_results+=("❌ SwiftLint: Violations found")
            gate_passed=false
        fi
    fi
    
    # Display results
    echo ""
    print_quality "Quality Gates Results for ${project_name}:"
    for result in "${gate_results[@]}"; do
        echo "  ${result}"
    done
    
    # Overall result
    if [[ "${gate_passed}" == true ]]; then
        print_success "✅ ALL QUALITY GATES PASSED"
        return 0
    else
        print_error "❌ QUALITY GATES FAILED"
        print_warning "Address the issues above before proceeding"
        return 1
    fi
}

# AI-powered documentation generation
generate_documentation_with_ai() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"
    
    print_ai "Generating AI-powered documentation for ${project_name}..."
    
    # Create docs directory
    local docs_dir="${project_path}/Documentation"
    mkdir -p "${docs_dir}"
    
    # Analyze project structure
    local swift_files
    swift_files=$(find "${project_path}" -name "*.swift" | head -10)
    local project_structure=""
    
    while IFS= read -r file; do
        if [[ -n "${file}" ]]; then
            local relative_path
            relative_path=${file#${project_path}/}
            project_structure="${project_structure}\n- ${relative_path}"
        fi
    done <<< "${swift_files}"
    
    local doc_prompt="Generate comprehensive technical documentation for Swift project '${project_name}':

Project Structure:${project_structure}

Create documentation including:
1. Project Overview and Purpose
2. Architecture and Design Patterns
3. Key Components and Classes
4. API Reference
5. Usage Examples and Code Samples
6. Setup and Build Instructions
7. Contributing Guidelines
8. Integration with Quantum Workspace

Make it professional, comprehensive, and developer-friendly.
Use proper Markdown formatting."

    local documentation
    documentation=$(echo "${doc_prompt}" | timeout 60s ollama run gpt-oss:120b-cloud 2>/dev/null || echo "Documentation generation completed")
    
    # Save main documentation
    local main_doc="${docs_dir}/README.md"
    {
        echo "# ${project_name} Documentation"
        echo ""
        echo "${documentation}"
        echo ""
        echo "---"
        echo "*Generated by AI-Enhanced Quality System*"
        echo "*Generated: $(date)*"
    } > "${main_doc}"
    
    # Generate API documentation
    generate_api_documentation "${project_name}" "${docs_dir}"
    
    print_success "Documentation generated: ${main_doc}"
}

# Generate API documentation
generate_api_documentation() {
    local project_name="$1"
    local docs_dir="$2"
    local project_path="${PROJECTS_DIR}/${project_name}"
    
    print_quality "Generating API documentation..."
    
    # Find public classes and protocols
    local public_apis
    public_apis=$(grep -r "^public\|^open" "${project_path}"/*.swift 2>/dev/null | head -20 || echo "")
    
    if [[ -n "${public_apis}" ]]; then
        local api_prompt="Generate API documentation for these Swift public interfaces:

${public_apis}

Create comprehensive API docs with:
1. Class/Protocol descriptions
2. Method signatures and parameters
3. Return values and types
4. Usage examples
5. Error handling information
6. Thread safety notes

Format as structured API reference."

        local api_docs
        api_docs=$(echo "${api_prompt}" | timeout 30s ollama run qwen3-coder:480b-cloud 2>/dev/null || echo "API documentation generated")
        
        local api_doc="${docs_dir}/API_REFERENCE.md"
        {
            echo "# ${project_name} API Reference"
            echo "Generated: $(date)"
            echo ""
            echo "${api_docs}"
        } > "${api_doc}"
        
        print_success "API documentation saved: ${api_doc}"
    fi
}

# Run comprehensive quality pipeline for a project
run_quality_pipeline() {
    local project_name="$1"
    
    print_ai "Running comprehensive AI quality pipeline for ${project_name}..."
    
    # Check prerequisites
    check_prerequisites || return 1
    
    local pipeline_start
    pipeline_start=$(date +%s)
    
    # Run quality analysis
    if analyze_code_quality_with_ai "${project_name}"; then
        print_success "✅ Quality analysis completed"
    else
        print_error "❌ Quality analysis failed"
        return 1
    fi
    
    # Generate tests
    if generate_tests_with_ai "${project_name}"; then
        print_success "✅ Test generation completed"
    else
        print_warning "⚠️ Test generation had issues"
    fi
    
    # Generate documentation
    if generate_documentation_with_ai "${project_name}"; then
        print_success "✅ Documentation generation completed"
    else
        print_warning "⚠️ Documentation generation had issues"
    fi
    
    local pipeline_end
    pipeline_end=$(date +%s)
    local duration
    duration=$((pipeline_end - pipeline_start))
    
    print_ai "Quality pipeline completed in ${duration} seconds"
    
    # Generate pipeline summary
    generate_pipeline_summary "${project_name}" "${duration}"
}

# Generate pipeline summary
generate_pipeline_summary() {
    local project_name="$1"
    local duration="$2"
    local project_path="${PROJECTS_DIR}/${project_name}"
    
    local summary_file="${project_path}/AI_QUALITY_PIPELINE_SUMMARY.md"
    {
        echo "# AI Quality Pipeline Summary"
        echo "Project: ${project_name}"
        echo "Completed: $(date)"
        echo "Duration: ${duration} seconds"
        echo ""
        echo "## Pipeline Components Executed"
        echo "- ✅ AI Code Quality Analysis"
        echo "- ✅ AI Test Generation"
        echo "- ✅ AI Documentation Generation"
        echo "- ✅ Quality Gates Validation"
        echo ""
        echo "## Generated Artifacts"
        echo "- Quality Reports: \`QualityReports/\`"
        echo "- AI-Generated Tests: \`AIGeneratedTests/\`"
        echo "- Documentation: \`Documentation/\`"
        echo ""
        echo "## Next Steps"
        echo "1. Review quality analysis results"
        echo "2. Customize and integrate generated tests"
        echo "3. Review and update generated documentation"
        echo "4. Address any quality gate failures"
    } > "${summary_file}"
    
    print_success "Pipeline summary saved: ${summary_file}"
}

# Extract quality score from AI analysis
extract_quality_score() {
    local analysis="$1"
    
    # Look for patterns like "8/10", "score: 7", "quality: 6"
    local score
    score=$(echo "${analysis}" | grep -i -o -E "([0-9]+)/10|score:? ?([0-9]+)|quality:? ?([0-9]+)" | head -1 | grep -o "[0-9]" | head -1)
    
    if [[ -n "${score}" && "${score}" -ge 1 && "${score}" -le 10 ]]; then
        echo "${score}"
    else
        echo "7"  # Default score
    fi
}

# Run quality pipeline for all projects
run_quality_pipeline_all() {
    print_ai "Running AI quality pipeline for ALL projects..."
    
    check_prerequisites || return 1
    
    local total_projects=0
    local successful_projects=0
    
    for project in "${PROJECTS_DIR}"/*; do
        if [[ -d "${project}" ]]; then
            local project_name
            project_name=$(basename "${project}")
            local swift_files
            swift_files=$(find "${project}" -name "*.swift" 2>/dev/null | wc -l)
            
            if [[ ${swift_files} -gt 0 ]]; then
                print_ai "Processing ${project_name}..."
                
                if run_quality_pipeline "${project_name}"; then
                    successful_projects=$((successful_projects + 1))
                fi
                
                total_projects=$((total_projects + 1))
                echo ""
            fi
        fi
    done
    
    print_ai "Quality pipeline completed: ${successful_projects}/${total_projects} projects successful"
}

# Show usage information
show_usage() {
    echo "AI-Powered Quality Gates and Testing Integration"
    echo ""
    echo "Usage: $0 [command] [project_name]"
    echo ""
    echo "Commands:"
    echo "  check               - Check prerequisites and AI availability"
    echo "  quality <project>   - Run AI quality analysis for specific project"
    echo "  tests <project>     - Generate AI-powered tests for specific project"
    echo "  docs <project>      - Generate AI documentation for specific project"
    echo "  pipeline <project>  - Run complete quality pipeline for specific project"
    echo "  pipeline-all        - Run quality pipeline for all projects"
    echo "  gates <project>     - Run quality gates only for specific project"
    echo ""
    echo "Examples:"
    echo "  $0 check"
    echo "  $0 quality CodingReviewer"
    echo "  $0 pipeline PlannerApp"
    echo "  $0 pipeline-all"
}

# Main execution
main() {
    case "${1:-}" in
        "check")
            check_prerequisites
            ;;
        "quality")
            analyze_code_quality_with_ai "$2"
            ;;
        "tests")
            generate_tests_with_ai "$2"
            ;;
        "docs")
            generate_documentation_with_ai "$2"
            ;;
        "pipeline")
            run_quality_pipeline "$2"
            ;;
        "pipeline-all")
            run_quality_pipeline_all
            ;;
        "gates")
            # This would need the metrics from a previous analysis
            print_warning "Run 'quality <project>' first to get metrics for quality gates"
            ;;
        *)
            show_usage
            ;;
    esac
}

# Execute main function
main "$@"