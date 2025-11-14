#!/usr/bin/env bash
# Fast validation for submodules: lint + describe/list checks, optional coverage
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBMODULES=("CodingReviewer" "PlannerApp" "HabitQuest" "MomentumFinance" "AvoidObstaclesGame" "shared-kit")
OUT_DIR="${ROOT_DIR}/metrics/validation"
mkdir -p "$OUT_DIR"

run_lint() {
    local dir="$1"
    local result="skipped"
    local warnings=0
    local errors=0
    if command -v swiftlint >/dev/null 2>&1; then
        pushd "$dir" >/dev/null
        if swiftlint --quiet >/dev/null 2>&1; then
            result="clean"
        else
            # Count via reporter output
            local json
            json=$(swiftlint --reporter json 2>/dev/null || true)
            warnings=$(echo "$json" | grep -o '"severity":"warning"' | wc -l | tr -d ' ' || true)
            errors=$(echo "$json" | grep -o '"severity":"error"' | wc -l | tr -d ' ' || true)
            result="issues"
        fi
        popd >/dev/null
    fi
    echo "$result|$warnings|$errors"
}

validate_submodule() {
    local sub="$1"
    local dir="${ROOT_DIR}/${sub}"
    if [[ ! -d "$dir" ]]; then
        echo "[FAST] Skip missing submodule: $sub" >&2
        return
    fi

    local lint_res lint_warn lint_err
    IFS='|' read -r lint_res lint_warn lint_err < <(run_lint "$dir")

    local mode="none"
    local status="unknown"
    pushd "$dir" >/dev/null
    shopt -s nullglob
    local xcodeprojs=(*.xcodeproj)
    local xcworkspaces=(*.xcworkspace)
    shopt -u nullglob
    if ((${#xcodeprojs[@]} > 0 || ${#xcworkspaces[@]} > 0)); then
        mode="xcode"
        if command -v xcodebuild >/dev/null 2>&1; then
            local schemes_json
            schemes_json=$(xcodebuild -list -json 2>/dev/null || true)
            if [[ -n "$schemes_json" ]] && command -v jq >/dev/null 2>&1; then
                local scheme
                scheme=$(echo "$schemes_json" | jq -r '(.project.schemes // [])[0] // (.workspace.schemes // [])[0] // empty' 2>/dev/null || true)
                if [[ -n "$scheme" ]] && xcodebuild -scheme "$scheme" -showBuildSettings -quiet >/dev/null 2>&1; then
                    status="ok"
                else
                    status="issues"
                fi
            else
                status="list-unavailable"
            fi
        else
            status="xcodebuild-missing"
        fi
    elif [[ -f "Package.swift" ]]; then
        mode="swiftpm"
        if command -v swift >/dev/null 2>&1 && swift package describe >/dev/null 2>&1; then
            status="ok"
        else
            status="issues"
        fi
    fi
    popd >/dev/null

    # Optional coverage step
    local coverage="skipped"
    if [[ "${RUN_COVERAGE:-0}" == "1" ]]; then
        if [[ -f "${ROOT_DIR}/analyze_coverage.sh" ]]; then
            pushd "$ROOT_DIR" >/dev/null
            if RUN_SUBMODULE="$sub" ./analyze_coverage.sh >/dev/null 2>&1; then
                coverage="generated"
            else
                coverage="failed"
            fi
            popd >/dev/null
        fi
    fi

    # Write summary JSON
    jq -n --arg sub "$sub" \
        --arg lint "$lint_res" --argjson lw "${lint_warn:-0}" --argjson le "${lint_err:-0}" \
        --arg mode "$mode" --arg status "$status" --arg coverage "$coverage" \
        '{submodule:$sub, lint:{result:$lint, warnings:$lw, errors:$le}, validation:{mode:$mode, status:$status}, coverage:$coverage, timestamp: now|floor}' >"${OUT_DIR}/${sub}.json"

    echo "[FAST] ${sub}: lint=${lint_res} (${lint_warn}w/${lint_err}e), ${mode}:${status}, coverage=${coverage}"
}

main() {
    local list=("${SUBMODULES[@]}")
    if (($# > 0)); then
        list=("$@")
    fi
    for s in "${list[@]}"; do
        validate_submodule "$s"
    done
    echo "[FAST] Results in ${OUT_DIR}"
}

main "$@"
