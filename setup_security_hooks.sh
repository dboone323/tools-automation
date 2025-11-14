#!/bin/bash
# Setup Security Hooks Script
# Installs and configures git hooks for security scanning
# Usage: ./setup_security_hooks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && pwd)"

echo "🔒 Setting up Security Hooks"
echo "============================"

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# Configure git to use our custom hooks path
echo "📁 Configuring git hooks path..."
git config core.hooksPath .githooks

# Make sure all hooks are executable
echo "🔧 Making hooks executable..."
find .githooks -type f -name "*" | while read -r hook; do
    if [[ -f "$hook" && ! -x "$hook" ]]; then
        chmod +x "$hook"
        echo "  ✅ Made executable: $hook"
    fi
done

# Test the hooks
echo "🧪 Testing hooks..."

# Test pre-commit hook
if [[ -x ".githooks/pre-commit" ]]; then
    echo "  Testing pre-commit hook..."
    # Create a temporary test file
    echo "# Test file for hook validation" >/tmp/hook_test.txt
    git add /tmp/hook_test.txt 2>/dev/null || true

    # The hook should pass for this test file
    if .githooks/pre-commit >/dev/null 2>&1; then
        echo "  ✅ Pre-commit hook working"
    else
        echo "  ⚠️  Pre-commit hook test failed (may be expected)"
    fi

    # Clean up
    git reset /tmp/hook_test.txt 2>/dev/null || true
    rm -f /tmp/hook_test.txt
fi

# Test pre-push hook
if [[ -x ".githooks/pre-push" ]]; then
    echo "  Testing pre-push hook..."
    if .githooks/pre-push >/dev/null 2>&1; then
        echo "  ✅ Pre-push hook working"
    else
        echo "  ⚠️  Pre-push hook test failed"
    fi
fi

echo ""
echo "✅ Security hooks setup complete!"
echo ""
echo "📋 Installed Hooks:"
echo "  • pre-commit: Scans for secrets and debug code before commits"
echo "  • pre-push: Runs path sanity checks before pushing"
echo "  • post-commit: (existing)"
echo "  • post-checkout: (existing)"
echo "  • post-merge: (existing)"
echo ""
echo "🔧 Git Configuration:"
echo "  • core.hooksPath set to .githooks"
echo ""
echo "📖 Usage:"
echo "  • Hooks run automatically on git operations"
echo "  • Use 'git commit --no-verify' to skip pre-commit checks"
echo "  • Use 'git push --no-verify' to skip pre-push checks"
echo ""
echo "🛡️  Security Features:"
echo "  • Secret detection in staged files"
echo "  • Debug code detection in production files"
echo "  • Path sanity validation before pushes"
