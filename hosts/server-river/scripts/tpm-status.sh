#!/usr/bin/env bash
set -euo pipefail

echo "🔍 TPM 2.0 Status"
echo "================="

# Check TPM device
if [ -c /dev/tpm0 ]; then
  echo "✅ TPM device found: /dev/tpm0"
else
  echo "❌ TPM device not found"
fi

if [ -c /dev/tpmrm0 ]; then
  echo "✅ TPM resource manager found: /dev/tpmrm0"
else
  echo "❌ TPM resource manager not found"
fi

# Check TPM services
echo ""
echo "📊 TPM Services:"
systemctl status tpm2-abrmd --no-pager -l || true

# Check PCR values
echo ""
echo "📊 Current PCR Values:"
tpm2_pcrread sha256:0,1,2,3,4,5,6,7 2>/dev/null || echo "Failed to read PCRs"

# Check sealed key status
echo ""
echo "🔐 Sealed CA Key Status:"
if [ -f /var/lib/step-ca/tpm/ca-key.ctx ]; then
  echo "✅ CA key sealed in TPM"
  echo "📅 Sealed: $(stat -c %y /var/lib/step-ca/tpm/ca-key.ctx)"
else
  echo "❌ CA key not sealed in TPM"
fi

# Check unsealed key status
if [ -f /run/credentials/step-ca/ca-key ]; then
  echo "✅ CA key currently unsealed"
  echo "📅 Unsealed: $(stat -c %y /run/credentials/step-ca/ca-key)"
else
  echo "⏸️  CA key not currently unsealed"
fi