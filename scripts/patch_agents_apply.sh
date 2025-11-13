#!/usr/bin/env bash
# Safer patcher: inject canonical boilerplate into agent scripts
# Usage: ./patch_agents_apply.sh [--dry-run]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$ROOT_DIR/.agent_backups"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

mkdir -p "$BACKUP_DIR"

echo "Patching agents from /tmp/missing_health.txt (dry-run=${DRY_RUN})"
count=0
modified=0

while IFS= read -r f || [[ -n "$f" ]]; do
    if [[ ! -f "$f" ]]; then
        echo "SKIP: $f (not found)"
        continue
    fi
    count=$((count + 1))

    base=$(basename "$f")

    if grep -qE -- '--health|agent_health_check|health[[:space:]]*check|status[[:space:]]*check' "$f" 2>/dev/null; then
        echo "SKIP: $base (already has health handler)"
        continue
    fi

    echo "PATCH: $base"
    if [[ "$DRY_RUN" == "false" ]]; then
        cp -p "$f" "$BACKUP_DIR/${base}.bak"

        tmpfile="/tmp/agent_patch_${base}.tmp"
        out="/tmp/agent_out_${base}"
        rm -f "$tmpfile" "$out"

        firstline=$(head -n1 "$f" || true)
        if [[ "$firstline" =~ ^#! ]]; then
            echo "$firstline" >"$tmpfile"
            tail -n +2 "$f" >>"$tmpfile"
        else
            cat "$f" >"$tmpfile"
        fi

        # Build boilerplate
        cat >"$out" <<'BOILER'
        #!/usr/bin/env bash
        # Auto-injected health & reliability shim

        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer shared helpers when available
if [[ -f "$DIR/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="__AGENT_BASENAME__"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  issues=()
  if [[ ! -w "/tmp" ]]; then
    issues+=("tmp_not_writable")
  fi
  if [[ ! -d "$DIR" ]]; then
    issues+=("cwd_missing")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
    exit 2
  fi
  printf '{"ok":true}\n'
  exit 0
fi

# Original agent script continues below
BOILER

        # append original body (tmpfile excludes shebang)
        tail -n +1 "$tmpfile" >>"$out"
        sed -i.bak "s|__AGENT_BASENAME__|${base}|g" "$out" || true
        mv "$out" "$f"
        chmod +x "$f"
        rm -f "$tmpfile"
        modified=$((modified + 1))
    fi

done </tmp/missing_health.txt

echo "Scanned $count agent files; modified $modified files (backups in $BACKUP_DIR)"

exit 0
