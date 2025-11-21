#!/usr/bin/env bash
# Automated Agent Syntax Fixer
# Identifies and fixes common syntax errors in agent scripts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(dirname "$SCRIPT_DIR")/agents"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Agent Syntax Error Fixer                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

FIXED_COUNT=0
SKIP_COUNT=0
MANUAL_COUNT=0

fix_agent_syntax() {
    local agent_file="$1"
    local agent_name=$(basename "$agent_file")
    
    # Check if already valid
    if bash -n "$agent_file" 2>/dev/null; then
        echo "  ✅ $agent_name - Already valid"
        ((SKIP_COUNT++))
        return 0
    fi
    
    echo "  🔧 $agent_name - Attempting fix..."
    
    # Get error details
    local error_output
    error_output=$(bash -n "$agent_file" 2>&1 || true)
    
    # Create backup
    cp "$agent_file" "${agent_file}.syntax_backup.$(date +%Y%m%d_%H%M%S)"
    
    # Common fix 1: Missing 'fi' for if statements
    if echo "$error_output" | grep -q "unexpected end of file.*if"; then
        # Count if/fi statements
        local if_count=$(grep -c "^[[:space:]]*if " "$agent_file" || true)
        local fi_count=$(grep -c "^[[:space:]]*fi" "$agent_file" || true)
        
        if [[ $if_count -gt $fi_count ]]; then
            local missing=$((if_count - fi_count))
            echo "    Missing $missing 'fi' statement(s), adding..."
            
            # Add missing 'fi' at end of file
            for ((i=0; i<missing; i++)); do
                echo "fi" >> "$agent_file"
            done
            
            if bash -n "$agent_file" 2>/dev/null; then
                echo "    ✅ Fixed by adding 'fi'"
                ((FIXED_COUNT++))
                return 0
            fi
        fi
    fi
    
    # Common fix 2: Missing 'done' for loops
    if echo "$error_output" | grep -q "unexpected end of file.*do\|for\|while"; then
        local do_count=$(grep -c "^[[:space:]]*do$\|; do$" "$agent_file" || true)
        local done_count=$(grep -c "^[[:space:]]*done" "$agent_file" || true)
        
        if [[ $do_count -gt $done_count ]]; then
            local missing=$((do_count - done_count))
            echo "    Missing $missing 'done' statement(s), adding..."
            
            for ((i=0; i<missing; i++)); do
                echo "done" >> "$agent_file"
            done
            
            if bash -n "$agent_file" 2>/dev/null; then
                echo "    ✅ Fixed by adding 'done'"
                ((FIXED_COUNT++))
                return 0
            fi
        fi
    fi
    
    # Common fix 3: Missing closing brace
    if echo "$error_output" | grep -q "unexpected end of file"; then
        local open_braces=$(grep -o "{" "$agent_file" | wc -l)
        local close_braces=$(grep -o "}" "$agent_file" | wc -l)
        
        if [[ $open_braces -gt $close_braces ]]; then
            local missing=$((open_braces - close_braces))
            echo "    Missing $missing closing brace(s), adding..."
            
            for ((i=0; i<missing; i++)); do
                echo "}" >> "$agent_file"
            done
            
            if bash -n "$agent_file" 2>/dev/null; then
                echo "    ✅ Fixed by adding '}'"
                ((FIXED_COUNT++))
                return 0
            fi
        fi
    fi
    
    # If automatic fixes didn't work, restore backup
    local latest_backup=$(ls -t "${agent_file}.syntax_backup."* 2>/dev/null | head -1)
    if [[ -n "$latest_backup" ]]; then
        cp "$latest_backup" "$agent_file"
    fi
    
    echo "    ⚠️ Requires manual fix"
    echo "       Error: $(echo "$error_output" | head -1)"
    ((MANUAL_COUNT++))
    return 1
}

# Find all agent files
echo "Scanning agents directory..."
AGENT_FILES=(../agents/agent_*.sh)

for agent in "${AGENT_FILES[@]}"; do
    if [[ -f "$agent" ]]; then
        fix_agent_syntax "$agent"
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   Fix Complete                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Results:"
echo "  ✅ Already valid: $SKIP_COUNT"
echo "  🔧 Auto-fixed: $FIXED_COUNT"
echo "  ⚠️  Need manual fix: $MANUAL_COUNT"
echo ""

if [[ $MANUAL_COUNT -gt 0 ]]; then
    echo "⚠️  Some agents require manual fixes."
    echo "    Review error messages above for details."
fi

echo ""
echo "Running final validation..."
error_count=0
for agent in "${AGENT_FILES[@]}"; do
    if [[ -f "$agent" ]] && ! bash -n "$agent" 2>/dev/null; then
        ((error_count++))
    fi
done

if [[ $error_count -eq 0 ]]; then
    echo "✅ All agents now have valid syntax!"
else
    echo "❌ $error_count agents still have syntax errors"
fi
