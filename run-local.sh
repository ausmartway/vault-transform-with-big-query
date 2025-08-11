#!/bin/bash
# Local development script for testing the Vault Transform Cloud Function
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Check if we have the client token from setup-transform.sh
if [ ! -f "creditcard-transform-policy.hcl" ]; then
    print_warning "No policy file found. Run ./setup-transform.sh first to generate client token"
    exit 1
fi

# Source environment variables
if [ -f ".env" ]; then
    print_status "Loading environment variables from .env"
    source .env
else
    print_warning "No .env file found. Make sure VAULT_ADDR and VAULT_CLIENT_TOKEN are set"
fi

# Set client token if we have it from the recent setup-transform.sh run
if [ -z "$VAULT_CLIENT_TOKEN" ] && [ -n "$CLIENT_TOKEN" ]; then
    export VAULT_CLIENT_TOKEN="$CLIENT_TOKEN"
    print_status "Using CLIENT_TOKEN from setup-transform.sh output"
fi

# Validate required environment variables
if [ -z "$VAULT_ADDR" ]; then
    print_warning "VAULT_ADDR not set. Using default from setup script"
    # Try to extract from recent terminal output if available
fi

if [ -z "$VAULT_CLIENT_TOKEN" ] && [ -z "$VAULT_TOKEN" ]; then
    print_warning "Neither VAULT_CLIENT_TOKEN nor VAULT_TOKEN is set"
    echo "Run: ./setup-transform.sh to generate a client token"
    exit 1
fi

print_status "Starting Cloud Function locally for testing..."

# Navigate to source directory
cd src

# Install dependencies if needed
if [ ! -d ".venv" ]; then
    print_status "Creating virtual environment..."
    python3 -m venv .venv
fi

source .venv/bin/activate
pip install -r requirements.txt

print_success "Dependencies installed"

# Start the function locally
print_status "Starting Functions Framework on http://localhost:8080"
print_status "Environment:"
echo "  VAULT_ADDR: ${VAULT_ADDR}"
echo "  VAULT_CLIENT_TOKEN: ${VAULT_CLIENT_TOKEN:0:20}..." # Show first 20 chars
echo "  VAULT_NAMESPACE: ${VAULT_NAMESPACE:-admin}"

# Start the function
functions-framework --target=vault_transform_bigquery --port=8080 --debug
