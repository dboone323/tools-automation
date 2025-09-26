#!/bin/bash

# Real-time AI monitoring script
MONITORING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${MONITORING_DIR}/../../.." && pwd)"
LOG_FILE="${MONITORING_DIR}/logs/ai_monitor_$(date +%Y%m%d).log"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"${LOG_FILE}"
	echo -e "${BLUE}[MONITOR]${NC} $1"
}

check_ollama_health() {
	if command -v ollama &>/dev/null; then
		if ollama list &>/dev/null; then
			local model_count=$(ollama list | tail -n +2 | wc -l)
			log "✅ Ollama healthy: ${model_count} models available"
			return 0
		else
			log "❌ Ollama server not responding"
			return 1
		fi
	else
		log "❌ Ollama not installed"
		return 1
	fi
}

monitor_ai_activity() {
	local ai_files_before=$(find "${WORKSPACE_ROOT}" -name "AI_*" -o -name "*ai_*" | wc -l)
	sleep 300 # Check every 5 minutes
	local ai_files_after=$(find "${WORKSPACE_ROOT}" -name "AI_*" -o -name "*ai_*" | wc -l)

	if [[ ${ai_files_after} -gt ${ai_files_before} ]]; then
		local new_files=$((ai_files_after - ai_files_before))
		log "📈 AI activity detected: ${new_files} new AI-generated files"
	fi
}

monitor_disk_usage() {
	local ai_dir_size=$(du -sh "${WORKSPACE_ROOT}/Tools/Automation" 2>/dev/null | cut -f1 || echo "0")
	log "💾 AI tools directory size: ${ai_dir_size}"
}

main_monitoring_loop() {
	log "Starting AI monitoring loop..."

	while true; do
		check_ollama_health
		monitor_ai_activity
		monitor_disk_usage

		# Check for automation processes
		local running_automations=$(pgrep -f "ai_enhanced_automation\|ai_quality_gates" | wc -l)
		if [[ ${running_automations} -gt 0 ]]; then
			log "⚙️ Active AI automations: ${running_automations}"
		fi

		sleep 300 # Check every 5 minutes
	done
}

# Handle signals
trap 'log "Monitoring stopped by user"; exit 0' INT TERM

# Start monitoring
main_monitoring_loop
