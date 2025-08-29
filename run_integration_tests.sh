#!/bin/bash

# Integration Test Runner
# Automatically runs integration tests and generates reports

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_AUTOMATION="$SCRIPT_DIR/master_automation.sh"

echo "Running integration test suite..."
bash "$MASTER_AUTOMATION" integration-test

echo "Generating test report..."
bash "$MASTER_AUTOMATION" performance
