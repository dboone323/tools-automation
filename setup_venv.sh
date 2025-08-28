#!/usr/bin/env bash
set -euo pipefail

# setup_venv.sh
# Creates a virtual environment in Automation/.venv (canonical) and installs requirements.

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"/..
# canonicalize to Automation/.venv to avoid Tools/ vs Automation/ confusion
VENV_DIR="$ROOT_DIR/.venv"
# requirements file located in the Automation directory
REQ_FILE="$ROOT_DIR/requirements.txt"

echo "Creating virtualenv at $VENV_DIR"
python3 -m venv "$VENV_DIR"
echo "Activating venv and upgrading pip"
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip
if [ -f "$REQ_FILE" ]; then
	echo "Installing requirements from $REQ_FILE"
	pip install -r "$REQ_FILE"
else
	echo "No requirements file found at $REQ_FILE"
fi
echo "Virtual environment ready. Activate with: source $VENV_DIR/bin/activate"
