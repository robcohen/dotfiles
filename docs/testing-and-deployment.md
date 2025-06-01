# Testing and Deployment Guide

## 🧪 Automated Testing

### Running Tests

```bash
# Run all infrastructure tests
nix flake check

# Run specific server-river test
nix build .#checks.x86_64-linux.server-river-test

# Enter development environment
nix develop
```

### Test Coverage

The automated test suite covers:

- ✅ **Core Services**: Networking, SSH, ZFS
- ✅ **Certificate Authority**: step-ca health, certificate issuance
- ✅ **Monitoring Stack**: Prometheus, Grafana, alerting
- ✅ **Backup Systems**: Borg backup configuration
- ✅ **VPN Coordination**: Headscale service and API
- ✅ **Security Hardening**: Service isolation, TPM integration
- ✅ **Log Aggregation**: Loki and Promtail functionality

### Creating Custom Tests

Add new tests to `tests/server-river-test.nix`:

```nix
# Test custom functionality
server.succeed("your-custom-command")
test_api_endpoint("http://localhost:8080/your-endpoint")
```

## 📋 Log Management

### Log Query Commands

```bash
# Basic log queries
logs-query '{job="systemd-journal"}' '1h'
logs-query '{unit="step-ca.service"}' '24h'
logs-query '{job="backup"} |= "FAILED"' '7d'

# Security analysis
logs-security 24h

# Backup analysis
logs-backup 7d

# Live monitoring
logs-monitor live

# System overview
logs-monitor
```

### Log Sources

- **SystemD Journal**: All system services
- **Step-CA**: Certificate authority operations
- **Nginx**: Access and error logs
- **Backup**: Borg backup operations
- **Security**: Authentication and firewall events

### Grafana Integration

1. Access Grafana: `http://grafana.internal.robcohen.dev:3000`
2. Use Loki data source for log exploration
3. Create custom dashboards combining metrics + logs

## 🚀 Deployment Process

### 1. Pre-Deployment Validation

```bash
# Run tests
nix flake check

# Validate configuration
nixos-rebuild dry-build --flake .#server-river

# Security check
security-status
```

### 2. Initial Deployment

```bash
# Setup secrets management
sops-setup
sops-edit-secrets  # Add real secrets

# Deploy configuration
nixos-rebuild switch --flake .#server-river

# Post-deployment verification
ca-status
tmp-status
logs-status
security-status
```

### 3. Certificate Authority Setup

```bash
# On air-gapped machine:
ca-generate-mnemonic         # Generate 24-word seed
ca-init-from-paper          # Create CA hierarchy
# Transfer package to server-river

# On server-river:
ca-install-from-airgap /path/to/transfer
tpm-seal-ca-key             # Seal key to TPM
systemctl restart step-ca   # Use TPM-backed key
```

### 4. VPN Network Setup

1. **Configure DNS**: Point `sync.robcohen.dev` to server IP
2. **Verify ACME**: Let's Encrypt certificate should auto-issue
3. **Setup Headscale users**: `headscale users create main`
4. **Connect clients**: Use Tailscale pointing to `sync.robcohen.dev`

### 5. Monitoring Setup

```bash
# Verify monitoring stack
systemctl status prometheus grafana loki promtail

# Test notifications
smart-notify info "Test" "Deployment successful" "deployment"

# Check dashboards
curl -s http://grafana.internal.robcohen.dev:3000/api/health
```

## 🔍 Troubleshooting

### Common Issues

1. **SOPS secrets not decrypting**:
   ```bash
   sops-setup  # Regenerate age key if needed
   systemctl restart sops-nix
   ```

2. **TPM key unsealing fails**:
   ```bash
   tpm-status  # Check TPM availability
   # Fallback to filesystem key if needed
   ```

3. **Certificate issues**:
   ```bash
   ca-status  # Check CA health
   ca-request-cert test.internal.robcohen.dev  # Test issuance
   ```

4. **Log shipping problems**:
   ```bash
   logs-status  # Check Loki/Promtail
   systemctl restart promtail
   ```

### Emergency Procedures

1. **Complete system rebuild from paper backup**:
   ```bash
   # On air-gapped machine
   ca-init-from-paper  # Same 24 words
   # Transfer new certificates to server
   ```

2. **Restore from encrypted backups**:
   ```bash
   # Mount backup drive
   borg list /mnt/backup-drive/borg-offline
   borg extract /mnt/backup-drive/borg-offline::archive-name
   ```

## 🔍 Backup Validation Automation

The system includes comprehensive automated backup validation that runs quarterly.

### Backup Validation Commands

```bash
# Run manual backup validation
backup-validate

# Test restore from specific backup type
backup-restore-test local "tank/nfs/share"
backup-restore-test offline "tank/nfs/share" 
backup-restore-test cloud "tank/nfs/share"

# Run complete disaster recovery simulation
backup-disaster-simulation
```

### Validation Reports

Backup validation generates detailed JSON reports in `/var/lib/backup-validation/reports/`:

- **Validation status**: Overall PASS/FAIL result
- **Individual test results**: Each backup type and restore test
- **Performance metrics**: Validation duration and resource usage
- **Recommendations**: Automated suggestions for improvement

### Monitoring Integration

Backup validation metrics are automatically exposed to Prometheus:

- `backup_validation_success`: Last validation success (1=pass, 0=fail)
- `backup_validation_last_run`: Timestamp of last validation
- `backup_restore_test_success`: Last restore test result
- `disaster_recovery_simulation_success`: Last disaster recovery test

Critical alerts are automatically generated for:
- Validation failures
- Overdue validations (>91 days)
- Restore test failures
- Disaster recovery simulation failures

## 📊 Performance Monitoring

### Key Metrics to Watch

- **Certificate expiry**: < 30 days warning
- **Backup success rate**: > 95%
- **Backup validation**: Quarterly validation success
- **Log ingestion rate**: Monitor Loki performance
- **System resources**: CPU, memory, disk usage
- **VPN connectivity**: Active Headscale nodes

### Automated Monitoring

The system automatically monitors and alerts on:
- Service failures
- Certificate expiration
- Backup failures
- Security events
- Resource exhaustion
- TPM integrity violations

## 🛡️ Security Checklist

### Pre-Production

- [ ] SOPS secrets configured with real values
- [ ] TPM key sealing enabled
- [ ] All services hardened with systemd security features
- [ ] Firewall rules restrict admin services to VPN only
- [ ] Paper backup of CA mnemonic stored securely
- [ ] Automated testing passes

### Post-Production

- [ ] Monitor security alerts daily
- [ ] Review logs weekly with `logs-security`
- [ ] Test backup restoration quarterly
- [ ] Update intermediate CA every 5 years
- [ ] Review and rotate secrets annually
- [ ] Verify quarterly backup validation reports

## 📈 Scaling Considerations

When scaling beyond personal use:
1. **Geographic redundancy**: Deploy secondary site
2. **Load balancing**: Add HAProxy for service distribution  
3. **External monitoring**: Add external health checks
4. **Compliance**: Implement audit logging and retention
5. **Access control**: Add role-based authentication