#!/bin/bash
# Simple plugin API for agent extensibility
# Usage: ./plugin_api.sh run <plugin_name> [args...]

PLUGINS_DIR="$(dirname "$0")/plugins"
AUDIT_LOG="$(dirname "$0")/audit.log"
POLICY_CONF="$(dirname "$0")/policy.conf"

case "$1" in
list)
	echo "Available plugins:"
	ls "$PLUGINS_DIR" | grep -E '\.sh$' | sed 's/\.sh$//'
	user=$(whoami)
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=$user action=list_plugins result=success" >>"$AUDIT_LOG"
	;;
run)
	plugin="$2"
	shift 2
	user=$(whoami)
	# Basic access control: require API_TOKEN env var
	if [[ -z $API_TOKEN ]]; then
		echo "Access denied: API_TOKEN not set."
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=$user action=run_plugin plugin=$plugin result=fail reason=missing_token" >>"$AUDIT_LOG"
		exit 1
	fi
	# Policy enforcement
	allow_list=$(awk '/^\[plugins\]/{f=1} f&&/^allow=/{print $0; exit}' "$POLICY_CONF" | cut -d= -f2 | tr ',' ' ')
	block_list=$(awk '/^\[plugins\]/{f=1} f&&/^block=/{print $0; exit}' "$POLICY_CONF" | cut -d= -f2 | tr ',' ' ')
	for blocked in $block_list; do
		if [[ $plugin == "$blocked" ]]; then
			echo "Plugin $plugin is blocked by policy."
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=$user action=run_plugin plugin=$plugin result=fail reason=policy_blocked" >>"$AUDIT_LOG"
			exit 1
		fi
	done
	allowed=false
	for allowed_plugin in $allow_list; do
		if [[ $plugin == "$allowed_plugin" ]]; then
			allowed=true
			break
		fi
	done
	if [[ $allowed != true ]]; then
		echo "Plugin $plugin is not allowed by policy."
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=$user action=run_plugin plugin=$plugin result=fail reason=policy_not_allowed" >>"$AUDIT_LOG"
		exit 1
	fi
	if [[ -x "$PLUGINS_DIR/$plugin.sh" ]]; then
		"$PLUGINS_DIR/$plugin.sh" "$@"
		result=$?
		if [[ $result -eq 0 ]]; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=$user action=run_plugin plugin=$plugin result=success" >>"$AUDIT_LOG"
		else
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=$user action=run_plugin plugin=$plugin result=fail code=$result" >>"$AUDIT_LOG"
		fi
	else
		echo "Plugin $plugin not found or not executable."
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] user=$user action=run_plugin plugin=$plugin result=fail reason=not_found" >>"$AUDIT_LOG"
		exit 1
	fi
	;;
*)
	echo "Usage: $0 list | run <plugin_name> [args...]"
	exit 1
	;;
esac
