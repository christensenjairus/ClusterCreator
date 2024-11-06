#!/bin/bash

# Check if the script is running under watch; if not, rerun it with watch -n 1
if [[ "$1" != "--watched" ]]; then
    exec watch -n 0.1 "$0" --watched
fi

# Check if `bc` is installed; if not, exit early and wait for the next watch interval
if ! command -v bc &> /dev/null; then
    echo "bc command not found. Waiting for it to be installed..."
    exit 0
fi

# File to keep track of the lowest space observed
LOG_FILE="/var/log/watch-disk-space.txt"

# Suggested disk size buffer in MB
BUFFER_SIZE=200

# Function to convert available space to MB for comparison
convert_to_mb() {
    local space=$1
    local num=${space%[GMK]}  # Remove units (G, M, K) from the number
    case ${space: -1} in
        G) echo $(( $(printf "%.0f" "$(echo "$num * 1024" | bc)") ));; # Convert GB to MB and round
        M) echo $(( $(printf "%.0f" "$num") ));;                      # MB remains MB, round to integer
        K) echo $(( $(printf "%.0f" "$(echo "$num / 1024" | bc)") ));; # Convert KB to MB and round
        *) echo $(( $(printf "%.0f" "$num") ));;                      # Assume MB if no unit
    esac
}

# Get the current available space on / and convert to MB
raw_space=$(df -h / | awk 'NR==2 {print $4}')
current_space=$(convert_to_mb "$raw_space")

# Check if the log file exists; if not, initialize it with the current space
if [[ ! -f "$LOG_FILE" ]]; then
    echo "Lowest available space during install: ${current_space}M" > "$LOG_FILE"
    lowest_space=$current_space
else
    # Extract the numeric value from the line containing "Lowest available space"
    raw_lowest=$(grep -oP 'Lowest available space during install: \K[0-9]+' "$LOG_FILE")
    lowest_space=$(convert_to_mb "${raw_lowest}M")
fi

# Ensure lowest_space is a valid number before comparison
if [[ -z "$lowest_space" ]]; then
    lowest_space=$current_space
fi

# Compare and update the space if needed
if (( current_space < lowest_space )); then
    lowest_space=$current_space
    # Calculate the current buffer by subtracting the desired buffer size from lowest_space
    buffered_space=$(( lowest_space - BUFFER_SIZE ))
    echo -n "Lowest available space during install: ${lowest_space}M" > "$LOG_FILE"

    if (( lowest_space < 10 )); then
        # Warn the user that they have run out of space
        echo -e -n "\nDisk space reached a critically low value" >> "$LOG_FILE"
    elif (( lowest_space >= 300 || lowest_space <= 100 )); then
        # Only provide suggestions if lowest_space is not between 100 and 300
        if (( buffered_space >= 0 )); then
            # Sufficient space for buffer
            echo -e -n "\nSuggestion: decrease TEMPLATE_DISK_SIZE by ${buffered_space}M to achieve a ${BUFFER_SIZE}M buffer from full" >> "$LOG_FILE"
        else
            # Insufficient space for buffer, suggest an increase
            required_increase=$(( BUFFER_SIZE - lowest_space ))
            echo -e -n "\nSuggestion: increase TEMPLATE_DISK_SIZE by ${required_increase}M to achieve a ${BUFFER_SIZE}M buffer from full" >> "$LOG_FILE"
        fi
    fi
fi

# Output the current and lowest available space
echo "Current available space: ${current_space}M"
echo "Lowest available space: ${lowest_space}M"