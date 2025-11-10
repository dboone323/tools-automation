#!/bin/bash

# encryption_agent.sh - Advanced encryption and security agent
# Provides comprehensive encryption services for files, data, and communications

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_DIR="${SCRIPT_DIR}/status"
LOG_DIR="${SCRIPT_DIR}/logs"
BACKUP_DIR="${SCRIPT_DIR}/backups"
ENCRYPTION_DIR="${SCRIPT_DIR}/encryption"
CONFIG_DIR="${SCRIPT_DIR}/config"

# Create necessary directories
mkdir -p "${STATUS_DIR}" "${LOG_DIR}" "${BACKUP_DIR}" "${ENCRYPTION_DIR}" "${CONFIG_DIR}"

# Files
LOG_FILE="${LOG_DIR}/encryption_agent.log"
STATUS_FILE="${STATUS_DIR}/encryption_agent.status"
CONFIG_FILE="${CONFIG_DIR}/encryption_config.json"
KEYSTORE_FILE="${ENCRYPTION_DIR}/keystore.enc"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Encryption settings
DEFAULT_CIPHER="aes-256-gcm"
DEFAULT_KEY_SIZE="4096"
DEFAULT_HASH="sha256"

# Log function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >>"${LOG_FILE}"
    echo -e "${BLUE}[${level}]${NC} ${message}"
}

# Error handling
trap 'log "ERROR" "Encryption agent encountered an error on line $LINENO"' ERR

# Initialize encryption system
initialize_encryption_system() {
    log "INFO" "Initializing encryption system..."

    # Create encryption configuration if it doesn't exist
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        cat >"${CONFIG_FILE}" <<EOF
{
  "cipher": "${DEFAULT_CIPHER}",
  "key_size": "${DEFAULT_KEY_SIZE}",
  "hash_algorithm": "${DEFAULT_HASH}",
  "auto_encrypt": true,
  "backup_encrypted": true,
  "key_rotation_days": 90,
  "audit_log": true
}
EOF
        log "INFO" "Created default encryption configuration"
    fi

    # Initialize keystore if it doesn't exist
    if [[ ! -f "${KEYSTORE_FILE}" ]]; then
        generate_master_key
        log "INFO" "Initialized encryption keystore"
    fi

    # Set status
    echo "initialized" >"${STATUS_FILE}"
    log "INFO" "Encryption system initialized successfully"
}

# Generate master encryption key
generate_master_key() {
    log "INFO" "Generating master encryption key..."

    # Generate a strong random key
    local master_key
    if command -v openssl >/dev/null 2>&1; then
        master_key=$(openssl rand -hex 32)
    else
        # Fallback to /dev/urandom
        master_key=$(head -c 32 /dev/urandom | xxd -p -c 32)
    fi

    # Store encrypted master key
    echo "${master_key}" | encrypt_data >"${KEYSTORE_FILE}"
    log "INFO" "Master encryption key generated and stored"
}

# Encrypt data using AES-256-GCM
encrypt_data() {
    local input="${1:-/dev/stdin}"
    local output="${2:-/dev/stdout}"

    if command -v openssl >/dev/null 2>&1; then
        openssl enc -${DEFAULT_CIPHER} -salt -pbkdf2 -iter 10000 -pass file:<(echo "encryption_agent_key") -in "${input}" -out "${output}" 2>/dev/null || {
            log "ERROR" "Failed to encrypt data"
            return 1
        }
    else
        log "ERROR" "OpenSSL not available for encryption"
        return 1
    fi
}

# Decrypt data
decrypt_data() {
    local input="${1:-/dev/stdin}"
    local output="${2:-/dev/stdout}"

    if command -v openssl >/dev/null 2>&1; then
        openssl enc -d -${DEFAULT_CIPHER} -pbkdf2 -iter 10000 -pass file:<(echo "encryption_agent_key") -in "${input}" -out "${output}" 2>/dev/null || {
            log "ERROR" "Failed to decrypt data"
            return 1
        }
    else
        log "ERROR" "OpenSSL not available for decryption"
        return 1
    fi
}

# Encrypt file
encrypt_file() {
    local input_file="$1"
    local output_file="${2:-${input_file}.enc}"

    if [[ ! -f "${input_file}" ]]; then
        log "ERROR" "Input file does not exist: ${input_file}"
        return 1
    fi

    log "INFO" "Encrypting file: ${input_file}"

    if encrypt_data "${input_file}" "${output_file}"; then
        log "INFO" "File encrypted successfully: ${output_file}"

        # Create backup if configured
        if [[ "$(get_config_value "backup_encrypted")" == "true" ]]; then
            local backup_file="${BACKUP_DIR}/$(basename "${input_file}").$(date +%Y%m%d_%H%M%S).enc"
            cp "${output_file}" "${backup_file}"
            log "INFO" "Encrypted file backed up: ${backup_file}"
        fi

        return 0
    else
        log "ERROR" "Failed to encrypt file: ${input_file}"
        return 1
    fi
}

# Decrypt file
decrypt_file() {
    local input_file="$1"
    local output_file="${2:-${input_file%.enc}}"

    if [[ ! -f "${input_file}" ]]; then
        log "ERROR" "Input file does not exist: ${input_file}"
        return 1
    fi

    log "INFO" "Decrypting file: ${input_file}"

    if decrypt_data "${input_file}" "${output_file}"; then
        log "INFO" "File decrypted successfully: ${output_file}"
        return 0
    else
        log "ERROR" "Failed to decrypt file: ${input_file}"
        return 1
    fi
}

# Generate encryption key for specific purpose
generate_key() {
    local purpose="$1"
    local key_file="${ENCRYPTION_DIR}/${purpose}_key.enc"

    log "INFO" "Generating encryption key for: ${purpose}"

    # Generate a random key
    local key
    if command -v openssl >/dev/null 2>&1; then
        key=$(openssl rand -hex 32)
    else
        key=$(head -c 32 /dev/urandom | xxd -p -c 32)
    fi

    # Store the key encrypted
    echo "${key}" | encrypt_data >"${key_file}"
    log "INFO" "Key generated and stored: ${key_file}"

    echo "${key_file}"
}

# Encrypt directory recursively
encrypt_directory() {
    local input_dir="$1"
    local output_dir="${2:-${input_dir}_encrypted}"

    if [[ ! -d "${input_dir}" ]]; then
        log "ERROR" "Input directory does not exist: ${input_dir}"
        return 1
    fi

    log "INFO" "Encrypting directory: ${input_dir}"

    mkdir -p "${output_dir}"

    # Find all files and encrypt them
    find "${input_dir}" -type f -not -name "*.enc" | while read -r file; do
        local relative_path="${file#${input_dir}/}"
        local output_file="${output_dir}/${relative_path}.enc"

        mkdir -p "$(dirname "${output_file}")"

        if encrypt_file "${file}" "${output_file}"; then
            log "INFO" "Encrypted: ${relative_path}"
        else
            log "ERROR" "Failed to encrypt: ${relative_path}"
        fi
    done

    log "INFO" "Directory encryption completed: ${output_dir}"
}

# Decrypt directory recursively
decrypt_directory() {
    local input_dir="$1"
    local output_dir="${2:-${input_dir}_decrypted}"

    if [[ ! -d "${input_dir}" ]]; then
        log "ERROR" "Input directory does not exist: ${input_dir}"
        return 1
    fi

    log "INFO" "Decrypting directory: ${input_dir}"

    mkdir -p "${output_dir}"

    # Find all encrypted files and decrypt them
    find "${input_dir}" -type f -name "*.enc" | while read -r file; do
        local relative_path="${file#${input_dir}/}"
        local output_file="${output_dir}/${relative_path%.enc}"

        mkdir -p "$(dirname "${output_file}")"

        if decrypt_file "${file}" "${output_file}"; then
            log "INFO" "Decrypted: ${relative_path}"
        else
            log "ERROR" "Failed to decrypt: ${relative_path}"
        fi
    done

    log "INFO" "Directory decryption completed: ${output_dir}"
}

# Get configuration value
get_config_value() {
    local key="$1"
    if command -v jq >/dev/null 2>&1 && [[ -f "${CONFIG_FILE}" ]]; then
        jq -r ".${key}" "${CONFIG_FILE}" 2>/dev/null || echo ""
    else
        # Fallback: parse with grep/sed
        grep "\"${key}\"" "${CONFIG_FILE}" | sed 's/.*: *"\?\([^"]*\)"\?.*/\1/' || echo ""
    fi
}

# Check encryption system health
check_encryption_health() {
    log "INFO" "Checking encryption system health..."

    local issues=0

    # Check if keystore exists and is readable
    if [[ ! -f "${KEYSTORE_FILE}" ]]; then
        log "ERROR" "Keystore file missing: ${KEYSTORE_FILE}"
        ((issues++))
    fi

    # Check if config exists
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log "ERROR" "Configuration file missing: ${CONFIG_FILE}"
        ((issues++))
    fi

    # Check if openssl is available
    if ! command -v openssl >/dev/null 2>&1; then
        log "WARNING" "OpenSSL not available - limited encryption capabilities"
    fi

    # Check key rotation
    local key_age_days
    if [[ -f "${KEYSTORE_FILE}" ]]; then
        key_age_days=$((($(date +%s) - $(stat -f %m "${KEYSTORE_FILE}" 2>/dev/null || stat -c %Y "${KEYSTORE_FILE}" 2>/dev/null || echo 0)) / 86400))
        local max_age=$(get_config_value "key_rotation_days")
        if [[ "${key_age_days}" -gt "${max_age:-90}" ]]; then
            log "WARNING" "Master key is ${key_age_days} days old, consider rotation"
        fi
    fi

    if [[ ${issues} -eq 0 ]]; then
        log "INFO" "Encryption system health check passed"
        return 0
    else
        log "ERROR" "Encryption system health check failed with ${issues} issues"
        return 1
    fi
}

# Rotate master key
rotate_master_key() {
    log "INFO" "Rotating master encryption key..."

    # Backup old keystore
    local backup_keystore="${KEYSTORE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "${KEYSTORE_FILE}" "${backup_keystore}"
    log "INFO" "Old keystore backed up: ${backup_keystore}"

    # Generate new key
    generate_master_key

    log "INFO" "Master key rotation completed"
}

# List encrypted files
list_encrypted_files() {
    local search_dir="${1:-${ENCRYPTION_DIR}}"

    log "INFO" "Listing encrypted files in: ${search_dir}"

    find "${search_dir}" -name "*.enc" -type f | while read -r file; do
        local size=$(stat -f %z "${file}" 2>/dev/null || stat -c %s "${file}" 2>/dev/null || echo "unknown")
        local mtime=$(stat -f %Sm -t "%Y-%m-%d %H:%M:%S" "${file}" 2>/dev/null || stat -c "%y" "${file}" 2>/dev/null || echo "unknown")
        echo "${file} (${size} bytes, modified: ${mtime})"
    done
}

# Clean up old encrypted backups
cleanup_old_backups() {
    local days_to_keep="${1:-30}"

    log "INFO" "Cleaning up encrypted backups older than ${days_to_keep} days..."

    find "${BACKUP_DIR}" -name "*.enc" -type f -mtime +${days_to_keep} -delete

    log "INFO" "Old backup cleanup completed"
}

# Main function
main() {
    local command="${1:-help}"

    case "${command}" in
    "init")
        initialize_encryption_system
        ;;
    "encrypt-file")
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 encrypt-file <input_file> [output_file]"
            exit 1
        fi
        encrypt_file "$2" "${3:-}"
        ;;
    "decrypt-file")
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 decrypt-file <input_file> [output_file]"
            exit 1
        fi
        decrypt_file "$2" "${3:-}"
        ;;
    "encrypt-dir")
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 encrypt-dir <input_dir> [output_dir]"
            exit 1
        fi
        encrypt_directory "$2" "${3:-}"
        ;;
    "decrypt-dir")
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 decrypt-dir <input_dir> [output_dir]"
            exit 1
        fi
        decrypt_directory "$2" "${3:-}"
        ;;
    "generate-key")
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 generate-key <purpose>"
            exit 1
        fi
        generate_key "$2"
        ;;
    "health")
        check_encryption_health
        ;;
    "rotate-key")
        rotate_master_key
        ;;
    "list")
        list_encrypted_files "${2:-}"
        ;;
    "cleanup")
        cleanup_old_backups "${2:-30}"
        ;;
    "status")
        echo "Encryption Agent Status:"
        echo "======================="
        echo "Status: $(cat "${STATUS_FILE}" 2>/dev/null || echo "unknown")"
        echo "Config: ${CONFIG_FILE} ($(stat -f %z "${CONFIG_FILE}" 2>/dev/null || stat -c %s "${CONFIG_FILE}" 2>/dev/null || echo "unknown") bytes)"
        echo "Keystore: ${KEYSTORE_FILE} ($(stat -f %z "${KEYSTORE_FILE}" 2>/dev/null || stat -c %s "${KEYSTORE_FILE}" 2>/dev/null || echo "unknown") bytes)"
        echo "Log: ${LOG_FILE} ($(wc -l <"${LOG_FILE}" 2>/dev/null || echo "0") lines)"
        ;;
    "help" | *)
        echo "Encryption Agent - Advanced encryption services"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  init                    Initialize encryption system"
        echo "  encrypt-file <file>     Encrypt a file"
        echo "  decrypt-file <file>     Decrypt a file"
        echo "  encrypt-dir <dir>       Encrypt a directory recursively"
        echo "  decrypt-dir <dir>       Decrypt a directory recursively"
        echo "  generate-key <purpose>  Generate a new encryption key"
        echo "  health                  Check encryption system health"
        echo "  rotate-key              Rotate master encryption key"
        echo "  list [dir]              List encrypted files"
        echo "  cleanup [days]          Clean up old backups (default: 30 days)"
        echo "  status                  Show agent status"
        echo "  help                    Show this help message"
        ;;
    esac
}

# Run main function with all arguments
main "$@"
