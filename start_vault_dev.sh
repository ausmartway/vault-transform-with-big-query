#!/bin/bash

# Script to start local Vault server and test the vault setup
# This script uses Docker Compose to run Vault in development mode

set -e

echo "🚀 Starting local Vault server with Docker Compose..."

# Check if .env file exists with license
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo "Please copy .env.example to .env and add your Vault Enterprise license:"
    echo "  cp .env.example .env"
    echo "  # Edit .env and add your VAULT_LICENSE"
    exit 1
fi

# Check if VAULT_LICENSE is set
if ! grep -q "^VAULT_LICENSE=" .env || grep -q "your-vault-enterprise-license-string-here" .env; then
    echo "❌ VAULT_LICENSE not properly configured in .env file"
    echo "Please edit .env and add your actual Vault Enterprise license"
    exit 1
fi

# Start Vault server
docker compose up -d

# Wait for Vault to be ready
echo "⏳ Waiting for Vault server to be ready..."
sleep 10

# Check if Vault is running
if ! docker compose ps | grep -q "vault-dev.*Up"; then
    echo "❌ Failed to start Vault server"
    docker compose logs vault
    exit 1
fi

echo "✅ Vault server is running!"

# Set environment variables for local testing
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="myroot"

echo "🔧 Environment variables set:"
echo "  VAULT_ADDR=$VAULT_ADDR"
echo "  VAULT_TOKEN=$VAULT_TOKEN"

# Verify Vault is accessible
echo "🔍 Checking Vault status..."
vault status

echo ""
echo "🎯 Vault server is ready for testing!"
echo ""
echo "To test the setup script, run:"
echo "  export VAULT_ADDR=http://localhost:8200"
echo "  export VAULT_TOKEN=myroot"
echo "  ./setup_vault.sh"
echo ""
echo "To stop the Vault server:"
echo "  docker compose down"
echo ""
echo "To view Vault UI:"
echo "  Open http://localhost:8200 in your browser"
echo "  Token: myroot"
