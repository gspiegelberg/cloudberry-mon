#!/usr/bin/env bash
#
# Enhanced SAR data extraction script
# Purpose: Extract and format system activity data from sysstat package
#

#!/usr/bin/env bash
#
# Enhanced SAR data extraction script
# Purpose: Extract and format system activity data from sysstat package
#

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the common functions library
# shellcheck disable=SC1091
if [[ -f "$SCRIPT_DIR/common_functions.bash" ]]; then
    source "$SCRIPT_DIR/common_functions.bash"
else
    echo "ERROR: Required common_functions.bash not found in $SCRIPT_DIR" >&2
    exit 1
fi

# Source configuration
# shellcheck disable=SC1091
if [[ -f /usr/local/cbmon/etc/config ]]; then
    source /usr/local/cbmon/etc/config
else
    logerror "Configuration file not found" 1
fi

# Check for required dependencies
check_dependencies sar sed grep mktemp date hostname || exit 1

# Display usage information
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Extract and format SAR data

Options:
  -a          Process all available SA files
  -p          Use previous day's data
  -d DATE     Specify date in YYYY-MM-DD format
  -S FLAGS    Specify SAR flags (required, e.g. "-u", "-r", "-b")
  -o FILE     Output to file instead of stdout
  -h          Display this help message

Example:
  $(basename "$0") -S "-u"        # CPU usage for today
  $(basename "$0") -p -S "-r"     # Memory usage for yesterday
  $(basename "$0") -a -S "-n DEV" # Network stats for all days
EOF
    exit 0
}

# Initialize variables
options="apd:S:o:h"
flags=""
output_file=""
all=0
custom_date=""
dom=$(date +%d)

# Parse command line options
while getopts "$options" opt; do
    case "$opt" in
        a)
            all=1
            ;;
        p)
            # Previous day
            dom=$(date -d "yesterday 13:00" '+%d')
            ;;
        d)
            custom_date="$OPTARG"
            # Validate date format
            if ! date -d "$custom_date" "+%Y-%m-%d" >/dev/null 2>&1; then
                logerror "Invalid date format: $custom_date (use YYYY-MM-DD)"
                exit 1
            fi
            dom=$(date -d "$custom_date" '+%d')
            ;;
        S)
            flags="$OPTARG"
            ;;
        o)
            output_file="$OPTARG"
            ;;
        h)
            usage
            ;;
        *)
            logerror "Unknown option: -$OPTARG"
            usage
            # No need for exit here as usage will exit
            ;;
    esac
done

# Validate required parameters
if [[ -z "$flags" ]]; then
    logerror "-S flag is required"
    usage
    # No need for exit here as usage will exit
fi

# Ensure flags have the appropriate format (add - prefix if missing)
if [[ "$flags" != -* && "$flags" != "" ]]; then
    loginfo "Adding dash prefix to flags: $flags -> -$flags"
    flags="-$flags"
fi

# Get hostname
hn=$(hostname)

# Create secure temporary directory
tmp_dir=$(create_temp_dir "sar_extract") || {
    logerror "Failed to create temporary directory"
    exit 1
}

# Ensure cleanup on exit
add_cleanup_trap "$tmp_dir"

# Determine which SA files to process
if [[ $all -eq 0 ]]; then
    if [[ -n "$custom_date" ]]; then
        loginfo "Processing data for specified date: $custom_date"
    else
        loginfo "Processing data for day: $dom"
    fi

    safiles="/var/log/sa/sa${dom}"

    # If we're still unable to determine the day, try direct system stats retrieval
    if [[ ! -f "$safiles" && $all -eq 0 ]]; then
        logwarn "No SA files found for day $dom. Attempting direct system stats retrieval."

        # Make sure safiles is set to an empty array for later processing
        safiles=()

        # Define a function to handle the direct stat retrieval
        # This ensures local variables are in a function scope
        get_direct_stats() {
            local direct_output
            direct_output="$tmp_dir/direct_system_stats.tmp"
            if S_TIME_FORMAT=ISO LC_ALL=en_UK.utf8 sar "$flags" 1 1 > "$direct_output" 2>/dev/null; then
                if [[ -s "$direct_output" ]]; then
                    loginfo "Successfully retrieved current system stats directly."
                    # Return success
                    return 0
                fi
            fi
            # Return failure
            return 1
        }

        # Call the function and check result
        if get_direct_stats; then
            safiles=("/dev/null") # Just a placeholder to trigger processing
        fi
    fi
else
    loginfo "Processing all available SA files"
    # Use find for more reliable file listing
    mapfile -t safiles < <(find /var/log/sa -name "sa[0-3][0-9]" -type f -size +0c | sort)

    if [[ ${#safiles[@]} -eq 0 ]]; then
        logerror "No SA files found"
        exit 0
    fi
fi

# Process each SA file
process_files() {
    local output="$tmp_dir/output.csv"

    # Always create the output file
    touch "$output"

    # Create CSV header for output
    echo "hostname,date,time,metrics" > "$output"

    loginfo "Processing with flags: $flags"

    # Handle display of files safely for both arrays and strings
    if [[ -n "${safiles[*]}" ]]; then
        loginfo "Processing files: ${safiles[*]}"
    elif [[ -n "$safiles" ]]; then
        loginfo "Processing files: $safiles"
    else
        loginfo "No specific files identified for processing."
    fi

    # Debug - check if SA files directory exists
    if [[ ! -d "/var/log/sa" ]]; then
        logwarn "SA directory not found: /var/log/sa"
        find / -name "sa[0-3][0-9]" -type f -size +0c 2>/dev/null | head -5 | while read -r file; do
            loginfo "Possible SA file found: $file"
        done
    fi

    # If safiles is a single string, convert to array for consistent handling
    local sa_array=()
    if [[ -n "$safiles" ]]; then
        if [[ -f "$safiles" ]]; then
            sa_array=("$safiles")
        elif [[ -n "${safiles[0]}" ]]; then
            sa_array=("${safiles[@]}")
        fi
    fi

    # If still no files found, try to find any SA files
    if [[ ${#sa_array[@]} -eq 0 ]]; then
        logwarn "No SA files specified. Trying to find any available SA files."
        mapfile -t sa_array < <(find /var/log/sa -name "sa[0-3][0-9]" -type f 2>/dev/null | sort)

        # If still no files, try running sar directly
        if [[ ${#sa_array[@]} -eq 0 ]]; then
            loginfo "No SA files found. Attempting direct sar command."
            local direct_output="$tmp_dir/direct_sar.tmp"
            # Try running SAR directly without referencing files
            if S_TIME_FORMAT=ISO LC_ALL=en_UK.utf8 sar "$flags" > "$direct_output" 2>/dev/null; then
                if [[ -s "$direct_output" ]]; then
                    grep -v "^Linux" "$direct_output" | \
                        grep -v "^Average" | \
                        grep -v "^$" | \
                        sed -e 's/ \{1,\}/,/g' -e "s/^/$(date +%Y-%m-%d) /g" -e "s/^/$hn,/g" >> "$output" || true
                    loginfo "Successfully retrieved data directly from sar."
                fi
            else
                logwarn "Direct sar command failed. Is sysstat installed and configured?"
            fi
        fi
    fi

    # Now process the files
    for sa in "${sa_array[@]}"; do
        if [[ ! -f "$sa" || ! -s "$sa" ]]; then
            logwarn "File does not exist or is empty: $sa"
            continue
        fi

        loginfo "Processing file: $sa"

        local tmpfile
        tmpfile="$tmp_dir/$(basename "$sa").tmp"

        # Run SAR command with specified flags
        # Note: We intentionally do not quote $flags based on testing
        # shellcheck disable=SC2086
        if ! S_TIME_FORMAT=ISO LC_ALL=en_UK.utf8 sar -f "$sa" $flags > "$tmpfile" 2>/dev/null; then
            # shellcheck disable=SC2086
            S_TIME_FORMAT=ISO LC_ALL=en_UK.utf8 sar $flags > "$tmpfile" 2>/dev/null
        fi

        # Check for data in the output
        if [[ ! -s "$tmpfile" ]]; then
            logwarn "SAR command produced no output for file: $sa with flags: $flags"
            continue
        fi

        # Debug info
        loginfo "SAR command successful, file size: $(wc -c < "$tmpfile") bytes"

        # Extract date from the file
        local that_day
        that_day=$(head -1 "$tmpfile" | grep -o "[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" || date +%Y-%m-%d)

        # Debug info
        loginfo "Extracted date: $that_day"

        # Debugging - show first few lines of the tmpfile
        loginfo "First lines of SAR output:"
        head -3 "$tmpfile" | while IFS= read -r line; do
            loginfo "  $line"
        done

        # Filter and format the data - Using simple approach to ensure it works
        local filtered_output="$tmp_dir/filtered.tmp"

        # First get the CPU lines
        grep -v "^Linux" "$tmpfile" | \
          grep -v "^Average" | \
          grep -v "^$" > "$filtered_output"

        # Debug info
        loginfo "Filtered data lines: $(wc -l < "$filtered_output")"

        # Convert to CSV
        if [[ -s "$filtered_output" ]]; then
            while IFS= read -r line; do
                # Convert spaces to commas and prepend hostname and date
                echo "$hn,$that_day,$(echo "$line" | tr -s ' ' ',')" >> "$output"
            done < "$filtered_output"
        else
            logwarn "No data lines after filtering for file: $sa"
        fi
    done

    # Output the results
    if [[ -n "$output_file" ]]; then
        cp "$output" "$output_file"
        loginfo "Output written to: $output_file"
    else
        if [[ -s "$output" ]]; then
            # Check if we have more than just the header line
            if [[ $(wc -l < "$output") -gt 1 ]]; then
                cat "$output"
            else
                cat "$output"
                echo "$hn,$(date +%Y-%m-%d),No data found for the specified criteria"
            fi
        else
            echo "hostname,date,time,metrics"
            echo "$hn,$(date +%Y-%m-%d),No data found for the specified criteria"
        fi
    fi
}

# Main execution
process_files 2>/dev/null
exit 0
