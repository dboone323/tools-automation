#!/usr/bin/env bash
#
# fix_docker_limits.sh - Fix macOS file descriptor limits for Docker
#

set -euo pipefail

echo "🔧 Fixing macOS file descriptor limits for Docker..."
echo ""

# Current limits
echo "Current limits:"
echo "  ulimit -n: $(ulimit -n)"
launchctl limit maxfiles

echo ""
echo "Increasing file descriptor limits..."

# Set temporary limits for current session
sudo launchctl limit maxfiles 65536 200000
ulimit -n 65536

echo "✅ Temporary limits set!"
echo ""

# Create persistent configuration
LIMIT_PLIST="/Library/LaunchDaemons/limit.maxfiles.plist"

echo "Creating persistent configuration at $LIMIT_PLIST..."

sudo tee "$LIMIT_PLIST" > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>limit.maxfiles</string>
    <key>ProgramArguments</key>
    <array>
        <string>launchctl</string>
        <string>limit</string>
        <string>maxfiles</string>
        <string>65536</string>
        <string>200000</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ServiceIPC</key>
    <false/>
</dict>
</plist>
EOF

sudo chown root:wheel "$LIMIT_PLIST"
sudo chmod 644 "$LIMIT_PLIST"

echo "✅ Persistent configuration created!"
echo ""

# Load the limit
sudo launchctl load -w "$LIMIT_PLIST" || echo "Already loaded"

echo "New limits:"
launchctl limit maxfiles

echo ""
echo "✅ File descriptor limits fixed!"
echo ""
echo "Next steps:"
echo "1. Restart Docker Desktop"
echo "2. Try running docker-compose again"
echo ""
echo "Note: These limits will persist across reboots."
