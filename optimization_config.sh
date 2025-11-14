#!/bin/bash

# Automation Optimization Configuration

# Parallel processing settings
export MAX_PARALLEL_JOBS=4
export BUILD_PARALLEL=8

# Cache settings
export USE_BUILD_CACHE=true
export CACHE_DIR="${CODE_DIR}/Tools/Automation/cache"

# Performance monitoring
export ENABLE_PERFORMANCE_LOGGING=true
export PERFORMANCE_LOG="${CODE_DIR}/Tools/Automation/logs/performance.log"

# AI optimization
export AI_CACHE_ENABLED=true
export AI_CACHE_DIR="${CODE_DIR}/Tools/AI/cache"

# Swift optimization
export SWIFT_OPTIMIZATION_LEVEL="-O"
export SWIFT_ENABLE_INDEXING=true
