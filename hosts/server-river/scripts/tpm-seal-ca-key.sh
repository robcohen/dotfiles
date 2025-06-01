#!/usr/bin/env bash
set -euo pipefail

echo "🔒 Sealing Intermediate CA Key to TPM"
echo "===================================="

CA_KEY_FILE="/etc/step-ca/secrets/intermediate_ca_key"
TPM_DIR="/var/lib/step-ca/tpm"

if [ ! -f "$CA_KEY_FILE" ]; then
  echo "❌ CA key file not found: $CA_KEY_FILE"
  echo "Run ca-install-from-airgap first"
  exit 1
fi

echo "📊 Reading current PCR values..."
tpm2_pcrread sha256:0,1,2,3,4,5,6,7 > "$TPM_DIR/pcr.values"

echo "📋 Creating PCR policy..."
tpm2_createpolicy --policy-pcr -l sha256:0,1,2,3,4,5,6,7 \
  -f "$TPM_DIR/pcr.values" -L "$TPM_DIR/pcr.policy"

echo "🔑 Creating TPM primary key..."
tpm2_createprimary -C o -g sha256 -G rsa \
  -c "$TPM_DIR/primary.ctx"

echo "🔐 Sealing CA key to TPM..."
tpm2_create -g sha256 -G keyedhash \
  -u "$TPM_DIR/ca-key.pub" \
  -r "$TPM_DIR/ca-key.priv" \
  -C "$TPM_DIR/primary.ctx" \
  -L "$TPM_DIR/pcr.policy" \
  -i "$CA_KEY_FILE"

echo "📦 Loading sealed key context..."
tpm2_load -C "$TPM_DIR/primary.ctx" \
  -u "$TPM_DIR/ca-key.pub" \
  -r "$TPM_DIR/ca-key.priv" \
  -c "$TPM_DIR/ca-key.ctx"

# Set proper ownership
chown -R step-ca:step-ca "$TPM_DIR"
chmod 600 "$TPM_DIR"/*

echo "✅ CA key sealed to TPM successfully!"
echo "🔒 Key will only unseal on this hardware with current boot state"
echo "📋 PCR values bound to key:"
tpm2_pcrread sha256:0,1,2,3,4,5,6,7