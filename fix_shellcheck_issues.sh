#!/bin/bash
# Comprehensive Shell Script Linter and Fixer
# Fixes common shellcheck issues across all shell scripts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/shellcheck_fixes_$(date +%Y%m%d_%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $*" | tee -a "${LOG_FILE}"; }
success() { echo -e "${GREEN}[✓]${NC} $*" | tee -a "${LOG_FILE}"; }
warning() { echo -e "${YELLOW}[!]${NC} $*" | tee -a "${LOG_FILE}"; }
error() { echo -e "${RED}[✗]${NC} $*" | tee -a "${LOG_FILE}"; }

# Initialize log
echo "=== Shell Script Linting and Fixing Session ===" >"${LOG_FILE}"
echo "Started: $(date)" >>"${LOG_FILE}"
echo "" >>"${LOG_FILE}"

# Find all shell scripts
log "Finding all shell scripts..."
mapfile -t ALL_SCRIPTS < <(find "${SCRIPT_DIR}" -name "*.sh" -type f | grep -v -E '\.git|node_modules|__pycache__' | sort)
TOTAL_SCRIPTS=${#ALL_SCRIPTS[@]}

log "Found ${TOTAL_SCRIPTS} shell scripts to check"

# Function to fix SC2086 (word splitting)
fix_sc2086() {
    local file="$1"
    local temp_file="${file}.tmp"
    local changed=false

    # Create temp file with fixes
    cp "$file" "$temp_file"

    # Fix unquoted variables in xcrun commands
    sed -i '' "s/xcrun simctl install \$DEVICE_ID/xcrun simctl install \"\$DEVICE_ID\"/g" "$temp_file" 2>/dev/null || true
    sed -i '' "s/xcrun simctl launch \$DEVICE_ID/xcrun simctl launch \"\$DEVICE_ID\"/g" "$temp_file" 2>/dev/null || true
    sed -i '' "s/id=\$DEVICE_ID/id=\"\$DEVICE_ID\"/g" "$temp_file" 2>/dev/null || true
    sed -i '' "s/platform=iOS Simulator,id=\$DEVICE_ID/platform=iOS Simulator,id=\"\$DEVICE_ID\"/g" "$temp_file" 2>/dev/null || true

    # Check if file changed
    if ! cmp -s "$file" "$temp_file"; then
        mv "$temp_file" "$file"
        changed=true
    else
        rm -f "$temp_file"
    fi

    $changed && return 0 || return 1
}

# Function to fix SC2181 (exit code checking)
fix_sc2181() {
    local file="$1"
    local temp_file="${file}.tmp"
    local changed=false

    cp "$file" "$temp_file"

    # This is hard to fix automatically as it requires understanding the command context
    # Just mark as attempted
    rm -f "$temp_file"
    return 1
}

# Function to fix SC2155 (declare and assign separately)
fix_sc2155() {
    local file="$1"
    local temp_file="${file}.tmp"
    local changed=false

    cp "$file" "$temp_file"

    # Fix export assignments that use command substitution
    sed -i '' "s/export \([A-Z_][A-Z0-9_]*\)=\"\$(\(.*\))\"/\1=\"\$(\2)\"\nexport \1/g" "$temp_file" 2>/dev/null || true

    if ! cmp -s "$file" "$temp_file"; then
        mv "$temp_file" "$file"
        changed=true
    else
        rm -f "$temp_file"
    fi

    $changed && return 0 || return 1
}

# Function to fix syntax errors (quotes and braces)
fix_syntax_errors() {
    local file="$1"
    local temp_file="${file}.tmp"
    local changed=false

    cp "$file" "$temp_file"

    # Fix common brace/quote issues
    sed -i '' 's/${ $/${ $/g' "$temp_file" 2>/dev/null || true
    sed -i '' 's/}ME}/}ME"/g' "$temp_file" 2>/dev/null || true
    sed -i '' 's/}NA}/}NA"/g' "$temp_file" 2>/dev/null || true

    if ! cmp -s "$file" "$temp_file"; then
        mv "$temp_file" "$file"
        changed=true
    else
        rm -f "$temp_file"
    fi

    $changed && return 0 || return 1
}

# Function to check and fix a single file
check_and_fix_file() {
    local file="$1"
    local issues_before
    local issues_after
    local fixed_count=0

    # Skip if file doesn't exist or isn't readable
    [[ ! -f "$file" ]] && return 1
    [[ ! -r "$file" ]] && return 1

    # Count shellcheck issues
    local sc_output
    sc_output=$(shellcheck "$file" 2>&1)
    issues_before=$(echo "$sc_output" | grep -c "^.*SC[0-9]\+" 2>/dev/null)
    # Ensure it's numeric
    issues_before=$((issues_before + 0))

    if [[ "$issues_before" -eq 0 ]]; then
        return 0 # No issues
    fi

    log "Checking: $file ($issues_before issues)"

    # Create backup
    cp "$file" "${file}.backup"

    # Try to fix common issues
    if fix_sc2086 "$file"; then
        ((fixed_count++))
        log "  Fixed SC2086 issues in $file"
    fi

    if fix_sc2181 "$file"; then
        ((fixed_count++))
        log "  Fixed SC2181 issues in $file"
    fi

    if fix_sc2155 "$file"; then
        ((fixed_count++))
        log "  Fixed SC2155 issues in $file"
    fi

    if fix_syntax_errors "$file"; then
        ((fixed_count++))
        log "  Fixed syntax errors in $file"
    fi

    # Check issues after fixes
    local sc_output_after
    sc_output_after=$(shellcheck "$file" 2>&1)
    issues_after=$(echo "$sc_output_after" | grep -c "^.*SC[0-9]\+" 2>/dev/null)
    # Ensure it's numeric
    issues_after=$((issues_after + 0))

    # Convert to numbers for comparison (ensure they're numeric)
    local before_num=$issues_before
    local after_num=$issues_after

    if [[ $after_num -lt $before_num ]]; then
        success "  Reduced issues in $file: $before_num → $after_num"
        return 0
    elif [[ $after_num -eq $before_num ]]; then
        warning "  No automatic fixes applied to $file"
        return 1
    else
        error "  Issues increased in $file: $before_num → $after_num"
        # Restore backup
        mv "${file}.backup" "$file"
        return 1
    fi
}

# Main processing
total_processed=0
total_fixed=0

log "Starting comprehensive shell script fixing..."
log "Processing ${TOTAL_SCRIPTS} files..."

for script in "${ALL_SCRIPTS[@]}"; do
    ((total_processed++))

    if [[ $((total_processed % 50)) -eq 0 ]]; then
        log "Processed $total_processed/$TOTAL_SCRIPTS files..."
    fi

    if check_and_fix_file "$script"; then
        ((total_fixed++))
    fi
done

# Final statistics
log ""
log "=== FINAL STATISTICS ==="
log "Total scripts processed: $total_processed"
log "Scripts with fixes applied: $total_fixed"
log "Success rate: $((total_fixed * 100 / total_processed))%"

# Get final issue count
all_sc_output=$(find "${SCRIPT_DIR}" -name "*.sh" -type f -exec shellcheck {} \; 2>&1)
final_issues=$(echo "$all_sc_output" | grep -c "^.*SC[0-9]\+" 2>/dev/null || echo "0")
log "Remaining shellcheck issues: $final_issues"

success "Shell script fixing session complete!"
success "Log saved to: ${LOG_FILE}"

echo ""
echo "Summary:"
echo "- Processed: $total_processed scripts"
echo "- Fixed: $total_fixed scripts"
echo "- Remaining issues: $final_issues"
echo "- Log: ${LOG_FILE}"
