#!/bin/bash

# Restore script for Open Notebook backups
# Usage: ./restore.sh backups/backup_full_20260319_140000.tar.gz

set -e

BACKUP_FILE="${1:-.}"
RESTORE_DIR="."

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    echo "Usage: $0 <backup-file>"
    exit 1
fi

echo "WARNING: This will overwrite existing data!"
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo "Stopping containers..."
docker compose down

echo "Removing current data directories..."
rm -rf ./surreal_data ./notebook_data

echo "Extracting backup: $BACKUP_FILE"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

echo "Restarting containers..."
docker compose up -d

echo "Restore complete. Checking status..."
sleep 5
docker compose ps
