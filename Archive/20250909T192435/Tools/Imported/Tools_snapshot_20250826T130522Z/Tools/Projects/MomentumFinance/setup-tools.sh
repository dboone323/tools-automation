#!/bin/bash
# setup-tools.sh - Script to set up development tools for MomentumFinance
# Copyright © 2025 Momentum Finance. All rights reserved.

echo "Setting up development tools for MomentumFinance..."

# Check if npm is installed (needed for Prettier)
if ! command -v npm &> /dev/null; then
    echo "npm is not installed. Installing node and npm..."
    brew install node
fi

# Install Prettier and Swift plugin
echo "Installing Prettier for code formatting..."
npm install --save-dev prettier prettier-plugin-swift

# Create Prettier scripts in package.json if it doesn't exist
if [ ! -f package.json ]; then
    echo "Creating package.json with Prettier scripts..."
    cat > package.json << 'EOF'
{
  "name": "momentum-finance",
  "version": "1.0.0",
  "description": "Momentum Finance - Personal Finance App",
  "scripts": {
    "format": "prettier --write \"**/*.{swift,js,json,md}\"",
    "format:check": "prettier --check \"**/*.{swift,js,json,md}\""
  },
  "devDependencies": {
    "prettier": "^2.8.8",
    "prettier-plugin-swift": "^1.0.0"
  }
}
EOF
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
else
    echo "Docker is installed."
fi

# Check if VS Code is installed
if ! command -v code &> /dev/null; then
    echo "VS Code is not installed. Please install VS Code from https://code.visualstudio.com/"
else
    echo "Installing recommended VS Code extensions..."
    # Install GitLens
    code --install-extension eamodio.gitlens
    # Install Prettier extension
    code --install-extension esbenp.prettier-vscode
    # Install Docker extension
    code --install-extension ms-azuretools.vscode-docker
    # Install Swift extension
    code --install-extension sswg.swift-lang
    # Install SwiftLint
    code --install-extension vknabel.vscode-swiftlint
fi

# Create VS Code settings file
mkdir -p .vscode
cat > .vscode/settings.json << 'EOF'
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "prettier.singleQuote": true,
  "prettier.trailingComma": "all",
  "prettier.printWidth": 120,
  "editor.tabSize": 2,
  "[swift]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "gitlens.codeLens.enabled": true,
  "gitlens.currentLine.enabled": true,
  "gitlens.hovers.currentLine.over": "line",
  "gitlens.statusBar.enabled": true
}
EOF

# Create VS Code launch configurations
cat > .vscode/launch.json << 'EOF'
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "lldb",
      "request": "launch",
      "name": "Debug MomentumFinance",
      "program": "${workspaceFolder}/.build/debug/MomentumFinance",
      "args": [],
      "cwd": "${workspaceFolder}",
      "preLaunchTask": "swift: Build Debug MomentumFinance"
    },
    {
      "type": "lldb",
      "request": "launch",
      "name": "Release MomentumFinance",
      "program": "${workspaceFolder}/.build/release/MomentumFinance",
      "args": [],
      "cwd": "${workspaceFolder}",
      "preLaunchTask": "swift: Build Release MomentumFinance"
    }
  ]
}
EOF

# Create VS Code tasks
cat > .vscode/tasks.json << 'EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Build with Swift Package Manager",
      "type": "shell",
      "command": "swift",
      "args": ["build"],
      "group": "build",
      "problemMatcher": "$swiftc"
    },
    {
      "label": "Run MomentumFinance App",
      "type": "shell",
      "command": "swift",
      "args": ["run", "MomentumFinance"],
      "group": "build",
      "isBackground": true
    },
    {
      "label": "Run SwiftLint Check",
      "type": "shell",
      "command": "swiftlint",
      "args": ["--quiet"],
      "group": "build"
    },
    {
      "label": "SwiftLint Auto-Fix",
      "type": "shell",
      "command": "swiftlint",
      "args": ["--fix", "--quiet"],
      "group": "build"
    },
    {
      "label": "Format Code with Prettier",
      "type": "shell",
      "command": "npm",
      "args": ["run", "format"],
      "group": "build"
    },
    {
      "label": "Build Docker Container",
      "type": "shell",
      "command": "docker",
      "args": ["build", "-t", "momentum-finance", "."],
      "group": "build"
    },
    {
      "label": "Run Docker Container",
      "type": "shell",
      "command": "docker",
      "args": ["run", "-it", "momentum-finance"],
      "group": "build"
    },
    {
      "label": "Docker Compose Up",
      "type": "shell",
      "command": "docker-compose",
      "args": ["up", "--build"],
      "group": "build",
      "isBackground": true
    }
  ]
}
EOF

echo "Setup complete! You can now use the following tools:"
echo "- Prettier: Run 'npm run format' to format code"
echo "- Docker: Use the Dockerfile and docker-compose.yml for containerization"
echo "- GitLens: Available in VS Code for enhanced Git functionality"
echo "- Additional VS Code tasks are available in the VS Code command palette"
