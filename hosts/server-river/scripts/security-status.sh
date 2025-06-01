#!/usr/bin/env bash
set -euo pipefail

echo "🛡️  Security Status Report"
echo "========================="

# Check SOPS secrets
echo "📝 SOPS Secrets:"
if [ -f /var/lib/sops-nix/key.txt ]; then
  echo "✅ Age key present"
  echo "📊 Accessible secrets:"
  ls -la /run/secrets/ 2>/dev/null || echo "No secrets decrypted yet"
else
  echo "❌ Age key missing - run sops-setup"
fi

echo ""
echo "🔒 Service Security Status:"

# Check service hardening
SERVICES=("step-ca" "grafana" "prometheus" "ntfy-sh" "headscale")
for service in "${SERVICES[@]}"; do
  if systemctl is-active "$service" >/dev/null 2>&1; then
    echo "✅ $service: Active"
    # Check if service has security features enabled
    if systemctl show "$service" -p NoNewPrivileges | grep -q "yes"; then
      echo "  🛡️  Security hardened"
    else
      echo "  ⚠️  Not hardened"
    fi
  else
    echo "❌ $service: Inactive"
  fi
done

echo ""
echo "🔍 Certificate Status:"

# Check certificate expiry
CERT_PATHS=(
  "/etc/step-ca/certs/intermediate_ca.crt"
  "/var/lib/acme/sync.robcohen.dev/cert.pem"
)

for cert in "${CERT_PATHS[@]}"; do
  if [ -f "$cert" ]; then
    EXPIRY=$(openssl x509 -noout -enddate -in "$cert" | cut -d= -f2)
    DAYS_LEFT=$(( ($(date -d "$EXPIRY" +%s) - $(date +%s)) / 86400 ))
    
    if [ $DAYS_LEFT -gt 30 ]; then
      echo "✅ $(basename "$cert"): $DAYS_LEFT days left"
    elif [ $DAYS_LEFT -gt 7 ]; then
      echo "⚠️  $(basename "$cert"): $DAYS_LEFT days left"
    else
      echo "🚨 $(basename "$cert"): $DAYS_LEFT days left - URGENT"
    fi
  fi
done

echo ""
echo "📊 TPM Status:"
tpm-status 2>/dev/null || echo "TPM status unavailable"