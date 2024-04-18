#!/bin/bash

# Function to safely move files with backup
move_file_safely() {
    local source_file=$1
    local backup_file=$2

    # Check if the source file exists
    if [ ! -f "$source_file" ]; then
        echo "Error: Source file $source_file does not exist."
        return 1
    fi

    # Check if the backup file already exists
    if [ -f "$backup_file" ]; then
        echo "Warning: Backup file $backup_file already exists. No action taken."
        return 2
    fi

    # Proceed with moving the file
    mv "$source_file" "$backup_file"
    echo "Moved $source_file to $backup_file."
}

# Option to toggle between two sets of moves
if [ -f "./clusters.tf" ] && [ ! -f "./my-clusters.tf.bak" ]; then
    # First scenario: Move clusters.tf to my-clusters.tf.bak and restore orig-clusters.tf.bak to clusters.tf
    move_file_safely "./clusters.tf" "./my-clusters.tf.bak"
    move_file_safely "./orig-clusters.tf.bak" "./clusters.tf"
elif [ -f "./clusters.tf" ] && [ ! -f "./orig-clusters.tf.bak" ]; then
    # Second scenario: Move clusters.tf to orig-clusters.tf.bak and restore my-clusters.tf.bak to clusters.tf
    move_file_safely "./clusters.tf" "./orig-clusters.tf.bak"
    move_file_safely "./my-clusters.tf.bak" "./clusters.tf"
else
    echo "Files are not in the expected state, or backups already exist."
fi
