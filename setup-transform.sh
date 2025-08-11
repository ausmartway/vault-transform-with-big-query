#!/bin/bash
# Setup Vault Transform Secrets Engine for credit card FPE (Format Preserving Encryption)
# Assumes VAULT_ADDR and VAULT_TOKEN are already set for your HCP Vault cluster

set -e

echo "Enabling Transform secrets engine..."
vault secrets enable transform || echo "Transform engine may already be enabled."

echo "Creating numeric alphabet..."
vault write transform/alphabet/numeric alphabet="0123456789"

echo "Creating credit card template..."
vault write transform/template/creditcard \
  type=regex \
  pattern="(\\d{4})-?(\\d{4})-?(\\d{4})-?(\\d{4})" \
  alphabet=numeric

echo "Creating FPE transformation for credit cards..."
vault write transform/transformation/creditcard-fpe \
  type=fpe \
  template=creditcard \
  tweak_source=internal \
  allowed_roles=creditcard-transform

echo "Creating role for credit card transformation..."
vault write transform/role/creditcard-transform \
  transformations=creditcard-fpe

echo "Vault Transform setup complete."

# Create a policy for credit card transform
echo -e "\nCreating Vault policy for credit card transform..."
cat > creditcard-transform-policy.hcl <<EOF
path "transform/encode/creditcard-transform" {
  capabilities = ["update"]
}
path "transform/decode/creditcard-transform" {
  capabilities = ["update"]
}
EOF
vault policy write creditcard-transform creditcard-transform-policy.hcl

# Generate a token for the creditcard-transform policy with 30-day TTL
echo -e "\nCreating a Vault token for credit card transform usage (30-day TTL)..."
CLIENT_TOKEN=$(vault token create -policy=creditcard-transform -ttl=720h -field=token)
echo "Client token for credit card transform: $CLIENT_TOKEN"

# Test: Encrypt and decrypt a made-up credit card number
echo "\nTesting Vault Transform with a sample credit card number..."
SAMPLE_CC="4111111111111111"

# Encrypt
echo "Encrypting sample credit card number..."
ENCRYPTED=$(vault write -field=encoded_value transform/encode/creditcard-transform value="$SAMPLE_CC")
echo "Encrypted: $ENCRYPTED"

# Decrypt
echo "Decrypting back to plaintext..."
DECRYPTED=$(vault write -field=decoded_value transform/decode/creditcard-transform value="$ENCRYPTED")
echo "Decrypted: $DECRYPTED"

if [ "$DECRYPTED" = "$SAMPLE_CC" ]; then
  echo "Transform test successful: round-trip matches original."
else
  echo "[ERROR] Transform test failed: round-trip does not match original."
  exit 1
fi
