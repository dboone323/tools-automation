#!/bin/bash
source tests/shell_test_framework.sh
source tests/test_agents_agent_analytics.sh
setup_test_env
export TEST_MODE=true
source agents/agent_analytics.sh

# Test agent metrics collection
metrics=$(collect_agent_metrics)
echo "Metrics output:"
echo "$metrics"

echo "Testing grep..."
if echo "$metrics" | grep -q '"total_agents":'; then
    echo "Found total_agents"
else
    echo "Did not find total_agents"
fi
