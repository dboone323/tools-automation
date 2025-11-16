#!/usr/bin/env bash
# Trend Calculator: builds metrics/trends.json based on historical dashboard snapshots
# Appends current dashboard snapshot to metrics/history/dashboard_history.jsonl and computes deltas.

set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD_FILE="${ROOT_DIR}/dashboard_data.json"
ALERT_CONFIG="${ROOT_DIR}/alert_config.json"
HISTORY_DIR="${ROOT_DIR}/metrics/history"
HISTORY_FILE="${HISTORY_DIR}/dashboard_history.jsonl"
TRENDS_FILE="${ROOT_DIR}/metrics/trends.json"
mkdir -p "${HISTORY_DIR}" "${ROOT_DIR}/metrics"

now_epoch="$(date +%s)"

if [[ ! -f "${DASHBOARD_FILE}" ]]; then
  echo "[TREND] dashboard_data.json missing; abort" >&2
  exit 0
fi

# Load window & thresholds from alert_config (fallback defaults)
window_hours=$(jq -r '.trend_detection.window_hours // 24' "${ALERT_CONFIG}" 2>/dev/null || echo 24)
error_thr=$(jq -r '.trend_detection.thresholds.error_rate_increase_percent // 50' "${ALERT_CONFIG}" 2>/dev/null || echo 50)
fallback_thr=$(jq -r '.trend_detection.thresholds.fallback_rate_increase_percent // 100' "${ALERT_CONFIG}" 2>/dev/null || echo 100)
coverage_thr=$(jq -r '.trend_detection.thresholds.coverage_drop_percent // 10' "${ALERT_CONFIG}" 2>/dev/null || echo 10)

# Extract snapshot relevant fields
snapshot=$(jq -n \
  --argjson dash "$(cat "${DASHBOARD_FILE}" 2>/dev/null || echo '{}')" \
  --arg ts "${now_epoch}" ' {
    timestamp: ($ts|tonumber),
    error_rates: ($dash.error_budget_status.services // [] | map(.failure_rate_percent // 0)),
    fallback_rate: ($dash.fallback_metrics.fallback_rate_percent // 0),
    coverage_values: ($dash.submodule_metrics // {} | to_entries | map(.value.coverage // 0))
  }')

# Append snapshot to history
printf '%s\n' "${snapshot}" >>"${HISTORY_FILE}"

# Collect window snapshots
window_seconds=$((window_hours * 3600))
cutoff=$((now_epoch - window_seconds))

# Filter snapshots within window
window_data=$(jq -s --arg cutoff "${cutoff}" '[.[] | select((.timestamp // 0) >= ($cutoff|tonumber))]' "${HISTORY_FILE}" 2>/dev/null || echo '[]')

# Baseline = earliest in window, current = last in window
baseline=$(echo "${window_data}" | jq '.[0]')
current=$(echo "${window_data}" | jq '.[-1]')

# Helper to compute max error rate from array
baseline_error=$(echo "${baseline}" | jq '[.error_rates[]] | max // 0' 2>/dev/null || echo 0)
current_error=$(echo "${current}" | jq '[.error_rates[]] | max // 0' 2>/dev/null || echo 0)

# Fallback rate
baseline_fallback=$(echo "${baseline}" | jq '.fallback_rate // 0' 2>/dev/null || echo 0)
current_fallback=$(echo "${current}" | jq '.fallback_rate // 0' 2>/dev/null || echo 0)

# Coverage average (if any)
baseline_cov=$(echo "${baseline}" | jq '(.coverage_values // []) | if length>0 then (add/length) else 0 end' 2>/dev/null || echo 0)
current_cov=$(echo "${current}" | jq '(.coverage_values // []) | if length>0 then (add/length) else 0 end' 2>/dev/null || echo 0)

## Load delta helpers from shared helper file to enable isolated unit testing.
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/trend_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/trend_helpers.sh"
else
  # Fallback: define minimal helpers inline (should not normally happen)
  percent_increase() { awk -v b="$1" -v c="$2" 'BEGIN{printf("%.2f", (b==0? (c==0?0:100) : ((c-b)/b)*100))}'; }
  percent_drop() { awk -v b="$1" -v c="$2" 'BEGIN{printf("%.2f", (b==0?0:((b-c)/b)*100))}'; }
fi

error_delta=$(percent_increase "$baseline_error" "$current_error")
fallback_delta=$(percent_increase "$baseline_fallback" "$current_fallback")
coverage_delta=$(percent_drop "$baseline_cov" "$current_cov")

# Compose trends JSON
jq -n \
  --argjson gen "$now_epoch" \
  --argjson wh "$window_hours" \
  --argjson bErr "$baseline_error" --argjson cErr "$current_error" --arg errDel "$error_delta" --arg errThr "$error_thr" \
  --argjson bFb "$baseline_fallback" --argjson cFb "$current_fallback" --arg fbDel "$fallback_delta" --arg fbThr "$fallback_thr" \
  --argjson bCov "$baseline_cov" --argjson cCov "$current_cov" --arg covDel "$coverage_delta" --arg covThr "$coverage_thr" '{
    generated_at: $gen,
    window_hours: $wh,
    metrics: {
      error_rate: {baseline: $bErr, current: $cErr, delta_percent: ($errDel|tonumber), threshold: ($errThr|tonumber), exceeded: (($errDel|tonumber) > ($errThr|tonumber))},
      fallback_rate: {baseline: $bFb, current: $cFb, delta_percent: ($fbDel|tonumber), threshold: ($fbThr|tonumber), exceeded: (($fbDel|tonumber) > ($fbThr|tonumber))},
      coverage_drop: {baseline: $bCov, current: $cCov, delta_percent: ($covDel|tonumber), threshold: ($covThr|tonumber), exceeded: (($covDel|tonumber) > ($covThr|tonumber))}
    }
  }' >"${TRENDS_FILE}"

echo "[TREND] Trends updated: ${TRENDS_FILE}" >&2
