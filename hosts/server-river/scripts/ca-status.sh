#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Certificate Authority Status"
echo "=============================="

# Check step-ca service
echo "📊 Step-CA Service:"
systemctl status step-ca --no-pager -l || true
echo ""

# Check step-ca health
echo "🏥 Step-CA Health:"
if curl -k https://localhost:9000/health 2>/dev/null; then
  echo "✅ Step-CA responding"
else
  echo "❌ Step-CA not responding"
fi
echo ""

# Show certificate details
if [ -f /etc/step-ca/certs/root_ca.crt ]; then
  echo "📋 Root CA Certificate:"
  openssl x509 -noout -subject -dates -fingerprint -in /etc/step-ca/certs/root_ca.crt
  echo ""
fi

if [ -f /etc/step-ca/certs/intermediate_ca.crt ]; then
  echo "📋 Intermediate CA Certificate:"
  openssl x509 -noout -subject -dates -fingerprint -in /etc/step-ca/certs/intermediate_ca.crt
  echo ""
fi

# Check system trust store
echo "🛡️  System Trust Store:"
if [ -f /etc/ssl/certs/robcohen-root-ca.crt ]; then
  echo "✅ Root CA installed in system trust store"
else
  echo "❌ Root CA not found in system trust store"
fi

# List issued certificates
echo ""
echo "📜 Recently Issued Certificates:"
find /var/lib/step-ca -name "*.crt" -mtime -30 2>/dev/null | head -10 || echo "None found"