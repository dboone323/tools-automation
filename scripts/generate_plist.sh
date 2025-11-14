#!/usr/bin/env bash
# Generate a macOS launchd plist from plist.template, substituting WORKSPACE_ROOT
set -euo pipefail

SETUP_PATH="$(git rev-parse --show-toplevel 2>/dev/null)/scripts/setup_paths.sh"
if [[ -f "${SETUP_PATH}" ]]; then
    # shellcheck disable=SC1090
    source "${SETUP_PATH}"
fi

TEMPLATE_FILE="$(git rev-parse --show-toplevel 2>/dev/null)/com.tools.automation.dashboard-server.plist.template"
OUTPUT_FILE="$HOME/Library/LaunchAgents/com.tools.automation.dashboard-server.plist"

if [[ ! -f "${TEMPLATE_FILE}" ]]; then
    echo "Template file not found: ${TEMPLATE_FILE}" >&2
    exit 1
fi

# Use envsubst if available or sed fallback
if command -v envsubst >/dev/null 2>&1; then
    envsubst <"${TEMPLATE_FILE}" >"${OUTPUT_FILE}"
else
    sed "s#\${WORKSPACE_ROOT}#${WORKSPACE_ROOT}#g" "${TEMPLATE_FILE}" >"${OUTPUT_FILE}"
fi

chmod 644 "${OUTPUT_FILE}"

echo "Created: ${OUTPUT_FILE}"

# To load:
#   launchctl unload ${OUTPUT_FILE} || true
#   launchctl load ${OUTPUT_FILE}
