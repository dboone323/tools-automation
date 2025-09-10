HabitQuest - NEXT_STEPS (snapshot)

Date: 2025-08-25
Branch: auto-fix/linewraps-1

Summary:
This file records the planned next steps to continue reducing SwiftLint noise and performing safe refactors.

Immediate next steps (tomorrow):
1. Continue low-risk mechanical PRs (linewraps-2, renames-1):
   - Fix remaining `line_length` violations (6–12 deterministic edits per PR).
   - Apply 3–4 identifier renames per PR where safe.
   - Small nesting/closure style fixes.
2. Medium-risk staged refactors (one or two files per PR):
   - Split `ProfileView.swift` into subviews (ProfileView+Sections.swift).
   - Extract `AnalyticsService` helper handlers into separate files.
   - Break `AdvancedAnalyticsEngine` internals into private helper types.
3. DataExportService:
   - Break long functions into named helpers and reduce nesting depth.
   - Add unit tests or smoke tests where applicable.
4. CI workflow policy:
   - Keep `QUIET_MODE` and agent-first dry-run active (`auto-fix/workflows-quiet-copilot`).
   - Allow agent dry-runs + retry/backoff to apply deterministic fixes and open draft PRs for refactors.

Notes:
- Logs from today's runs are saved under `Tools/Automation/logs/` (look for swiftlint logs: habitquest_swiftlint.log and swiftlint_auto-fix_linewraps-1-run.log).
- Current outstanding high-impact rules: file_length, type_body_length, function_body_length.

Goals for next session:
- Reduce overall SwiftLint warnings by ~20% via line wraps and renames.
- Open 1–2 split/refactor PRs to address file/type length issues incrementally.

Contact:
- PR created: https://github.com/dboone323/HabitQuest/pull/8
- Automation logs: Tools/Automation/logs/
