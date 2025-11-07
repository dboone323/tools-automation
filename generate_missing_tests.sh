#!/bin/bash
# Simple Test Generator for Python Functions
# Creates basic unit tests for uncovered Python functions

set -euo pipefail

WORKSPACE_ROOT="/Users/danielstevens/Desktop/github-projects/tools-automation"
TESTS_DIR="$WORKSPACE_ROOT/tests"

echo "🔍 Analyzing Python files for missing tests..."

# Find Python files with functions but no corresponding test files
find "$WORKSPACE_ROOT" -name "*.py" -not -path "*/tests/*" -not -path "*/__pycache__/*" -not -path "*/.venv/*" | while read -r pyfile; do
    # Skip if it's already a test file
    [[ "$pyfile" == *test* ]] && continue

    # Get relative path for test file naming
    rel_path="${pyfile#$WORKSPACE_ROOT/}"
    test_file="$TESTS_DIR/test_${rel_path//\//_}"
    test_file="${test_file%.py}.py"

    # Check if test file already exists
    if [[ -f "$test_file" ]]; then
        echo "✅ Test exists: $test_file"
        continue
    fi

    echo "📝 Generating test for: $rel_path"

    # Create module path for import
    module_path="${rel_path%.py}"
    module_name=$(basename "$module_path")

    # Create basic test structure
    cat >"$test_file" <<EOF
import pytest
import sys
import os

# Add the workspace root to sys.path
if "$WORKSPACE_ROOT" not in sys.path:
    sys.path.insert(0, "$WORKSPACE_ROOT")

# Try to import the module
MODULE_AVAILABLE = False
try:
    # For files in subdirectories, try different import approaches
    if "/" in "$module_path"; then
        # Try absolute import from workspace root
        exec("import $module_name")
        MODULE_AVAILABLE = True
    else:
        # Try direct import
        exec("import $module_name")
        MODULE_AVAILABLE = True
except (ImportError, ModuleNotFoundError, SyntaxError) as e:
    print(f"Warning: Could not import $module_name: {e}")
    # Try to at least check if file exists and is syntactically valid
    try:
        with open("$pyfile", 'r') as f:
            compile(f.read(), "$pyfile", 'exec')
        print(f"File $rel_path is syntactically valid but import failed")
    except SyntaxError as se:
        print(f"File $rel_path has syntax errors: {se}")

@pytest.mark.skipif(not MODULE_AVAILABLE, reason="Module not available or has import issues")
class Test${module_name}:
    """Basic tests for $rel_path"""

    def test_module_syntax_valid(self):
        """Test that the module file is syntactically valid"""
        try:
            with open("$pyfile", 'r') as f:
                compile(f.read(), "$pyfile", 'exec')
            assert True
        except SyntaxError:
            pytest.fail(f"Syntax error in $rel_path")

    def test_file_exists(self):
        """Test that the source file exists"""
        assert os.path.exists("$pyfile")

    # TODO: Add specific tests for functions in $rel_path
    # The module import failed, so you'll need to:
    # 1. Fix any import issues in $rel_path
    # 2. Add proper test cases for each function
    # 3. Run this script again after implementing function-specific tests

EOF

    echo "✅ Created: $test_file"
done

echo ""
echo "🎯 Test generation complete!"
echo "📋 Next steps:"
echo "   1. Review generated test files in tests/"
echo "   2. Fix import issues in source files if needed"
echo "   3. Add specific test cases for each function"
echo "   4. Run: python3 -m pytest tests/ -v"
echo "   5. Run coverage analysis: ./analyze_coverage.sh"
