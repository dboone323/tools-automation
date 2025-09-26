#!/bin/bash

# AI-Powered Enhancement System (legacy entrypoint)
# Thin wrapper that forwards to ai_enhancement_unified.sh for compatibility.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${CODE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
UNIFIED_SCRIPT="${ROOT_DIR}/Tools/Automation/ai_enhancement_unified.sh"

PURPLE='\033[0;35m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

log_header() {
	echo -e "${PURPLE}[AI-ENHANCE]${NC} ${CYAN}$1${NC}"
}

log_error() {
	echo -e "${RED}❌ $1${NC}"
}

ensure_unified_script() {
	if [[ ! -x ${UNIFIED_SCRIPT} ]]; then
		log_error "Unified enhancement script missing at ${UNIFIED_SCRIPT}"
		echo "Run analyze from Tools/Automation/ai_enhancement_unified.sh directly while this is fixed." >&2
		exit 1
	fi
}

forward() {
	bash "${UNIFIED_SCRIPT}" "$@"
}

show_help() {
	log_header "AI Enhancement System"
	echo "Usage: $0 <command> [project]"
	echo ""
	echo "Commands:"
	echo "  analyze <project|all>    Analyze project(s) for enhancements"
	echo "  auto-apply <project|all> Apply safe enhancements"
	echo "  report                   Generate master report"
	echo "  status                   Show enhancement status"
	echo "  help                     Display this message"
	echo ""
	echo "Examples:"
	echo "  $0 analyze HabitQuest"
	echo "  $0 auto-apply CodingReviewer"
	echo "  $0 report"
}

main() {
	ensure_unified_script
	local command="${1:-help}"
	case "${command}" in
	analyze)
		if [[ -z ${2-} ]]; then
			log_error "Usage: $0 analyze <project|all>"
			exit 1
		fi
		forward analyze "$2"
		;;
	analyze-all)
		forward analyze all
		;;
	auto-apply)
		if [[ -z ${2-} ]]; then
			log_error "Usage: $0 auto-apply <project|all>"
			exit 1
		fi
		forward auto-apply "$2"
		;;
	auto-apply-all)
		forward auto-apply all
		;;
	report)
		forward report
		;;
	status)
		forward status
		;;
	help | --help | -h)
		show_help
		;;
	*)
		show_help
		log_error "Unknown command: ${command}"
		exit 1
		;;
	esac
}

main "$@"
