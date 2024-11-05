#!/bin/bash

# Check if the script is running under watch; if not, rerun it with watch -n 1
if [[ "$1" != "--watched" ]]; then
    exec watch -n 0.1 "$0" --watched
fi

# File to keep track of the lowest space observed
LOG_FILE="/var/log/watch-disk-space.txt"

# Function to convert available space to MB for comparison
convert_to_mb() {
    local space=$1
    case ${space: -1} in
        G) echo "$(echo "${space%?} * 1024" | bc)";; # Convert GB to MB
        M) echo "${space%?}";;                       # MB remains MB
        K) echo "$(echo "${space%?} / 1024" | bc)";; # Convert KB to MB
        *) echo "$space";;                           # Assume MB if no unit
    esac
}

# Get the current available space on / and convert to MB
raw_space=$(df -h / | awk 'NR==2 {print $4}')
current_space=$(convert_to_mb "$raw_space")

# Check if the log file exists; if not, initialize it with the current space
if [[ ! -f "$LOG_FILE" ]]; then
    echo "Initial lowest space: ${current_space}M" > "$LOG_FILE"
    lowest_space=$current_space
else
    # Read the last recorded lowest space from the log file (in MB)
    raw_lowest=$(tail -n 1 "$LOG_FILE" | awk '{print $NF}')
    lowest_space=$(convert_to_mb "$raw_lowest")
fi

# Compare and update the lowest space if needed
if (( $(echo "$current_space < $lowest_space" | bc -l) )); then
    lowest_space=$current_space
    echo "$(date): New lowest available space: ${lowest_space}M" >> "$LOG_FILE"
fi

# Output the current and lowest available space
echo "Current available space: ${current_space}M"
echo "Lowest available space: ${lowest_space}M"