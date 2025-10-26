#!/usr/bin/env bash

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -euo pipefail

# Agent: runs inventory and updates docs. Intended for cron/CI.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../.. && pwd)"
cd "${ROOT_DIR}"

# 1) Inventory report
bash "${ROOT_DIR}/Tools/Automation/workspace_inventory.sh"

# 2) Consolidation status doc
bash "${ROOT_DIR}/Projects/scripts/gen_docs.sh"

echo "scheduled_inventory: completed"
