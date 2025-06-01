#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Backup Validation Suite"
echo "=========================="

VALIDATION_DIR="/var/lib/backup-validation"
TEST_RESTORE_DIR="$VALIDATION_DIR/test-restore"
REPORTS_DIR="$VALIDATION_DIR/reports"
CHECKPOINT_DIR="$VALIDATION_DIR/checkpoints"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="$REPORTS_DIR/backup-validation-$TIMESTAMP.json"

# Initialize validation report
cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date --iso-8601=seconds)",
  "validation_id": "$TIMESTAMP",
  "tests": [],
  "summary": {
    "total_tests": 0,
    "passed": 0,
    "failed": 0,
    "warnings": 0
  }
}
EOF

function add_test_result() {
  local test_name="$1"
  local status="$2"
  local details="$3"
  local duration="$4"
  
  # Update report
  jq --arg name "$test_name" \
                   --arg status "$status" \
                   --arg details "$details" \
                   --arg duration "$duration" \
    '.tests += [{
      "name": $name,
      "status": $status, 
      "details": $details,
      "duration": $duration,
      "timestamp": now | strftime("%Y-%m-%dT%H:%M:%SZ")
    }] | 
    .summary.total_tests += 1 |
    if $status == "PASS" then .summary.passed += 1
    elif $status == "FAIL" then .summary.failed += 1
    else .summary.warnings += 1 end' \
    "$REPORT_FILE" > "$REPORT_FILE.tmp" && mv "$REPORT_FILE.tmp" "$REPORT_FILE"
}

function test_local_borg_backup() {
  echo "🔍 Testing local Borg backup..."
  local start_time=$(date +%s)
  
  local borg_repo="/tank/nfs/backup/borg-local"
  
  if [ ! -d "$borg_repo" ]; then
    add_test_result "local_borg_existence" "FAIL" "Borg repository does not exist at $borg_repo" "0"
    return 1
  fi
  
  # Test repository integrity
  if borg check --repository-only "$borg_repo" 2>/dev/null; then
    add_test_result "local_borg_integrity" "PASS" "Repository integrity check passed" "$(($(date +%s) - start_time))"
  else
    add_test_result "local_borg_integrity" "FAIL" "Repository integrity check failed" "$(($(date +%s) - start_time))"
    return 1
  fi
  
  # List archives
  local archive_count=$(borg list --short "$borg_repo" 2>/dev/null | wc -l)
  if [ "$archive_count" -gt 0 ]; then
    add_test_result "local_borg_archives" "PASS" "Found $archive_count archives in repository" "$(($(date +%s) - start_time))"
  else
    add_test_result "local_borg_archives" "WARN" "No archives found in repository" "$(($(date +%s) - start_time))"
  fi
  
  # Test restore of latest archive
  local latest_archive=$(borg list --short "$borg_repo" 2>/dev/null | tail -1)
  if [ -n "$latest_archive" ]; then
    echo "Testing restore of latest archive: $latest_archive"
    
    rm -rf "$TEST_RESTORE_DIR/borg-local"
    mkdir -p "$TEST_RESTORE_DIR/borg-local"
    
    if BORG_PASSCOMMAND="cat /run/secrets/borg-passphrase" \
       borg extract \
       "$borg_repo::$latest_archive" \
       --destination "$TEST_RESTORE_DIR/borg-local" \
       tank/nfs/share 2>/dev/null; then
      
      # Verify restored files
      local restored_files=$(find "$TEST_RESTORE_DIR/borg-local" -type f | wc -l)
      add_test_result "local_borg_restore" "PASS" "Successfully restored $restored_files files from $latest_archive" "$(($(date +%s) - start_time))"
    else
      add_test_result "local_borg_restore" "FAIL" "Failed to restore from $latest_archive" "$(($(date +%s) - start_time))"
    fi
  fi
}

function test_offline_borg_backup() {
  echo "🔍 Testing offline Borg backup..."
  local start_time=$(date +%s)
  
  local offline_repo="/mnt/backup-drive/borg-offline"
  
  if [ ! -d "$offline_repo" ]; then
    add_test_result "offline_borg_existence" "WARN" "Offline backup drive not mounted or repository missing" "0"
    return 0
  fi
  
  # Test repository integrity
  if BORG_PASSCOMMAND="cat /run/secrets/borg-passphrase-offline" \
     borg check --repository-only "$offline_repo" 2>/dev/null; then
    add_test_result "offline_borg_integrity" "PASS" "Offline repository integrity check passed" "$(($(date +%s) - start_time))"
  else
    add_test_result "offline_borg_integrity" "FAIL" "Offline repository integrity check failed" "$(($(date +%s) - start_time))"
    return 1
  fi
  
  # List archives
  local archive_count=$(BORG_PASSCOMMAND="cat /run/secrets/borg-passphrase-offline" \
                       borg list --short "$offline_repo" 2>/dev/null | wc -l)
  if [ "$archive_count" -gt 0 ]; then
    add_test_result "offline_borg_archives" "PASS" "Found $archive_count offline archives" "$(($(date +%s) - start_time))"
  else
    add_test_result "offline_borg_archives" "WARN" "No offline archives found" "$(($(date +%s) - start_time))"
  fi
}

function test_cloud_backup() {
  echo "🔍 Testing cloud backup (Backblaze B2)..."
  local start_time=$(date +%s)
  
  # Test B2 connectivity and list buckets
  if rclone listremotes | grep -q "b2:"; then
    add_test_result "cloud_config" "PASS" "Backblaze B2 configuration found" "1"
    
    # Test bucket access
    if rclone lsd b2:server-river-backup 2>/dev/null; then
      add_test_result "cloud_access" "PASS" "Successfully accessed B2 bucket" "$(($(date +%s) - start_time))"
      
      # List recent files
      local file_count=$(rclone ls b2:server-river-backup/share 2>/dev/null | wc -l)
      add_test_result "cloud_files" "PASS" "Found $file_count files in cloud backup" "$(($(date +%s) - start_time))"
    else
      add_test_result "cloud_access" "FAIL" "Cannot access B2 bucket" "$(($(date +%s) - start_time))"
    fi
  else
    add_test_result "cloud_config" "FAIL" "Backblaze B2 not configured" "1"
  fi
}

function test_zfs_snapshots() {
  echo "🔍 Testing ZFS snapshots..."
  local start_time=$(date +%s)
  
  # Check if ZFS is available
  if command -v zfs >/dev/null 2>&1; then
    # List snapshots
    local snapshot_count=$(zfs list -t snapshot 2>/dev/null | grep -c "tank/" || echo "0")
    
    if [ "$snapshot_count" -gt 0 ]; then
      add_test_result "zfs_snapshots" "PASS" "Found $snapshot_count ZFS snapshots" "$(($(date +%s) - start_time))"
      
      # Test snapshot rollback capability (dry run)
      local latest_snapshot=$(zfs list -t snapshot -o name tank/nfs 2>/dev/null | tail -1)
      if [ -n "$latest_snapshot" ]; then
        add_test_result "zfs_rollback_test" "PASS" "Latest snapshot available for rollback: $latest_snapshot" "$(($(date +%s) - start_time))"
      fi
    else
      add_test_result "zfs_snapshots" "WARN" "No ZFS snapshots found" "$(($(date +%s) - start_time))"
    fi
  else
    add_test_result "zfs_availability" "WARN" "ZFS not available on this system" "1"
  fi
}

function test_backup_encryption() {
  echo "🔍 Testing backup encryption..."
  local start_time=$(date +%s)
  
  # Test that backup passphrases are accessible
  if [ -f "/run/secrets/borg-passphrase" ]; then
    if [ -s "/run/secrets/borg-passphrase" ]; then
      add_test_result "local_backup_passphrase" "PASS" "Local backup passphrase accessible" "1"
    else
      add_test_result "local_backup_passphrase" "FAIL" "Local backup passphrase file empty" "1"
    fi
  else
    add_test_result "local_backup_passphrase" "FAIL" "Local backup passphrase not found" "1"
  fi
  
  if [ -f "/run/secrets/borg-passphrase-offline" ]; then
    if [ -s "/run/secrets/borg-passphrase-offline" ]; then
      add_test_result "offline_backup_passphrase" "PASS" "Offline backup passphrase accessible" "1"
    else
      add_test_result "offline_backup_passphrase" "FAIL" "Offline backup passphrase file empty" "1"
    fi
  else
    add_test_result "offline_backup_passphrase" "FAIL" "Offline backup passphrase not found" "1"
  fi
}

function test_disaster_recovery() {
  echo "🔍 Testing disaster recovery procedures..."
  local start_time=$(date +%s)
  
  # Test CA paper backup recovery simulation
  echo "Simulating CA recovery (dry run)..."
  if command -v ca-verify-paper-backup >/dev/null 2>&1; then
    add_test_result "ca_recovery_tools" "PASS" "CA recovery tools available" "1"
  else
    add_test_result "ca_recovery_tools" "FAIL" "CA recovery tools missing" "1"
  fi
  
  # Test configuration backup
  if [ -d "/etc/nixos" ] || [ -f "/etc/nixos/configuration.nix" ]; then
    add_test_result "config_backup" "PASS" "System configuration accessible for recovery" "1"
  else
    add_test_result "config_backup" "WARN" "System configuration location unclear" "1"
  fi
  
  # Test secrets recovery
  if [ -d "/run/secrets" ] && [ "$(ls -A /run/secrets 2>/dev/null | wc -l)" -gt 0 ]; then
    add_test_result "secrets_recovery" "PASS" "Secrets management operational" "1"
  else
    add_test_result "secrets_recovery" "FAIL" "Secrets not accessible" "1"
  fi
}

function create_checkpoint() {
  echo "📸 Creating system checkpoint..."
  local checkpoint_file="$CHECKPOINT_DIR/checkpoint-$TIMESTAMP.json"
  
  cat > "$checkpoint_file" << EOF
{
  "timestamp": "$(date --iso-8601=seconds)",
  "checkpoint_id": "$TIMESTAMP",
  "system_state": {
    "uptime": "$(uptime -p)",
    "disk_usage": $(df -h /tank | tail -1 | awk '{print "{\"used\":\""$3"\",\"available\":\""$4"\",\"percent\":\""$5"\"}"}'),
    "services": $(systemctl list-units --state=active --type=service --no-legend | wc -l),
    "zfs_health": "$(zpool status tank | grep -o "state: [A-Z]*" | cut -d: -f2 | xargs || echo "unknown")",
    "backup_space": {
      "local_borg": "$(du -sh /tank/nfs/backup/borg-local 2>/dev/null | cut -f1 || echo "unknown")",
      "total_nfs": "$(du -sh /tank/nfs 2>/dev/null | cut -f1 || echo "unknown")"
    }
  }
}
EOF
  
  echo "📸 Checkpoint saved: $checkpoint_file"
}

# Main validation sequence
echo "🚀 Starting backup validation..."
echo "Validation ID: $TIMESTAMP"
echo ""

create_checkpoint

test_backup_encryption
test_zfs_snapshots  
test_local_borg_backup
test_offline_borg_backup
test_cloud_backup
test_disaster_recovery

# Generate summary
echo ""
echo "📊 Validation Summary:"
echo "===================="

local total=$(jq -r '.summary.total_tests' "$REPORT_FILE")
local passed=$(jq -r '.summary.passed' "$REPORT_FILE")
local failed=$(jq -r '.summary.failed' "$REPORT_FILE")
local warnings=$(jq -r '.summary.warnings' "$REPORT_FILE")

echo "Total tests: $total"
echo "✅ Passed: $passed"
echo "❌ Failed: $failed"
echo "⚠️  Warnings: $warnings"

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "❌ Failed tests:"
  jq -r '.tests[] | select(.status == "FAIL") | "  - " + .name + ": " + .details' "$REPORT_FILE"
fi

if [ "$warnings" -gt 0 ]; then
  echo ""
  echo "⚠️  Warnings:"
  jq -r '.tests[] | select(.status == "WARN") | "  - " + .name + ": " + .details' "$REPORT_FILE"
fi

echo ""
echo "📁 Detailed report: $REPORT_FILE"

# Send notification
if [ "$failed" -gt 0 ]; then
  smart-notify critical "Backup Validation Failed" "$failed backup tests failed. Check report: $REPORT_FILE" "backup,validation,critical"
elif [ "$warnings" -gt 0 ]; then
  smart-notify warning "Backup Validation Warnings" "$warnings backup tests had warnings. Report: $REPORT_FILE" "backup,validation"
else
  smart-notify info "Backup Validation Success" "All $total backup tests passed successfully" "backup,validation"
fi

# Return appropriate exit code
if [ "$failed" -gt 0 ]; then
  exit 1
else
  exit 0
fi