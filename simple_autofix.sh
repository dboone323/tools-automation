#!/bin/bash

set -euo pipefail

die() {
  echo "❌ ${1}" >&2
  exit 1
}

show_usage() {
  echo "Usage: $(basename "$0") [project_path]"
  echo "Runs SwiftFormat and SwiftLint autocorrect, then cleans .build artifacts for the target project."
}

if [[ ${1-} == "--help" ]] || [[ ${1-} == "-h" ]]; then
  show_usage
  exit 0
fi

PROJECT_PATH="${1:-${PWD}}"

if [[ ! -d ${PROJECT_PATH} ]]; then
  die "Project path not found: ${PROJECT_PATH}"
fi

cd "${PROJECT_PATH}"

PROJECT_NAME="$(basename "${PROJECT_PATH}")"

echo "🔧 Simple Auto-Fix for ${PROJECT_NAME}"

# Basic SwiftFormat
if command -v swiftformat >/dev/null 2>&1; then
  echo "🔄 Running SwiftFormat..."
  if ! swiftformat .; then
    echo "⚠️ SwiftFormat reported issues (continuing anyway)"
  fi
  echo "✅ SwiftFormat completed"
else
  echo "⚠️ SwiftFormat not available"
fi

# Basic SwiftLint autocorrect
if command -v swiftlint >/dev/null 2>&1; then
  echo "🔄 Running SwiftLint autocorrect..."
  if ! swiftlint lint --autocorrect; then
    echo "⚠️ SwiftLint autocorrect reported issues (continuing anyway)"
  fi
  echo "✅ SwiftLint autocorrect completed"
else
  echo "⚠️ SwiftLint not available"
fi

# Clean build artifacts
if [[ -d ".build" ]]; then
  echo "🔄 Cleaning build artifacts..."
  rm -rf .build || true
  echo "✅ Build artifacts cleaned"
fi

echo "✅ Simple auto-fix completed successfully"
