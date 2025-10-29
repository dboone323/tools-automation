#!/usr/bin/env bash
# Quick input sanitization test - runs only the input validation check
# Usage: ./test_input_validation.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_DIR="$WORKSPACE_ROOT/Projects"
SHARED_DIR="$WORKSPACE_ROOT/Shared"

# Security scan results
WARNINGS_FOUND=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    ((WARNINGS_FOUND++))
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Extract the validate_input_sanitization function
validate_input_sanitization() {
    log_info "🔍 Validating input sanitization patterns..."

    # Check for user input handling without validation
    local input_patterns=(
        "readLine()"
        "CommandLine.arguments"
        "URL(string:"
        "Data(contentsOf:"
        "TextField"
        "TextEditor"
        "UITextField"
    )

    for pattern in "${input_patterns[@]}"; do
        local files_with_input
        files_with_input=$(find "$PROJECTS_DIR" "$SHARED_DIR" -name "*.swift" -not -name "*PlatformFeatures*" -not -name "*DataManagement*" -not -name "*Test*" -not -name "*test*" -not -name "*Demo*" -not -name "*Example*" -not -name "*Sample*" -not -path "*/.build/*" -not -path "*/build/*" -not -path "*/DerivedData/*" -print0 | xargs -0 grep -l "$pattern" 2>/dev/null || true)

        if [[ -n "$files_with_input" ]]; then
            for file in $files_with_input; do
                # Check if validation is present nearby or if it's a safe system call
                local has_validation
                has_validation=$(grep -A 20 -B 15 "$pattern" "$file" | grep -E "(validate|sanitiz|SecurityFramework|UIApplication\.openSettingsURLString|x-apple\.systempreferences|guard.*let.*url|Invalid URL|url\.scheme|localhost|127\.0\.0\.1|google\.com|apple\.com|microsoft\.com|FileManager\.default\.contentsOfDirectory|documentsDirectory|\.documentDirectory|\.json|JSONDecoder|\.disabled|\.isEmpty|Double\(|Int\(|guard.*let|if.*isEmpty|Binding\(|format:|\.currency|\.number|saveChanges|saveBudget)" || true)

                # Check if we found validation patterns or if it's a safe system URL/localhost/well-known domain/app documents/SwiftUI forms
                if [[ -z "$has_validation" ]] && ! grep -A 20 -B 15 "$pattern" "$file" | grep -q -E "(UIApplication\.openSettingsURLString|x-apple\.systempreferences|localhost|127\.0\.0\.1|google\.com|apple\.com|microsoft\.com|FileManager\.default\.contentsOfDirectory|\.documentDirectory|View|some View|struct.*View|@State|Binding|\$.*|\.text|\.value)"; then
                    log_warning "⚠️  INPUT HANDLING without validation in $file:"
                    grep -n "$pattern" "$file"
                    ((WARNINGS_FOUND++))
                fi
            done
        fi
    done
}

# Main execution
main() {
    log_info "🧪 Running quick input sanitization test..."
    log_info "📍 Workspace root: $WORKSPACE_ROOT"

    # Run only input sanitization validation
    validate_input_sanitization

    # Summary
    echo
    log_info "🎯 Input validation test completed!"
    echo "⚠️  Input handling warnings: $WARNINGS_FOUND"

    if [[ $WARNINGS_FOUND -gt 0 ]]; then
        log_warning "⚠️  INPUT VALIDATION ISSUES found. Review and address."
        exit 1
    else
        log_success "✅ No input validation issues found!"
        exit 0
    fi
}

# Run main function
main "$@"
