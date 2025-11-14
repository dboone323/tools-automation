#!/usr/bin/env bash
# Generates test suites for each .auto_restart_*.sh marker file in agents/
# Usage: bash tests/generate_auto_restart_marker_tests.sh

# set -euo pipefail  # Disabled to handle missing agents gracefully

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="$ROOT_DIR/agents"
TESTS_DIR="$ROOT_DIR/tests"
FRAMEWORK="$ROOT_DIR/shell_test_framework.sh"

if [[ ! -d "$AGENTS_DIR" ]]; then
    echo "Agents directory not found: $AGENTS_DIR"
    exit 1
fi

mkdir -p "$TESTS_DIR"

count=0
for marker in "$AGENTS_DIR"/.auto_restart_*.sh; do
    # If glob didn't match, skip
    [[ -e "$marker" ]] || continue

    marker_base="$(basename "$marker")"
    # Remove .sh extension for test filename
    marker_name="${marker_base%.sh}"
    # Derive a safe test filename: test_agents_<marker_name>.sh
    test_filename="$TESTS_DIR/test_agents_${marker_name}.sh"

    # Derive corresponding agent name by removing leading .auto_restart_
    agent_name="${marker_base#.auto_restart_}"

    # If test already exists, skip
    if [[ -f "$test_filename" ]]; then
        echo "Skipping existing test: $(basename "$test_filename")"
        continue
    fi

    cat >"$test_filename" <<EOF
#!/bin/bash
# Auto-generated test for $marker_base
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
MARKER_FILE="\$SCRIPT_DIR/agents/$marker_base"
AGENT_FILE="\$SCRIPT_DIR/agents/$agent_name"

# Source test framework
source "\$SCRIPT_DIR/shell_test_framework.sh"

run_tests() {
    announce_test "check_marker_$(echo "$marker_name" | sed 's/[^a-zA-Z0-9_]/_/g')"

    assert_file_exists "\$MARKER_FILE" "Marker file should exist"
    assert_file_executable "\$MARKER_FILE" "Marker file should be executable"

    local content
    content=\$(cat "\$MARKER_FILE" 2>/dev/null || echo "")
    assert_contains "\$content" "exit 0" "Marker file should exit 0"

    assert_file_exists "\$AGENT_FILE" "Corresponding agent should exist"
    assert_file_executable "\$AGENT_FILE" "Corresponding agent should be executable"

    test_passed "check_marker_$(echo "$marker_name" | sed 's/[^a-zA-Z0-9_]/_/g')"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
    exit 0
fi
EOF

    chmod +x "$test_filename"
    echo "Generated: $(basename "$test_filename")"
    ((count++))
done

echo "Generation complete. Tests created: $count"
exit 0
