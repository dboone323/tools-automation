#!/usr/bin/env bash
# Quick Test Coverage Booster - Generate Missing Tests
# Simpler, more robust version

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJECTS_DIR="${WORKSPACE_ROOT}/Projects"

log() { echo -e "${BLUE}$*${NC}"; }
success() { echo -e "${GREEN}✅ $*${NC}"; }

# Count current coverage
log "Current Test Coverage:"
for proj in MomentumFinance PlannerApp; do
    if [[ -d "${PROJECTS_DIR}/${proj}" ]]; then
        src=$(find "${PROJECTS_DIR}/${proj}" -name "*.swift" -not -path "*/Tests/*" -not -name "*Tests.swift" 2>/dev/null | wc -l | tr -d ' ')
        tst=$(find "${PROJECTS_DIR}/${proj}" -name "*Tests.swift" 2>/dev/null | wc -l | tr -d ' ')
        log "  $proj: $tst tests for $src files"
    fi
done

success "
Next steps to improve coverage:
1. Use Xcode Test Navigator to create test targets
2. Use Xcode Editor > Create Unit Test to generate test skeletons
3. Run comprehensive_test_generator.sh for AI-powered test generation
4. Use generate_missing_tests.sh for ollama-based generation
5. Manually write critical path tests first

For quick start:
  cd Projects/MomentumFinance && xcodebuild test -scheme MomentumFinance
  cd Projects/PlannerApp && xcodebuild test -scheme PlannerApp
"
