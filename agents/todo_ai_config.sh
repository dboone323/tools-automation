#!/bin/bash
# Quantum Enhanced TODO Agent Configuration
# AI Integration Settings for Code Review and Analysis

# AI Model Configuration
export AI_MODEL="codellama"
export AI_ENDPOINT="http://localhost:11434"
export AI_TIMEOUT=60
export AI_MAX_FILE_SIZE=1000 # lines

# Analysis Settings
export AI_ANALYSIS_CYCLE=10    # Run project analysis every N cycles
export AI_CODE_REVIEW_LIMIT=10 # Max files to review per cycle
export AI_SUGGESTION_PRIORITY_DEFAULT="medium"

# Project Analysis Settings
export PROJECT_ANALYSIS_TIMEOUT=120
export PROJECT_ANALYSIS_MAX_FILES=20

# TODO Generation Settings
export AI_TODO_PREFIX="AI-SUGGESTION"
export AI_PROJECT_TODO_PREFIX="AI-PROJECT-SUGGESTION"
export AI_TODO_DEDUPLICATION=true

# Logging
export AI_LOG_LEVEL="INFO"
export AI_LOG_FILE="ai_integration.log"

# Feature Flags
export ENABLE_AI_CODE_REVIEW=true
export ENABLE_AI_PROJECT_ANALYSIS=true
export ENABLE_AI_TODO_GENERATION=true
export ENABLE_AI_DEDUPLICATION=true

# Enhanced TODO Processing Settings
export TODO_SCAN_CYCLE=5           # Scan for code TODOs every N cycles
export METRICS_GENERATION_CYCLE=10 # Generate metrics every N cycles
export ENABLE_CODE_SCANNING=true   # Enable automatic code scanning for TODOs
export ENABLE_PRIORITIZATION=true  # Enable TODO prioritization
export ENABLE_METRICS=true         # Enable metrics generation

# Backup Settings (disabled for TODOs as requested)
export ENABLE_BACKUP=false
export BACKUP_RETENTION_DAYS=0
