#!/bin/bash

# Vault Transform Secret Engine Setup Script
# This script sets up the Transform Secret Engine in Vault for credit card encryption
# Creates a custom FPE transformation for credit card numbers

set -e

echo "Setting up Vault Transform Secret Engine..."

# 1. Enable the Transform Secret Engine
echo "Enabling Transform Secret Engine..."
if vault secrets list | grep -q "transform/"; then
    echo "Transform Secret Engine already enabled, skipping..."
else
    vault secrets enable transform
fi

# 2. Create the alphabet for numeric characters
echo "Creating numeric alphabet..."
vault write transform/alphabet/numeric alphabet="0123456789"

# 3. Create the template for credit card numbers
echo "Creating credit card template..."
vault write transform/template/creditcard \
  type=regex \
  pattern='(\d{4})-?(\d{4})-?(\d{4})-?(\d{4})' \
  alphabet=numeric

# 4. Create the FPE transformation
echo "Creating FPE transformation..."
vault write transform/transformation/creditcard-fpe \
  type=fpe \
  template=creditcard \
  tweak_source=internal \
  allowed_roles=creditcard-transform

# 5. Create the role using our custom transformation
echo "Creating transform role with custom creditcard-fpe transformation..."
vault write transform/role/creditcard-transform \
  transformations=creditcard-fpe

# 6. Create a policy for the Cloud Function
echo "Creating policy for Cloud Function..."
vault policy write transform-policy transform-policy.hcl

# 7. Create a token with the policy (optional - better to use auth methods in production)
echo "Creating token with transform policy..."
VAULT_TOKEN=$(vault token create -policy=transform-policy -format=json | jq -r '.auth.client_token')

echo "Setup complete!"
echo "Vault token for Cloud Function: $VAULT_TOKEN"
echo ""
echo "IMPORTANT: In production, use Vault auth methods (like GCP auth) instead of static tokens."
echo "Set this token as VAULT_TOKEN environment variable in your Cloud Function."

# Test the setup
echo ""
echo "Testing the setup..."
echo "Testing encryption..."
vault write transform/encode/creditcard-transform value="4111111111111111"

echo ""
echo "If you see an encoded value above, the setup was successful!"
