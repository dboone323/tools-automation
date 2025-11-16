#!/usr/bin/env bash
# Helper functions for trend calculations (percent_increase / percent_drop)
set -euo pipefail

# percent_increase baseline current -> prints percent increase formatted to 2 decimals
percent_increase() {
    local b=${1:-0}
    local c=${2:-0}

    # Treat numeric zero specially
    if awk -v x="$b" 'BEGIN{exit !(x==0)}'; then
        if awk -v y="$c" 'BEGIN{exit !(y==0)}'; then
            printf "0\n"
        else
            printf "100\n"
        fi
    else
        # Use awk for floating point math/formatting
        awk -v b="$b" -v c="$c" 'BEGIN{printf("%.2f", ((c - b) / b) * 100)}'
    fi
}

# percent_drop baseline current -> prints percent drop (positive when decreased)
percent_drop() {
    local b=${1:-0}
    local c=${2:-0}

    if awk -v x="$b" 'BEGIN{exit !(x==0)}'; then
        printf "0\n"
    else
        awk -v b="$b" -v c="$c" 'BEGIN{printf("%.2f", ((b - c) / b) * 100)}'
    fi
}

return 0
