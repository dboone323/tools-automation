#!/bin/bash
# Check if service error budget allows rollback

SERVICE="${1:-post_merge_tests}"
TRACKER="metrics/error_budget_tracker.json"

if [[ "$2" == "--can-rollback" ]]; then
    # Read current failure rate
    FAILURES=$(jq -r ".services.${SERVICE}.current_failures" "$TRACKER" 2>/dev/null || echo "0")
    TOTAL=$(jq -r ".services.${SERVICE}.total_runs" "$TRACKER" 2>/dev/null || echo "0")
    BUDGET=$(jq -r ".services.${SERVICE}.budget_percent" "$TRACKER" 2>/dev/null || echo "5.0")

    if ((TOTAL == 0)); then
        echo "true"
        exit 0
    fi

    RATE=$(awk "BEGIN {print ($FAILURES / $TOTAL) * 100}")

    if (($(echo "$RATE < $BUDGET" | bc -l))); then
        echo "true"
        exit 0
    else
        echo "false - error budget exhausted ($RATE% >= $BUDGET%)"
        exit 1
    fi
else
    # Display error budget status
    echo "Error Budget Status for: $SERVICE"
    echo "=========================================="

    if [[ ! -f "$TRACKER" ]]; then
        echo "ERROR: Tracker file not found: $TRACKER"
        exit 1
    fi

    jq -r ".services.${SERVICE} // empty" "$TRACKER" | jq .

    if [[ -z "$(jq -r ".services.${SERVICE} // empty" "$TRACKER")" ]]; then
        echo "ERROR: Service not found in tracker: $SERVICE"
        exit 1
    fi
fi
