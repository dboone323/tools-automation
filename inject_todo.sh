#!/bin/bash
# Manual TODO Injection Agent
# Allows manual injection of TODO items into the TODO processing system

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define agents directory
AGENTS_DIR="${SCRIPT_DIR}/agents"

# Source the main TODO processing agent for functionality
source "${AGENTS_DIR}/agent_todo.sh"

# Check argument count - need at least file path, line number, and TODO text
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <file_path> <line_number> <todo_text> [priority] [project]"
    echo "  file_path: Path to the file where TODO should be injected"
    echo "  line_number: Line number in the file"
    echo "  todo_text: Description of the TODO item"
    echo "  priority: Optional priority (high/medium/low, default: medium)"
    echo "  project: Optional project name"
    exit 1
fi

# Parse arguments
FILE_PATH="$1"
LINE_NUMBER="$2"
TODO_TEXT="$3"
PRIORITY="${4:-medium}"
PROJECT="${5:-}"

# Validate line number is numeric
if ! [[ "$LINE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: Line number must be a positive integer"
    exit 1
fi

# Validate priority
if [[ "$PRIORITY" != "high" && "$PRIORITY" != "medium" && "$PRIORITY" != "low" ]]; then
    echo "Error: Priority must be 'high', 'medium', or 'low'"
    exit 1
fi

# Inject the manual TODO
if inject_manual_todo "$FILE_PATH" "$LINE_NUMBER" "$TODO_TEXT" "$PRIORITY" "$PROJECT"; then
    echo "✅ Successfully injected TODO: $TODO_TEXT"
    echo "   File: $FILE_PATH"
    echo "   Line: $LINE_NUMBER"
    echo "   Priority: $PRIORITY"
    [[ -n "$PROJECT" ]] && echo "   Project: $PROJECT"
else
    echo "❌ Failed to inject TODO"
    exit 1
fi
