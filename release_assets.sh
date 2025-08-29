#!/usr/bin/env bash
set -eu

# release_assets.sh
# Usage: ./release_assets.sh [--apply] [--message "commit message"]
# By default runs build and tests and prints the git commands it would run.

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
BUILD_PY="$ROOT_DIR/build_assets.py"
TEST_DIR="$ROOT_DIR/tests"

# Prefer virtualenv python if available at Tools/.venv
VENV_PY="$(cd "$ROOT_DIR/.." && pwd)/.venv/bin/python"
if [ -x "$VENV_PY" ]; then
  PYTHON="$VENV_PY"
else
  PYTHON="python3"
fi

APPLY=false
MSG="Add asset build step and hashed static assets; manifest support for long-lived caching and PWA meta"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --message) MSG="$2"; shift 2 ;;
    -m) MSG="$2"; shift 2 ;;
    --help) echo "Usage: $0 [--apply] [--message \"commit message\"]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

echo "1) Running asset build with $PYTHON"
"$PYTHON" "$BUILD_PY"

echo "2) Running tests"
if command -v "$PYTHON" >/dev/null 2>&1; then
  "$PYTHON" -m pytest -q "$TEST_DIR"
else
  echo "pytest not found on PATH. Skipping tests." >&2
fi

echo "3) Git actions"
GIT_ADD=(git add "$ROOT_DIR/static" "$ROOT_DIR/templates/index.html" "$ROOT_DIR/mcp_dashboard_flask.py" "$ROOT_DIR/build_assets.py" "$ROOT_DIR/README-ASSETS.md")
GIT_COMMIT=(git commit -m "$MSG")
GIT_PUSH=(git push)

if [ "$APPLY" = true ]; then
  echo "Executing: ${GIT_ADD[*]}"
  "${GIT_ADD[@]}"
  echo "Executing: ${GIT_COMMIT[*]}"
  # allow commit to fail if no changes
  set +e
  "${GIT_COMMIT[@]}" || true
  set -e
  echo "Executing: ${GIT_PUSH[*]}"
  "${GIT_PUSH[@]}"
  echo "Completed: changes pushed."
else
  echo "Dry-run mode (no git actions performed). To apply the commit and push, re-run with --apply."
  echo "Would run: ${GIT_ADD[*]}"
  echo "Would run: ${GIT_COMMIT[*]}"
  echo "Would run: ${GIT_PUSH[*]}"
fi

echo "Done."
