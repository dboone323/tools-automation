#!/usr/bin/env python3
"""
File Backup Automator Plugin
Automatically backs up files to cloud storage with configurable schedules.
"""

import os
import json
import logging
import schedule
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict, Any

try:
    import boto3
    from botocore.exceptions import ClientError

    BOTO3_AVAILABLE = True
except ImportError:
    BOTO3_AVAILABLE = False

# Plugin metadata
PLUGIN_INFO = {
    "name": "File Backup Automator",
    "version": "1.0.0",
    "description": "Automated file backup to cloud storage",
    "author": "Tools Automation Community",
}


class FileBackupAutomator:
    """Main plugin class for file backup automation."""

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.backup_paths = [
            Path(p).expanduser() for p in config.get("backup_paths", [])
        ]
        self.backup_schedule = config.get("backup_schedule", "daily")
        self.retention_days = config.get("retention_days", 30)
        self.cloud_provider = config.get("cloud_provider", "aws_s3")
        self.bucket_name = config.get("bucket_name", "backups")

        # Initialize cloud client
        self.cloud_client = None
        if self.cloud_provider == "aws_s3" and BOTO3_AVAILABLE:
            self.cloud_client = boto3.client("s3")
        elif self.cloud_provider == "aws_s3":
            self.logger.warning("boto3 not available. Cloud backup disabled.")

    def validate_config(self) -> bool:
        """Validate plugin configuration."""
        if not self.backup_paths:
            self.logger.error("No backup paths configured")
            return False

        for path in self.backup_paths:
            if not path.exists():
                self.logger.warning(f"Backup path does not exist: {path}")
            elif not path.is_dir():
                self.logger.warning(f"Backup path is not a directory: {path}")

        return True

    def get_files_to_backup(self, base_path: Path) -> List[Path]:
        """Get list of files to backup from a base path."""
        files = []
        try:
            for file_path in base_path.rglob("*"):
                if file_path.is_file():
                    files.append(file_path)
        except PermissionError as e:
            self.logger.warning(f"Permission denied accessing {base_path}: {e}")
        except Exception as e:
            self.logger.error(f"Error scanning {base_path}: {e}")

        return files

    def create_backup_archive(self, files: List[Path], backup_name: str) -> str:
        """Create a compressed archive of files to backup."""
        import tarfile
        import tempfile

        with tempfile.NamedTemporaryFile(suffix=".tar.gz", delete=False) as temp_file:
            archive_path = temp_file.name

        try:
            with tarfile.open(archive_path, "w:gz") as tar:
                for file_path in files:
                    try:
                        # Add file to archive with relative path
                        tar.add(file_path, arcname=file_path.name)
                    except (PermissionError, OSError) as e:
                        self.logger.warning(f"Could not add {file_path} to backup: {e}")

            self.logger.info(f"Created backup archive: {archive_path}")
            return archive_path

        except Exception as e:
            self.logger.error(f"Failed to create backup archive: {e}")
            if os.path.exists(archive_path):
                os.unlink(archive_path)
            raise

    def upload_to_cloud(self, local_path: str, remote_name: str) -> bool:
        """Upload backup to cloud storage."""
        if not self.cloud_client:
            self.logger.warning("Cloud client not available")
            return False

        try:
            if self.cloud_provider == "aws_s3":
                self.cloud_client.upload_file(local_path, self.bucket_name, remote_name)
                self.logger.info(
                    f"Uploaded {remote_name} to S3 bucket {self.bucket_name}"
                )
                return True
        except ClientError as e:
            self.logger.error(f"Failed to upload to cloud: {e}")
            return False
        except Exception as e:
            self.logger.error(f"Unexpected error during cloud upload: {e}")
            return False

    def cleanup_old_backups(self):
        """Clean up backups older than retention period."""
        if not self.cloud_client:
            return

        try:
            cutoff_date = datetime.now() - timedelta(days=self.retention_days)

            if self.cloud_provider == "aws_s3":
                # List objects in bucket
                response = self.cloud_client.list_objects_v2(Bucket=self.bucket_name)

                if "Contents" in response:
                    for obj in response["Contents"]:
                        # Parse backup date from object key
                        try:
                            # Assuming format: backup-YYYY-MM-DD-HH-MM-SS.tar.gz
                            key_parts = obj["Key"].split("-")
                            if len(key_parts) >= 6:
                                backup_date = datetime(
                                    int(key_parts[1]),
                                    int(key_parts[2]),
                                    int(key_parts[3]),
                                    int(key_parts[4]),
                                    int(key_parts[5]),
                                    int(key_parts[6].split(".")[0]),
                                )

                                if backup_date < cutoff_date:
                                    self.cloud_client.delete_object(
                                        Bucket=self.bucket_name, Key=obj["Key"]
                                    )
                                    self.logger.info(
                                        f"Deleted old backup: {obj['Key']}"
                                    )
                        except (ValueError, IndexError):
                            continue

        except Exception as e:
            self.logger.error(f"Failed to cleanup old backups: {e}")

    def perform_backup(self):
        """Perform the backup operation."""
        self.logger.info("Starting backup operation")

        total_files = 0
        total_size = 0

        # Collect all files to backup
        all_files = []
        for base_path in self.backup_paths:
            if base_path.exists():
                files = self.get_files_to_backup(base_path)
                all_files.extend(files)
                self.logger.info(f"Found {len(files)} files in {base_path}")

        if not all_files:
            self.logger.warning("No files found to backup")
            return

        # Create backup archive
        timestamp = datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
        backup_name = f"backup-{timestamp}.tar.gz"

        try:
            archive_path = self.create_backup_archive(all_files, backup_name)

            # Upload to cloud
            if self.upload_to_cloud(archive_path, backup_name):
                self.logger.info("Backup completed successfully")
            else:
                self.logger.error("Backup upload failed")

            # Clean up local archive
            if os.path.exists(archive_path):
                os.unlink(archive_path)

        except Exception as e:
            self.logger.error(f"Backup operation failed: {e}")

        # Cleanup old backups
        self.cleanup_old_backups()

    def schedule_backups(self):
        """Set up backup scheduling."""
        if self.backup_schedule == "hourly":
            schedule.every().hour.do(self.perform_backup)
        elif self.backup_schedule == "daily":
            schedule.every().day.at("02:00").do(self.perform_backup)
        elif self.backup_schedule == "weekly":
            schedule.every().week.do(self.perform_backup)
        else:
            self.logger.warning(f"Unknown backup schedule: {self.backup_schedule}")

    def start(self):
        """Start the backup automator."""
        self.logger.info("Starting File Backup Automator")

        if not self.validate_config():
            raise ValueError("Invalid configuration")

        # Schedule backups
        self.schedule_backups()

        # Perform initial backup
        self.perform_backup()

        self.logger.info("File Backup Automator started successfully")

    def stop(self):
        """Stop the backup automator."""
        self.logger.info("Stopping File Backup Automator")
        schedule.clear()

    def run_scheduler(self):
        """Run the backup scheduler (blocking)."""
        self.logger.info("Running backup scheduler")
        while True:
            schedule.run_pending()
            time.sleep(60)  # Check every minute


# Plugin interface functions
def initialize_plugin(config: Dict[str, Any]) -> FileBackupAutomator:
    """Initialize the plugin with configuration."""
    return FileBackupAutomator(config)


def get_plugin_info() -> Dict[str, str]:
    """Get plugin information."""
    return PLUGIN_INFO


def get_required_permissions() -> List[str]:
    """Get required permissions for this plugin."""
    return ["read_files", "write_files", "network_access"]


def get_supported_hooks() -> List[str]:
    """Get supported plugin hooks."""
    return ["startup", "shutdown", "scheduled_backup"]


if __name__ == "__main__":
    # Example usage
    config = {
        "backup_paths": ["~/Documents", "~/Desktop"],
        "backup_schedule": "daily",
        "retention_days": 30,
        "cloud_provider": "aws_s3",
        "bucket_name": "my-backups",
    }

    plugin = FileBackupAutomator(config)
    plugin.start()

    # Run scheduler for testing (normally this would be handled by the main system)
    try:
        plugin.run_scheduler()
    except KeyboardInterrupt:
        plugin.stop()
