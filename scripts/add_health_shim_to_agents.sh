#!/usr/bin/env bash
# Add a lightweight --health handler to shell agents that don't have one.
# This script is conservative: it only prepends a small non-invasive handler
# when it detects the agent file lacks a --health flag.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="$ROOT_DIR/agents"
BACKUP_DIR="$ROOT_DIR/.agent_backups"
mkdir -p "$BACKUP_DIR"

echo "Scanning agents in $AGENTS_DIR"
count=0
modified=0
for f in "$AGENTS_DIR"/agent_*.sh "$AGENTS_DIR"/*_agent.sh; do
  if [[ -f "$f" ]]; then
    ((count++))
    if ! grep -qE -- '--health|health\)' "$f"; then
      echo "Patching $f (no --health detected)"
      cp "$f" "$BACKUP_DIR/$(basename "$f").bak"
      tmpfile="$f.tmp"
      # keep shebang
      shebang=""
      read -r firstline <"$f"
      if [[ "$firstline" =~ ^#! ]]; then
        shebang="${firstline}\n"
        tail -n +2 "$f" >"$tmpfile"
      else
        cat "$f" >"$tmpfile"
      fi
      cat >"$f" <<'EOF'
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
AGENT_NAME="$(basename "$f")"
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
EOF
      # append the original body (excluding original shebang if we preserved it)
      if [[ -n "$shebang" ]]; then
        # re-add original shebang as comment to preserve info
        echo "# original shebang: $shebang" >>"$f"
      fi
      cat "$tmpfile" >>"$f"
      rm -f "$tmpfile"
      chmod +x "$f"
      ((modified++))
    fi
  fi
done

echo "Scanned $count agent files; modified $modified files (backups in $BACKUP_DIR)"
