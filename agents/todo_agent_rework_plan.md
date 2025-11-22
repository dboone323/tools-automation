# TODO Agent Rework Plan

## Objective
Refactor `agent_todo.sh` to run as a stable daemon without exiting prematurely and add comprehensive logging for easier debugging.

## Key Changes
1. **Removed `set -e`** – keep `set -uo pipefail` only; errors are now handled explicitly.
2. **Added explicit error handling** for commands that may fail (missing TODO file, optional AI services, resource‑limit checks).
3. **Wrapped counter increments** (`scan_cycle`, `metrics_cycle`, `ai_analysis_cycle`) with `|| true` to prevent abort on non‑zero exit status.
4. **Centralized `handle_error` helper** (optional) for consistent warning/error logging.
5. **Replaced `return` statements inside the main loop** with `continue` or `break` to keep the loop alive.
6. **Inserted DEBUG logs** before and after each major section (resource check, scanning, prioritization, metrics, AI analysis, code review, TODO processing, sleep).
7. **Ensured loop continuity** – added a fallback that restarts the script if the `while true` ever exits.

## Verification Steps
- Run `bash -x agents/agent_todo.sh` and confirm continuous `[LOOP]` entries for multiple cycles.
- Simulate failures (missing `todo-tree-output.json`, invalid `WORKSPACE_ROOT`) and verify the script logs warnings and continues.
- Start the daemon with `nohup` and let it run for several minutes; check `agents/todo_agent.log` for no premature exit.

## Future Work
- Review and possibly integrate the `handle_error` helper into other agents.
- Tune resource‑limit thresholds based on observed usage.
- Add unit tests for each helper function.
