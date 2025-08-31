#!/usr/bin/env bash
# Install monitoring/service templates to common system locations.
# Dry-run by default. Use --apply to perform changes and --force to overwrite.

set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES_DIR="$ROOT_DIR/monitoring/templates"

DRY_RUN=1
FORCE=0
ENABLE=0

usage() {
	cat <<EOF
Usage: $(basename "$0") [--apply] [--force] [--help]

By default this script lists what would be installed and does not modify the system.
Options:
  --apply   Actually copy files to system locations (requires sudo when necessary).
  --force   Overwrite existing files.
  --help    Show this message.

This script installs templates for systemd (Linux), launchd (macOS) and Supervisor (any).
It will not enable or start services; that must be done by the operator.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--apply)
		DRY_RUN=0
		shift
		;;
	--force)
		FORCE=1
		shift
		;;
	--help)
		usage
		exit 0
		;;
	--enable)
		ENABLE=1
		shift
		;;
	*)
		echo "Unknown arg: $1"
		usage
		exit 2
		;;
	esac
done

if [[ ! -d $TEMPLATES_DIR ]]; then
	echo "Templates directory not found: $TEMPLATES_DIR" >&2
	exit 3
fi

declare -A targets
# systemd unit files
targets["$TEMPLATES_DIR/mcp.service"]="/etc/systemd/system/mcp.service"
targets["$TEMPLATES_DIR/github-monitor.service"]="/etc/systemd/system/github-monitor.service"
targets["$TEMPLATES_DIR/agent.service"]="/etc/systemd/system/automation-agent.service"

# launchd plists (macOS)
targets["$TEMPLATES_DIR/mcp.plist"]="/Library/LaunchDaemons/com.quantum.mcp.plist"
targets["$TEMPLATES_DIR/github-monitor.plist"]="/Library/LaunchDaemons/com.quantum.github-monitor.plist"
targets["$TEMPLATES_DIR/agent.plist"]="/Library/LaunchDaemons/com.quantum.agent.plist"

# supervisor conf
targets["$TEMPLATES_DIR/supervisor.conf"]="/etc/supervisor/conf.d/quantum-automation.conf"

install_one() {
	local src="$1" dst="$2"
	if [[ ! -f $src ]]; then
		echo "Skipping missing template: $src"
		return
	fi

	if [[ -e $dst && $FORCE -eq 0 ]]; then
		echo "Target exists: $dst (use --force to overwrite)"
		return
	fi

	echo "Install: $src -> $dst"
	if [[ $DRY_RUN -eq 1 ]]; then
		return
	fi

	mkdir -p "$(dirname "$dst")"
	# copy preserving mode; use sudo if not writable
	if [[ -w "$(dirname "$dst")" ]]; then
		cp -a "$src" "$dst"
	else
		sudo cp -a "$src" "$dst"
	fi
}

echo "Templates directory: $TEMPLATES_DIR"
echo
for src in "${!targets[@]}"; do
	install_one "$src" "${targets[$src]}"
done

if [[ $ENABLE -eq 1 ]]; then
	echo
	echo "Service enable/start phase (dry-run prints commands)."
	# systemd
	if command -v systemctl >/dev/null 2>&1; then
		echo "systemd detected. To enable/start services run (or this script with --apply --enable):"
		echo "  sudo systemctl daemon-reload"
		echo "  sudo systemctl enable mcp.service github-monitor.service automation-agent.service"
		echo "  sudo systemctl start mcp.service github-monitor.service automation-agent.service"
		if [[ $DRY_RUN -eq 0 ]]; then
			sudo systemctl daemon-reload
			sudo systemctl enable mcp.service github-monitor.service automation-agent.service || true
			sudo systemctl start mcp.service github-monitor.service automation-agent.service || true
		fi
	fi

	# launchd (macOS)
	if [[ "$(uname -s)" == "Darwin" ]]; then
		echo "macOS launchd detected. Commands to load plists:"
		echo "  sudo launchctl bootstrap system /Library/LaunchDaemons/com.quantum.mcp.plist"
		echo "  sudo launchctl bootstrap system /Library/LaunchDaemons/com.quantum.github-monitor.plist"
		echo "  sudo launchctl bootstrap system /Library/LaunchDaemons/com.quantum.agent.plist"
		if [[ $DRY_RUN -eq 0 ]]; then
			sudo launchctl bootstrap system /Library/LaunchDaemons/com.quantum.mcp.plist || true
			sudo launchctl bootstrap system /Library/LaunchDaemons/com.quantum.github-monitor.plist || true
			sudo launchctl bootstrap system /Library/LaunchDaemons/com.quantum.agent.plist || true
		fi
	fi

	# supervisor
	if command -v supervisorctl >/dev/null 2>&1; then
		echo "Supervisor detected. Commands to reload and start:"
		echo "  sudo supervisorctl reread"
		echo "  sudo supervisorctl update"
		if [[ $DRY_RUN -eq 0 ]]; then
			sudo supervisorctl reread || true
			sudo supervisorctl update || true
		fi
	fi
fi

if [[ $DRY_RUN -eq 1 ]]; then
	echo
	echo "Dry-run complete. Rerun with --apply to copy files. Use --force to overwrite existing files. Add --enable to also attempt to enable/start services."
fi

exit 0
