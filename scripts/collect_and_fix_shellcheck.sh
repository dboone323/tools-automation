#!/usr/bin/env bash
# Collect ShellCheck issues repo-wide and apply a small set of safe fixes automatically.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/issues"
mkdir -p "$OUT_DIR"

SC_CMD="shellcheck"
if ! command -v "$SC_CMD" >/dev/null 2>&1; then
    echo "shellcheck is not installed. Please install shellcheck and re-run." >&2
    exit 1
fi

REPORT_JSON="$OUT_DIR/shellcheck_issues_before.json"
REPORT_TXT="$OUT_DIR/shellcheck_issues_before.txt"
REPORT_JSON_AFTER="$OUT_DIR/shellcheck_issues_after.json"
REPORT_TXT_AFTER="$OUT_DIR/shellcheck_issues_after.txt"

echo "Running shellcheck across repo..."
find "$ROOT_DIR" -type f -name '*.sh' -not -path "$ROOT_DIR/.git/*" -not -path "$ROOT_DIR/test_tmp/*" -print0 |
    xargs -0 "$SC_CMD" --format=json --external-sources --color=never --shell=bash >"$REPORT_JSON" || true

if [[ ! -s "$REPORT_JSON" ]]; then
    echo "No shellcheck output (no issues or error running shellcheck)." >"$REPORT_TXT"
else
    echo "Parsing shellcheck JSON results to $REPORT_TXT"
    jq -r '.[] | "\(.file):\(.line):\(.column): [\(.level)] SC\(.code): \(.message)"' "$REPORT_JSON" >"$REPORT_TXT" || true
fi

echo "Applying safe automatic fixes (SC1114, SC2155)"

# Fix SC1114: leading spaces before shebang (remove leading whitespace before #!)
files_sc1114=$(jq -r '.[] | select(.code==1114) | .file' "$REPORT_JSON" 2>/dev/null | sort -u || true)
for f in $files_sc1114; do
    if [[ -f "$f" ]]; then
        echo "Fixing SC1114 shebang spacing in: $f"
        # Use perl for robust in-place edits across platforms; create .bak for safety
        perl -0777 -i.bak -pe 's/^[ \t]+#!/#!/mg' "$f"
        rm -f "$f.bak"
    fi
done

# Fix SC2155: avoid masking return values by splitting declaration and assignment
files_sc2155=$(jq -r '.[] | select(.code==2155) | .file' "$REPORT_JSON" 2>/dev/null | sort -u || true)
for f in $files_sc2155; do
    if [[ -f "$f" ]]; then
        echo "Fixing SC2155 local declaration masking in: $f"
        # Transform lines like: local var=$(cmd)  -> local var; var=$(cmd)
        # Use perl multiline to keep it robust; create .bak for safety
        perl -0777 -i.bak -pe 's/^(\s*)local\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$/\1local \2;\n\1\2=\3/gm' "$f"
        rm -f "$f.bak"
    fi
done

echo "Re-running shellcheck to generate after-report..."
find "$ROOT_DIR" -type f -name '*.sh' -not -path "$ROOT_DIR/.git/*" -not -path "$ROOT_DIR/test_tmp/*" -print0 |
    xargs -0 "$SC_CMD" --format=json --external-sources --color=never --shell=bash >"$REPORT_JSON_AFTER" || true

if [[ ! -s "$REPORT_JSON_AFTER" ]]; then
    echo "No shellcheck output after fixes." >"$REPORT_TXT_AFTER"
else
    jq -r '.[] | "\(.file):\(.line):\(.column): [\(.level)] SC\(.code): \(.message)"' "$REPORT_JSON_AFTER" >"$REPORT_TXT_AFTER" || true
fi

echo "Reports written to:"
echo "  $REPORT_JSON"
echo "  $REPORT_TXT"
echo "  $REPORT_JSON_AFTER"
echo "  $REPORT_TXT_AFTER"

echo "Done. Review the $OUT_DIR files and, if OK, commit the intended fixes."

exit 0
