#!/usr/bin/env bash
set -euo pipefail

echo "🔄 Backup Restore Test"
echo "======================"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <backup-type> <test-file-pattern>"
  echo ""
  echo "Backup types:"
  echo "  local     - Test restore from local Borg backup"
  echo "  offline   - Test restore from offline Borg backup"  
  echo "  cloud     - Test restore from Backblaze B2"
  echo "  zfs       - Test restore from ZFS snapshot"
  echo ""
  echo "Examples:"
  echo "  $0 local 'tank/nfs/share/important.txt'"
  echo "  $0 cloud 'share/documents'"
  echo "  $0 zfs 'share/configs'"
  exit 1
fi

BACKUP_TYPE="$1"
TEST_PATTERN="$2"

RESTORE_DIR="/var/lib/backup-validation/test-restore"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TEST_DIR="$RESTORE_DIR/$BACKUP_TYPE-$TIMESTAMP"

mkdir -p "$TEST_DIR"

case "$BACKUP_TYPE" in
  "local")
    echo "🔄 Testing local Borg backup restore..."
    BORG_REPO="/tank/nfs/backup/borg-local"
    LATEST_ARCHIVE=$(borg list --short "$BORG_REPO" | tail -1)
    
    echo "Restoring from archive: $LATEST_ARCHIVE"
    echo "Pattern: $TEST_PATTERN"
    
    BORG_PASSCOMMAND="cat /run/secrets/borg-passphrase" \
    borg extract \
      "$BORG_REPO::$LATEST_ARCHIVE" \
      --destination "$TEST_DIR" \
      "$TEST_PATTERN"
    ;;
    
  "offline")
    echo "🔄 Testing offline Borg backup restore..."
    OFFLINE_REPO="/mnt/backup-drive/borg-offline"
    
    if [ ! -d "$OFFLINE_REPO" ]; then
      echo "❌ Offline backup drive not mounted"
      exit 1
    fi
    
    LATEST_ARCHIVE=$(BORG_PASSCOMMAND="cat /run/secrets/borg-passphrase-offline" \
                    borg list --short "$OFFLINE_REPO" | tail -1)
    
    echo "Restoring from offline archive: $LATEST_ARCHIVE"
    
    BORG_PASSCOMMAND="cat /run/secrets/borg-passphrase-offline" \
    borg extract \
      "$OFFLINE_REPO::$LATEST_ARCHIVE" \
      --destination "$TEST_DIR" \
      "$TEST_PATTERN"
    ;;
    
  "cloud")
    echo "🔄 Testing cloud backup restore..."
    echo "Downloading from Backblaze B2..."
    
    rclone copy \
      "b2:server-river-backup/$TEST_PATTERN" \
      "$TEST_DIR" \
      --progress
    ;;
    
  "zfs")
    echo "🔄 Testing ZFS snapshot restore..."
    LATEST_SNAPSHOT=$(zfs list -t snapshot -o name tank/nfs | tail -1)
    
    if [ -z "$LATEST_SNAPSHOT" ]; then
      echo "❌ No ZFS snapshots found"
      exit 1
    fi
    
    echo "Restoring from snapshot: $LATEST_SNAPSHOT"
    
    # Mount snapshot readonly and copy files
    SNAP_MOUNT="/tmp/zfs-snapshot-$TIMESTAMP"
    mkdir -p "$SNAP_MOUNT"
    
    # Note: This would require actual ZFS snapshot mounting in production
    echo "⚠️  ZFS snapshot restore test requires manual snapshot mounting"
    echo "Snapshot available: $LATEST_SNAPSHOT"
    ;;
    
  *)
    echo "❌ Unknown backup type: $BACKUP_TYPE"
    exit 1
    ;;
esac

# Verify restore
if [ -d "$TEST_DIR" ] && [ "$(find "$TEST_DIR" -type f | wc -l)" -gt 0 ]; then
  RESTORED_FILES=$(find "$TEST_DIR" -type f | wc -l)
  TOTAL_SIZE=$(du -sh "$TEST_DIR" | cut -f1)
  
  echo "✅ Restore successful!"
  echo "📁 Files restored: $RESTORED_FILES"
  echo "💾 Total size: $TOTAL_SIZE"
  echo "📂 Location: $TEST_DIR"
  
  echo ""
  echo "📋 Restored files:"
  find "$TEST_DIR" -type f | head -20 | while read -r file; do
    echo "  - $(basename "$file") ($(stat --printf='%s' "$file" | numfmt --to=iec))"
  done
  
  # Cleanup option
  echo ""
  read -p "🗑️  Remove test restore directory? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$TEST_DIR"
    echo "✅ Test directory cleaned up"
  else
    echo "📂 Test files preserved at: $TEST_DIR"
  fi
  
else
  echo "❌ Restore failed - no files found"
  exit 1
fi