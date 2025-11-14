#!/bin/bash
# Project Configuration for Quantum Workspace Automation
# This file contains project-specific settings for automation scripts

# Global automation settings
export ENABLE_AUTO_BUILD=true
export ENABLE_AUTO_TEST=true
export ENABLE_AUTO_DEPLOY=false

# Project-specific settings
export PROJECT_NAME="CodingReviewer"
export BUILD_TIMEOUT=300
export TEST_TIMEOUT=180

# Logging settings
export LOG_LEVEL="INFO"
export ENABLE_PERFORMANCE_LOGGING=true

# Backup settings
export ENABLE_AUTO_BACKUP=true
export BACKUP_RETENTION_DAYS=7

# AI Enhancement settings
export ENABLE_AI_ENHANCEMENT=true
export AI_ANALYSIS_TIMEOUT=120
export AUTO_APPLY_SAFE_ENHANCEMENTS=true

# Validation settings
export ENABLE_VALIDATION=true
export VALIDATION_TIMEOUT=60
