# ZFS Pool Setup for Server-River

This document outlines the ZFS setup procedures for the server-river host.

## Prerequisites

- NixOS installed with ZFS support enabled
- Root access to the server
- Target storage device(s) identified

## 1. ZFS Pool Creation

### Single Disk Setup (Basic)
```bash
# Replace /dev/sdX with your actual device
sudo zpool create -o ashift=12 \
    -O compression=lz4 \
    -O acltype=posixacl \
    -O xattr=sa \
    -O relatime=on \
    -O encryption=aes-256-gcm \
    -O keyformat=passphrase \
    -O keylocation=prompt \
    tank /dev/sdX
```

### Mirror Setup (Recommended)
```bash
# Replace /dev/sdX and /dev/sdY with your actual devices  
sudo zpool create -o ashift=12 \
    -O compression=lz4 \
    -O acltype=posixacl \
    -O xattr=sa \
    -O relatime=on \
    -O encryption=aes-256-gcm \
    -O keyformat=passphrase \
    -O keylocation=prompt \
    tank mirror /dev/sdX /dev/sdY
```

### RAIDZ Setup (3+ disks)
```bash
# Replace with your actual devices
sudo zpool create -o ashift=12 \
    -O compression=lz4 \
    -O acltype=posixacl \
    -O xattr=sa \
    -O relatime=on \
    -O encryption=aes-256-gcm \
    -O keyformat=passphrase \
    -O keylocation=prompt \
    tank raidz /dev/sdX /dev/sdY /dev/sdZ
```

## 2. ZFS Dataset Creation

After pool creation, create the required datasets:

```bash
# Create main NFS export directories
sudo zfs create tank/nfs
sudo zfs create tank/nfs/share
sudo zfs create tank/nfs/backup  
sudo zfs create tank/nfs/media
sudo zfs create tank/nfs/documents

# Create Syncthing dataset
sudo zfs create tank/syncthing

# Set NFS properties
sudo zfs set sharenfs="rw=100.64.0.0/10" tank/nfs
sudo zfs set sharenfs="rw=100.64.0.0/10" tank/nfs/share
sudo zfs set sharenfs="rw=100.64.0.0/10" tank/nfs/backup
sudo zfs set sharenfs="rw=100.64.0.0/10" tank/nfs/media
sudo zfs set sharenfs="rw=100.64.0.0/10" tank/nfs/documents
```

## 3. ZFS Configuration Options Explained

- **ashift=12**: Optimizes for 4K sector drives (modern standard)
- **compression=lz4**: Fast, lightweight compression
- **acltype=posixacl**: POSIX ACL support for Linux compatibility
- **xattr=sa**: Store extended attributes in system attributes for better performance
- **relatime=on**: Update access times efficiently
- **encryption=aes-256-gcm**: Full dataset encryption
- **keyformat=passphrase**: Use passphrase for encryption key

## 4. Pool Status and Health Checks

```bash
# Check pool status
sudo zpool status tank

# Check pool health
sudo zpool list tank

# View dataset information
sudo zfs list

# Check compression ratio
sudo zfs get compressratio tank

# Monitor pool I/O
sudo zpool iostat tank 1
```

## 5. Automatic Services Setup

The NixOS configuration automatically enables:

- **Auto-scrub**: Weekly integrity checks
- **Auto-snapshot**: Automated snapshots with retention
- **ZED (ZFS Event Daemon)**: Monitoring and alerting

Manual scrub (if needed):
```bash
sudo zpool scrub tank
```

## 6. Backup Integration

The ZFS pool integrates with the backup strategy:

1. **Local Borg**: `/tank/nfs/backup/borg-local`
2. **Offline Borg**: `/mnt/backup-drive/borg-offline` 
3. **Cloud Sync**: Backblaze B2 via rclone
4. **ZFS Snapshots**: Point-in-time recovery

## 7. Disaster Recovery

### Export/Import Pool
```bash
# Export pool (for migration)
sudo zpool export tank

# Import pool on new system
sudo zpool import tank

# Import with different name
sudo zpool import tank tank-recovered
```

### Key Management
```bash
# Load encryption key
sudo zfs load-key tank

# Change encryption key
sudo zfs change-key tank

# Backup encryption key
sudo zfs get -o value encryption tank > tank-key-backup.txt
```

## 8. Performance Tuning

### ARC (Adaptive Replacement Cache) Settings
Add to `/etc/modprobe.d/zfs.conf`:
```
# Limit ARC to 8GB (adjust for your RAM)
options zfs zfs_arc_max=8589934592

# Minimum ARC size  
options zfs zfs_arc_min=1073741824
```

### Dataset Tuning
```bash
# For database workloads
sudo zfs set recordsize=8K tank/databases

# For media files
sudo zfs set recordsize=1M tank/media

# Disable access time updates for performance
sudo zfs set atime=off tank/nfs/media
```

## 9. Monitoring and Alerting

The configuration includes:

- **Prometheus metrics**: ZFS pool health and usage
- **Grafana dashboards**: Visual monitoring
- **Smart notifications**: Disk health alerts
- **Weekly scrub reports**: Automated integrity checks

## 10. Troubleshooting

### Common Issues

**Pool won't import:**
```bash
# Force import (use with caution)
sudo zpool import -f tank

# Import with different device paths
sudo zpool import -d /dev/disk/by-id tank
```

**Out of space:**
```bash
# Check space usage by dataset
sudo zfs list -o space

# Find large files
sudo du -h /tank | sort -hr | head -20
```

**Performance issues:**
```bash
# Check pool fragmentation
sudo zpool list -o fragmentation

# Monitor real-time I/O
sudo zpool iostat -v tank 1
```

## 11. Maintenance Schedule

- **Daily**: Automated snapshots
- **Weekly**: Automated scrub
- **Monthly**: Review pool health metrics
- **Quarterly**: Test backup restoration
- **Annually**: Review retention policies and capacity planning

---

⚠️ **Important Notes:**
- Always test backup restoration procedures
- Monitor pool health regularly
- Keep encryption passphrases secure
- Document any custom configurations
- Plan for capacity growth