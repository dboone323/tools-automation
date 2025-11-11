#!/usr/bin/env bash
set -euo pipefail

# Background mode and autorestart
BACKGROUND_MODE="${BACKGROUND_MODE:-false}"
AUDIT_INTERVAL="${AUDIT_INTERVAL:-3600}" # 1 hour default
MAX_RESTARTS="${MAX_RESTARTS:-5}"

threshold="${1:-50M}"

# Convert threshold units to find-compatible format (k for kilobytes, etc.)
threshold_find="${threshold//K/k}"

# Function to run audit
run_audit() {
  echo "=== LARGE FILES AUDIT $(date) ==="
  echo "Scanning working tree for files > $threshold..."
  find . -type f -not -path "./.git/*" -size +"$threshold_find" -print | sed 's|^./||' || true

  printf "\nTop 30 largest blobs in Git history (bytes\tpath):\n"

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  git rev-list --objects --all >"$tmpdir/objects.txt" 2>/dev/null || echo "Warning: Could not access git history"
  if [[ -s "$tmpdir/objects.txt" ]]; then
    cut -d' ' -f1 "$tmpdir/objects.txt" |
      git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' >"$tmpdir/sizes.txt" 2>/dev/null || echo "Warning: Could not get object sizes"

    awk '
          FNR==NR && $1=="blob" { size[$2]=$3; next }
          { sha=$1; $1=""; sub(/^ /,""); path=$0; if (sha in size) print size[sha] "\t" path }
        ' "$tmpdir/sizes.txt" "$tmpdir/objects.txt" | sort -nr | head -n 30 || true
  fi

  rm -rf "$tmpdir"
  echo "=== AUDIT COMPLETE ==="
}

# Main execution
if [[ "$BACKGROUND_MODE" == "true" ]]; then
  echo "Starting large files audit in background mode (interval: ${AUDIT_INTERVAL}s)"

  restart_count=0
  while [[ $restart_count -lt $MAX_RESTARTS ]]; do
    echo "Audit cycle $((restart_count + 1))/$MAX_RESTARTS started at $(date)"

    if run_audit; then
      echo "Audit completed successfully"
      restart_count=0 # Reset on success
    else
      echo "Audit failed, will retry"
      restart_count=$((restart_count + 1))
      sleep 30 # Wait before retry
      continue
    fi

    echo "Sleeping for ${AUDIT_INTERVAL} seconds..."
    sleep "$AUDIT_INTERVAL"
  done

  echo "Maximum restart attempts reached, stopping audit service"
  exit 1
else
  run_audit
fi
