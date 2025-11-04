#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
    echo "git is required" >&2
    exit 1
fi

if ! command -v git-lfs >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        echo "Installing git-lfs via Homebrew..."
        brew install git-lfs
    else
        echo "git-lfs not found. Install from https://git-lfs.com and re-run." >&2
        exit 1
    fi
fi

echo "Configuring Git LFS in this repo..."
git lfs install

# Register common patterns (also reflected in .gitattributes)
patterns=(
    "*.xcarchive" "*.ipa" "*.dSYM" "*.dylib" "*.a" "*.framework/**"
    "*.zip" "*.tar" "*.tar.gz" "*.7z" "*.bin"
    "*.psd" "*.ai" "*.sketch" "*.fig"
    "*.mov" "*.mp4" "*.wav" "*.aiff" "*.flac" "*.png" "*.jpg" "*.jpeg" "*.gif"
)

for ptn in "${patterns[@]}"; do
    git lfs track "$ptn"
done

echo "Git LFS patterns registered. Current .gitattributes:"
echo "---------------------------------------------"
cat .gitattributes || true
