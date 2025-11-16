#!/bin/bash
# Documentation Completeness Check Script
# Step 7: Final System Validation

set -e

echo "📚 Documentation Completeness Check"
echo "==================================="
echo "Date: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Documentation requirements
REQUIRED_DOCS=(
    "README.md:Main project documentation with setup and usage"
    "AGENT_SYSTEM_README.md:Agent system architecture and operation"
    "RUNBOOK.md:Operational procedures and troubleshooting"
    "TOOLS_IMPLEMENTATION_GUIDE.md:Technical implementation details"
    "SETUP_README.md:Installation and configuration guide"
    "docs/ARCHITECTURE.md:System architecture documentation"
    "docs/API_REFERENCE.md:API endpoint documentation"
    "docs/TROUBLESHOOTING.md:Common issues and solutions"
)

OPTIONAL_DOCS=(
    "docs/CONFIGURATION_REFERENCE.md:Configuration options reference"
    "docs/DEVELOPMENT.md:Development guidelines"
    "docs/SECURITY.md:Security considerations"
    "CHANGELOG.md:Version history and changes"
    "CONTRIBUTING.md:Contribution guidelines"
)

# Test results
PASSED_CHECKS=0
FAILED_CHECKS=0
TOTAL_CHECKS=0

check_document() {
    local doc_spec;
    doc_spec="$1"
    local doc_file;
    doc_file=$(echo "$doc_spec" | cut -d':' -f1)
    local description;
    description=$(echo "$doc_spec" | cut -d':' -f2-)

    ((TOTAL_CHECKS++))

    if [ -f "$doc_file" ]; then
        # Check if file has content (not empty)
        if [ -s "$doc_file" ]; then
            # Check if file has minimum content (at least 100 characters)
            content_size=$(wc -c <"$doc_file")
            if [ "$content_size" -gt 100 ]; then
                echo -e "${GREEN}✅ PASS${NC}: $doc_file - $description"
                ((PASSED_CHECKS++))
                return 0
            else
                echo -e "${RED}❌ FAIL${NC}: $doc_file - File too small (${content_size} bytes) - $description"
                ((FAILED_CHECKS++))
                return 1
            fi
        else
            echo -e "${RED}❌ FAIL${NC}: $doc_file - Empty file - $description"
            ((FAILED_CHECKS++))
            return 1
        fi
    else
        echo -e "${RED}❌ FAIL${NC}: $doc_file - Missing file - $description"
        ((FAILED_CHECKS++))
        return 1
    fi
}

echo "🔍 Checking Required Documentation..."
echo ""

# Check required documentation
for doc_spec in "${REQUIRED_DOCS[@]}"; do
    check_document "$doc_spec"
done

echo ""
echo "🔍 Checking Optional Documentation..."
echo ""

# Check optional documentation (warnings only)
OPTIONAL_PASSED=0
OPTIONAL_FAILED=0

for doc_spec in "${OPTIONAL_DOCS[@]}"; do
    if check_document "$doc_spec"; then
        ((OPTIONAL_PASSED++))
    else
        ((OPTIONAL_FAILED++))
    fi
done

echo ""
echo "📊 Documentation Analysis..."
echo ""

# Check for basic documentation quality
echo "🔍 Analyzing Documentation Quality..."

# Check if README has basic sections
if [ -f "README.md" ]; then
    echo "Analyzing README.md structure..."

    # Check for common sections
    sections=("Installation" "Usage" "Configuration" "API" "Contributing" "License")
    found_sections=0

    for section in "${sections[@]}"; do
        if grep -i "^#* *$section" README.md >/dev/null 2>&1; then
            ((found_sections++))
        fi
    done

    if [ $found_sections -ge 3 ]; then
        echo -e "${GREEN}✅ PASS${NC}: README.md has good structure (${found_sections}/${#sections[@]} sections found)"
        ((PASSED_CHECKS++))
    else
        echo -e "${YELLOW}⚠️  WARN${NC}: README.md could use more sections (${found_sections}/${#sections[@]} sections found)"
    fi
    ((TOTAL_CHECKS++))
fi

# Check for API documentation
if [ -f "docs/API_REFERENCE.md" ] || grep -r "API" docs/ >/dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC}: API documentation found"
    ((PASSED_CHECKS++))
else
    echo -e "${RED}❌ FAIL${NC}: No API documentation found"
    ((FAILED_CHECKS++))
fi
((TOTAL_CHECKS++))

# Check for code examples in documentation
if grep -r '```' docs/ README.md AGENT_SYSTEM_README.md >/dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC}: Code examples found in documentation"
    ((PASSED_CHECKS++))
else
    echo -e "${YELLOW}⚠️  WARN${NC}: No code examples found in documentation"
fi
((TOTAL_CHECKS++))

# Check for troubleshooting section
if [ -f "docs/TROUBLESHOOTING.md" ] || grep -i "troubleshoot" docs/ README.md RUNBOOK.md >/dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC}: Troubleshooting information found"
    ((PASSED_CHECKS++))
else
    echo -e "${RED}❌ FAIL${NC}: No troubleshooting information found"
    ((FAILED_CHECKS++))
fi
((TOTAL_CHECKS++))

# Check documentation freshness (files modified within last 30 days)
echo ""
echo "🔍 Checking Documentation Freshness..."

THIRTY_DAYS_AGO=$(date -d '30 days ago' +%s 2>/dev/null || date -v -30d +%s 2>/dev/null || echo "0")

FRESH_DOCS=0
STALE_DOCS=0

for doc_spec in "${REQUIRED_DOCS[@]}"; do
    doc_file=$(echo "$doc_spec" | cut -d':' -f1)
    if [ -f "$doc_file" ]; then
        file_mtime=$(stat -f %m "$doc_file" 2>/dev/null || stat -c %Y "$doc_file" 2>/dev/null || echo "0")
        if [ "$file_mtime" -gt "$THIRTY_DAYS_AGO" ]; then
            ((FRESH_DOCS++))
        else
            ((STALE_DOCS++))
        fi
    fi
done

if [ $STALE_DOCS -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}: All required documentation is fresh (modified within 30 days)"
    ((PASSED_CHECKS++))
else
    echo -e "${YELLOW}⚠️  WARN${NC}: $STALE_DOCS required documents haven't been updated in 30+ days"
fi
((TOTAL_CHECKS++))

echo ""
echo "📊 Documentation Completeness Results"
echo "====================================="
echo "Required Documentation: $PASSED_CHECKS/$((${#REQUIRED_DOCS[@]} + 4)) checks passed"
echo "Optional Documentation: $OPTIONAL_PASSED/$((${#OPTIONAL_DOCS[@]})) files present"
echo "Fresh Documentation: $FRESH_DOCS/$((${#REQUIRED_DOCS[@]})) files recently updated"

SUCCESS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "\n${GREEN}🎉 Documentation completeness check passed!${NC}"
    echo -e "${GREEN}✅ All required documentation is present and adequate${NC}"

    # Generate documentation report
    echo "Generating documentation report..."

    # Prepare required-docs status block and simple quality checks to avoid complex
    # command substitutions inside a heredoc which can confuse parsers.
    REQUIRED_DOCS_STATUS=$(for doc_spec in "${REQUIRED_DOCS[@]}"; do
        doc_file=$(echo "$doc_spec" | cut -d':' -f1)
        if [ -f "$doc_file" ] && [ -s "$doc_file" ]; then
            echo "- ✅ $doc_file - Present"
        else
            echo "- ❌ $doc_file - Missing"
        fi
    done)

    CODE_EXAMPLES_STATUS=$(grep -r '```' docs/ README.md >/dev/null 2>&1 && echo "Found" || echo "Missing")

    cat >docs_completeness_report_$(date +%Y%m%d_%H%M%S).md <<EOF
# Documentation Completeness Report
Generated: $(date)

## Summary
- **Required Documents**: ${PASSED_CHECKS}/$((${#REQUIRED_DOCS[@]} + 4)) checks passed
- **Optional Documents**: ${OPTIONAL_PASSED}/${#OPTIONAL_DOCS[@]} present
- **Fresh Documents**: ${FRESH_DOCS}/${#REQUIRED_DOCS[@]} updated recently
- **Success Rate**: ${SUCCESS_RATE}%

## Required Documents Status
${REQUIRED_DOCS_STATUS}

## Quality Checks
- README Structure: $([ -f "README.md" ] && echo "Good" || echo "Missing")
- API Documentation: $([ -f "docs/API_REFERENCE.md" ] && echo "Present" || echo "Missing")
- Code Examples: ${CODE_EXAMPLES_STATUS}
- Troubleshooting: $([ -f "docs/TROUBLESHOOTING.md" ] && echo "Present" || echo "Missing")

---
*Report generated by check_documentation_completeness.sh*
EOF

    exit 0
else
    echo -e "\n${RED}❌ Documentation completeness check failed${NC}"
    echo -e "${YELLOW}⚠️  $FAILED_CHECKS required items missing or inadequate${NC}"
    echo ""
    echo "📋 Missing or inadequate documentation:"
    echo "======================================"

    for doc_spec in "${REQUIRED_DOCS[@]}"; do
        doc_file=$(echo "$doc_spec" | cut -d':' -f1)
        if [ ! -f "$doc_file" ] || [ ! -s "$doc_file" ]; then
            description=$(echo "$doc_spec" | cut -d':' -f2-)
            echo "- $doc_file: $description"
        fi
    done

    exit 1
fi
