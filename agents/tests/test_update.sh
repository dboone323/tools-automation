#!/bin/bash
source shared_functions.sh
echo "Testing update_agent_status..."
update_agent_status "test_agent" "running" $$ "test_task"
echo "Done"
