#!/usr/bin/env bash
#
# CloudBerry DB Alter Script (Bash Version)
# This script loads and applies database alters to a CloudBerry database
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

# Initialize variables
DB_NAME=""
DB_USER=""
DB_PORT=""
CBPATH="/usr/local/cloudberry-db/greenplum_path.sh"
ALTERS_DIR="/usr/local/cbmon/alters/cloudberry"
readonly OPTIONS="hc:d:U:p:"

# Display usage information
usage() {
    local rval="${1:-0}"
    cat << EOL
usage: load_cbalters.bash ...
 -c path    path to nonstandard location of greenplum_path.sh
            default $CBPATH
 -h         help
 -d DBNAME  database name (REQUIRED)
 -p DBPORT  database port (REQUIRED)
 -U DBUSER  database user with superuser privilege (REQUIRED)
EOL
    exit "$rval"
}

# Parse command line arguments
while getopts $OPTIONS opt; do
    case "$opt" in
        c)
            CBPATH="${OPTARG}"
            ;;
        d)
            DB_NAME="${OPTARG}"
            ;;
        U)
            DB_USER="${OPTARG}"
            ;;
        p)
            DB_PORT="${OPTARG}"
            ;;
        h)
            usage 0
            ;;
        *)
            usage 1
            ;;
    esac
done

# Validate required parameters
[[ -z "${DB_NAME}" ]] && logerror "Database name required" 1
[[ -z "${DB_USER}" ]] && logerror "Database user with superuser required" 1
[[ -z "${DB_PORT}" ]] && logerror "Database port required" 1

# Validate DB_PORT is numeric
if ! [[ "${DB_PORT}" =~ ^[0-9]+$ ]]; then
    logerror "Port must be a number" 1
fi

# Check if CloudBerry path exists
if [[ ! -f "${CBPATH}" ]]; then
    logerror "greenplum_path not found at %s" 1 "${CBPATH}"
fi

# Source the CloudBerry environment
# shellcheck disable=SC1090
source "${CBPATH}"

# Check if psql command is available
if ! command -v psql > /dev/null 2>&1; then
    logerror "psql command not found. Is PostgreSQL client installed?" 1
fi

# Setup PostgreSQL command with array for better security
PSQL_CMD=(psql -qAt -d "${DB_NAME}" -p "${DB_PORT}" -U "${DB_USER}")

# Test database connection
if ! "${PSQL_CMD[@]}" -c "SELECT 1" > /dev/null 2>&1; then
    logerror "Could not connect to database. Check credentials and connection." 1
fi

# Function to execute SQL queries safely
execute_sql() {
    local query="$1"
    local output

    output=$("${PSQL_CMD[@]}" -c "$query" 2>&1)
    local status=$?

    echo "$output"
    return $status
}

# Function to count lines in output
count_lines() {
    wc -l | tr -d ' '
}

# Check if cbmon schema exists
loginfo "Checking if cbmon schema exists"
exists=$(execute_sql "SELECT * FROM pg_catalog.pg_namespace WHERE nspname = 'cbmon'" | count_lines)

if [[ "$exists" -ne 0 ]]; then
    # Check if cbmon.alters table exists
    loginfo "Checking if cbmon.alters table exists"
    exists=$(execute_sql "SELECT * FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON (c.relnamespace = n.oid) WHERE c.relname = 'alters' AND n.nspname = 'cbmon'" | count_lines)

    if [[ "$exists" -eq 0 ]]; then
        logerror "cbmon schema exists but appears inconsistent" 1
        logwarn "Recommend DROP SCHEMA cbmon; and run again"
        exit 1
    fi

    loginfo "cbmon schema and alters table confirmed"
else
    loginfo "cbmon schema does not exist, it will be created by alter-1000"
fi

# Create timestamped log file
log=$(create_temp_dir "cbalters")/load_cbalters.log
loginfo "Starting alter application process at %s" "$(date)" | tee -a "${log}"

# Find all alter files
mapfile -t ALTER_FILES < <(find "${ALTERS_DIR}" -name "alter-[1-9]*.sql" | sort -n)
total_alters=${#ALTER_FILES[@]}

loginfo "Found %d alter files to process" "$total_alters" | tee -a "${log}"

# Begin transaction
if ! "${PSQL_CMD[@]}" -c "BEGIN TRANSACTION;" >> "${log}" 2>&1; then
    logerror "Could not begin transaction" 1 | tee -a "${log}"
fi

# Initialize counters
applied_count=0
skipped_count=0

# Process each alter file
for alter in "${ALTER_FILES[@]}"; do
    # Extract alter ID using bash regex
    if [[ $alter =~ alter-([1-9][0-9]{3}).sql$ ]]; then
        alter_id="${BASH_REMATCH[1]}"
    else
        logwarn "Could not parse alter ID from %s, skipping" "$alter" | tee -a "${log}"
        continue
    fi

    # alter-1000 delivers cbmon.alters
    if [[ "${alter_id}" -gt "1000" ]]; then
        loaded=$(execute_sql "SELECT * FROM cbmon.alters WHERE id = ${alter_id}" | count_lines)
        if [[ "$loaded" -eq 1 ]]; then
            loginfo "Alter %s already loaded, skipping" "${alter_id}" | tee -a "${log}"
            ((skipped_count++))
            continue
        fi
    fi

    loginfo "Applying alter %s from %s" "${alter_id}" "$alter" | tee -a "${log}"
    if ! "${PSQL_CMD[@]}" -f "$alter" >> "${log}" 2>&1; then
        logerror "Applying alter %s failed" 1 "${alter_id}" | tee -a "${log}"

        # Attempt rollback
        if ! "${PSQL_CMD[@]}" -c "ROLLBACK;" >> "${log}" 2>&1; then
            logwarn "Failed to roll back transaction" | tee -a "${log}"
        else
            loginfo "Transaction rolled back" | tee -a "${log}"
        fi

        logwarn "Review %s and try again" "${log}" | tee -a "${log}"
        exit 1
    fi

    ((applied_count++))
    logdebug "Successfully applied alter %s" "${alter_id}"
done

# Commit the transaction
if ! "${PSQL_CMD[@]}" -c "COMMIT;" >> "${log}" 2>&1; then
    logerror "Failed to commit transaction" 1 | tee -a "${log}"
    exit 1
fi

# Print summary
loginfo "Summary:" | tee -a "${log}"
loginfo "  Total alters processed: %d" "$total_alters" | tee -a "${log}"
loginfo "  Alters applied: %d" "$applied_count" | tee -a "${log}"
loginfo "  Alters skipped (already applied): %d" "$skipped_count" | tee -a "${log}"
loginfo "Completed successfully at %s" "$(date)" | tee -a "${log}"
loginfo "Log file: %s" "${log}"

exit 0
