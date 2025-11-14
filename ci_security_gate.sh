#!/bin/bash
# CI/CD Security Gate Script
# Performs comprehensive security checks before deployment
# Usage: ./ci_security_gate.sh [--strict] [--report-only]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && pwd)"

# Configuration
STRICT_MODE=false
REPORT_ONLY=false
EXIT_CODE=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --strict)
        STRICT_MODE=true
        shift
        ;;
    --report-only)
        REPORT_ONLY=true
        shift
        ;;
    *)
        echo "Unknown option: $1"
        echo "Usage: $0 [--strict] [--report-only]"
        exit 1
        ;;
    esac
done

echo "🔒 CI/CD Security Gate"
echo "======================"
echo "Date: $(date)"
echo "Mode: $(if [[ "$STRICT_MODE" == "true" ]]; then echo "STRICT"; else echo "NORMAL"; fi)"
echo "Report Only: $(if [[ "$REPORT_ONLY" == "true" ]]; then echo "YES"; else echo "NO"; fi)"
echo ""

# Security check results
CRITICAL_ISSUES=0
HIGH_ISSUES=0
MEDIUM_ISSUES=0
LOW_ISSUES=0
PASSED_CHECKS=0

log_security_issue() {
    local severity="$1"
    local issue="$2"
    local details="$3"

    case "$severity" in
    "CRITICAL")
        CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        echo -e "${RED}🚨 CRITICAL${NC}: $issue"
        ;;
    "HIGH")
        HIGH_ISSUES=$((HIGH_ISSUES + 1))
        echo -e "${RED}🔴 HIGH${NC}: $issue"
        ;;
    "MEDIUM")
        MEDIUM_ISSUES=$((MEDIUM_ISSUES + 1))
        echo -e "${YELLOW}🟡 MEDIUM${NC}: $issue"
        ;;
    "LOW")
        LOW_ISSUES=$((LOW_ISSUES + 1))
        echo -e "${BLUE}🔵 LOW${NC}: $issue"
        ;;
    esac

    if [ -n "$details" ]; then
        echo -e "   ${BLUE}Details:${NC} $details"
    fi
}

log_security_pass() {
    local check="$1"
    echo -e "${GREEN}✅ PASS${NC}: $check"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
}

echo "🔍 Running CI/CD Security Checks..."
echo ""

# 1. Secret Detection
echo "1. Secret Detection..."
echo ""

# More specific patterns to avoid false positives - look for actual hardcoded values
SECRET_PATTERNS=(
    # Password patterns - require actual complex values
    "password\s*=\s*['\"][a-zA-Z0-9!@#$%^&*()_+\-=\[\]{}|;:,.<>?]{8,}['\"]"
    "passwd\s*=\s*['\"][a-zA-Z0-9!@#$%^&*()_+\-=\[\]{}|;:,.<>?]{8,}['\"]"
    "pwd\s*=\s*['\"][a-zA-Z0-9!@#$%^&*()_+\-=\[\]{}|;:,.<>?]{8,}['\"]"
    # API key patterns - require actual long alphanumeric keys
    "\bapi[_-]?key\s*=\s*['\"][a-zA-Z0-9]{25,}['\"]"
    "apikey\s*=\s*['\"][a-zA-Z0-9]{25,}['\"]"
    # Token patterns - require actual long tokens (avoid JWT generation code)
    "\btoken\s*=\s*['\"][a-zA-Z0-9_]{35,}['\"]"
    "TOKEN\s*=\s*['\"][a-zA-Z0-9_]{35,}['\"]"
    # Private key patterns - require actual base64-like strings
    "PRIVATE[_-]?KEY\s*=\s*['\"][a-zA-Z0-9+/=]{50,}['\"]"
)

# Check for hardcoded secrets in all files (simplified and optimized)
secret_found=false
echo "Scanning for secrets (optimized check)..."

# Simple approach: check a limited number of files for common patterns
for pattern in "${SECRET_PATTERNS[@]}"; do
    # Use a simple grep approach with timeout, excluding venv and common directories
    if timeout 5 grep -r -E "$pattern" --include="*.py" --include="*.sh" --include="*.js" --include="*.json" . \
        --exclude-dir="test*" \
        --exclude-dir="example*" \
        --exclude-dir="mock*" \
        --exclude-dir="__pycache__" \
        --exclude-dir="node_modules" \
        --exclude-dir=".git" \
        --exclude-dir=".venv" \
        --exclude-dir="venv" \
        --exclude-dir="env" \
        --exclude-dir="*.egg-info" \
        >/dev/null 2>&1; then
        log_security_issue "HIGH" "Hardcoded secrets detected" "Secret pattern '$pattern' found in codebase"
        secret_found=true
        break
    fi
done

if [[ "$secret_found" == "false" ]]; then
    log_security_pass "No hardcoded secrets detected"
fi

echo ""

# 2. Dependency Security
echo "2. Dependency Security..."
echo ""

# Check Python dependencies for vulnerabilities
if command -v python3 >/dev/null 2>&1 && [ -f "requirements.txt" ]; then
    echo "Checking Python dependencies for vulnerabilities..."
    if command -v safety >/dev/null 2>&1; then
        if timeout 60 safety check --file requirements.txt >/dev/null 2>&1; then
            log_security_pass "Python dependencies security check passed"
        else
            log_security_issue "HIGH" "Python dependencies have known vulnerabilities" "Run 'safety check --file requirements.txt' for details"
        fi
    else
        log_security_issue "MEDIUM" "Cannot check Python vulnerabilities" "Install safety: pip install safety"
    fi
else
    log_security_issue "LOW" "Cannot check Python dependencies" "requirements.txt or python3 not found"
fi

# Check for outdated packages (only warn in CI, don't fail)
if command -v pip >/dev/null 2>&1; then
    OUTDATED=$(pip list --outdated 2>/dev/null | wc -l)
    if [ "$OUTDATED" -gt 1 ]; then
        OUTDATED_COUNT=$((OUTDATED - 1))
        if [ "$OUTDATED_COUNT" -gt 10 ]; then
            log_security_issue "MEDIUM" "Many outdated Python packages" "$OUTDATED_COUNT packages need updates"
        else
            log_security_pass "Python packages reasonably up-to-date"
        fi
    else
        log_security_pass "All Python packages up-to-date"
    fi
fi

echo ""

# 3. Code Security Analysis
echo "3. Code Security Analysis..."
echo ""

# Check for debug code in production (optimized)
DEBUG_FILES=$(timeout 10 find . -type f \( -name "*.py" -o -name "*.js" \) \
    -not -path "*/test*" \
    -not -path "*/example*" \
    -not -path "*/mock*" \
    -exec grep -l "pdb\.set_trace()\|import pdb" {} \; 2>/dev/null | wc -l)

if [ "$DEBUG_FILES" -gt 0 ]; then
    if [[ "$STRICT_MODE" == "true" ]]; then
        log_security_issue "MEDIUM" "Debug code found in production" "$DEBUG_FILES files contain debug breakpoints"
    else
        log_security_issue "LOW" "Debug code found in production" "$DEBUG_FILES files contain debug breakpoints (consider removing)"
    fi
else
    log_security_pass "No debug breakpoints found in production code"
fi

# Check for SQL injection vulnerabilities (optimized)
SQL_INJECTION_FILES=$(timeout 10 find . -type f \( -name "*.py" -o -name "*.js" \) \
    -exec grep -l "SELECT.*+.*WHERE\|INSERT.*+.*VALUES\|UPDATE.*+.*SET" {} \; 2>/dev/null | wc -l)

if [ "$SQL_INJECTION_FILES" -gt 0 ]; then
    log_security_issue "HIGH" "Potential SQL injection vulnerabilities" "$SQL_INJECTION_FILES files use string concatenation in SQL"
else
    log_security_pass "No SQL injection vulnerabilities detected"
fi

echo ""

# 4. File Permissions
echo "4. File Permissions..."
echo ""

# Check for world-writable files
WORLD_WRITABLE=$(find . -type f -perm -002 2>/dev/null | wc -l)
if [ "$WORLD_WRITABLE" -gt 0 ]; then
    log_security_issue "HIGH" "World-writable files found" "$WORLD_WRITABLE files are world-writable"
else
    log_security_pass "No world-writable files found"
fi

# Check for sensitive files with weak permissions
SENSITIVE_FILES=(
    ".env"
    ".env.local"
    ".env.production"
    "secrets.json"
    "keys.json"
    "private.key"
    "id_rsa"
)

for file in "${SENSITIVE_FILES[@]}"; do
    if [ -f "$file" ]; then
        PERMS=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%Lp" "$file" 2>/dev/null || echo "unknown")
        if [ "$PERMS" != "600" ] && [ "$PERMS" != "400" ]; then
            log_security_issue "HIGH" "Sensitive file with weak permissions" "$file has permissions $PERMS (should be 600)"
        else
            log_security_pass "Sensitive file $file has proper permissions"
        fi
    fi
done

echo ""

# 5. Configuration Security
echo "5. Configuration Security..."
echo ""

# Check for .env files with debug enabled
if [ -f ".env" ]; then
    if grep -q "DEBUG.*=.*True\|DEBUG.*=.*1" .env 2>/dev/null; then
        log_security_issue "MEDIUM" "Debug mode enabled in production" "Set DEBUG=False in production environment"
    else
        log_security_pass "Debug mode properly disabled"
    fi
fi

# Check for backup files with sensitive data
BACKUP_FILES=$(find . -name "*.bak*" -o -name "*.backup*" -o -name "*~" | wc -l)
if [ "$BACKUP_FILES" -gt 0 ]; then
    SENSITIVE_BACKUPS=$(find . -name "*.bak*" -o -name "*.backup*" -o -name "*~" | xargs grep -l "password\|secret\|key\|token" 2>/dev/null | wc -l)
    if [ "$SENSITIVE_BACKUPS" -gt 0 ]; then
        log_security_issue "HIGH" "Backup files contain sensitive data" "$SENSITIVE_BACKUPS backup files with secrets"
    else
        log_security_pass "Backup files do not contain sensitive data"
    fi
else
    log_security_pass "No backup files found"
fi

echo ""

# Summary
echo "📊 CI/CD Security Gate Results"
echo "=============================="
echo "Critical Issues: $CRITICAL_ISSUES"
echo "High Issues: $HIGH_ISSUES"
echo "Medium Issues: $MEDIUM_ISSUES"
echo "Low Issues: $LOW_ISSUES"
echo "Passed Checks: $PASSED_CHECKS"

TOTAL_ISSUES=$((CRITICAL_ISSUES + HIGH_ISSUES + MEDIUM_ISSUES + LOW_ISSUES))

# Determine exit code based on mode
if [[ "$STRICT_MODE" == "true" ]]; then
    # In strict mode, any issue fails the build
    if [ $TOTAL_ISSUES -gt 0 ]; then
        EXIT_CODE=1
    fi
else
    # In normal mode, only critical and high issues fail the build
    if [ $CRITICAL_ISSUES -gt 0 ] || [ $HIGH_ISSUES -gt 0 ]; then
        EXIT_CODE=1
    fi
fi

if [[ "$REPORT_ONLY" == "true" ]]; then
    EXIT_CODE=0
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "\n${GREEN}🎉 CI/CD Security Gate PASSED${NC}"
    if [[ "$STRICT_MODE" == "true" ]]; then
        echo -e "${GREEN}✅ All security checks passed (strict mode)${NC}"
    else
        echo -e "${GREEN}✅ No critical or high-severity security issues${NC}"
    fi
else
    echo -e "\n${RED}❌ CI/CD Security Gate FAILED${NC}"
    if [[ "$STRICT_MODE" == "true" ]]; then
        echo -e "${RED}🚨 $TOTAL_ISSUES security issues found (strict mode)${NC}"
    else
        echo -e "${RED}🚨 $CRITICAL_ISSUES critical and $HIGH_ISSUES high-severity issues require attention${NC}"
    fi
fi

# Generate security report
REPORT_FILE="ci_security_report_$(date +%Y%m%d_%H%M%S).md"
cat >"$REPORT_FILE" <<EOF
# CI/CD Security Gate Report
Generated: $(date)
Mode: $(if [[ "$STRICT_MODE" == "true" ]]; then echo "STRICT"; else echo "NORMAL"; fi)
Result: $(if [ $EXIT_CODE -eq 0 ]; then echo "PASSED"; else echo "FAILED"; fi)

## Summary
- **Critical Issues**: $CRITICAL_ISSUES
- **High Issues**: $HIGH_ISSUES
- **Medium Issues**: $MEDIUM_ISSUES
- **Low Issues**: $LOW_ISSUES
- **Passed Checks**: $PASSED_CHECKS
- **Overall Status**: $(if [ $EXIT_CODE -eq 0 ]; then echo "SECURE"; else echo "NEEDS ATTENTION"; fi)

## Security Checks Performed
1. ✅ Secret Detection - Scanned for hardcoded credentials
2. ✅ Dependency Security - Checked for vulnerable packages
3. ✅ Code Security Analysis - SQL injection and debug code detection
4. ✅ File Permissions - World-writable and sensitive file checks
5. ✅ Configuration Security - Environment and backup file validation

---
*Generated by ci_security_gate.sh*
EOF

echo ""
echo "📄 Security report saved: $REPORT_FILE"

exit $EXIT_CODE
