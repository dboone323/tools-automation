#!/bin/bash
# Tools/Automation/analyze_and_fix_todo_json.sh
# Use AI to analyze and fix issues in the todo-tree-output.json file

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TODO_FILE="${CODE_DIR}/Projects/todo-tree-output.json"
BACKUP_FILE="${TODO_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
ANALYSIS_FILE="${CODE_DIR}/Tools/Automation/todo_analysis_$(date +%Y%m%d).md"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_status() {
  echo -e "${BLUE}[TODO-ANALYSIS]${NC} $1"
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
  echo -e "${PURPLE}[🤖 AI-ANALYSIS]${NC} $1"
}

# Check if jq and ollama are available
check_dependencies() {
  if ! command -v jq >/dev/null 2>&1; then
    print_error "jq not found. Please install jq (brew install jq)"
    exit 1
  fi

  if ! command -v ollama >/dev/null 2>&1; then
    print_error "Ollama not found. Please install Ollama"
    exit 1
  fi

  if ! ollama list >/dev/null 2>&1; then
    print_warning "Starting Ollama server..."
    ollama serve &
    sleep 5
  fi
}

# Create backup of current todo file
create_backup() {
  print_status "Creating backup of current todo file..."
  cp "${TODO_FILE}" "${BACKUP_FILE}"
  print_success "Backup created: ${BACKUP_FILE}"
}

# Analyze the todo JSON file with AI
analyze_todo_file() {
  print_ai "Analyzing todo JSON file with AI..."

  # Get basic statistics
  local total_entries
  total_entries=$(jq '. | length' "${TODO_FILE}")
  local unique_files
  unique_files=$(jq '[.[].file] | unique | length' "${TODO_FILE}")
  local unique_texts
  unique_texts=$(jq '[.[].text] | unique | length' "${TODO_FILE}")

  print_status "Current statistics:"
  echo "  Total entries: ${total_entries}"
  echo "  Unique files: ${unique_files}"
  echo "  Unique texts: ${unique_texts}"

  # Sample some entries for AI analysis
  local sample_entries
  sample_entries=$(jq '.[0:20][] | {file: .file, text: .text}' "${TODO_FILE}")

  # Create analysis prompt
  local analysis_prompt="Analyze this TODO/FIXME JSON file and identify issues:

Current Statistics:
- Total entries: ${total_entries}
- Unique files: ${unique_files}
- Unique texts: ${unique_texts}

Sample entries:
${sample_entries}

Common issues to identify:
1. **Duplicate entries** - Same TODO appearing multiple times
2. **Non-TODO content** - Entries that aren't actual TODO/FIXME comments
3. **Agent-generated content** - TODOs from agent logs/status files
4. **Backup files** - TODOs from .backup, .bak, .orig files
5. **Documentation TODOs** - TODOs in .md files that aren't actionable
6. **Test file TODOs** - TODOs in test files that aren't real issues
7. **Malformed entries** - Entries with incorrect structure

Provide:
1. Summary of issues found
2. Specific cleanup recommendations
3. Priority order for fixes
4. Expected reduction in file size"

  # Get AI analysis
  local ai_analysis
  ai_analysis=$(echo "${analysis_prompt}" | ollama run qwen3-coder:480b-cloud 2>/dev/null || echo "AI analysis temporarily unavailable")

  # Save analysis
  {
    echo "# TODO JSON Analysis Report"
    echo "Generated: $(date)"
    echo ""
    echo "## Current Statistics"
    echo "- Total entries: ${total_entries}"
    echo "- Unique files: ${unique_files}"
    echo "- Unique texts: ${unique_texts}"
    echo ""
    echo "## AI Analysis"
    echo "${ai_analysis}"
  } >"${ANALYSIS_FILE}"

  print_success "Analysis saved to: ${ANALYSIS_FILE}"
}

# Clean up the todo file based on AI recommendations
cleanup_todo_file() {
  print_ai "Cleaning up todo file based on AI analysis..."

  # Create a temporary cleaned file
  local temp_file
  temp_file="${TODO_FILE}.temp"

  # Use jq to filter out problematic entries
  jq '
    # Filter out entries that match problematic patterns
    map(select(
      # Remove entries from agent/orchestrator files
      (.file | contains("orchestrator_status") | not) and
      (.file | contains("agent_") | not) and
      (.file | contains("Tools/agents/") | not) and

      # Remove entries from backup files
      (.file | contains(".backup") | not) and
      (.file | contains(".bak") | not) and
      (.file | contains(".orig") | not) and
      (.file | contains(".tmp") | not) and

      # Remove entries from documentation that are not real TODOs
      (.file | endswith(".md") | not) and

      # Remove entries that are clearly not TODO/FIXME comments
      (.text | startswith("TODO:") or startswith("FIXME:") or contains("TODO") or contains("FIXME")) and

      # Remove duplicate entries (keep first occurrence)
      true
    )) |

    # Remove duplicates based on file + line + text
    unique_by(.file + .line + .text)
  ' "${TODO_FILE}" >"${temp_file}"

  # Get statistics before and after
  local original_count
  original_count=$(jq '. | length' "${TODO_FILE}")
  local cleaned_count
  cleaned_count=$(jq '. | length' "${temp_file}")

  local reduction=$((original_count - cleaned_count))
  local reduction_percent=$((reduction * 100 / original_count))

  print_success "Cleanup completed:"
  echo "  Original entries: ${original_count}"
  echo "  Cleaned entries: ${cleaned_count}"
  echo "  Removed: ${reduction} entries (${reduction_percent}%)"

  # Replace original file
  mv "${temp_file}" "${TODO_FILE}"

  # Update analysis file
  {
    echo ""
    echo "## Cleanup Results"
    echo "- Original entries: ${original_count}"
    echo "- Cleaned entries: ${cleaned_count}"
    echo "- Entries removed: ${reduction} (${reduction_percent}%)"
    echo "- Backup file: ${BACKUP_FILE}"
  } >>"${ANALYSIS_FILE}"
}

# Generate AI-powered recommendations for remaining TODOs
generate_recommendations() {
  print_ai "Generating AI recommendations for remaining TODOs..."

  # Get a sample of remaining TODOs
  local remaining_todos
  remaining_todos=$(jq '.[0:10][] | {file: .file, text: .text}' "${TODO_FILE}")

  local rec_prompt="Based on these remaining TODO entries, provide recommendations:

${remaining_todos}

Recommendations should include:
1. **Priority assessment** - Which TODOs are most critical
2. **Categorization** - Group similar TODOs together
3. **Actionable next steps** - Specific recommendations for addressing them
4. **Agent assignment** - Which type of agent should handle each category
5. **Timeline estimates** - Rough time estimates for completion

Focus on the most impactful TODOs first."

  local ai_recommendations
  ai_recommendations=$(echo "${rec_prompt}" | ollama run qwen3-coder:480b-cloud 2>/dev/null || echo "Recommendations generation temporarily unavailable")

  # Add to analysis file
  {
    echo ""
    echo "## AI Recommendations for Remaining TODOs"
    echo "${ai_recommendations}"
  } >>"${ANALYSIS_FILE}"

  print_success "Recommendations added to analysis file"
}

# Main execution
main() {
  print_status "Starting AI-powered TODO JSON analysis and cleanup..."

  check_dependencies
  create_backup
  analyze_todo_file
  cleanup_todo_file
  generate_recommendations

  print_success "TODO JSON analysis and cleanup completed!"
  echo ""
  echo "📊 Analysis report: ${ANALYSIS_FILE}"
  echo "💾 Backup file: ${BACKUP_FILE}"
  echo "📝 Cleaned TODO file: ${TODO_FILE}"
}

# Run main if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
