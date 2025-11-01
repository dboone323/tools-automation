#!/usr/bin/env bash
# SwiftPM Coverage Gate
# Computes line coverage for a SwiftPM package using llvm-cov and enforces a threshold.
#
# Usage:
#   spm_coverage_gate.sh <project_dir> [threshold_percent] [ignore_regex] [soft_fail]
#
# Args:
#   project_dir        Path to the SwiftPM project (directory containing Package.swift)
#   threshold_percent  Integer percent threshold to enforce (default: 85)
#   ignore_regex       Regex passed to llvm-cov -ignore-filename-regex (optional)
#   soft_fail          If set to 'true', prints failure but exits 0 (default: false)
#
# Output:
#   Prints computed coverage percent and pass/fail message.
#   Exits non-zero on failure unless soft_fail=true.

set -euo pipefail

PROJECT_DIR=${1:-}
THRESHOLD=${2:-85}
IGNORE_REGEX=${3:-}
SOFT_FAIL=${4:-false}

if [[ -z "${PROJECT_DIR}" ]] || [[ ! -f "${PROJECT_DIR}/Package.swift" ]]; then
    echo "Usage: $0 <project_dir> [threshold_percent] [ignore_regex] [soft_fail]" >&2
    exit 2
fi

pushd "${PROJECT_DIR}" >/dev/null

echo "🔧 Running tests with code coverage (SwiftPM)…"
if ! swift test --enable-code-coverage --parallel; then
    echo "❌ swift test failed"
    if [[ "${SOFT_FAIL}" == "true" ]]; then
        popd >/dev/null
        exit 0
    else
        popd >/dev/null
        exit 1
    fi
fi

# Locate profdata and test bundle binary
PROFDATA=$(find .build -type f -path "*/codecov/default.profdata" | head -n 1 || true)
if [[ -z "${PROFDATA}" ]]; then
    PROFDATA=$(find .build -type f -name "*.profdata" | head -n 1 || true)
fi

TEST_BUNDLE=$(find .build -type f -path "*.xctest/Contents/MacOS/*Tests" | head -n 1 || true)
if [[ -z "${TEST_BUNDLE}" ]]; then
    # Fallback (debug path may differ by arch)
    TEST_BUNDLE=$(find .build -type f -name "*PackageTests" | head -n 1 || true)
fi

if [[ -z "${PROFDATA}" || -z "${TEST_BUNDLE}" ]]; then
    echo "❌ Could not find coverage artifacts (.profdata or test bundle)"
    echo "   profdata: ${PROFDATA:-<none>}"
    echo "   bundle:   ${TEST_BUNDLE:-<none>}"
    if [[ "${SOFT_FAIL}" == "true" ]]; then
        popd >/dev/null
        exit 0
    else
        popd >/dev/null
        exit 1
    fi
fi

echo "📦 profdata: ${PROFDATA}"
echo "🧪 bundle:   ${TEST_BUNDLE}"

CMD=(xcrun llvm-cov report "${TEST_BUNDLE}" -instr-profile "${PROFDATA}" -use-color=0)
if [[ -n "${IGNORE_REGEX}" ]]; then
    CMD+=(-ignore-filename-regex "${IGNORE_REGEX}")
fi

echo "🔎 Computing coverage (filtered)…"
REPORT=$("${CMD[@]}" || true)
echo "${REPORT}" >.build/coverage_report.txt

# Try to parse total line coverage percent from report output
# The TOTAL line format varies; extract the last percentage value in the output.
COVERAGE=$(echo "${REPORT}" | grep -Eo "[0-9]+\.[0-9]+%" | tail -n 1 | tr -d '%')
if [[ -z "${COVERAGE}" ]]; then
    # Fallback: derive from lines executed/total if present
    # Not all llvm-cov versions print a TOTAL row consistently; best-effort parsing.
    COVERAGE="0.0"
fi

printf "📈 Coverage: %.2f%%\n" "${COVERAGE}"

PASS=0
awk -v c="${COVERAGE}" -v t="${THRESHOLD}" 'BEGIN{ if (c+0 >= t+0) exit 0; else exit 1 }' || PASS=1

if [[ ${PASS} -eq 0 ]]; then
    echo "✅ Coverage meets threshold (${COVERAGE}% >= ${THRESHOLD}%)"
    popd >/dev/null
    exit 0
else
    echo "❌ Coverage below threshold (${COVERAGE}% < ${THRESHOLD}%)"
    if [[ "${SOFT_FAIL}" == "true" ]]; then
        popd >/dev/null
        exit 0
    else
        popd >/dev/null
        exit 1
    fi
fi
