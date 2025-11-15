#!/bin/bash

# Phase 16: AI-Powered Code Review and Optimization System

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_REVIEW_CONFIG_DIR="$WORKSPACE_ROOT/ai_review_config"
REVIEW_LOG="$WORKSPACE_ROOT/logs/ai_code_review.log"
CODE_ANALYSIS_CACHE="$AI_REVIEW_CONFIG_DIR/analysis_cache.json"

# Create config directory
mkdir -p "$AI_REVIEW_CONFIG_DIR" "$WORKSPACE_ROOT/logs"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$REVIEW_LOG"
}

# Initialize analysis patterns and rules
init_analysis_patterns() {
    cat >"$AI_REVIEW_CONFIG_DIR/analysis_patterns.json" <<'EOF'
{
  "patterns": {
    "security": {
      "hardcoded_secrets": {
        "pattern": "(password|secret|key|token)\\s*[=:].*['\"][^'\"]*['\"]",
        "severity": "high",
        "message": "Potential hardcoded secret detected"
      },
      "sql_injection": {
        "pattern": "(SELECT|INSERT|UPDATE|DELETE).*\\+.*\\$",
        "severity": "high",
        "message": "Potential SQL injection vulnerability"
      },
      "command_injection": {
        "pattern": "(exec|system|eval|shell_exec).*\\$",
        "severity": "high",
        "message": "Potential command injection vulnerability"
      }
    },
    "performance": {
      "inefficient_loops": {
        "pattern": "for.*in.*range.*len\\(\\)",
        "severity": "medium",
        "message": "Consider using enumerate() for index and value access"
      },
      "memory_leaks": {
        "pattern": "(open|file).*\\)\\s*$",
        "severity": "medium",
        "message": "File handle not properly closed, consider using 'with' statement"
      }
    },
    "maintainability": {
      "long_functions": {
        "pattern": "def.*:\\s*$",
        "severity": "low",
        "message": "Function length should be reviewed for complexity"
      },
      "magic_numbers": {
        "pattern": "\\b[0-9]{2,}\\b",
        "severity": "low",
        "message": "Consider using named constants for magic numbers"
      }
    },
    "best_practices": {
      "unused_imports": {
        "pattern": "^import|^from.*import",
        "severity": "low",
        "message": "Check for unused imports"
      },
      "naming_conventions": {
        "pattern": "\\b[A-Z][a-zA-Z0-9]*[a-zA-Z0-9_]*\\b",
        "severity": "low",
        "message": "Review naming conventions"
      }
    }
  },
  "language_specific": {
    "python": {
      "type_hints": {
        "pattern": "def.*\\(.*\\).*->.*:",
        "severity": "low",
        "message": "Consider adding type hints for better code clarity"
      },
      "docstrings": {
        "pattern": "def.*:\\s*$",
        "severity": "low",
        "message": "Functions should have docstrings"
      }
    },
    "bash": {
      "error_handling": {
        "pattern": "^#!/bin/bash",
        "severity": "medium",
        "message": "Consider adding 'set -euo pipefail' for better error handling"
      },
      "quoting": {
        "pattern": "\\$[a-zA-Z_][a-zA-Z0-9_]*",
        "severity": "medium",
        "message": "Consider quoting variables to prevent word splitting"
      }
    }
  }
}
EOF
}

# Analyze code file
analyze_code_file() {
    local file_path;
    file_path="$1"
    local language;
    language="${2:-auto}"

    if [[ ! -f "$file_path" ]]; then
        echo '{"error": "file_not_found"}'
        return 1
    fi

    # Detect language if not specified
    if [[ "$language" == "auto" ]]; then
        case "${file_path##*.}" in
        "py") language="python" ;;
        "sh") language="bash" ;;
        "js") language="javascript" ;;
        "swift") language="swift" ;;
        *) language="unknown" ;;
        esac
    fi

    log "Analyzing $file_path (language: $language)"

    local file_content
    file_content=$(cat "$file_path")

    # Basic metrics
    local lines_count;
    lines_count=$(echo "$file_content" | wc -l)
    local chars_count;
    chars_count=$(echo "$file_content" | wc -c)
    local functions_count;
    functions_count=$(echo "$file_content" | grep -c "^def\|^function\|^func" || echo "0")
    local comments_count;
    comments_count=$(echo "$file_content" | grep -c "^[[:space:]]*#" || echo "0")

    # Complexity analysis
    local complexity_score;
    complexity_score=0
    if ((lines_count > 100)); then
        complexity_score=$((complexity_score + 20))
    fi
    if ((functions_count > 10)); then
        complexity_score=$((complexity_score + 15))
    fi
    if ((chars_count > 10000)); then
        complexity_score=$((complexity_score + 25))
    fi

    # Pattern-based analysis
    local issues;
    issues=()
    local patterns_file;
    patterns_file="$AI_REVIEW_CONFIG_DIR/analysis_patterns.json"

    if [[ -f "$patterns_file" ]]; then
        # General patterns
        while IFS= read -r category; do
            while IFS= read -r pattern_name; do
                local pattern;
                pattern=$(jq -r ".patterns.$category.$pattern_name.pattern" "$patterns_file" 2>/dev/null || echo "")
                local severity;
                severity=$(jq -r ".patterns.$category.$pattern_name.severity" "$patterns_file" 2>/dev/null || echo "low")
                local message;
                message=$(jq -r ".patterns.$category.$pattern_name.message" "$patterns_file" 2>/dev/null || echo "")

                if [[ -n "$pattern" ]] && echo "$file_content" | grep -q "$pattern"; then
                    issues+=("{\"category\":\"$category\",\"pattern\":\"$pattern_name\",\"severity\":\"$severity\",\"message\":\"$message\"}")
                fi
            done < <(jq -r ".patterns.$category | keys[]" "$patterns_file" 2>/dev/null || echo "")
        done < <(jq -r '.patterns | keys[]' "$patterns_file" 2>/dev/null || echo "")

        # Language-specific patterns
        if [[ -n "$language" ]]; then
            while IFS= read -r pattern_name; do
                local pattern;
                pattern=$(jq -r ".language_specific.$language.$pattern_name.pattern" "$patterns_file" 2>/dev/null || echo "")
                local severity;
                severity=$(jq -r ".language_specific.$language.$pattern_name.severity" "$patterns_file" 2>/dev/null || echo "low")
                local message;
                message=$(jq -r ".language_specific.$language.$pattern_name.message" "$patterns_file" 2>/dev/null || echo "")

                if [[ -n "$pattern" ]] && echo "$file_content" | grep -q "$pattern"; then
                    issues+=("{\"category\":\"language_specific\",\"pattern\":\"$pattern_name\",\"severity\":\"$severity\",\"message\":\"$message\",\"language\":\"$language\"}")
                fi
            done < <(jq -r ".language_specific.$language | keys[]" "$patterns_file" 2>/dev/null || echo "")
        fi
    fi

    # Generate AI-powered suggestions using Ollama
    local ai_suggestions;
    ai_suggestions="[]"
    if command -v ollama &>/dev/null && command -v jq &>/dev/null; then
        local prompt;
        prompt="Analyze this ${language} code and provide 2-3 specific improvement suggestions. Focus on code quality, performance, and best practices. Be concise.

Code:
$(head -50 "$file_path")

Respond with JSON array of suggestions, each with 'priority' (high/medium/low), 'category', and 'suggestion'."

        ai_suggestions=$(echo "{\"task\":\"codeReview\",\"prompt\":\"$prompt\"}" | "$WORKSPACE_ROOT/ollama_client.sh" 2>/dev/null | jq '.text // "[]' | jq -R 'fromjson? // []' 2>/dev/null || echo "[]")
    fi

    # Calculate overall score
    local issue_count;
    issue_count=${#issues[@]}
    local score;
    score=100

    # Deduct points based on issues
    for issue in "${issues[@]}"; do
        local severity;
        severity=$(echo "$issue" | jq -r '.severity')
        case "$severity" in
        "high") score=$((score - 15)) ;;
        "medium") score=$((score - 8)) ;;
        "low") score=$((score - 3)) ;;
        esac
    done

    # Complexity penalty
    score=$((score - complexity_score))

    # Ensure score doesn't go below 0
    if ((score < 0)); then
        score=0
    fi

    # Format issues as JSON array
    local issues_json;
    issues_json="["
    for i in "${!issues[@]}"; do
        if ((i > 0)); then
            issues_json+=","
        fi
        issues_json+="${issues[$i]}"
    done
    issues_json+="]"

    jq -n \
        --arg file_path "$file_path" \
        --arg language "$language" \
        --argjson lines_count "$lines_count" \
        --argjson chars_count "$chars_count" \
        --argjson functions_count "$functions_count" \
        --argjson comments_count "$comments_count" \
        --argjson complexity_score "$complexity_score" \
        --argjson score "$score" \
        --argjson issues "$issues_json" \
        --argjson ai_suggestions "$ai_suggestions" \
        '{
            file_path: $file_path,
            language: $language,
            metrics: {
                lines_count: $lines_count,
                chars_count: $chars_count,
                functions_count: $functions_count,
                comments_count: $comments_count,
                complexity_score: $complexity_score
            },
            analysis_score: $score,
            issues: ($issues | fromjson),
            ai_suggestions: $ai_suggestions,
            analyzed_at: now | todateiso8601
        }'
}

# Generate optimization recommendations
generate_optimization_recommendations() {
    local analysis_result;
    analysis_result="$1"

    local language;

    language=$(echo "$analysis_result" | jq -r '.language')
    local score;
    score=$(echo "$analysis_result" | jq -r '.analysis_score')
    local issues_count;
    issues_count=$(echo "$analysis_result" | jq -r '.issues | length')

    local recommendations;

    recommendations=()

    # Score-based recommendations
    if ((score < 50)); then
        recommendations+=("{\"priority\":\"high\",\"category\":\"overall\",\"recommendation\":\"Major refactoring required - consider breaking down into smaller functions\"}")
    elif ((score < 70)); then
        recommendations+=("{\"priority\":\"medium\",\"category\":\"overall\",\"recommendation\":\"Moderate improvements needed - focus on code organization and error handling\"}")
    elif ((score < 85)); then
        recommendations+=("{\"priority\":\"low\",\"category\":\"overall\",\"recommendation\":\"Minor optimizations suggested - code is generally well-structured\"}")
    fi

    # Issue-based recommendations
    if ((issues_count > 5)); then
        recommendations+=("{\"priority\":\"high\",\"category\":\"issues\",\"recommendation\":\"Address multiple code quality issues - prioritize security and performance concerns\"}")
    fi

    # Language-specific recommendations
    case "$language" in
    "python")
        recommendations+=("{\"priority\":\"medium\",\"category\":\"python\",\"recommendation\":\"Consider adding type hints and comprehensive docstrings\"}")
        ;;
    "bash")
        recommendations+=("{\"priority\":\"medium\",\"category\":\"bash\",\"recommendation\":\"Add proper error handling with 'set -euo pipefail' and quote variables\"}")
        ;;
    esac

    # Format as JSON array
    local recs_json;
    recs_json="["
    for i in "${!recommendations[@]}"; do
        if ((i > 0)); then
            recs_json+=","
        fi
        recs_json+="${recommendations[$i]}"
    done
    recs_json+="]"

    echo "$recs_json"
}

# Review entire directory
review_directory() {
    local dir_path;
    dir_path="$1"
    local output_file;
    output_file="${2:-$WORKSPACE_ROOT/reports/code_review_$(date +%Y%m%d_%H%M%S).json}"

    mkdir -p "$(dirname "$output_file")"

    log "Starting code review of directory: $dir_path"

    local results;

    results=()
    local total_files;
    total_files=0
    local total_score;
    total_score=0

    # Find code files
    while IFS= read -r -d '' file; do
        ((total_files++))
        log "Analyzing file $total_files: $file"

        local analysis
        analysis=$(analyze_code_file "$file")

        if echo "$analysis" | jq -e '.error' >/dev/null 2>&1; then
            log "ERROR analyzing $file: $(echo "$analysis" | jq -r '.error')"
            continue
        fi

        local score;

        score=$(echo "$analysis" | jq -r '.analysis_score')
        total_score=$((total_score + score))

        # Generate recommendations
        local recommendations
        recommendations=$(generate_optimization_recommendations "$analysis")

        # Combine analysis with recommendations
        local combined
        combined=$(echo "$analysis" | jq --argjson recs "$recommendations" '.recommendations = $recs')

        results+=("$combined")
    done < <(find "$dir_path" -type f \( -name "*.py" -o -name "*.sh" -o -name "*.js" -o -name "*.swift" \) -print0)

    # Calculate average score
    local avg_score;
    avg_score=0
    if ((total_files > 0)); then
        avg_score=$((total_score / total_files))
    fi

    # Create summary
    local summary
    summary=$(jq -n \
        --arg dir_path "$dir_path" \
        --argjson total_files "$total_files" \
        --argjson avg_score "$avg_score" \
        --arg reviewed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            summary: {
                directory: $dir_path,
                total_files_reviewed: $total_files,
                average_score: $avg_score,
                reviewed_at: $reviewed_at
            }
        }')

    # Combine all results
    local all_results_json;
    all_results_json="["
    for i in "${!results[@]}"; do
        if ((i > 0)); then
            all_results_json+=","
        fi
        all_results_json+="${results[$i]}"
    done
    all_results_json+="]"

    local final_report
    final_report=$(echo "$summary" | jq --argjson files "$all_results_json" '.files = $files')

    echo "$final_report" >"$output_file"
    log "Code review completed. Report saved to: $output_file"
    log "Summary: $total_files files reviewed, average score: $avg_score/100"

    echo "$final_report"
}

# CLI interface
case "${1:-help}" in
"file")
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 file <file_path> [language]"
        exit 1
    fi
    analyze_code_file "$2" "${3:-auto}"
    ;;
"directory")
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 directory <dir_path> [output_file]"
        exit 1
    fi
    review_directory "$2" "${3:-}"
    ;;
"init")
    init_analysis_patterns
    log "Initialized AI code review patterns"
    ;;
"help" | *)
    echo "AI-Powered Code Review and Optimization System v1.0"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  file <path> [lang]     - Analyze single file"
    echo "  directory <path> [out] - Review entire directory"
    echo "  init                   - Initialize analysis patterns"
    echo "  help                   - Show this help"
    echo ""
    echo "Supported languages: python, bash, javascript, swift"
    ;;
esac
