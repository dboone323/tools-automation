# Documentation

This directory contains automated documentation maintenance and validation tools.

## Structure

- `docs_maintenance.sh` - Main validation and maintenance script
- `update_docs.sh` - Documentation update workflow
- `setup_docs_automation.sh` - Automation setup script
- `examples/` - Usage examples
- `tutorials/` - Tutorial documentation
- `api/` - API reference documentation
- `logs/` - Maintenance logs
- `reports/` - Validation reports

## Automation

Documentation maintenance runs automatically via cron jobs:

- **Daily**: Validation and link checking (6 AM)
- **Weekly**: Content updates and API docs refresh (Sunday 2 AM)
- **Monthly**: Comprehensive validation (1st of month 3 AM)

## Manual Usage

```bash
# Run validation
./docs_maintenance.sh

# Update documentation
./update_docs.sh

# Setup automation
./setup_docs_automation.sh
```

## Reports

Check `reports/` directory for validation reports and `logs/` for execution logs.
