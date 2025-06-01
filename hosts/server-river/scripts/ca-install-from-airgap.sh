#!/usr/bin/env bash
set -euo pipefail

echo "📦 Installing CA Certificates from Air-Gap Transfer"
echo "================================================="

TRANSFER_DIR="${1:-/tmp/ca-transfer}"

if [ ! -d "$TRANSFER_DIR" ]; then
  echo "❌ Transfer directory not found: $TRANSFER_DIR"
  echo "Usage: $0 [transfer-directory]"
  exit 1
fi

# Verify required files exist
REQUIRED_FILES=(
  "ca.cert.pem"
  "intermediate.cert.pem" 
  "intermediate.key.pem"
  "ca-chain.cert.pem"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$TRANSFER_DIR/$file" ]; then
    echo "❌ Missing required file: $file"
    exit 1
  fi
done

echo "✅ All required files found"

# Stop step-ca if running
systemctl stop step-ca || true

# Install certificates
echo "📋 Installing root CA certificate..."
cp "$TRANSFER_DIR/ca.cert.pem" /etc/step-ca/certs/root_ca.crt
chmod 644 /etc/step-ca/certs/root_ca.crt

echo "📋 Installing intermediate CA certificate..."
cp "$TRANSFER_DIR/intermediate.cert.pem" /etc/step-ca/certs/intermediate_ca.crt
chmod 644 /etc/step-ca/certs/intermediate_ca.crt

echo "🔐 Installing intermediate CA private key..."
cp "$TRANSFER_DIR/intermediate.key.pem" /etc/step-ca/secrets/intermediate_ca_key
chmod 600 /etc/step-ca/secrets/intermediate_ca_key
chown step-ca:step-ca /etc/step-ca/secrets/intermediate_ca_key

echo "🔗 Installing certificate chain..."
cp "$TRANSFER_DIR/ca-chain.cert.pem" /etc/step-ca/certs/ca_chain.crt
chmod 644 /etc/step-ca/certs/ca_chain.crt

# Install CRL if present
if [ -f "$TRANSFER_DIR/intermediate.crl.pem" ]; then
  echo "📜 Installing certificate revocation list..."
  cp "$TRANSFER_DIR/intermediate.crl.pem" /etc/step-ca/certs/intermediate.crl
  chmod 644 /etc/step-ca/certs/intermediate.crl
fi

# Add root CA to system trust store
echo "🛡️  Adding root CA to system trust store..."
cp /etc/step-ca/certs/root_ca.crt /etc/ssl/certs/robcohen-root-ca.crt
update-ca-certificates

# Initialize step-ca database if needed
if [ ! -f /var/lib/step-ca/db/data.mdb ]; then
  echo "🗄️  Initializing step-ca database..."
  chown -R step-ca:step-ca /var/lib/step-ca
fi

# Start step-ca
echo "🚀 Starting step-ca service..."
systemctl start step-ca
systemctl enable step-ca

# Wait for step-ca to start
sleep 3

# Verify step-ca is working
if curl -k https://localhost:9000/health > /dev/null 2>&1; then
  echo "✅ Step-CA is running and healthy"
else
  echo "⚠️  Step-CA may not be fully ready yet"
fi

echo ""
echo "📋 Certificate Summary:"
echo "======================"
echo "Root CA:"
openssl x509 -noout -subject -dates -in /etc/step-ca/certs/root_ca.crt
echo ""
echo "Intermediate CA:"
openssl x509 -noout -subject -dates -in /etc/step-ca/certs/intermediate_ca.crt
echo ""
echo "✅ CA installation complete!"
echo "🔧 Configure services to use internal ACME endpoint: https://localhost:9000/acme/internal-acme/directory"
echo ""
echo "🔒 Optional: Seal CA key to TPM for hardware protection:"
echo "   tpm-seal-ca-key"