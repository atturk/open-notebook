#!/bin/bash

# Comprehensive backup script for Open Notebook
# Supports: Local file backups, SurrealDB export, incremental backups
# Usage: ./backup.sh [full|incremental|export]
# Cron: 0 2 * * * cd /path/to/open-notebook && ./backup.sh full

set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_MODE="${1:-full}"
RETENTION_DAYS=30
VERBOSE=1

# Create backups directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

log() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    fi
}

# Full backup of data directories
backup_full() {
    log "Starting full backup..."
    local BACKUP_FILE="$BACKUP_DIR/backup_full_$TIMESTAMP.tar.gz"
    
    tar -czf "$BACKUP_FILE" ./surreal_data ./notebook_data 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log "Full backup successful: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
    else
        log "ERROR: Full backup failed!"
        return 1
    fi
}

# Incremental backup (only changed files since last backup)
backup_incremental() {
    log "Starting incremental backup..."
    local BACKUP_FILE="$BACKUP_DIR/backup_incremental_$TIMESTAMP.tar.gz"
    local LAST_BACKUP=$(ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$LAST_BACKUP" ]; then
        log "No previous backup found. Running full backup instead..."
        backup_full
        return 0
    fi
    
    local BACKUP_TIME=$(stat -f%m "$LAST_BACKUP" 2>/dev/null || stat -c%Y "$LAST_BACKUP")
    
    tar -czf "$BACKUP_FILE" \
        --newer-mtime-than="@$BACKUP_TIME" \
        ./surreal_data ./notebook_data 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log "Incremental backup successful: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
    else
        log "ERROR: Incremental backup failed!"
        return 1
    fi
}

# Export SurrealDB via HTTP (when running)
backup_export() {
    log "Starting SurrealDB export..."
    
    if ! docker ps --format '{{.Names}}' | grep -q "surrealdb"; then
        log "WARNING: SurrealDB container not running. Skipping export."
        return 0
    fi
    
    local EXPORT_FILE="$BACKUP_DIR/backup_export_$TIMESTAMP.surql"
    
    docker exec open-notebook-surrealdb surreal export \
        --conn ws://127.0.0.1:8000 \
        --user root \
        --pass password \
        --namespace open_notebook \
        --database open_notebook > "$EXPORT_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log "SurrealDB export successful: $EXPORT_FILE ($(du -h "$EXPORT_FILE" | cut -f1))"
    else
        log "WARNING: SurrealDB export failed (container may be offline)"
    fi
}

# Cleanup old backups
cleanup_old() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    find "$BACKUP_DIR" -type f -name "backup_*" -mtime +$RETENTION_DAYS -delete
    log "Cleanup complete."
}

# Main execution
case "$BACKUP_MODE" in
    full)
        backup_full
        backup_export
        cleanup_old
        ;;
    incremental)
        backup_incremental
        backup_export
        cleanup_old
        ;;
    export)
        backup_export
        ;;
    *)
        echo "Usage: $0 [full|incremental|export]"
        exit 1
        ;;
esac

log "Backup process completed."
