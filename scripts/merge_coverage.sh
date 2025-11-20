#!/usr/bin/env bash
set -euo pipefail
# Merge Python (coverage.py JSON) and Swift (llvm-cov export JSON) into a single summary JSON
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPORTS="$ROOT_DIR/reports"
mkdir -p "$REPORTS"

PY_JSON="$REPORTS/python-coverage.json"
mapfile -t SWIFT_JSONS < <(ls "$REPORTS"/swift-coverage-*.json 2>/dev/null || true)

python_summary=0
python_total=0
if [[ -f "$PY_JSON" ]]; then
    # coverage.py JSON has totals in 'totals' with 'covered_lines' and 'num_statements'
    python_summary=$(jq -r '.totals.covered_lines // 0' "$PY_JSON" 2>/dev/null || echo 0)
    python_total=$(jq -r '.totals.num_statements // 0' "$PY_JSON" 2>/dev/null || echo 0)
fi

swift_covered=0
swift_total=0
for f in "${SWIFT_JSONS[@]}"; do
    # Try to parse export format, else fallback summary keys
    if jq -e '.data' "$f" >/dev/null 2>&1; then
        # llvm-cov export format: sum regions where count>0
        covered=$(jq '[.data[].files[].segments[] | select(.[2] > 0)] | length' "$f" 2>/dev/null || echo 0)
        total=$(jq '[.data[].files[].segments[]] | length' "$f" 2>/dev/null || echo 0)
    else
        covered=$(jq -r '.summary.covered // 0' "$f" 2>/dev/null || echo 0)
        total=$(jq -r '.summary.lines // 0' "$f" 2>/dev/null || echo 0)
    fi
    swift_covered=$((swift_covered + covered))
    swift_total=$((swift_total + total))
done

overall_covered=$((python_summary + swift_covered))
overall_total=$((python_total + swift_total))

jq -n \
    --argjson python_covered "$python_summary" \
    --argjson python_total "$python_total" \
    --argjson swift_covered "$swift_covered" \
    --argjson swift_total "$swift_total" \
    --argjson overall_covered "$overall_covered" \
    --argjson overall_total "$overall_total" \
    '{python:{covered: $python_covered, total: $python_total}, swift:{covered:$swift_covered, total:$swift_total}, overall:{covered:$overall_covered, total:$overall_total}}' \
    >"$REPORTS/coverage_unified.json"

echo "Wrote $REPORTS/coverage_unified.json"
