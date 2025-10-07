#!/bin/bash
# AI-Powered Code Generation Optimization Module
# Provides intelligent code generation, refactoring suggestions, and automated code improvements

# Check if Ollama is available
check_ollama() {
  if command -v ollama &>/dev/null && ollama list &>/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# AI-powered code generation from specifications
ai_generate_code() {
  local spec="$1"
  local language="${2:-swift}"
  local output_file="$3"

  if ! check_ollama; then
    echo "# AI code generation unavailable - manual implementation required" >"${output_file}"
    return 1
  fi

  local prompt="Generate production-ready ${language} code based on this specification:
${spec}

Requirements:
- Follow best practices and design patterns
- Include comprehensive error handling
- Add inline documentation
- Make code testable and maintainable
- Follow ${language} conventions

Provide only the code, no explanations."

  ollama run codellama "${prompt}" 2>/dev/null >"${output_file}"

  if [[ -s "${output_file}" ]]; then
    return 0
  else
    echo "# AI code generation failed" >"${output_file}"
    return 1
  fi
}

# AI-powered refactoring suggestions
ai_suggest_refactoring() {
  local code_file="$1"

  if ! check_ollama; then
    echo "No suggestions available (AI unavailable)"
    return
  fi

  local code_content
  code_content=$(cat "${code_file}" 2>/dev/null)

  local prompt="Analyze this code and suggest refactoring improvements:

${code_content}

Identify:
- Code smells and anti-patterns
- Duplicate code opportunities
- Performance optimizations
- Readability improvements
- Design pattern applications

Provide specific, actionable suggestions with code examples."

  ollama run codellama "${prompt}" 2>/dev/null
}

# AI-powered code complexity analysis
ai_analyze_complexity() {
  local code_file="$1"

  if ! check_ollama; then
    echo "medium" # Default complexity
    return
  fi

  local code_content
  code_content=$(cat "${code_file}" 2>/dev/null)

  local prompt="Analyze the complexity of this code and respond with one word: low, medium, or high

${code_content}

Consider:
- Cyclomatic complexity
- Cognitive complexity
- Nesting depth
- Number of responsibilities

Respond with ONLY: low, medium, or high"

  local complexity
  complexity=$(ollama run codellama "${prompt}" 2>/dev/null | grep -oiE '(low|medium|high)' | head -1 | tr '[:upper:]' '[:lower:]')

  echo "${complexity:-medium}"
}

# AI-powered API documentation generation
ai_generate_api_docs() {
  local code_file="$1"
  local output_file="$2"

  if ! check_ollama; then
    echo "# API Documentation (auto-generated)" >"${output_file}"
    echo "AI documentation unavailable - manual documentation required" >>"${output_file}"
    return
  fi

  local code_content
  code_content=$(cat "${code_file}" 2>/dev/null)

  local prompt="Generate comprehensive API documentation for this code:

${code_content}

Include:
- Overview and purpose
- Public API reference
- Parameters and return types
- Usage examples
- Edge cases and gotchas

Format as Markdown."

  ollama run codellama "${prompt}" 2>/dev/null >"${output_file}"
}

# AI-powered test case generation
ai_generate_test_cases() {
  local code_file="$1"
  local test_framework="${2:-XCTest}"

  if ! check_ollama; then
    echo "// AI test generation unavailable"
    return
  fi

  local code_content
  code_content=$(cat "${code_file}" 2>/dev/null)

  local prompt="Generate comprehensive test cases using ${test_framework} for this code:

${code_content}

Include:
- Unit tests for all public methods
- Edge case testing
- Error condition testing
- Mock/stub examples where needed
- Test setup and teardown

Provide complete, runnable test code."

  ollama run codellama "${prompt}" 2>/dev/null
}

# AI-powered code review
ai_code_review() {
  local code_file="$1"

  if ! check_ollama; then
    echo "✅ Manual review required (AI unavailable)"
    return 0
  fi

  local code_content
  code_content=$(cat "${code_file}" 2>/dev/null)

  local prompt="Perform a thorough code review of this code:

${code_content}

Review for:
- Bugs and potential errors
- Security vulnerabilities
- Performance issues
- Best practice violations
- Maintainability concerns

Provide:
1. Overall assessment (APPROVE/REQUEST_CHANGES)
2. Critical issues
3. Suggestions for improvement
4. Positive aspects

Start your response with either 'APPROVE:' or 'REQUEST_CHANGES:'"

  local review
  review=$(ollama run codellama "${prompt}" 2>/dev/null)

  echo "${review}"

  if echo "${review}" | grep -q "^REQUEST_CHANGES:"; then
    return 1
  else
    return 0
  fi
}

# AI-powered naming suggestions
ai_suggest_names() {
  local purpose="$1"
  local type="${2:-function}" # function, class, variable, etc.

  if ! check_ollama; then
    echo "suggestedName"
    return
  fi

  local prompt="Suggest 3 clear, descriptive ${type} names for: ${purpose}

Follow naming conventions:
- ${type} naming best practices
- Clear and self-documenting
- Appropriate length
- Industry standard patterns

Provide ONLY 3 names, one per line, no explanations."

  ollama run codellama "${prompt}" 2>/dev/null | head -3
}

# AI-powered bug fix suggestions
ai_suggest_bug_fix() {
  local error_message="$1"
  local code_context="$2"

  if ! check_ollama; then
    echo "Manual debugging required (AI unavailable)"
    return
  fi

  local prompt="Suggest a fix for this error:

Error: ${error_message}

Code Context:
${code_context}

Provide:
1. Root cause analysis
2. Specific fix with code example
3. Prevention strategies

Be concise and actionable."

  ollama run codellama "${prompt}" 2>/dev/null
}

# AI-powered code optimization
ai_optimize_code() {
  local code_file="$1"
  local optimization_goal="${2:-performance}" # performance, memory, readability

  if ! check_ollama; then
    return 1
  fi

  local code_content
  code_content=$(cat "${code_file}" 2>/dev/null)

  local prompt="Optimize this code for ${optimization_goal}:

${code_content}

Provide:
1. Optimized version of the code
2. Explanation of changes
3. Expected improvement metrics

Focus on ${optimization_goal} while maintaining correctness."

  ollama run codellama "${prompt}" 2>/dev/null
}

# Generate code quality insights
ai_generate_code_insights() {
  local project_path="$1"
  local output_file="$2"

  if ! check_ollama; then
    echo "# Code Quality Insights (AI unavailable)" >"${output_file}"
    return
  fi

  # Gather code statistics
  local file_count
  file_count=$(find "${project_path}" -name "*.swift" 2>/dev/null | wc -l)
  local line_count
  line_count=$(find "${project_path}" -name "*.swift" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')

  local prompt="Analyze this codebase summary and provide insights:

Files: ${file_count}
Lines of code: ${line_count}
Language: Swift

Provide insights on:
1. Codebase health assessment
2. Maintainability score (1-10)
3. Suggested improvements
4. Technical debt indicators
5. Recommended focus areas

Format as Markdown."

  ollama run codellama "${prompt}" 2>/dev/null >"${output_file}"
}

# Export functions for sourcing
export -f check_ollama
export -f ai_generate_code
export -f ai_suggest_refactoring
export -f ai_analyze_complexity
export -f ai_generate_api_docs
export -f ai_generate_test_cases
export -f ai_code_review
export -f ai_suggest_names
export -f ai_suggest_bug_fix
export -f ai_optimize_code
export -f ai_generate_code_insights
