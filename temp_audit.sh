#!/bin/bash
# Final Security Audit Script
# Step 7: Final System Validation

# set -e

echo "🔒 Final Security Audit"
echo "======================"
echo "Date: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Security test results
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
        ((CRITICAL_ISSUES++))
        echo -e "${RED}🚨 CRITICAL${NC}: $issue"
        ;;
    "HIGH")
        ((HIGH_ISSUES++))
        echo -e "${RED}🔴 HIGH${NC}: $issue"
        ;;
    "MEDIUM")
        ((MEDIUM_ISSUES++))
        echo -e "${YELLOW}🟡 MEDIUM${NC}: $issue"
        ;;
    "LOW")
        ((LOW_ISSUES++))
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
    ((PASSED_CHECKS++))
}

echo "🔍 Running Security Audit Checks..."
echo ""

# 1. File Permissions Check
echo "1. Checking File Permissions..."
echo ""

# Check for world-writable files
WORLD_WRITABLE=$(find . -type f -perm -002 2>/dev/null | wc -l)
if [ "$WORLD_WRITABLE" -gt 0 ]; then
    log_security_issue "HIGH" "World-writable files found" "$WORLD_WRITABLE files are world-writable"
else
    log_security_pass "No world-writable files found"
fi

# Check for executable scripts without proper permissions
EXECUTABLE_SCRIPTS=$(find . -name "*.sh" -type f -executable | wc -l)
TOTAL_SCRIPTS=$(find . -name "*.sh" -type f | wc -l)
if [ "$EXECUTABLE_SCRIPTS" -eq "$TOTAL_SCRIPTS" ]; then
    log_security_pass "All shell scripts have execute permissions"
else
    MISSING_EXEC=$((TOTAL_SCRIPTS - EXECUTABLE_SCRIPTS))
    log_security_issue "MEDIUM" "Scripts without execute permissions" "$MISSING_EXEC scripts lack execute permission"
fi

# Check for sensitive files
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

# 2. Network Security Check
echo "2. Checking Network Security..."
echo ""

# Check if MCP server is running on localhost only
if command -v netstat >/dev/null 2>&1 || command -v ss >/dev/null 2>&1; then
    if command -v netstat >/dev/null 2>&1; then
        LISTENING_PORTS=$(netstat -tln 2>/dev/null | grep LISTEN || true)
    else
        LISTENING_PORTS=$(ss -tln 2>/dev/null | grep LISTEN || true)
    fi

    if echo "$LISTENING_PORTS" | grep -q "5005"; then
        if echo "$LISTENING_PORTS" | grep "5005" | grep -q "127.0.0.1\|localhost"; then
            log_security_pass "MCP server bound to localhost only"
        else
            log_security_issue "CRITICAL" "MCP server listening on all interfaces" "Server should be bound to 127.0.0.1 only"
        fi
    else
        log_security_issue "MEDIUM" "MCP server not detected as running" "Cannot verify network binding"
    fi
else
    log_security_issue "LOW" "Cannot check network bindings" "netstat/ss not available"
fi

# Check for open ports that shouldn't be exposed
if command -v nmap >/dev/null 2>&1; then
    echo "Scanning for open ports..."
    # Quick scan of common ports (this might take a moment)
    OPEN_PORTS=$(timeout 10 nmap -p 22,80,443,5005 localhost 2>/dev/null | grep -c "open" 2>/dev/null || echo "0")
    if [ "$OPEN_PORTS" -gt 1 ]; then # Allow at least port 5005
        log_security_issue "MEDIUM" "Multiple open ports detected" "Consider firewall rules"
    else
        log_security_pass "Port exposure appears minimal"
    fi
else
    log_security_issue "LOW" "Cannot scan open ports" "nmap not available - install with 'brew install nmap'"
fi

echo ""

# 3. Dependency Security Check
echo "3. Checking Dependencies..."
echo ""

# Check Python dependencies for known vulnerabilities
if command -v python3 >/dev/null 2>&1 && [ -f "requirements.txt" ]; then
    echo "Checking Python dependencies for vulnerabilities..."
    if command -v safety >/dev/null 2>&1; then
        VULN_COUNT=$(safety check --file requirements.txt 2>/dev/null | grep -c "vulnerability" || echo "0")
        if [ "$VULN_COUNT" -gt 0 ]; then
            log_security_issue "HIGH" "Python dependencies have known vulnerabilities" "$VULN_COUNT vulnerabilities found"
        else
            log_security_pass "Python dependencies appear secure"
        fi
    else
        log_security_issue "MEDIUM" "Cannot check Python vulnerabilities" "safety tool not installed"
    fi
else
    log_security_issue "LOW" "Cannot check Python dependencies" "requirements.txt or python3 not found"
fi

# Check for outdated packages
if command -v pip >/dev/null 2>&1; then
    OUTDATED=$(pip list --outdated 2>/dev/null | wc -l)
    if [ "$OUTDATED" -gt 1 ]; then # Header line doesn't count
        OUTDATED_COUNT=$((OUTDATED - 1))
        if [ "$OUTDATED_COUNT" -gt 5 ]; then
            log_security_issue "MEDIUM" "Many outdated Python packages" "$OUTDATED_COUNT packages need updates"
        else
            log_security_pass "Python packages reasonably up-to-date"
        fi
    else
        log_security_pass "All Python packages up-to-date"
    fi
fi

echo ""

# 4. Code Security Analysis
echo "4. Analyzing Code Security..."
echo ""

# Check for hardcoded secrets
SECRET_PATTERNS=(
    "password.*="
    "secret.*="
    "key.*="
    "token.*="
    "api_key.*="
)

for pattern in "${SECRET_PATTERNS[@]}"; do
    SECRET_FILES=$(grep -r -l "$pattern" --include="*.py" --include="*.sh" --include="*.js" . 2>/dev/null | wc -l)
    if [ "$SECRET_FILES" -gt 0 ]; then
        log_security_issue "HIGH" "Potential hardcoded secrets found" "$SECRET_FILES files contain '$pattern'"
    fi
done

# Check for debug code in production
DEBUG_PATTERNS=(
    "print("
    "console.log("
    "debug.*=.*True"
    "DEBUG.*=.*1"
)

DEBUG_FILES=$(grep -r -l "${DEBUG_PATTERNS[0]}" --include="*.py" . 2>/dev/null | head -5 | wc -l)
if [ "$DEBUG_FILES" -gt 0 ]; then
    log_security_issue "LOW" "Debug print statements found" "Consider removing debug output in production"
fi

# Check for SQL injection vulnerabilities (basic check)
if grep -r "SELECT.*+" --include="*.py" . >/dev/null 2>&1; then
    log_security_issue "HIGH" "Potential SQL injection vulnerability" "String concatenation in SQL queries detected"
fi

echo ""

# 5. Configuration Security
echo "5. Checking Configuration Security..."
echo ""

# Check for secure configuration files
if [ -f ".env" ]; then
    if grep -q "DEBUG.*=.*True\|DEBUG.*=.*1" .env 2>/dev/null; then
        log_security_issue "MEDIUM" "Debug mode enabled in production" "Set DEBUG=False in production"
    else
        log_security_pass "Debug mode properly disabled"
    fi
fi

# Check for backup files with sensitive data
BACKUP_FILES=$(find . -name "*.bak" -o -name "*.backup" -o -name "*~" | wc -l)
if [ "$BACKUP_FILES" -gt 0 ]; then
    SENSITIVE_BACKUPS=$(find . -name "*.bak" -o -name "*.backup" -o -name "*~" | xargs grep -l "password\|secret\|key" 2>/dev/null | wc -l)
    if [ "$SENSITIVE_BACKUPS" -gt 0 ]; then
        log_security_issue "HIGH" "Backup files contain sensitive data" "$SENSITIVE_BACKUPS backup files with secrets"
    else
        log_security_pass "Backup files do not contain sensitive data"
    fi
fi

echo ""

# 6. System Security
echo "6. Checking System Security..."
echo ""

# Check if running as root (not recommended)
if [ "$EUID" -eq 0 ]; then
    log_security_issue "MEDIUM" "Running as root user" "Consider running as non-privileged user"
else
    log_security_pass "Not running as root user"
fi

# Check for SUID binaries (potential security risk)
if command -v find >/dev/null 2>&1; then
    SUID_FILES=$(find . -type f -perm -4000 2>/dev/null | wc -l)
    if [ "$SUID_FILES" -gt 0 ]; then
        log_security_issue "MEDIUM" "SUID binaries found" "$SUID_FILES files have SUID bit set"
    else
        log_security_pass "No SUID binaries found"
    fi
fi

echo ""

# Summary
echo "📊 Security Audit Results"
echo "========================"
echo "Critical Issues: $CRITICAL_ISSUES"
echo "High Issues: $HIGH_ISSUES"
echo "Medium Issues: $MEDIUM_ISSUES"
echo "Low Issues: $LOW_ISSUES"
echo "Passed Checks: $PASSED_CHECKS"

TOTAL_ISSUES=$((CRITICAL_ISSUES + HIGH_ISSUES + MEDIUM_ISSUES + LOW_ISSUES))

if [ $CRITICAL_ISSUES -eq 0 ] && [ $HIGH_ISSUES -eq 0 ]; then
    echo -e "\n${GREEN}🎉 Security audit passed!${NC}"
    echo -e "${GREEN}✅ No critical or high-severity security issues found${NC}"

    # Generate security report
    echo "Generating security audit report..."
    cat >security_audit_report_$(date +%Y%m%d_%H%M%S).md <<EOF
# Security Audit Report
Generated: $(date)

## Summary
- **Critical Issues**: $CRITICAL_ISSUES
- **High Issues**: $HIGH_ISSUES
- **Medium Issues**: $MEDIUM_ISSUES
- **Low Issues**: $LOW_ISSUES
- **Passed Checks**: $PASSED_CHECKS
- **Overall Status**: $([ $CRITICAL_ISSUES -eq 0 ] && [ $HIGH_ISSUES -eq 0 ] && echo "SECURE" || echo "NEEDS ATTENTION")

## Issues Found
$(if [ $TOTAL_ISSUES -eq 0 ]; then
        echo "No security issues found."
    else
        echo "See security audit output above for details."
    fi)

## Recommendations
$(if [ $CRITICAL_ISSUES -gt 0 ] || [ $HIGH_ISSUES -gt 0 ]; then
        echo "- Address all CRITICAL and HIGH issues before production deployment"
    fi)
$(if [ $MEDIUM_ISSUES -gt 0 ]; then
        echo "- Review and fix MEDIUM issues for improved security posture"
    fi)
$(if [ $LOW_ISSUES -gt 0 ]; then
        echo "- Consider addressing LOW issues for best practices"
    fi)

---
*Report generated by final_security_audit.sh*
EOF

    exit 0
else
    echo -e "\n${RED}❌ Security audit failed${NC}"
    echo -e "${YELLOW}⚠️  $CRITICAL_ISSUES critical and $HIGH_ISSUES high-severity issues require attention${NC}"
    echo ""
    echo "🚨 Critical Security Issues:"
    echo "==========================="
    [ $CRITICAL_ISSUES -gt 0 ] && echo "- $CRITICAL_ISSUES critical issues found"
    [ $HIGH_ISSUES -gt 0 ] && echo "- $HIGH_ISSUES high-severity issues found"
    echo ""
    echo "📋 Next Steps:"
    echo "=============="
    echo "1. Address all CRITICAL and HIGH issues immediately"
    echo "2. Review MEDIUM and LOW issues for risk assessment"
    echo "3. Re-run security audit after fixes"
    echo "4. Consider automated security scanning in CI/CD"

    exit 1
fi
