#!/usr/bin/env bash
set -euo pipefail

# Thin wrapper to run the error learning pipeline without integrating with the
# broader agent status framework. Avoids side-effects during bootstrap.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

"${SCRIPT_DIR}/error_learning_agent.sh" --scan-once "$@"
