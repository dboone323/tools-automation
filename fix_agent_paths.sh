#!/bin/bash
# Fix path references in all agent scripts

WORKSPACE_DIR="/Users/danielstevens/Desktop/Quantum-workspace"
TOOLS_DIR="${WORKSPACE_DIR}/Tools"
AUTOMATION_DIR="${TOOLS_DIR}/Automation"
AGENTS_DIR="${AUTOMATION_DIR}/agents"

echo "Fixing path references in agent scripts..."

# Fix agent_build.sh
sed -i '' "s|/Users/danielstevens/Desktop/Code/|${WORKSPACE_DIR}/|g" "${AGENTS_DIR}/agent_build.sh"
sed -i '' "s|/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/build_agent.log|${AGENTS_DIR}/build_agent.log|g" "${AGENTS_DIR}/agent_build.sh"

# Fix agent_debug.sh
sed -i '' "s|/Users/danielstevens/Desktop/Code/|${WORKSPACE_DIR}/|g" "${AGENTS_DIR}/agent_debug.sh"
sed -i '' "s|/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/debug_agent.log|${AGENTS_DIR}/debug_agent.log|g" "${AGENTS_DIR}/agent_debug.sh"

# Fix agent_codegen.sh
sed -i '' "s|/Users/danielstevens/Desktop/Code/|${WORKSPACE_DIR}/|g" "${AGENTS_DIR}/agent_codegen.sh"
sed -i '' "s|/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/codegen_agent.log|${AGENTS_DIR}/codegen_agent.log|g" "${AGENTS_DIR}/agent_codegen.sh"

# Fix ai_log_analyzer.py
sed -i '' "s|/Users/danielstevens/Desktop/Code/|${WORKSPACE_DIR}/|g" "${AGENTS_DIR}/ai_log_analyzer.py"

echo "Path fixes completed. Creating missing project config files..."

# Create missing project config files
for project in CodingReviewer MomentumFinance HabitQuest AvoidObstaclesGame PlannerApp; do
  PROJECT_DIR="${WORKSPACE_DIR}/Projects/${project}"
  if [[ -d ${PROJECT_DIR} ]]; then
    mkdir -p "${PROJECT_DIR}/Tools/Automation"
    cat >"${PROJECT_DIR}/Tools/Automation/project_config.sh" <<EOF
#!/bin/bash
# Project configuration for ${project}

export ENABLE_AUTO_BUILD=true
export ENABLE_AI_ENHANCEMENT=true
export ENABLE_AUTO_TEST=true
export PROJECT_NAME="${project}"
export PROJECT_DIR="${PROJECT_DIR}"
EOF
    chmod +x "${PROJECT_DIR}/Tools/Automation/project_config.sh"
    echo "Created config for ${project}"
  fi
done

echo "All fixes applied successfully!"
