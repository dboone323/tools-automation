#!/bin/bash

# RBAC maintenance utilities

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSIONS_DB="$WORKSPACE_ROOT/rbac_config/sessions.json"
LOGFILE="$WORKSPACE_ROOT/logs/rbac_maintenance.log"

log() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $*" >>"$LOGFILE"
    echo "[$ts] $*" >&2
}

iso_to_epoch() {
    local iso="$1"
    if [[ -z "$iso" || "$iso" == "null" ]]; then
        echo 0
        return
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null || echo 0
        return
    fi

    printf '%s' "$iso" | python3 - <<'PY'
import sys,datetime
s=sys.stdin.read().strip()
s=s.replace('Z','+00:00')
try:
    dt=datetime.datetime.fromisoformat(s)
    print(int(dt.timestamp()))
except Exception:
    print(0)
PY
}

prune_expired() {
    log "Starting session prune"
    if [[ ! -f "$SESSIONS_DB" ]]; then
        log "No sessions DB found at $SESSIONS_DB"
        return 0
    fi

    local now
    now=$(date +%s)

    # Iterate session ids
    local ids
    ids=$(jq -r '.sessions | keys[]' "$SESSIONS_DB") || ids=""

    for sid in $ids; do
        local expires
        expires=$(jq -r ".sessions.\"$sid\".expires_at // empty" "$SESSIONS_DB" || true)

        if [[ -z "$expires" ]]; then
            # No expiry; skip
            continue
        fi

        local exp_epoch
        exp_epoch=$(iso_to_epoch "$expires")

        if [[ -z "$exp_epoch" || "$exp_epoch" -le 0 ]]; then
            # Invalid expiry - skip
            continue
        fi

        if ((now > exp_epoch)); then
            # Mark inactive
            jq ".sessions.\"$sid\".active = false" "$SESSIONS_DB" >"${SESSIONS_DB}.tmp" && mv "${SESSIONS_DB}.tmp" "$SESSIONS_DB"
            log "Pruned expired session $sid"
        fi
    done

    log "Session prune completed"
}

migrate_sessions() {
    local dry_run="${1:-false}"
    log "Starting sessions migration (normalizing legacy entries) dry_run=$dry_run"
    if [[ ! -f "$SESSIONS_DB" ]]; then
        log "No sessions DB found at $SESSIONS_DB"
        return 0
    fi

    # Default expiry: now + 8 hours
    local default_expires
    default_expires=$(
        python3 - <<PY
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc)+timedelta(hours=8)).strftime('%Y-%m-%dT%H:%M:%SZ'))
PY
    )

    # Iterate session ids and normalize
    local ids
    ids=$(jq -r '.sessions | keys[]' "$SESSIONS_DB") || ids=""

    # Backup unless dry-run
    if [[ "$dry_run" != "true" ]]; then
        cp "$SESSIONS_DB" "${SESSIONS_DB}.bak.$(date +%s)"
    else
        log "Dry-run: not creating backup"
    fi

    for sid in $ids; do
        # ensure active exists
        if ! jq -e ".sessions.\"$sid\".active" "$SESSIONS_DB" >/dev/null 2>&1; then
            if [[ "$dry_run" == "true" ]]; then
                echo "DRY-RUN: would set active=true for $sid"
            else
                jq ".sessions.\"$sid\".active = true" "$SESSIONS_DB" >"${SESSIONS_DB}.tmp" && mv "${SESSIONS_DB}.tmp" "$SESSIONS_DB"
                log "Set active=true for $sid"
            fi
        fi

        # ensure expires_at exists
        if ! jq -e ".sessions.\"$sid\".expires_at" "$SESSIONS_DB" >/dev/null 2>&1 || [[ $(jq -r ".sessions.\"$sid\".expires_at" "$SESSIONS_DB") == "" || $(jq -r ".sessions.\"$sid\".expires_at" "$SESSIONS_DB") == "null" ]]; then
            if [[ "$dry_run" == "true" ]]; then
                echo "DRY-RUN: would populate expires_at for $sid -> $default_expires"
            else
                jq ".sessions.\"$sid\".expires_at = \"$default_expires\"" "$SESSIONS_DB" >"${SESSIONS_DB}.tmp" && mv "${SESSIONS_DB}.tmp" "$SESSIONS_DB"
                log "Populated expires_at for $sid -> $default_expires"
            fi
        fi
    done

    log "Sessions migration completed"
}

revoke_session() {
    local sid="$1"
    if [[ -z "$sid" ]]; then
        echo "Usage: $0 revoke <session_id>"
        return 1
    fi
    if [[ ! -f "$SESSIONS_DB" ]]; then
        echo "No sessions DB found"
        return 1
    fi

    if jq -e ".sessions.\"$sid\"" "$SESSIONS_DB" >/dev/null 2>&1; then
        jq ".sessions.\"$sid\".active = false" "$SESSIONS_DB" >"${SESSIONS_DB}.tmp" && mv "${SESSIONS_DB}.tmp" "$SESSIONS_DB"
        log "Revoked session $sid"
        echo "revoked"
        return 0
    else
        echo "session_not_found"
        return 1
    fi
}

list_sessions() {
    if [[ ! -f "$SESSIONS_DB" ]]; then
        echo '{}'
        return 0
    fi
    jq '.sessions' "$SESSIONS_DB"
}

case "${1:-help}" in
prune)
    prune_expired
    ;;
migrate-sessions)
    migrate_sessions
    ;;
revoke)
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 revoke <session_id>"
        exit 1
    fi
    revoke_session "$2"
    ;;
list)
    list_sessions
    ;;
help | *)
    echo "RBAC maintenance utilities"
    echo "Usage: $0 <command>"
    echo "Commands:"
    echo "  prune            - Mark expired sessions inactive"
    echo "  revoke <session> - Revoke a session"
    echo "  list             - List sessions"
    ;;
esac
