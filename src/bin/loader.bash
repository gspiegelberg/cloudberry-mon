#!/usr/bin/env bash
#
# Cluster Data Loader
# This script loads cluster data into the monitoring database
#

# Source configuration
if [[ -f /usr/local/cbmon/etc/config ]]; then
    # shellcheck disable=SC1091
    source /usr/local/cbmon/etc/config
else
    echo "ERROR: Configuration file not found" >&2
    exit 1
fi

# Source common functions for logging
if [[ -f /usr/local/cbmon/bin/common_functions.bash ]]; then
    # shellcheck disable=SC1091
    source /usr/local/cbmon/bin/common_functions.bash
else
    echo "ERROR: Common functions library not found" >&2
    exit 1
fi

# Check required dependencies
check_dependencies psql sleep || exit 1

# Initialize default variables if not set in config
CLUSTER_ID=${CLUSTER_ID:-}
LOAD_DELAY=${LOAD_DELAY:-60}
ANALYZE_FREQ=${ANALYZE_FREQ:-5}
readonly OPTIONS="ac:Dd:hz:"

# Display usage information
usage() {
    local msg="${1:-}"

    [[ -n "$msg" ]] && echo -e "$msg\n" >&2

    cat << EOMSG
usage: loader.bash { -a | -c CLUSTER_ID }
  -a      Load all enabled clusters
  -c      Specify single cluster id to load, overrides config (default ${CLUSTER_ID:-unset})
          May be a quoted, space-delimited list of cluster ids
             Example: "1 5 23"
  -d      Delay in seconds between iterations (default ${LOAD_DELAY})
  -D      Turn on debug output
  -z      Analyze frequency in iterations (default ${ANALYZE_FREQ})
  -h      Help

Note:
  If cluster id list is long, reduce load delay (-d secs) to ensure metrics
  data is fresh. Alternatively, run multiple independent loader instances where each
  executes for a single cluster id.
EOMSG
    exit 1
}

# Set default cluster command
cluster_cmd=("echo" "${CLUSTER_ID}")

# Parse command line arguments
while getopts $OPTIONS opt; do
    case "$opt" in
        a)
            # Use array to safely store the command
            cluster_cmd=(psql -qAt -d "${PGDATABASE}" -U "${PGUSER}" -p "${PGPORT}" -c "SELECT id FROM public.clusters WHERE enabled ORDER BY id")
            ;;
        c)
            # Check if input is a single cluster ID or space-delimited list
            if [[ "${OPTARG}" != *" "* ]]; then
                # Single cluster ID
                cluster_ids="${OPTARG}"
                # Update log file for single cluster
                logdir=$(dirname "${LOGFILE}")
                LOGFILE="${logdir}/loader-cluster${OPTARG}.log"
            else
                # Space-delimited list of cluster IDs
                cluster_ids="${OPTARG}"
            fi
            # Use array for command that echoes cluster IDs
            cluster_cmd=(echo "${cluster_ids}")
            ;;
        D)
            # Set debug mode
            export DEBUG=1
            loginfo "Debug mode enabled"
            ;;
        d)
            # Validate delay is a positive number
            if ! [[ "${OPTARG}" =~ ^[0-9]+$ ]] || [[ "${OPTARG}" -lt 1 ]]; then
                logerror "Delay must be a positive integer" 1
            fi
            LOAD_DELAY="${OPTARG}"
            ;;
        z)
            # Validate analyze frequency is a positive number
            if ! [[ "${OPTARG}" =~ ^[0-9]+$ ]] || [[ "${OPTARG}" -lt 1 ]]; then
                logerror "Analyze frequency must be a positive integer" 1
            fi
            ANALYZE_FREQ="${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            usage "Unknown flag -${opt}"
            ;;
    esac
done

# Initialize variables for main loop
loadall="false"
i=$(( ANALYZE_FREQ + 1 ))

# Log configuration
loginfo "Starting cluster data loader"
logdebug "Configuration:"
logdebug "  LOGFILE      = %s" "${LOGFILE}"
logdebug "  cluster_ids  = %s" "${cluster_ids:-derived from query}"
logdebug "  LOAD_DELAY   = %s seconds" "${LOAD_DELAY}"
logdebug "  ANALYZE_FREQ = %s iterations" "${ANALYZE_FREQ}"

# Verify database connection before starting the loop
if ! PGPASSWORD="${PGPASSWORD}" psql -c "SELECT 1" -d "${PGDATABASE}" -U "${PGUSER}" -p "${PGPORT}" -q > /dev/null 2>&1; then
    logerror "Cannot connect to database. Check database connection parameters." 1
fi

# Trap Ctrl+C and other signals to exit gracefully
trap cleanup SIGINT SIGTERM EXIT
cleanup() {
    loginfo "Shutting down loader"
    exit 0
}

# SQL execution function
execute_load() {
    local cluster_id="$1"
    local analyze="$2"
    local loadall="$3"

    loginfo "Loading cluster_id %s (analyze=%s, loadall=%s)" "${cluster_id}" "${analyze}" "${loadall}"

    if ! PGPASSWORD="${PGPASSWORD}" psql -qAt -d "${PGDATABASE}" -U "${PGUSER}" -p "${PGPORT}" \
         -c "CALL public.load(${cluster_id}, ${analyze}, ${loadall})" >> "${LOGFILE}" 2>&1; then
        logerror "Failed to load cluster_id %s, check %s for details" "${cluster_id}" "${LOGFILE}"
        return 1
    fi

    return 0
}

# Main loop
loginfo "Starting main processing loop"
while true; do
    # Log iteration count if debug enabled
    logdebug "Processing iteration %d" "$i"

    # Determine if analyze should run this iteration
    analyze="false"
    if [[ $i -gt ${ANALYZE_FREQ} ]]; then
        if [[ $i -eq $(( ANALYZE_FREQ + 1 )) ]]; then
            loginfo "First run on start, loading all"
            loadall="true"
        fi
        analyze="true"
        i=1
    fi

    # Process each cluster
    # Use command substitution with proper quoting to handle the results safely
    while IFS= read -r cluster_id; do
        if [[ -n "${cluster_id}" ]]; then
            execute_load "${cluster_id}" "${analyze}" "${loadall}"
            # Reset loadall flag after first cluster
            loadall="false"
        fi
    done < <("${cluster_cmd[@]}")

    # Sleep between iterations
    logdebug "Waiting %d seconds before next iteration" "${LOAD_DELAY}"
    sleep "${LOAD_DELAY}"
    ((i++))
done
