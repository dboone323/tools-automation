#!/bin/bash
# DEPRECATED: Use agent_test_quality.sh instead
# This script redirects to the consolidated Phase 4 enhanced testing agent


# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

echo "⚠️  testing_agent.sh is deprecated as of Phase 5 (Oct 2025)"
echo "🔄 Redirecting to agent_test_quality.sh (Phase 4 enhanced)..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/agent_test_quality.sh" "$@"
