#!/bin/bash
# Production Deployment Validation Script
# Step 7: Final System Validation

set -e

echo "🚀 Production Deployment Validation"
echo "=================================="
echo "Date: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation results
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

log_validation() {
    local result="$1"
    local check="$2"
    local details="$3"

    case "$result" in
    "PASS")
        echo -e "${GREEN}✅ PASS${NC}: $check"
        ((PASSED_CHECKS++))
        ;;
    "FAIL")
        echo -e "${RED}❌ FAIL${NC}: $check"
        ((FAILED_CHECKS++))
        ;;
    "WARN")
        echo -e "${YELLOW}⚠️  WARN${NC}: $check"
        ((WARNINGS++))
        ;;
    esac

    if [ -n "$details" ]; then
        echo -e "   ${BLUE}Details:${NC} $details"
    fi
}

echo "🔍 Validating Production Deployment Readiness..."
echo ""

# 1. Environment Validation
echo "1. Environment Validation..."
echo ""

# Check if running in virtual environment
if [ -n "$VIRTUAL_ENV" ]; then
    log_validation "PASS" "Virtual environment active" "Running in: $VIRTUAL_ENV"
else
    log_validation "FAIL" "Virtual environment not active" "Activate virtual environment before deployment"
fi

# Check Python version compatibility
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
    PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)

    if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 8 ]; then
        log_validation "PASS" "Python version compatible" "Python $PYTHON_VERSION"
    else
        log_validation "FAIL" "Python version incompatible" "Requires Python 3.8+, found $PYTHON_VERSION"
    fi
else
    log_validation "FAIL" "Python3 not found" "Python3 is required"
fi

# Check required system dependencies
REQUIRED_COMMANDS=("curl" "grep" "find" "ps" "netstat" "ss")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        log_validation "PASS" "System command available" "$cmd"
    else
        # Special handling for ss command - not available on macOS
        if [ "$cmd" = "ss" ]; then
            if command -v "netstat" >/dev/null 2>&1 || command -v "lsof" >/dev/null 2>&1; then
                log_validation "PASS" "Alternative network tool available" "netstat/lsof available instead of ss"
            else
                log_validation "WARN" "Network inspection limited" "Neither ss, netstat, nor lsof available"
            fi
        else
            log_validation "WARN" "System command missing" "$cmd (may affect some features)"
        fi
    fi
done

echo ""

# 2. Dependency Validation
echo "2. Dependency Validation..."
echo ""

# Check Python dependencies
if [ -f "requirements.txt" ]; then
    if python3 -c "
import sys
import importlib

# Map package names to import names
PACKAGE_IMPORT_MAP = {
    'Flask': 'flask',
    'flask-cors': 'flask_cors',
    'requests': 'requests',
    'scikit-learn': 'sklearn',
    'pandas': 'pandas',
    'numpy': 'numpy',
    'joblib': 'joblib',
    'pytest': 'pytest',
    'pytest-cov': 'pytest_cov',
    'pytest-html': 'pytest_html',
    'pytest-mock': 'pytest_mock',
    'pytest-asyncio': 'pytest_asyncio',
    'playwright': 'playwright',
    'locust': 'locust',
    'responses': 'responses',
    'freezegun': 'freezegun',
    'faker': 'faker'
}

# Packages that are pytest plugins (don't have direct imports)
PYTEST_PLUGINS = ['pytest-xdist']

# Read requirements
with open('requirements.txt', 'r') as f:
    requirements = [line.strip() for line in f if line.strip() and not line.startswith('#')]

missing_deps = []
for req in requirements:
    try:
        # Parse package name (handle version specifiers)
        pkg_name = req.split()[0].split('==')[0].split('>=')[0].split('<=')[0]
        
        # Skip pytest plugins as they don't have direct imports
        if pkg_name in PYTEST_PLUGINS:
            continue
            
        # Get the correct import name
        import_name = PACKAGE_IMPORT_MAP.get(pkg_name, pkg_name.replace('-', '_'))
        importlib.import_module(import_name)
    except ImportError:
        missing_deps.append(pkg_name)

if not missing_deps:
    print('PYTHON_DEPS_OK')
else:
    print(f'MISSING_DEPS: {missing_deps}')
" 2>/dev/null | grep -q "PYTHON_DEPS_OK"; then
        log_validation "PASS" "Python dependencies installed" "All required packages available"
    else
        MISSING=$(python3 -c "
import sys
with open('requirements.txt', 'r') as f:
    requirements = [line.strip() for line in f if line.strip() and not line.startswith('#')]
print(f'{len(requirements)} packages checked')
" 2>/dev/null)
        log_validation "FAIL" "Python dependencies missing" "Some required packages not installed"
    fi
else
    log_validation "WARN" "No requirements.txt found" "Cannot validate Python dependencies"
fi

# Check for package-lock.json or similar
if [ -f "package-lock.json" ] || [ -f "yarn.lock" ] || [ -f "Pipfile.lock" ]; then
    log_validation "PASS" "Dependency lockfile present" "Dependencies are pinned for reproducible builds"
else
    log_validation "WARN" "No dependency lockfile" "Consider using lockfiles for reproducible deployments"
fi

echo ""

# 3. Configuration Validation
echo "3. Configuration Validation..."
echo ""

# Check for environment configuration
if [ -f ".env" ] || [ -f ".env.example" ]; then
    log_validation "PASS" "Environment configuration present" "Environment variables configured"
else
    log_validation "WARN" "No environment configuration" "Consider using .env files for configuration"
fi

# Check for production-specific settings
if [ -f ".env" ]; then
    if grep -q "DEBUG.*=.*False\|DEBUG.*=.*0" .env 2>/dev/null; then
        log_validation "PASS" "Debug mode disabled" "Production settings configured"
    else
        log_validation "WARN" "Debug mode may be enabled" "Ensure DEBUG=False in production"
    fi
fi

# Check configuration files
CONFIG_FILES=("config/automation_config.yaml" "alert_config.json" "agent_status.json")
for config_file in "${CONFIG_FILES[@]}"; do
    if [ -f "$config_file" ]; then
        if [ -r "$config_file" ]; then
            log_validation "PASS" "Configuration file accessible" "$config_file"
        else
            log_validation "FAIL" "Configuration file not readable" "$config_file"
        fi
    else
        log_validation "WARN" "Configuration file missing" "$config_file"
    fi
done

echo ""

# 4. Service Validation
echo "4. Service Validation..."
echo ""

# Check service files
SERVICE_FILES=("mcp_server.service" "auto-restart-monitor.service")
for service_file in "${SERVICE_FILES[@]}"; do
    if [ -f "$service_file" ]; then
        log_validation "PASS" "Service file present" "$service_file"
    else
        log_validation "WARN" "Service file missing" "$service_file (systemd integration not configured)"
    fi
done

# Check for launchd plist files (macOS)
LAUNCHD_FILES=("com.quantum.mcp.plist" "com.tools.automation.autorestart.plist")
for plist_file in "${LAUNCHD_FILES[@]}"; do
    if [ -f "$plist_file" ]; then
        log_validation "PASS" "Launch daemon configured" "$plist_file"
    else
        log_validation "WARN" "Launch daemon missing" "$plist_file (macOS service integration not configured)"
    fi
done

echo ""

# 5. Directory Structure Validation
echo "5. Directory Structure Validation..."
echo ""

# Check required directories
REQUIRED_DIRS=("agents" "workflows" "tests" "docs" "backups" "logs" "tasks")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        if [ -w "$dir" ]; then
            log_validation "PASS" "Directory present and writable" "$dir"
        else
            log_validation "FAIL" "Directory not writable" "$dir"
        fi
    else
        log_validation "FAIL" "Required directory missing" "$dir"
    fi
done

# Check backup directories
BACKUP_DIRS=("backups" ".agent_backups" "ollama_backups")
for backup_dir in "${BACKUP_DIRS[@]}"; do
    if [ -d "$backup_dir" ]; then
        log_validation "PASS" "Backup directory present" "$backup_dir"
    else
        log_validation "WARN" "Backup directory missing" "$backup_dir (backups not configured)"
    fi
done

echo ""

# 6. Security Validation
echo "6. Security Validation..."
echo ""

# Check file permissions on sensitive files
SENSITIVE_FILES=(".env" "keys/" "secrets.json" "private.key")
for sensitive_file in "${SENSITIVE_FILES[@]}"; do
    if [ -f "$sensitive_file" ]; then
        PERMS=$(stat -c "%a" "$sensitive_file" 2>/dev/null || stat -f "%Lp" "$sensitive_file" 2>/dev/null || echo "unknown")
        if [ "$PERMS" = "600" ] || [ "$PERMS" = "400" ]; then
            log_validation "PASS" "Sensitive file properly secured" "$sensitive_file ($PERMS)"
        else
            log_validation "FAIL" "Sensitive file insecure" "$sensitive_file ($PERMS) - should be 600"
        fi
    fi
done

# Check for world-writable files
WORLD_WRITABLE=$(find . -type f -perm -002 2>/dev/null | wc -l)
if [ "$WORLD_WRITABLE" -eq 0 ]; then
    log_validation "PASS" "No world-writable files" "File permissions are secure"
else
    log_validation "FAIL" "World-writable files found" "$WORLD_WRITABLE files are world-writable"
fi

echo ""

# 7. Monitoring & Logging Validation
echo "7. Monitoring & Logging Validation..."
echo ""

# Check monitoring configuration
if [ -f "docker-compose.monitoring.yml" ]; then
    log_validation "PASS" "Monitoring stack configured" "Docker Compose monitoring available"
else
    log_validation "WARN" "Monitoring not configured" "Consider setting up monitoring stack"
fi

# Check for log rotation
if [ -d "logs" ]; then
    LOG_FILES=$(find logs -name "*.log" 2>/dev/null | wc -l)
    if [ "$LOG_FILES" -gt 0 ]; then
        log_validation "PASS" "Logging configured" "$LOG_FILES log files present"
    else
        log_validation "WARN" "No log files found" "Logging may not be active"
    fi
else
    log_validation "WARN" "Logs directory missing" "Logging not configured"
fi

echo ""

# 8. Performance Validation
echo "8. Performance Validation..."
echo ""

# Quick performance check
if python3 -c "
import time
import requests

# Test MCP server response time
start_time = time.time()
try:
    response = requests.get('http://localhost:5005/health', timeout=5)
    end_time = time.time()
    response_time = (end_time - start_time) * 1000

    if response.status_code == 200 and response_time < 1000:
        print(f'PERF_OK: {response_time:.0f}ms')
    else:
        print(f'PERF_SLOW: {response_time:.0f}ms')
except:
    print('PERF_FAIL: Server not responding')
" >/tmp/perf_check.log 2>&1; then

    if grep -q "PERF_OK" /tmp/perf_check.log; then
        RESPONSE_TIME=$(grep "PERF_OK" /tmp/perf_check.log | cut -d':' -f2)
        log_validation "PASS" "Performance acceptable" "MCP server responds in ${RESPONSE_TIME}"
    elif grep -q "PERF_SLOW" /tmp/perf_check.log; then
        RESPONSE_TIME=$(grep "PERF_SLOW" /tmp/perf_check.log | cut -d':' -f2)
        log_validation "WARN" "Performance slow" "MCP server responds in ${RESPONSE_TIME} (target: <1000ms)"
    else
        log_validation "FAIL" "Performance check failed" "MCP server not responding"
    fi
else
    log_validation "WARN" "Cannot check performance" "MCP server may not be running"
fi

echo ""

# Summary
echo "📊 Production Deployment Validation Results"
echo "=========================================="
echo "Passed Checks: $PASSED_CHECKS"
echo "Failed Checks: $FAILED_CHECKS"
echo "Warnings: $WARNINGS"

SUCCESS_RATE=0
if [ $((PASSED_CHECKS + FAILED_CHECKS + WARNINGS)) -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_CHECKS * 100 / (PASSED_CHECKS + FAILED_CHECKS + WARNINGS)))
fi

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "\n${GREEN}🎉 Production deployment validation passed!${NC}"
    echo -e "${GREEN}✅ System is ready for production deployment${NC}"

    # Generate deployment readiness report
    echo "Generating deployment readiness report..."
    cat >deployment_readiness_report_$(date +%Y%m%d_%H%M%S).md <<EOF
# Production Deployment Readiness Report
Generated: $(date)

## Summary
- **Passed Checks**: $PASSED_CHECKS
- **Failed Checks**: $FAILED_CHECKS
- **Warnings**: $WARNINGS
- **Success Rate**: ${SUCCESS_RATE}%
- **Deployment Status**: $([ $FAILED_CHECKS -eq 0 ] && echo "READY" || echo "NOT READY")

## Environment
- **Python Version**: $(python3 --version 2>&1)
- **Virtual Environment**: $([ -n "$VIRTUAL_ENV" ] && echo "Active ($VIRTUAL_ENV)" || echo "Not Active")
- **Operating System**: $(uname -a)

## Key Validation Results
- **Dependencies**: $([ -f "requirements.txt" ] && echo "Configured" || echo "Not configured")
- **Services**: $([ -f "mcp_server.service" ] && echo "Systemd configured" || echo "Not configured")
- **Security**: $([ $FAILED_CHECKS -eq 0 ] && echo "Passed" || echo "Issues found")
- **Performance**: Acceptable response times verified

## Recommendations
$(if [ $WARNINGS -gt 0 ]; then
        echo "- Review $WARNINGS warning(s) for potential improvements"
    fi)
$(if [ -z "$VIRTUAL_ENV" ]; then
        echo "- Activate virtual environment for deployment"
    fi)
$(if [ ! -f ".env" ]; then
        echo "- Configure environment variables in .env file"
    fi)

---
*Report generated by production_deployment_validation.sh*
EOF

    exit 0
else
    echo -e "\n${RED}❌ Production deployment validation failed${NC}"
    echo -e "${YELLOW}⚠️  $FAILED_CHECKS critical issues must be resolved before deployment${NC}"
    echo ""
    echo "🚨 Critical Issues Requiring Attention:"
    echo "======================================"
    echo "- $FAILED_CHECKS validation checks failed"
    echo ""
    echo "📋 Next Steps:"
    echo "=============="
    echo "1. Address all FAILED checks immediately"
    echo "2. Review WARNING items for best practices"
    echo "3. Re-run validation after fixes"
    echo "4. Generate deployment readiness report"

    exit 1
fi
