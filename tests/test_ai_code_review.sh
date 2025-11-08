#!/bin/bash

# Test suite for ai_code_review.sh
# Comprehensive tests covering all functionality

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shell_test_framework.sh"

# Override PROJECT_ROOT for this test
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AI_REVIEW_SCRIPT="$PROJECT_ROOT/ai_code_review.sh"

# Test: Basic AI code review functionality (requires Ollama)
test_ai_code_review_basic() {
    echo "Testing basic AI code review functionality..."

    # Skip if Ollama is not available or no suitable models
    if ! curl -sf "${OLLAMA_URL:-http://localhost:11434}/api/tags" >/dev/null 2>&1; then
        echo "Skipping test: Ollama not available"
        assert_success "Test skipped - Ollama not available"
        return 0
    fi

    # Check if we have a suitable model
    local available_models
    available_models=$(curl -sf "${OLLAMA_URL:-http://localhost:11434}/api/tags" | jq -r '.models[]?.name' 2>/dev/null || echo "")
    local has_model=false
    for model in codellama:7b llama3.2:3b mistral:7b; do
        if echo "$available_models" | grep -q "$model"; then
            has_model=true
            break
        fi
    done

    if [[ "$has_model" != "true" ]]; then
        echo "Skipping test: No suitable Ollama models available"
        assert_success "Test skipped - No suitable models"
        return 0
    fi

    # Create a temporary directory for testing
    local test_dir="/tmp/test_ai_review_basic"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize a git repo
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1

    # Create initial commit
    echo "initial content" >test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1

    # Make changes
    echo "modified content" >test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "Modified content" >/dev/null 2>&1

    # Run review with timeout to avoid hanging
    local exit_code=0
    timeout 120 "$AI_REVIEW_SCRIPT" >/dev/null 2>&1 || exit_code=$?

    # Check if review completed successfully (exit code 0 for APPROVED/NEEDS_CHANGES, 1 for BLOCKED)
    if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 1 ]]; then
        assert_success "AI code review executed (exit code: $exit_code)"
    else
        assert_failure "AI code review failed with unexpected exit code: $exit_code"
    fi

    # Clean up
    cd - >/dev/null 2>&1
    rm -rf "$test_dir"
}

# Test: No changes detected
test_ai_code_review_no_changes() {
    echo "Testing AI code review with no changes..."

    # Create a temporary directory for testing
    local test_dir="/tmp/test_ai_review_no_changes"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize a git repo
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1

    # Create initial commit
    echo "content" >test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1

    # Run review on same commit (no changes)
    local output
    output=$("$AI_REVIEW_SCRIPT" HEAD HEAD 2>/dev/null)

    # Should detect no changes
    if echo "$output" | grep -q "NO_CHANGES"; then
        assert_success "No changes correctly detected"
    else
        assert_failure "No changes detection failed"
    fi

    # Clean up
    cd - >/dev/null 2>&1
    rm -rf "$test_dir"
}

# Test: Ollama server not available
test_ai_code_review_ollama_down() {
    echo "Testing AI code review with Ollama server down..."

    # Skip if Ollama is actually available
    if curl -sf "${OLLAMA_URL:-http://localhost:11434}/api/tags" >/dev/null 2>&1; then
        echo "Skipping test: Ollama is available"
        assert_success "Test skipped - Ollama available"
        return 0
    fi

    # Create a temporary directory for testing
    local test_dir="/tmp/test_ai_review_ollama_down"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize a git repo
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1

    # Create initial commit
    echo "content" >test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1

    # Make changes
    echo "modified" >test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "Modified" >/dev/null 2>&1

    # Run review with invalid Ollama URL
    local output
    OLLAMA_URL="http://invalid-url:9999" \
        output=$("$AI_REVIEW_SCRIPT" HEAD~1 HEAD 2>&1)

    # Should fail due to Ollama not available
    if echo "$output" | grep -q "Cannot proceed without Ollama"; then
        assert_success "Ollama unavailable error handled"
    else
        assert_failure "Ollama unavailable error not handled"
    fi

    # Clean up
    cd - >/dev/null 2>&1
    rm -rf "$test_dir"
}

# Test: Command line argument parsing
test_ai_code_review_arguments() {
    echo "Testing command line argument parsing..."

    # Test help option
    local output
    output=$("$AI_REVIEW_SCRIPT" --help 2>/dev/null)

    if echo "$output" | grep -q "Usage:"; then
        assert_success "Help option works"
    else
        assert_failure "Help option failed"
    fi

    # Test invalid option
    output=$("$AI_REVIEW_SCRIPT" --invalid 2>&1)

    if echo "$output" | grep -q "Unknown option"; then
        assert_success "Invalid option handled"
    else
        assert_failure "Invalid option not handled"
    fi
}

# Test: Review file saving
test_ai_code_review_file_saving() {
    echo "Testing review file saving..."

    # Skip if Ollama is not available or no suitable models
    if ! curl -sf "${OLLAMA_URL:-http://localhost:11434}/api/tags" >/dev/null 2>&1; then
        echo "Skipping test: Ollama not available"
        assert_success "Test skipped - Ollama not available"
        return 0
    fi

    # Check if we have a suitable model
    local available_models
    available_models=$(curl -sf "${OLLAMA_URL:-http://localhost:11434}/api/tags" | jq -r '.models[]?.name' 2>/dev/null || echo "")
    local has_model=false
    for model in codellama:7b llama3.2:3b mistral:7b; do
        if echo "$available_models" | grep -q "$model"; then
            has_model=true
            break
        fi
    done

    if [[ "$has_model" != "true" ]]; then
        echo "Skipping test: No suitable Ollama models available"
        assert_success "Test skipped - No suitable models"
        return 0
    fi

    # Create a temporary directory for testing
    local test_dir="/tmp/test_ai_review_files"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize a git repo
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1

    # Create initial commit
    echo "content" >test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1

    # Make changes
    echo "modified content" >test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "Modified content" >/dev/null 2>&1

    # Run review with timeout to avoid hanging
    local exit_code=0
    local review_dir="/tmp/test_reviews_$(date +%s)"
    REVIEW_DIR="$review_dir" timeout 120 "$AI_REVIEW_SCRIPT" >/dev/null 2>&1 || exit_code=$?

    # Check if review file was created
    if [[ -d "$review_dir" ]] && [[ $(find "$review_dir" -name "review_*.md" 2>/dev/null | wc -l) -gt 0 ]]; then
        assert_success "Review file saved correctly"
    else
        assert_failure "Review file not saved (exit code: $exit_code)"
    fi

    # Clean up
    cd - >/dev/null 2>&1
    rm -rf "$test_dir" "$review_dir"
}

# Test: Different approval statuses
test_ai_code_review_approval_statuses() {
    echo "Testing different approval statuses..."

    # Skip if Ollama is not available or no suitable models
    if ! curl -sf "${OLLAMA_URL:-http://localhost:11434}/api/tags" >/dev/null 2>&1; then
        echo "Skipping test: Ollama not available"
        assert_success "Test skipped - Ollama not available"
        return 0
    fi

    # Check if we have a suitable model
    local available_models
    available_models=$(curl -sf "${OLLAMA_URL:-http://localhost:11434}/api/tags" | jq -r '.models[]?.name' 2>/dev/null || echo "")
    local has_model=false
    for model in codellama:7b llama3.2:3b mistral:7b; do
        if echo "$available_models" | grep -q "$model"; then
            has_model=true
            break
        fi
    done

    if [[ "$has_model" != "true" ]]; then
        echo "Skipping test: No suitable Ollama models available"
        assert_success "Test skipped - No suitable models"
        return 0
    fi

    # Create a temporary directory for testing
    local test_dir="/tmp/test_ai_review_status"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize a git repo
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1

    # Create initial commit
    echo "content" >test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1

    # Make changes
    echo "modified content" >test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "Modified content" >/dev/null 2>&1

    # Run review with timeout to avoid hanging
    local output
    output=$(timeout 120 "$AI_REVIEW_SCRIPT" 2>&1)

    # Check if it contains approval status information
    if echo "$output" | grep -q "Status:"; then
        assert_success "Approval status handled correctly"
    else
        assert_failure "Approval status not handled correctly"
    fi

    # Clean up
    cd - >/dev/null 2>&1
    rm -rf "$test_dir"
}

# Test: Git diff failure
test_ai_code_review_git_failure() {
    echo "Testing AI code review with git failure..."

    # Create a temporary directory (not a git repo)
    local test_dir="/tmp/test_ai_review_git_fail"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Run review without git repo
    local output
    output=$("$AI_REVIEW_SCRIPT" HEAD~1 HEAD 2>&1)

    # Should fail due to git error
    if echo "$output" | grep -q "Failed to get git diff"; then
        assert_success "Git failure handled correctly"
    else
        assert_failure "Git failure not handled"
    fi

    # Clean up
    cd - >/dev/null 2>&1
    rm -rf "$test_dir"
}
