#!/bin/bash

# Setup Infrastructure Script
# Installs missing system dependencies and checks service status

echo "Starting infrastructure setup..."

# Install bc if not present
if ! command -v bc &> /dev/null; then
    echo "Installing bc..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install bc
    elif [[ -f /etc/debian_version ]]; then
        sudo apt-get update && sudo apt-get install -y bc
    else
        echo "Warning: Could not determine OS to install 'bc'. Please install manually."
    fi
else
    echo "bc is already installed."
fi

# Check Docker Daemon
if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running."
    echo "Please start Docker Desktop or the docker service."
    # Attempt to start on macOS if possible, or just warn
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open -a Docker
    fi
else
    echo "Docker daemon is running."
fi

echo "Infrastructure setup check complete."
