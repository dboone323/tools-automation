#!/usr/bin/env bash
# Patch agents with robust health & error-handling boilerplate.
# Makes backups to .agent_backups/

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="$ROOT_DIR/agents"
BACKUP_DIR="$ROOT_DIR/.agent_backups"
mkdir -p "$BACKUP_DIR"

echo "Patching agents in $AGENTS_DIR"
count=0
modified=0

for f in "$AGENTS_DIR"/agent_*.sh "$AGENTS_DIR"/*_agent.sh; do
    if [[ ! -f "$f" ]]; then
        continue
    fi
    ((count++))

    # Skip files that already expose health or agent_health_check
    if grep -qE -- '--health|agent_health_check|health[[:space:]]*check|status[[:space:]]*check' "$f"; then
        echo "SKIP: $(basename "$f") (already has health handler)"
        continue
    fi

    echo "Patching: $(basename "$f")"
    cp "$f" "$BACKUP_DIR/$(basename "$f").bak"

    tmpfile="/tmp/agent_patch_$(basename "$f").tmp"
    rm -f "$tmpfile"

    # preserve shebang
    firstline=$(head -n1 "$f" || true)
    if [[ "$firstline" =~ ^#! ]]; then
        echo "$firstline" >"$tmpfile"
        tail -n +2 "$f" >>"$tmpfile"
    else
        cat "$f" >"$tmpfile"
    fi

    out="/tmp/agent_out_$(basename "$f")"
    rm -f "$out"

    # Build boilerplate
    cat >"$out" <<'BOILER'
#!/usr/bin/env bash
# Auto-injected health & reliability shim
# Adds: standardized --health handler, strict mode, and a graceful shutdown trap

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

# Enable strict mode for safer scripts
set -euo pipefail

# Default agent logging vars if not present
AGENT_NAME="__AGENT_BASENAME__"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

# Ensure we update status on termination if helper available
if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

# Health handler
if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  # Best-effort lightweight checks
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

    # Combine the boilerplate with the original script body (excluding original shebang if present)
    # If the original file had a shebang, it is preserved at top of tmpfile; we should avoid duplicating shebang
    # We'll append the body from tmpfile (which excludes shebang if it was present)
    # Remove any leading blank lines from tmpfile
    tail -n +1 "$tmpfile" >>"$out"

    # Replace placeholder with actual basename
    sed -i.bak "s|__AGENT_BASENAME__|$(basename "$f")|g" "$out" || true
    mv "$out" "$f"
    chmod +x "$f"
    rm -f "$tmpfile"
    ((modified++))
done

echo "Scanned $count agent files; modified $modified files (backups in $BACKUP_DIR)"
