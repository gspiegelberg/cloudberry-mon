#!/usr/bin/env bash
#
# Common Functions Library for System Scripts
# This library provides shared functionality used across multiple system scripts
#

# Global Variables
LOGMAXSIZE=${LOGMAXSIZE:-10485760}  # Default log max size: 10MB if not defined

# Core logging function
# This implementation mirrors the original _log function from logging.sh
_log() {
    local level="$1"
    local message="$2"

    # Use script name for log file if LOGFILE is not set
    if [[ -z "${LOGFILE}" ]]; then
        # Get the main script name - look for the top-most script in the source array
        local scriptname
        local script_path="${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}"
        scriptname=$(basename "$script_path" | sed 's/\.[^.]*$//')
        LOGFILE="/usr/local/cbmon/logs/${scriptname}.log"
    fi

    # Ensure log directory exists
    if [[ ! -d /usr/local/cbmon/logs ]]; then
        if ! mkdir -p /usr/local/cbmon/logs; then
            printf "Unable to create /usr/local/cbmon/logs\n" >&2
            return 1
        fi
    fi

    # Check if log rotation is needed
    local sz=0
    if [[ -f "${LOGFILE}" ]]; then
        sz=$(stat -c %s "${LOGFILE}" 2>/dev/null || echo 0)
    fi

    if [[ "$sz" -gt "$LOGMAXSIZE" ]]; then
        mv "${LOGFILE}" "${LOGFILE}.old"
    fi

    # Format timestamp
    local timestamp
    timestamp=$(date)

    # Write to log file
    printf "%s: %s: %s\n" "$timestamp" "$level" "$message" >> "${LOGFILE}" 2>&1
}

# Log an informational message
# Usage: loginfo "Info message" [args]
# or:    loginfo "Value: %s" "some value"
loginfo() {
    local message="$1"
    shift

    # If there are additional arguments, attempt formatted output
    if [[ $# -gt 0 ]]; then
        # Use a secure way to handle variable arguments
        # shellcheck disable=SC2059
        message=$(printf -- "$message" "$@")
    fi

    _log "INFO" "$message"
}

# Log a warning message
# Usage: logwarn "Warning message" [args]
# or:    logwarn "Warning: %s" "some value"
logwarn() {
    local message="$1"
    shift

    # If there are additional arguments, attempt formatted output
    if [[ $# -gt 0 ]]; then
        # Use a secure way to handle variable arguments
        # shellcheck disable=SC2059
        message=$(printf -- "$message" "$@")
    fi

    _log "WARN" "$message"
}

# Log an error message
# Usage: logerror "Error message" [exit_code] [args]
# or:    logerror "Error: %s" 1 "some value"
logerror() {
    local message="$1"
    shift
    local exit_code=0

    # Check if second arg is an exit code
    if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
        exit_code="$1"
        shift
    fi

    # If there are additional arguments, attempt formatted output
    if [[ $# -gt 0 ]]; then
        # Use a secure way to handle variable arguments
        # shellcheck disable=SC2059
        message=$(printf -- "$message" "$@")
    fi

    _log "ERROR" "$message"

    # Exit if exit_code is non-zero
    [[ $exit_code -ne 0 ]] && exit "$exit_code"
}

# Log a debug message (only if DEBUG is set)
# Usage: logdebug "Debug message" [args]
# or:    logdebug "Debug: %s" "some value"
logdebug() {
    # Check if first arg is DEBUG (compatibility with original)
    if [[ "$1" == "DEBUG" && -z "${DEBUG}" ]]; then
        return 0
    fi

    # Only log if DEBUG environment variable is set
    [[ -z "${DEBUG}" ]] && return 0

    local message="$1"
    shift

    # If there are additional arguments, attempt formatted output
    if [[ $# -gt 0 ]]; then
        # Use a secure way to handle variable arguments
        # shellcheck disable=SC2059
        message=$(printf -- "$message" "$@")
    fi

    _log "DEBUG" "$message"
}

# Check dependencies
# Verifies all required commands are available
# Usage: check_dependencies cmd1 cmd2 cmd3...
check_dependencies() {
    local missing=0
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            logerror "Required command '%s' not found. Please install it." "$cmd"
            missing=$((missing + 1))
        fi
    done

    if [[ $missing -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Create a secure temporary directory
# Usage: create_temp_dir [prefix]
# Returns: Path to temporary directory
create_temp_dir() {
    local prefix="${1:-temp}"
    local tmp_dir

    tmp_dir=$(mktemp -d -p "${TMPDIR:-/tmp}" "${prefix}_XXXXXX") || {
        logerror "Failed to create temporary directory"
        return 1
    }

    # Print the directory path so the caller can capture it
    echo "$tmp_dir"
}

# Add cleanup trap for temporary files/directories
# Usage: add_cleanup_trap directory_or_file [directory_or_file...]
add_cleanup_trap() {
    # Create a trap command that removes all specified paths
    local trap_cmd="rm -rf"

    for path in "$@"; do
        trap_cmd="$trap_cmd \"$path\""
    done

    # Set the trap for EXIT, INT and TERM signals
    # We use eval because we need to expand the trap_cmd
    eval "trap '$trap_cmd' EXIT INT TERM"
}

# Export functions
export -f _log
export -f loginfo
export -f logwarn
export -f logerror
export -f logdebug
export -f check_dependencies
export -f create_temp_dir
export -f add_cleanup_trap
