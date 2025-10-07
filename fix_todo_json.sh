#!/bin/bash
# Tools/Automation/fix_todo_json.sh
# Fix malformed JSON in todo-tree-output.json

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TODO_FILE="${CODE_DIR}/Projects/todo-tree-output.json"
FIXED_FILE="${TODO_FILE}.fixed"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
  echo -e "${BLUE}[JSON-FIX]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Fix the malformed JSON
fix_json() {
  print_status "Fixing malformed JSON structure..."

  # Use sed to add missing commas between objects
  # The pattern is: } followed by newline and { without a comma
  sed 's/}\s*$/},/g; $s/,$//' "${TODO_FILE}" >"${FIXED_FILE}"

  # Validate the fixed JSON
  if jq empty "${FIXED_FILE}" 2>/dev/null; then
    print_success "JSON structure fixed successfully"
    mv "${FIXED_FILE}" "${TODO_FILE}"
    print_success "Original file replaced with fixed version"
  else
    print_error "JSON still invalid after fix attempt"
    rm -f "${FIXED_FILE}"
    exit 1
  fi
}

# Main execution
main() {
  print_status "Starting JSON fix for todo-tree-output.json..."

  if [[ ! -f "${TODO_FILE}" ]]; then
    print_error "TODO file not found: ${TODO_FILE}"
    exit 1
  fi

  # Test if JSON is valid
  if jq empty "${TODO_FILE}" 2>/dev/null; then
    print_success "JSON is already valid"
    exit 0
  else
    print_status "JSON is malformed, attempting to fix..."
    fix_json
  fi
}

# Run main if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
