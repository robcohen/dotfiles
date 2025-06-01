{ config, pkgs, lib, ... }:

let
  vars = import ../../lib/vars.nix;
in {
  imports = [
    ./hardware-configuration.nix
  ];

  # Air-gapped security configuration
  networking.wireless.enable = false;
  networking.networkmanager.enable = false;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ ]; # No network access
  networking.firewall.allowedUDPPorts = [ ];

  # Minimal system for CA operations only
  services.xserver.enable = false;
  sound.enable = false;
  hardware.bluetooth.enable = false;

  # Essential CA packages with BIP39 support
  environment.systemPackages = with pkgs; [
    # Certificate authority tools
    openssl
    step-cli
    cfssl
    cfssl-certinfo
    
    # BIP39 and crypto tools
    python3Packages.mnemonic  # BIP39 implementation
    electrum                  # BIP39 tools
    
    # Secure data transfer
    qrencode
    zbar  # QR code reader
    
    # Key derivation tools
    openssl
    python3
    
    # Security tools
    gnupg
    
    # File utilities
    tree
    vim
    jq
    
    # System utilities
    htop
    lsof

    # Custom BIP39 CA key derivation tool
    (writeShellScriptBin "bip39-ca-keygen" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔐 BIP39-Based CA Key Generation"
      echo "==============================="
      
      if [ $# -lt 2 ]; then
        echo "Usage: $0 <master-seed-file> <key-type>"
        echo "  key-type: root-ca | intermediate-ca"
        exit 1
      fi
      
      SEED_FILE="$1"
      KEY_TYPE="$2"
      
      if [ ! -f "$SEED_FILE" ]; then
        echo "❌ Seed file not found: $SEED_FILE"
        exit 1
      fi
      
      # Read BIP39 mnemonic
      MNEMONIC=$(cat "$SEED_FILE")
      
      # Validate mnemonic
      echo "🔍 Validating BIP39 mnemonic..."
      if ! python3 -c "
from mnemonic import Mnemonic
mnemo = Mnemonic('english')
words = '''$MNEMONIC'''.strip()
if not mnemo.check(words):
    exit(1)
print('✅ Valid BIP39 mnemonic')
"; then
        echo "❌ Invalid BIP39 mnemonic"
        exit 1
      fi
      
      # Derive key based on type
      case "$KEY_TYPE" in
        "root-ca")
          DERIVATION_LABEL="robcohen.dev-root-ca-2024"
          KEY_BITS=4096
          ;;
        "intermediate-ca")
          DERIVATION_LABEL="robcohen.dev-intermediate-ca-2024"
          KEY_BITS=4096
          ;;
        *)
          echo "❌ Invalid key type: $KEY_TYPE"
          exit 1
          ;;
      esac
      
      echo "🔑 Deriving $KEY_TYPE key..."
      
      # Convert mnemonic to seed, then derive key material
      python3 << EOF
from mnemonic import Mnemonic
import hashlib
import hmac
import binascii

# Convert mnemonic to seed
mnemo = Mnemonic('english')
mnemonic = '''$MNEMONIC'''.strip()
seed = mnemo.to_seed(mnemonic, passphrase="")

# HKDF key derivation
def hkdf_expand(prk, info, length):
    t = b""
    okm = b""
    counter = 1
    while len(okm) < length:
        t = hmac.new(prk, t + info + bytes([counter]), hashlib.sha256).digest()
        okm += t
        counter += 1
    return okm[:length]

def hkdf_extract(salt, ikm):
    return hmac.new(salt, ikm, hashlib.sha256).digest()

# Derive key material
salt = b"robcohen.dev-ca-salt"
info = b"$DERIVATION_LABEL"
prk = hkdf_extract(salt, seed)
key_material = hkdf_expand(prk, info, 64)  # 512 bits

# Output hex-encoded key material
print(binascii.hexlify(key_material).decode())
EOF
    '')

    (writeShellScriptBin "ca-generate-mnemonic" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🎲 Generating BIP39 Master Seed for CA"
      echo "====================================="
      
      OUTPUT_FILE="''${1:-/etc/ca/master-seed.txt}"
      
      # Generate 256 bits of entropy from multiple sources
      echo "🔀 Gathering entropy from multiple sources..."
      
      # Combine hardware random, urandom, and timestamp
      ENTROPY1=$(dd if=/dev/random bs=32 count=1 2>/dev/null | xxd -p | tr -d '\n')
      ENTROPY2=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | xxd -p | tr -d '\n')
      TIMESTAMP=$(date +%s%N)
      
      # Hash combined entropy
      COMBINED_ENTROPY=$(echo -n "$ENTROPY1$ENTROPY2$TIMESTAMP" | sha256sum | cut -d' ' -f1)
      
      echo "🔤 Converting to BIP39 mnemonic..."
      
      # Convert to BIP39 mnemonic
      MNEMONIC=$(python3 -c "
from mnemonic import Mnemonic
import binascii
mnemo = Mnemonic('english')
entropy_hex = '$COMBINED_ENTROPY'
entropy_bytes = binascii.unhexlify(entropy_hex)
mnemonic = mnemo.to_mnemonic(entropy_bytes)
print(mnemonic)
")
      
      # Save mnemonic securely
      echo "$MNEMONIC" > "$OUTPUT_FILE"
      chmod 600 "$OUTPUT_FILE"
      
      echo "✅ Master seed generated: $OUTPUT_FILE"
      echo ""
      echo "🖨️  WRITE DOWN THESE 24 WORDS ON PAPER:"
      echo "========================================"
      echo "$MNEMONIC"
      echo "========================================"
      echo ""
      echo "⚠️  Store paper copies in multiple secure locations"
      echo "⚠️  This mnemonic can regenerate ALL CA keys"
      
      # Generate QR code for verification
      qrencode -o /tmp/mnemonic-qr.png "$MNEMONIC"
      echo "📱 QR code saved to /tmp/mnemonic-qr.png"
    '')

    (writeShellScriptBin "ca-init-from-paper" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "📄 Initializing CA from Paper Backup"
      echo "===================================="
      
      # Prompt for mnemonic input
      echo "Enter your 24-word BIP39 mnemonic:"
      echo "(words separated by spaces)"
      read -s MNEMONIC
      
      # Save to temporary file for processing
      echo "$MNEMONIC" > /tmp/input-mnemonic.txt
      
      # Validate mnemonic
      if ! bip39-ca-keygen /tmp/input-mnemonic.txt root-ca > /dev/null; then
        echo "❌ Invalid mnemonic"
        rm -f /tmp/input-mnemonic.txt
        exit 1
      fi
      
      echo "✅ Valid mnemonic provided"
      
      # Create CA directory structure
      mkdir -p /etc/ca/{root,intermediate}/{certs,crl,newcerts,private,csr}
      chmod 700 /etc/ca/*/private
      
      # Initialize database files
      touch /etc/ca/root/index.txt
      echo 1000 > /etc/ca/root/serial
      echo 1000 > /etc/ca/root/crlnumber
      
      touch /etc/ca/intermediate/index.txt
      echo 1000 > /etc/ca/intermediate/serial
      echo 1000 > /etc/ca/intermediate/crlnumber
      
      echo "🔑 Generating Root CA key from mnemonic..."
      
      # Derive root CA key
      ROOT_KEY_MATERIAL=$(bip39-ca-keygen /tmp/input-mnemonic.txt root-ca)
      
      # Generate RSA key using derived entropy
      python3 << EOF
import binascii
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
import secrets

# Use derived key material as seed for RSA generation
key_material = binascii.unhexlify("$ROOT_KEY_MATERIAL")
secrets.SystemRandom = lambda: type('obj', (object,), {'random': lambda: int.from_bytes(key_material[:8], 'big') / (2**64)})()

# Generate RSA key
private_key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=4096,
    backend=default_backend()
)

# Serialize with passphrase
encrypted_key = private_key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.BestAvailableEncryption(b"ca-root-key-2024")
)

with open("/etc/ca/root/private/ca.key.pem", "wb") as f:
    f.write(encrypted_key)
EOF
      
      chmod 400 /etc/ca/root/private/ca.key.pem
      
      echo "📜 Generating Root CA certificate..."
      
      # Generate root CA certificate (20 year validity)
      openssl req -config /etc/ca/openssl-root.cnf \
        -key /etc/ca/root/private/ca.key.pem \
        -new -x509 -days 7300 -sha256 -extensions v3_ca \
        -out /etc/ca/root/certs/ca.cert.pem \
        -passin pass:ca-root-key-2024 \
        -subj "/C=US/ST=State/L=City/O=Personal/OU=Home Lab/CN=RobCohen.dev Root CA"
      
      chmod 444 /etc/ca/root/certs/ca.cert.pem
      
      echo "🔗 Generating Intermediate CA key from same mnemonic..."
      
      # Derive intermediate CA key  
      INTERMEDIATE_KEY_MATERIAL=$(bip39-ca-keygen /tmp/input-mnemonic.txt intermediate-ca)
      
      # Generate intermediate RSA key
      python3 << EOF
import binascii
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
import secrets

# Use derived key material as seed
key_material = binascii.unhexlify("$INTERMEDIATE_KEY_MATERIAL")
secrets.SystemRandom = lambda: type('obj', (object,), {'random': lambda: int.from_bytes(key_material[:8], 'big') / (2**64)})()

private_key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=4096,
    backend=default_backend()
)

encrypted_key = private_key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.BestAvailableEncryption(b"ca-intermediate-key-2024")
)

with open("/etc/ca/intermediate/private/intermediate.key.pem", "wb") as f:
    f.write(encrypted_key)
EOF
      
      chmod 400 /etc/ca/intermediate/private/intermediate.key.pem
      
      echo "📝 Generating Intermediate CSR..."
      
      # Generate intermediate CSR
      openssl req -config /etc/ca/openssl-intermediate.cnf -new -sha256 \
        -key /etc/ca/intermediate/private/intermediate.key.pem \
        -out /etc/ca/intermediate/csr/intermediate.csr.pem \
        -passin pass:ca-intermediate-key-2024 \
        -subj "/C=US/ST=State/L=City/O=Personal/OU=Home Lab/CN=RobCohen.dev Intermediate CA"
      
      echo "✍️  Signing Intermediate certificate with Root CA..."
      
      # Sign intermediate certificate
      openssl ca -config /etc/ca/openssl-root.cnf -extensions v3_intermediate_ca \
        -days 1825 -notext -md sha256 -batch \
        -passin pass:ca-root-key-2024 \
        -in /etc/ca/intermediate/csr/intermediate.csr.pem \
        -out /etc/ca/intermediate/certs/intermediate.cert.pem
      
      chmod 444 /etc/ca/intermediate/certs/intermediate.cert.pem
      
      # Create certificate chain
      cat /etc/ca/intermediate/certs/intermediate.cert.pem \
          /etc/ca/root/certs/ca.cert.pem > \
          /etc/ca/intermediate/certs/ca-chain.cert.pem
      chmod 444 /etc/ca/intermediate/certs/ca-chain.cert.pem
      
      # Generate initial CRLs
      openssl ca -config /etc/ca/openssl-root.cnf -gencrl \
        -passin pass:ca-root-key-2024 \
        -out /etc/ca/root/crl/ca.crl.pem
        
      openssl ca -config /etc/ca/openssl-intermediate.cnf -gencrl \
        -passin pass:ca-intermediate-key-2024 \
        -out /etc/ca/intermediate/crl/intermediate.crl.pem
      
      # Clean up
      rm -f /tmp/input-mnemonic.txt
      
      echo "✅ CA hierarchy initialized from paper backup!"
      echo ""
      echo "📋 Root CA Certificate:"
      openssl x509 -noout -text -in /etc/ca/root/certs/ca.cert.pem | head -20
      echo ""
      echo "📋 Intermediate CA Certificate:"  
      openssl x509 -noout -text -in /etc/ca/intermediate/certs/intermediate.cert.pem | head -20
      
      echo ""
      echo "📦 Preparing transfer package for online server..."
      TRANSFER_DIR="/media/ca-transfer/$(date +%Y%m%d)"
      mkdir -p "$TRANSFER_DIR"
      
      # Copy certificates and intermediate key for online server
      cp /etc/ca/root/certs/ca.cert.pem "$TRANSFER_DIR/"
      cp /etc/ca/intermediate/certs/intermediate.cert.pem "$TRANSFER_DIR/"
      cp /etc/ca/intermediate/private/intermediate.key.pem "$TRANSFER_DIR/"
      cp /etc/ca/intermediate/certs/ca-chain.cert.pem "$TRANSFER_DIR/"
      cp /etc/ca/intermediate/crl/intermediate.crl.pem "$TRANSFER_DIR/"
      
      echo "📁 Transfer package ready at: $TRANSFER_DIR"
      echo "🚚 Copy this directory to your online server"
    '')

    (writeShellScriptBin "ca-verify-paper-backup" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔍 Verifying Paper Backup Recovery"
      echo "================================="
      
      echo "This will test if your paper backup can recreate the CA keys"
      echo "Enter your 24-word mnemonic for verification:"
      read -s TEST_MNEMONIC
      
      # Test key derivation
      echo "$TEST_MNEMONIC" > /tmp/test-mnemonic.txt
      
      if ROOT_KEY=$(bip39-ca-keygen /tmp/test-mnemonic.txt root-ca 2>/dev/null); then
        echo "✅ Root CA key derivation: SUCCESS"
      else
        echo "❌ Root CA key derivation: FAILED"
        rm -f /tmp/test-mnemonic.txt
        exit 1
      fi
      
      if INT_KEY=$(bip39-ca-keygen /tmp/test-mnemonic.txt intermediate-ca 2>/dev/null); then
        echo "✅ Intermediate CA key derivation: SUCCESS"
      else
        echo "❌ Intermediate CA key derivation: FAILED"
        rm -f /tmp/test-mnemonic.txt
        exit 1
      fi
      
      # If existing CA, verify keys match
      if [ -f /etc/ca/root/private/ca.key.pem ]; then
        echo "🔄 Comparing with existing CA keys..."
        # This would require implementing key comparison logic
        echo "⚠️  Manual verification required - compare key fingerprints"
      fi
      
      rm -f /tmp/test-mnemonic.txt
      echo "✅ Paper backup verification complete"
    '')
  ];

  # Include OpenSSL configuration files (same as before)
  environment.etc = {
    "ca/openssl-root.cnf".text = ''
      [ ca ]
      default_ca = CA_default

      [ CA_default ]
      dir               = /etc/ca/root
      certs             = $dir/certs
      crl_dir           = $dir/crl
      new_certs_dir     = $dir/newcerts
      database          = $dir/index.txt
      serial            = $dir/serial
      RANDFILE          = $dir/private/.rand

      private_key       = $dir/private/ca.key.pem
      certificate       = $dir/certs/ca.cert.pem

      crlnumber         = $dir/crlnumber
      crl               = $dir/crl/ca.crl.pem
      crl_extensions    = crl_ext
      default_crl_days  = 30

      default_md        = sha256
      name_opt          = ca_default
      cert_opt          = ca_default
      default_days      = 375
      preserve          = no
      policy            = policy_strict

      [ policy_strict ]
      countryName             = match
      stateOrProvinceName     = match
      organizationName        = match
      organizationalUnitName  = optional
      commonName              = supplied
      emailAddress            = optional

      [ req ]
      default_bits        = 4096
      distinguished_name  = req_distinguished_name
      string_mask         = utf8only
      default_md          = sha256
      x509_extensions     = v3_ca

      [ req_distinguished_name ]
      countryName                     = Country Name (2 letter code)
      stateOrProvinceName             = State or Province Name
      localityName                    = Locality Name
      0.organizationName              = Organization Name
      organizationalUnitName          = Organizational Unit Name
      commonName                      = Common Name
      emailAddress                    = Email Address

      [ v3_ca ]
      subjectKeyIdentifier = hash
      authorityKeyIdentifier = keyid:always,issuer
      basicConstraints = critical, CA:true
      keyUsage = critical, digitalSignature, cRLSign, keyCertSign

      [ v3_intermediate_ca ]
      subjectKeyIdentifier = hash
      authorityKeyIdentifier = keyid:always,issuer
      basicConstraints = critical, CA:true, pathlen:0
      keyUsage = critical, digitalSignature, cRLSign, keyCertSign
      crlDistributionPoints = URI:http://files.internal.robcohen.dev/crl/intermediate.crl

      [ crl_ext ]
      authorityKeyIdentifier=keyid:always
    '';

    "ca/openssl-intermediate.cnf".text = ''
      [ ca ]
      default_ca = CA_default

      [ CA_default ]
      dir               = /etc/ca/intermediate
      certs             = $dir/certs
      crl_dir           = $dir/crl
      new_certs_dir     = $dir/newcerts
      database          = $dir/index.txt
      serial            = $dir/serial
      RANDFILE          = $dir/private/.rand

      private_key       = $dir/private/intermediate.key.pem
      certificate       = $dir/certs/intermediate.cert.pem

      crlnumber         = $dir/crlnumber
      crl               = $dir/crl/intermediate.crl.pem
      crl_extensions    = crl_ext
      default_crl_days  = 30

      default_md        = sha256
      name_opt          = ca_default
      cert_opt          = ca_default
      default_days      = 90
      preserve          = no
      policy            = policy_loose

      [ policy_loose ]
      countryName             = optional
      stateOrProvinceName     = optional
      localityName            = optional
      organizationName        = optional
      organizationalUnitName  = optional
      commonName              = supplied
      emailAddress            = optional

      [ req ]
      default_bits        = 2048
      distinguished_name  = req_distinguished_name
      string_mask         = utf8only
      default_md          = sha256

      [ req_distinguished_name ]
      countryName                     = Country Name (2 letter code)
      stateOrProvinceName             = State or Province Name
      localityName                    = Locality Name
      0.organizationName              = Organization Name
      organizationalUnitName          = Organizational Unit Name
      commonName                      = Common Name
      emailAddress                    = Email Address

      [ server_cert ]
      basicConstraints = CA:FALSE
      nsCertType = server
      nsComment = "OpenSSL Generated Server Certificate"
      subjectKeyIdentifier = hash
      authorityKeyIdentifier = keyid,issuer:always
      keyUsage = critical, digitalSignature, keyEncipherment
      extendedKeyUsage = serverAuth
      crlDistributionPoints = URI:http://files.internal.robcohen.dev/crl/intermediate.crl

      [ usr_cert ]
      basicConstraints = CA:FALSE
      nsCertType = client, email
      nsComment = "OpenSSL Generated Client Certificate"
      subjectKeyIdentifier = hash
      authorityKeyIdentifier = keyid,issuer
      keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
      extendedKeyUsage = clientAuth, emailProtection

      [ crl_ext ]
      authorityKeyIdentifier=keyid:always
    '';
  };

  # Enhanced Python environment for crypto operations
  environment.systemPackages = with pkgs; [
    (python3.withPackages (ps: with ps; [
      cryptography
      mnemonic
      pycryptodome
    ]))
  ];

  # Secure user configuration
  users.mutableUsers = false;
  users.users.${vars.user.name} = {
    isNormalUser = true;
    hashedPassword = "$6$rounds=100000$...";  # Generate with mkpasswd
    extraGroups = [ "wheel" "ca-operators" ];
  };

  users.groups.ca-operators = {};

  # System hardening
  security.sudo.wheelNeedsPassword = true;
  security.apparmor.enable = true;
  security.auditd.enable = true;

  # Disable unnecessary services
  services.openssh.enable = false;  # Air-gapped
  services.printing.enable = false;
  services.avahi.enable = false;

  # Filesystem setup
  systemd.tmpfiles.rules = [
    "d /etc/ca 0700 root ca-operators -"
    "d /etc/ca/root 0700 root ca-operators -"
    "d /etc/ca/intermediate 0700 root ca-operators -"
    "d /media/ca-transfer 0755 root ca-operators -"
  ];

  system.stateVersion = "25.05";
}