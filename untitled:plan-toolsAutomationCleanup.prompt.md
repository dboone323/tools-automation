Plan: Safe disk cleanup, archive & quarantine

Summary
- Goal: Remove or archive unneeded files in `tools-automation` and submodules to reclaim disk space while retaining safety and recoverability.
- Retention policy: Keep logs and backups for 30 days (default).
- Quarantine policy: After archiving, keep files in a local quarantine folder for 7 days before permanent deletion.
- Archive targets: default local archive folder `~/tools-automation-archive/YYYYMMDD/` (support optional S3/GCS/NAS later).

Steps & Safe Checks
1. Run exact size checks from repo root and capture results:
   - du -sh node_modules
   - du -sh .venv
   - du -sh venv
   - du -sh test_venv
   - du -sh .cache
   - du -sh coverage htmlcov playwright-report
   - du -sh archives logs ollama_backups models
   - find . -type f -name '*.bak' -print0 | xargs -0 du -sh

2. Dry-run removal commands (do not execute; print them first):
   - echo rm -rf node_modules
   - echo rm -rf .venv
   - echo rm -rf venv
   - echo rm -rf test_venv
   - echo rm -rf .cache
   - echo rm -rf htmlcov coverage playwright-report
   - find . -type f -name '*.bak' -print0 | xargs -0 -I{} echo rm -f {}

3. Archive high-risk / large items to the local archive folder before deletion (example):
   - mkdir -p ~/tools-automation-archive/$(date +%Y%m%d)/ && rsync -av --progress archives/ ~/tools-automation-archive/$(date +%Y%m%d)/archives/
   - Verify checksums (sha256) before moving to quarantine.

4. Move archived items to quarantine after successful archive verification:
   - mv archives /path/to/quarantine/20251121_archives/
   - Quarantine retention: 7 days. After that, remove permanently: rm -rf /path/to/quarantine/20251121_archives/

5. Safety gates for cleanup script:
   - Default to --dry-run
   - Require --confirm to perform destructive actions
   - Exclude `.git`, `models/` and any explicit patterns unless --allow-models + archive provided
   - Create an audit manifest for each cleanup (path, size, checksum, archived-to, timestamp, user)

Cleanup Script Outline (POSIX/Bash)
- Parameters: --retention-days (default 30), --quarantine-days (default 7), --archive (default ~/tools-automation-archive), --dry-run (default true), --confirm, --exclude
- Behavior:
  1. Build candidate list using explicit paths + globs and find -mtime +RETENTION
  2. Report sizes and print planned actions when dry-run
  3. If archive given: rsync/s3/gsutil to archive path; verify checksums
  4. Move to quarantine path with metadata manifest
  5. If confirmed and quarantine age > QUARANTINE_DAYS, permanently remove
  6. Log every action and produce a final summary

Archive Targets (local default)
- Default: local archive directory `~/tools-automation-archive/$(date +%Y%m%d)/`
- Support optional S3 / GCS / NAS later with verification and encryption

Retention Policy
- Default retention days: 30
- Candidates: files and directories older than 30 days by mtime
- Find example: find /path/to/candidates -mtime +${RETENTION_DAYS} -print0
- Quarantine: keep a copy for 7 days after archive before final deletion

Priorities (recommended)
1. Low-risk removals: node_modules/ + nested node_modules/ (reinstallable).
2. Consolidate and remove duplicate venvs: .venv/ venv/ test_venv/
3. Archive logs & release artifacts > 30 days, then remove local copies
4. Archive and review *.bak, .merged.bak, and large backup files before deletion
5. Review model files and ollama_backups — HIGH RISK. Archive externally before deleting.

Up to 50 Best Practices (disk-space focused)
1. Use single workspace venv and document it.
2. Add `venv/`, `.venv/`, `node_modules/`, `.cache/`, `*.bak`, `htmlcov/`, `coverage/` to `.gitignore`.
3. Use npm/pnpm workspaces to minimize nested dependencies.
4. Avoid committing binaries; use artifact storage.
5. Use git-lfs only for essential large files.
6. Store models and large datasets on external storage (S3/GCS/NAS).
7. Central archive directory: `~/tools-automation-archive/`.
8. Two-phase deletion: archive → quarantine → delete.
9. Quarantine retention default 7 days.
10. Default cleanup runs to --dry-run; require explicit confirmation.
11. Record checksums for every archived object and verify transfer.
12. Compress old archives (tar.zst or tar.gz) to reduce footprint.
13. Rotate and compress logs with logrotate or similar.
14. Offload CI artifacts to a dedicated object bucket.
15. Use `find -mtime` for age-based cleanup.
16. Remove caches (`node_modules/.cache`, `.pytest_cache`, `.ruff_cache`).
17. Regularly remove `__pycache__` directories.
18. Use `npm ci` / `pip install --no-cache-dir` in CI.
19. Use dev containers or codespaces to avoid duplicated local dev envs.
20. Prune local Docker images/volumes and caches.
21. Use shallow git clones in CI where full history is unnecessary.
22. Avoid keeping multiple `.bak` snapshots at repo root.
23. Centralize developer backups into a dedicated archive folder.
24. Add pre-commit to block large files and node_modules commits.
25. Config CI caches with expiration to avoid infinite growth.
26. Archive test reports externally, keep the most recent locally.
27. Document Ollama/model storage outside repo and retrieval steps.
28. Provide `scripts/cleanup.sh --status` to preview removals.
29. Produce an audit manifest for each cleanup run.
30. Use TRASH/quarantine directory for staged deletes rather than immediate removal.
31. Use deduping filesystems (zfs/btrfs) where available.
32. Use `rsync --link-dest` or hardlinking for incremental archives.
33. Enforce artifacts-out policy for releases.
34. Use pipx for global dev tools, reducing venv duplication.
35. Add disk usage alerts and weekly reports.
36. Use a central cache server for shared dependency caches.
37. Periodically prune package manager caches.
38. Keep `CLEANUP.md` with safe commands and policy.
39. Tag and archive historical large files with metadata.
40. Use ephemeral dev environments to avoid persistent caches.
41. Add a CI job to report repo disk usage trends.
42. Use consistent archive naming conventions with dates.
43. Block pushes of files exceeding allowed size limits.
44. Run routine secret scans on archives before deletion.
45. Document recovery steps and archive locations.
46. Provide a rollback plan and restore test for archived items.
47. Use lifecycle policies in cloud storage to transition or delete old archives.
48. Use fast cloud storage classes for frequent archives and move to cold storage later.
49. Keep repository and submodule boundaries clear; avoid mixing build artifacts across them.
50. Add a one-click developer README snippet to show how to reclaim space safely.

Next actions (pick one):
A) I can generate the exact `du` checks + dry-run command list files and the safe `scripts/cleanup.sh` implementation (POSIX bash).
B) I can go straight to authoring `scripts/cleanup.sh`, add `README.md` updates, and create a `.github/workflows/cleanup.yml` scheduled job in dry-run mode.

Notes
- This plan defaults to local archive and 7-day quarantine as requested. It uses conservative safety gating; everything is dry-run by default.
- Before any permanent delete, run a manual review and verify that archives/checksums are valid and accessible.
