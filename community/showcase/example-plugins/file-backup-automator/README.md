# File Backup Automator Plugin

Automatically backs up your important files to cloud storage with configurable schedules and retention policies.

## Features

- 🔄 **Automated Scheduling**: Daily, weekly, or hourly backup schedules
- ☁️ **Cloud Storage**: AWS S3 integration for secure, scalable storage
- 📁 **Flexible Paths**: Backup multiple directories with custom configurations
- 🗂️ **Smart Retention**: Automatic cleanup of old backups
- 📊 **Comprehensive Logging**: Detailed logs for monitoring and troubleshooting
- 🔒 **Secure**: Encrypted storage and secure credential management

## Installation

### Prerequisites

- Python 3.8+
- AWS account with S3 bucket
- AWS CLI configured with appropriate permissions

### Plugin Installation

1. Download the plugin files
2. Place in your Tools Automation plugins directory
3. Configure AWS credentials:

```bash
aws configure
```

4. Update plugin configuration in `plugin.json`

## Configuration

Edit the `plugin.json` file to customize your backup settings:

```json
{
  "configuration": {
    "backup_paths": [
      "~/Documents",
      "~/Desktop",
      "~/Projects"
    ],
    "backup_schedule": "daily",
    "retention_days": 30,
    "cloud_provider": "aws_s3",
    "bucket_name": "my-backups-bucket"
  }
}
```

### Configuration Options

| Option | Type | Description | Default |
|--------|------|-------------|---------|
| `backup_paths` | array | List of directories to backup | `["~/Documents", "~/Desktop"]` |
| `backup_schedule` | string | Backup frequency: `hourly`, `daily`, `weekly` | `"daily"` |
| `retention_days` | number | Days to keep backups | `30` |
| `cloud_provider` | string | Cloud storage provider | `"aws_s3"` |
| `bucket_name` | string | S3 bucket name | `"backups"` |

## Usage

### Automatic Operation

Once installed and configured, the plugin runs automatically according to your schedule:

- **Daily**: Runs at 2:00 AM every day
- **Weekly**: Runs at 2:00 AM every Sunday
- **Hourly**: Runs at the top of every hour

### Manual Backup

You can also trigger manual backups through the Tools Automation interface:

```bash
# Trigger immediate backup
tools-automation plugin run file-backup-automator backup_now

# Check backup status
tools-automation plugin status file-backup-automator
```

## AWS Setup

### 1. Create S3 Bucket

```bash
aws s3 mb s3://my-backups-bucket
```

### 2. Configure Bucket Policy

Apply the following bucket policy for backup access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:user/YOUR_USER"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-backups-bucket",
        "arn:aws:s3:::my-backups-bucket/*"
      ]
    }
  ]
}
```

### 3. Enable Versioning (Optional)

```bash
aws s3api put-bucket-versioning \
  --bucket my-backups-bucket \
  --versioning-configuration Status=Enabled
```

## Backup Structure

Backups are stored in your S3 bucket with the following naming convention:

```
backup-2025-11-12-14-30-00.tar.gz
backup-2025-11-13-14-30-00.tar.gz
backup-2025-11-14-14-30-00.tar.gz
```

Each backup contains:
- All files from configured backup paths
- Compressed using gzip for efficient storage
- Timestamped for easy identification

## Monitoring

### Logs

Check the Tools Automation logs for backup activity:

```bash
tail -f ~/.tools-automation/logs/file-backup-automator.log
```

### Cloud Storage

Monitor your S3 bucket usage:

```bash
# List recent backups
aws s3 ls s3://my-backups-bucket/ --recursive

# Get bucket size
aws s3 ls s3://my-backups-bucket/ --recursive --summarize
```

## Troubleshooting

### Common Issues

**Permission Denied Errors**
- Ensure AWS credentials are properly configured
- Check IAM permissions for S3 operations
- Verify bucket exists and is accessible

**Backup Path Not Found**
- Check that configured paths exist
- Use absolute paths or expand user paths properly
- Verify read permissions on backup directories

**Large Backup Sizes**
- Consider excluding unnecessary files
- Use compression-friendly file types
- Implement incremental backups for large datasets

### Debug Mode

Enable debug logging for detailed troubleshooting:

```bash
export BACKUP_DEBUG=true
tools-automation plugin run file-backup-automator backup_now
```

## Security Considerations

- AWS credentials are stored securely using AWS CLI configuration
- Backups are encrypted in transit and at rest (S3 default)
- Consider enabling S3 server-side encryption for additional security
- Regularly rotate AWS access keys

## Contributing

We welcome contributions! Please see the main [Contributing Guide](../../CONTRIBUTING.md) for details.

### Development Setup

```bash
# Clone and setup
git clone https://github.com/tools-automation/file-backup-automator.git
cd file-backup-automator
pip install -r requirements-dev.txt

# Run tests
pytest

# Run linting
flake8
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- 📖 [Documentation](https://tools-automation.dev/docs/plugins/file-backup-automator)
- 🐛 [Bug Reports](https://github.com/tools-automation/file-backup-automator/issues)
- 💬 [Discussions](https://github.com/tools-automation/file-backup-automator/discussions)
- 📧 [Email Support](mailto:support@tools-automation.dev)

---

**Made with ❤️ by the Tools Automation Community**