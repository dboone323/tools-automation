#!/bin/bash
# Manual TODO Injection Script
# Usage: ./inject_todo.sh "file/path" "line_number" "todo_description" ["priority"] ["project"]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents"

# Source the agent functions
source "${AGENTS_DIR}/agent_todo.sh"

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <file_path> <line_number> <todo_description> [priority] [project]"
    echo "Example: $0 'Projects/CodingReviewer/main.swift' 42 'Add error handling' high CodingReviewer"
    exit 1
fi

FILE_PATH="$1"
LINE_NUMBER="$2"
TODO_TEXT="$3"
PRIORITY="${4:-medium}"
PROJECT="${5:-}"

echo "Injecting manual TODO:"
echo "  File: $FILE_PATH"
echo "  Line: $LINE_NUMBER"
echo "  Text: $TODO_TEXT"
echo "  Priority: $PRIORITY"
echo "  Project: $PROJECT"

if inject_manual_todo "$FILE_PATH" "$LINE_NUMBER" "$TODO_TEXT" "$PRIORITY" "$PROJECT"; then
    echo "✅ Manual TODO injected successfully"
else
    echo "❌ Failed to inject manual TODO"
    exit 1
fi
