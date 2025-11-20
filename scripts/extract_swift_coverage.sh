#!/usr/bin/env bash
set -euo pipefail
# Export SwiftPM code coverage for a package into JSON using llvm-cov.
# Usage: scripts/extract_swift_coverage.sh <package_dir> <output_json>

if [[ $# -lt 2 ]]; then
    echo "usage: $0 <package_dir> <output_json>" >&2
    exit 2
fi

PKG_DIR="$1"
OUT_JSON="$2"

if ! command -v xcrun >/dev/null 2>&1; then
    echo '{"error":"xcrun not available"}' >"$OUT_JSON"
    exit 0
fi

# Locate profdata and binary objects
BUILD_DIR="$PKG_DIR/.build"
PROFDATA="$(find "$BUILD_DIR" -name default.profdata -print -quit 2>/dev/null || true)"
if [[ -z "$PROFDATA" ]]; then
    # Swift 5.10+: coverage may be under .build/debug/codecov
    PROFDATA="$(find "$BUILD_DIR" -name codecov -type d -print -quit 2>/dev/null)/default.profdata"
fi
if [[ ! -f "$PROFDATA" ]]; then
    echo '{"error":"profdata not found"}' >"$OUT_JSON"
    exit 0
fi

# Collect object files (swiftmodule binaries)
OBJECTS=()
while IFS= read -r -d '' o; do OBJECTS+=("$o"); done < <(find "$BUILD_DIR" -name "*.build" -prune -o \( -name "*.o" -o -name "*.swiftmodule" \) -print0 2>/dev/null)

if [[ ${#OBJECTS[@]} -eq 0 ]]; then
    echo '{"error":"no object files found"}' >"$OUT_JSON"
    exit 0
fi

# Try exporting as JSON summary (llvm-cov export supports -format=lcov/json depending on version)
set +e
xcrun llvm-cov export \
    -instr-profile "$PROFDATA" \
    -ignore-filename-regex '.*/Tests/.*' \
    "${OBJECTS[@]}" 2>/dev/null >"$OUT_JSON"
rc=$?
set -e

if [[ $rc -ne 0 || ! -s "$OUT_JSON" ]]; then
    # Fallback: produce minimal summary by running show and converting to JSON-ish text
    TMP_TXT="$(mktemp)"
    xcrun llvm-cov show -instr-profile "$PROFDATA" "${OBJECTS[@]}" >"$TMP_TXT" 2>/dev/null || true
    total_lines=$(grep -cE "^\s*[0-9]+\s*\|" "$TMP_TXT")
    covered=$(grep -cE "^\s*[1-9][0-9]*\s*\|" "$TMP_TXT")
    echo "{\"summary\":{\"lines\":$total_lines,\"covered\":$covered}}" >"$OUT_JSON"
    rm -f "$TMP_TXT"
fi

echo "Wrote $OUT_JSON"
