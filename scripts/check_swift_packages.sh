#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPORTS="$ROOT_DIR/reports"
mkdir -p "$REPORTS"

status_json="$REPORTS/swift_package_status.json"

declare -a packages
while IFS= read -r -d '' f; do
    packages+=("$f")
done < <(find "$ROOT_DIR" -maxdepth 3 -name Package.swift -print0 | sort -z)

jq_array="[]"

for pkg_file in "${packages[@]}"; do
    pkg_dir="$(dirname "$pkg_file")"
    rel="${pkg_dir#"$ROOT_DIR"/}"
    tests_dir="$pkg_dir/Tests"
    issues=()
    if [[ ! -d "$tests_dir" ]]; then
        issues+=("missing Tests directory")
    else
        # Count test files
        test_files_count=$(find "$tests_dir" -type f -name '*Tests.swift' 2>/dev/null | wc -l | awk '{print $1}')
        if [[ "$test_files_count" -eq 0 ]]; then
            issues+=("no *Tests.swift files detected")
        fi
    fi
    # Validate swift build (dry run)
    build_ok=1
    if ! (cd "$pkg_dir" && swift package describe >/dev/null 2>&1); then
        build_ok=0
        issues+=("swift package describe failed")
    fi
    # Add entry
    issues_json=$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')
    jq_array=$(jq \
        --arg dir "$rel" \
        --argjson build_ok "$build_ok" \
        --argjson issues "$issues_json" \
        '. + [{package_dir:$dir, build_ok:($build_ok==1), issues:$issues}]' <<<"$jq_array")

done

echo "$jq_array" >"$status_json"
echo "Wrote $status_json"
