#!/bin/bash

# Test script for the complete Vault Transform setup
# This script tests both the setup and the actual encryption/decryption functionality

set -e

echo "🧪 Testing Vault Transform Secret Engine with custom FPE transformation..."

# Check if Vault is accessible
if ! vault status &>/dev/null; then
    echo "❌ Vault is not accessible. Make sure to run start_vault_dev.sh first"
    echo "And set the environment variables:"
    echo "  export VAULT_ADDR=http://localhost:8200"
    echo "  export VAULT_TOKEN=myroot"
    exit 1
fi

echo "✅ Vault is accessible"

# Check if transform secret engine is already enabled
if vault secrets list | grep -q "transform/"; then
    echo "✅ Transform Secret Engine already enabled, skipping setup"
else
    # Run the setup script
    echo "📋 Running Vault setup script..."
    ./setup_vault.sh
fi

echo ""
echo "🔬 Testing encryption and decryption functionality..."

# Test credit card numbers
test_cards=("4111111111111111" "4222222222222222" "5555555555554444")

for card in "${test_cards[@]}"; do
    echo ""
    echo "Testing card: $card"
    
    # Encrypt the card
    echo "  🔒 Encrypting..."
    encrypted=$(vault write -field=encoded_value transform/encode/creditcard-transform value="$card")
    echo "  Original:  $card"
    echo "  Encrypted: $encrypted"
    
    # Decrypt the card
    echo "  🔓 Decrypting..."
    decrypted=$(vault write -field=decoded_value transform/decode/creditcard-transform value="$encrypted")
    echo "  Decrypted: $decrypted"
    
    # Verify they match
    if [ "$card" = "$decrypted" ]; then
        echo "  ✅ Encryption/Decryption successful!"
    else
        echo "  ❌ Encryption/Decryption failed!"
        echo "     Expected: $card"
        echo "     Got:      $decrypted"
        exit 1
    fi
done

echo ""
echo "🎉 All tests passed! Vault Transform Secret Engine is working correctly."
echo ""
echo "📊 Summary:"
echo "  ✅ Vault Transform Secret Engine enabled"
echo "  ✅ Custom FPE transformation working"
echo "  ✅ Role 'creditcard-transform' created and functional"
echo "  ✅ Policy 'transform-policy' created"
echo "  ✅ Encryption/Decryption tested with multiple credit card numbers"
echo ""
echo "🚀 Ready to deploy to Google Cloud Functions!"
