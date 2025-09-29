# Quantum Workspace Setup Guide

## Overview

This comprehensive setup script configures your macOS development environment for the Quantum Workspace, including all necessary tools, dependencies, and AI agents for automated development workflows.

## What Gets Installed

### Core Development Tools

- **Homebrew** - Package manager for macOS
- **Git** - Version control
- **Python 3.11** - Programming language with virtual environment
- **Node.js LTS** - JavaScript runtime with NVM
- **Swift** - Apple's programming language with Xcode tools

### AI and Automation Tools

- **Ollama** - Local AI model server with CodeLlama, Llama2, and Mistral models
- **Trunk CI** - Comprehensive code quality and security scanning
- **GitHub CLI** - Command-line interface for GitHub

### Quality Assurance Tools

- **SwiftLint** - Swift code linting
- **SwiftFormat** - Swift code formatting
- **ShellCheck** - Shell script linting
- **ESLint & Prettier** - JavaScript/TypeScript formatting

### Development Environment

- **VS Code Extensions** - Essential extensions for development
- **Python Virtual Environment** - Isolated Python environment
- **Shell Environment** - Custom aliases and functions

## Quick Start

### Option 1: Full Setup (Recommended)

```bash
# Navigate to the automation directory
cd /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation

# Run the complete setup
./setup_quantum_workspace.sh
```

### Option 2: Verification Only

```bash
# Check current setup status
./setup_quantum_workspace.sh verify
```

### Option 3: Cleanup

```bash
# Remove setup logs
./setup_quantum_workspace.sh clean
```

## What Happens During Setup

1. **Pre-flight Checks** - Verifies macOS compatibility
2. **Homebrew Setup** - Installs/updates Homebrew package manager
3. **Development Tools** - Installs essential development tools
4. **Python Environment** - Sets up Python virtual environment and dependencies
5. **Node.js Environment** - Installs Node.js with NVM
6. **Ollama AI** - Installs Ollama and downloads AI models
7. **Trunk CI** - Sets up comprehensive code quality tools
8. **Swift Development** - Configures Swift development environment
9. **GitHub CLI** - Sets up GitHub command-line interface
10. **VS Code Extensions** - Installs essential VS Code extensions
11. **Workspace Structure** - Creates necessary directories and files
12. **Configuration Files** - Creates agent status and task queue files
13. **Shell Environment** - Adds custom aliases and functions
14. **Final Verification** - Validates all installations

## Post-Setup Configuration

After setup completes, restart your terminal and you'll have access to these commands:

### Navigation Commands

```bash
qw              # Navigate to Quantum Workspace root
qwa             # Navigate to agents directory
```

### Agent Management

```bash
qw-start-agents     # Start all AI agents
qw-stop-agents      # Stop all running agents
qw-agent-status     # Check agent status and health
qw-quality-check    # Run comprehensive quality checks
```

## Environment Variables

The setup adds these environment variables to your `~/.zshrc`:

```bash
QUANTUM_WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
PATH="$QUANTUM_WORKSPACE/Tools/Automation:$PATH"
```

## Manual Authentication Required

After setup, you'll need to manually authenticate:

### GitHub CLI

```bash
gh auth login
```

### VS Code (if not already authenticated)

- Open VS Code
- Sign in with your GitHub account for Copilot access

## Troubleshooting

### Common Issues

1. **Permission Denied**

   ```bash
   chmod +x setup_quantum_workspace.sh
   ```

2. **Homebrew Path Issues**

   - Restart terminal after Homebrew installation
   - Or run: `eval "$(/opt/homebrew/bin/brew shellenv)"`

3. **Ollama Model Download Failures**

   - Check internet connection
   - Models can be downloaded later with: `ollama pull <model-name>`

4. **VS Code Extensions Not Installing**
   - Ensure VS Code is installed and accessible via `code` command
   - Install VS Code from: https://code.visualstudio.com/

### Verification Commands

```bash
# Check all tools
which git python3 node npm trunk ollama gh jq swiftlint

# Check Ollama models
ollama list

# Check Python environment
python3 --version
pip3 list

# Check Node.js
node --version
npm --version

# Check Trunk
trunk --version
```

## File Structure Created

```
Quantum-workspace/
├── .venv/                          # Python virtual environment
├── .trunk/                         # Trunk CI configuration
├── Tools/Automation/
│   ├── agents/
│   │   ├── agent_status.json       # Agent status tracking
│   │   ├── task_queue.json         # Task queue management
│   │   ├── communication/          # Inter-agent communication
│   │   ├── knowledge_exports/      # AI knowledge exports
│   │   └── knowledge_reports/      # AI analysis reports
│   ├── reports/                    # Quality and analysis reports
│   ├── logs/                       # Application logs
│   ├── metrics/                    # Performance metrics
│   └── monitoring/                 # System monitoring data
```

## Next Steps

1. **Restart Terminal** - Load new environment variables
2. **Start Agents** - Run `qw-start-agents` to begin AI workflows
3. **Run Quality Checks** - Execute `qw-quality-check` to validate setup
4. **Monitor Agents** - Use `qw-agent-status` to check agent health
5. **Begin Development** - Start using the enhanced automation tools

## Support

If you encounter issues:

1. Check the setup log file: `setup_log_*.txt`
2. Run verification: `./setup_quantum_workspace.sh verify`
3. Review troubleshooting section above
4. Check individual tool documentation for specific issues

## Advanced Usage

### Custom Model Installation

```bash
# Install additional Ollama models
ollama pull codellama:34b
ollama pull llama2:13b-chat
```

### Trunk Configuration

```bash
# Initialize trunk in specific directories
cd Projects/MyProject
trunk init
trunk install
```

### Agent Development

```bash
# Navigate to agents directory
qwa

# View agent capabilities
cat agent_status.json

# Monitor agent activity
qw-agent-status
```
