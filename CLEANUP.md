# Safe Disk Cleanup Policy & Guide

This document outlines the policy and procedures for automated disk cleanup in the `tools-automation` repository.

## Policy

### 1. Retention
- **Default Retention**: Files are considered for cleanup if they are older than **30 days**.
- **Logs & Artifacts**: Archived before deletion.
- **Caches & Dependencies**: Can be regenerated, so they are prioritized for removal.

### 2. Safety & Quarantine
- **Dry-Run Default**: All cleanup operations default to a dry-run mode. Explicit confirmation is required to delete files.
- **Quarantine**: "Deleted" files are first moved to a local quarantine directory (`~/tools-automation-archive/quarantine/`).
- **Permanent Deletion**: Items in quarantine are permanently deleted after **7 days**.
- **Archives**: Important files (logs, backups) are archived to `~/tools-automation-archive/YYYYMMDD/` before being moved to quarantine.

### 3. Exclusions
- `.git` directories are ALWAYS excluded.
- `models/` directories are excluded by default (use `--allow-models` to override).

## Usage

The cleanup is managed by `scripts/cleanup.sh`.

### Check what would be deleted (Dry Run)
```bash
./scripts/cleanup.sh
```

### Execute Cleanup
```bash
./scripts/cleanup.sh --confirm
```

### Custom Options
```bash
# Change retention period
./scripts/cleanup.sh --retention 60

# Change archive location
./scripts/cleanup.sh --archive-dir /path/to/backup

# Allow cleaning model files
./scripts/cleanup.sh --allow-models --confirm

# Enable compression (tar.gz)
./scripts/cleanup.sh --compress --confirm

# Prune Docker objects and Package Caches
./scripts/cleanup.sh --prune-docker --prune-caches --confirm
```

## Restoration
Use `scripts/restore.sh` to recover files from archives or quarantine.

```bash
# Search and restore a file
./scripts/restore.sh my-important-file.txt
```
The script will list matching backups and prompt for a restore location.

## Automated Cleanup
A GitHub Actions workflow (`.github/workflows/cleanup.yml`) runs periodically in **dry-run mode** to report potential space savings and identify cleanup candidates.

## Recovery
To recover a file deleted by the script:
1. Check the `~/tools-automation-archive/quarantine/` directory.
2. If it has been more than 7 days, check the `~/tools-automation-archive/YYYYMMDD/` archives.
3. Consult the manifest file in the archive directory for original paths and checksums.
