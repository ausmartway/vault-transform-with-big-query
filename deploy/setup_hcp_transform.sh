#!/bin/bash
# HCP Vault Transform Secrets Engine Setup Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if required environment variables are set
check_environment() {
    print_status "Checking HCP Vault environment variables..."
    
    if [ -z "$VAULT_ADDR" ]; then
        print_error "VAULT_ADDR environment variable not set"
        echo "Please set: export VAULT_ADDR=https://your-hcp-vault-cluster.vault.aws.hashicorp.cloud:8200"
        exit 1
    fi
    
    if [ -z "$VAULT_TOKEN" ]; then
        print_error "VAULT_TOKEN environment variable not set"
        echo "Please set: export VAULT_TOKEN=your-hcp-admin-token"
        exit 1
    fi
    
    if [ -z "$VAULT_NAMESPACE" ]; then
        print_error "VAULT_NAMESPACE environment variable not set"
        echo "Please set: export VAULT_NAMESPACE=admin"
        echo "HCP Vault requires VAULT_NAMESPACE=admin"
        exit 1
    fi
    
    if [ "$VAULT_NAMESPACE" != "admin" ]; then
        print_error "VAULT_NAMESPACE must be 'admin' for HCP Vault"
        echo "Please set: export VAULT_NAMESPACE=admin"
        exit 1
    fi
    
    # Verify it's not localhost
    if echo "$VAULT_ADDR" | grep -q "localhost\|127.0.0.1\|0.0.0.0"; then
        print_error "VAULT_ADDR appears to be localhost - please use HCP Vault URL"
        exit 1
    fi
    
    print_success "Environment variables validated"
    print_success "HCP Vault: $VAULT_ADDR"
    print_success "HCP Namespace: $VAULT_NAMESPACE"
}

# Test vault connectivity
test_vault_connection() {
    print_status "Testing HCP Vault connection..."
    
    # Check if vault CLI is available
    if ! command -v vault &> /dev/null; then
        print_error "vault CLI not found"
        echo "Install with: brew install vault (macOS) or download from https://releases.hashicorp.com/vault/"
        exit 1
    fi
    
    # Set vault environment
    export VAULT_ADDR
    export VAULT_TOKEN
    export VAULT_NAMESPACE
    
    # Test connection by checking vault status
    if ! vault status &> /dev/null; then
        print_error "Failed to connect to HCP Vault"
        echo "Please check your VAULT_ADDR, VAULT_TOKEN, and VAULT_NAMESPACE"
        echo "Make sure VAULT_NAMESPACE=admin for HCP Vault"
        exit 1
    fi
    
    print_success "Successfully connected to HCP Vault"
}

# Enable Transform secrets engine
enable_transform_engine() {
    print_status "Enabling Transform secrets engine..."
    
    # Check if already enabled
    if vault secrets list | grep -q "transform/"; then
        print_warning "Transform secrets engine already enabled"
    else
        if vault secrets enable transform; then
            print_success "Transform secrets engine enabled"
        else
            print_error "Failed to enable Transform secrets engine"
            echo "Note: Transform engine requires HCP Vault Standard or Plus tier"
            exit 1
        fi
    fi
}

# Create alphabet for credit card numbers
create_alphabet() {
    print_status "Creating alphabet for credit card numbers..."
    
    if vault write transform/alphabet/creditcard-digits \
        alphabet="0123456789"; then
        print_success "Credit card digits alphabet created"
    else
        print_error "Failed to create alphabet"
        exit 1
    fi
}

# Create template for credit card format
create_template() {
    print_status "Creating template for credit card format..."
    
    if vault write transform/template/creditcard-tmpl \
        type=regex \
        pattern='(\d{4})(\d{4})(\d{4})(\d{4})' \
        alphabet="creditcard-digits"; then
        print_success "Credit card template created"
    else
        print_error "Failed to create template"
        exit 1
    fi
}

# Create FPE transformation
create_transformation() {
    print_status "Creating FPE transformation for credit cards..."
    
    if vault write transform/transformation/creditcard-fpe \
        type=fpe \
        template="creditcard-tmpl" \
        tweak_source=internal \
        allowed_roles="creditcard-transform"; then
        print_success "FPE transformation created"
    else
        print_error "Failed to create FPE transformation"
        exit 1
    fi
}

# Create role for the application
create_role() {
    print_status "Creating role for BigQuery Cloud Function..."
    
    if vault write transform/role/creditcard-transform \
        transformations="creditcard-fpe"; then
        print_success "Application role created"
    else
        print_error "Failed to create role"
        exit 1
    fi
}

# Create policy for Cloud Function
create_policy() {
    print_status "Creating policy for Cloud Function access..."
    
    # Create policy file
    cat > /tmp/creditcard-policy.hcl << 'EOF'
# Policy for BigQuery Cloud Function to use Transform engine
path "transform/encode/creditcard-transform" {
  capabilities = ["create", "update"]
}

path "transform/decode/creditcard-transform" {
  capabilities = ["create", "update"]
}

# Allow token self-renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow token lookup for debugging
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF

    if vault policy write creditcard-policy /tmp/creditcard-policy.hcl; then
        print_success "Policy created: creditcard-policy"
        rm -f /tmp/creditcard-policy.hcl
    else
        print_error "Failed to create policy"
        exit 1
    fi
}

# Create service token for Cloud Function
create_service_token() {
    print_status "Creating service token for Cloud Function..."
    
    # Create a renewable token with the policy
    token_output=$(vault token create \
        -policy="creditcard-policy" \
        -period=24h \
        -renewable=true \
        -display-name="bigquery-cloud-function" \
        -format=json)
    
    if [ $? -eq 0 ]; then
        service_token=$(echo "$token_output" | jq -r '.auth.client_token')
        print_success "Service token created"
        echo ""
        print_warning "🔑 SAVE THESE VALUES - you'll need them for the Cloud Function:"
        echo "export VAULT_TOKEN=$service_token"
        echo "export VAULT_NAMESPACE=admin"
        echo ""
        echo "Add these to your .env file:"
        echo "VAULT_TOKEN=$service_token"
        echo "VAULT_NAMESPACE=admin"
        
        # Save to file for convenience
        echo "# Service token for BigQuery Cloud Function" > service_token.txt
        echo "export VAULT_TOKEN=$service_token" >> service_token.txt
        echo "export VAULT_NAMESPACE=admin" >> service_token.txt
        print_success "Token and namespace saved to service_token.txt"
    else
        print_error "Failed to create service token"
        exit 1
    fi
}

# Test the configuration
test_transform_engine() {
    print_status "Testing Transform engine configuration..."
    
    # Test encoding
    print_status "Testing credit card encryption..."
    encode_result=$(vault write -format=json transform/encode/creditcard-transform \
        value="4111111111111111" | jq -r '.data.encoded_value')
    
    if [ -n "$encode_result" ] && [ "$encode_result" != "null" ]; then
        print_success "Encryption test passed: 4111111111111111 → $encode_result"
        
        # Test decoding
        print_status "Testing credit card decryption..."
        decode_result=$(vault write -format=json transform/decode/creditcard-transform \
            value="$encode_result" | jq -r '.data.decoded_value')
        
        if [ "$decode_result" = "4111111111111111" ]; then
            print_success "Decryption test passed: $encode_result → $decode_result"
            print_success "🎉 Transform engine is working correctly!"
        else
            print_error "Decryption test failed"
            exit 1
        fi
    else
        print_error "Encryption test failed"
        exit 1
    fi
}

# Test with service token
test_service_token() {
    if [ -f service_token.txt ]; then
        print_status "Testing service token permissions..."
        
        # Save current token
        original_token="$VAULT_TOKEN"
        
        # Source the service token
        source service_token.txt
        
        # Export environment variables for vault CLI
        export VAULT_ADDR
        export VAULT_TOKEN
        export VAULT_NAMESPACE
        
        # Test with limited permissions
        test_result=$(vault write -format=json transform/encode/creditcard-transform \
            value="5555555555554444" 2>/dev/null | jq -r '.data.encoded_value' || echo "error")
        
        if [ "$test_result" != "error" ] && [ -n "$test_result" ]; then
            print_success "Service token test passed"
            print_success "Cloud Function will be able to use this token"
        else
            print_warning "Service token test failed - check policy permissions"
        fi
        
        # Restore original token
        export VAULT_TOKEN="$original_token"
    else
        print_warning "service_token.txt not found - skipping service token test"
    fi
}

# List configuration for verification
show_configuration() {
    print_status "Showing Transform engine configuration..."
    
    echo ""
    echo "📋 Transform Configuration Summary:"
    echo "=================================="
    
    echo ""
    echo "🔤 Alphabets:"
    vault list transform/alphabet/ || true
    
    echo ""
    echo "📝 Templates:"
    vault list transform/template/ || true
    
    echo ""
    echo "🔄 Transformations:"
    vault list transform/transformation/ || true
    
    echo ""
    echo "👥 Roles:"
    vault list transform/role/ || true
    
    echo ""
    echo "🔐 Policies:"
    vault policy list | grep creditcard || true
}

# Main setup function
main() {
    echo "🔧 HCP Vault Transform Secrets Engine Setup"
    echo "This script will configure the Transform engine for credit card encryption."
    echo ""
    
    check_environment
    test_vault_connection
    enable_transform_engine
    create_alphabet
    create_template
    create_transformation
    create_role
    create_policy
    create_service_token
    test_transform_engine
    test_service_token
    show_configuration
    
    echo ""
    print_success "🎉 HCP Vault Transform engine setup completed!"
    echo ""
    echo "📋 Next steps:"
    echo "  1. Copy the service token to your .env file"
    echo "  2. Run ./setup_prerequisites.sh to validate"
    echo "  3. Deploy with ./deploy_production.sh"
    echo ""
    echo "💡 Important files created:"
    echo "  • service_token.txt - Contains the Cloud Function token"
    echo ""
    echo "🧪 Test commands:"
    echo "  vault write transform/encode/creditcard-transform value=\"4111111111111111\""
    echo "  vault write transform/decode/creditcard-transform value=\"<encoded-value>\""
}

# Handle command line arguments
case "${1:-setup}" in
    setup)
        main
        ;;
    test)
        check_environment
        test_vault_connection
        test_transform_engine
        ;;
    show)
        check_environment
        test_vault_connection
        show_configuration
        ;;
    clean)
        print_warning "This will remove the Transform configuration. Are you sure? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_status "Cleaning up Transform configuration..."
            vault secrets disable transform || true
            vault policy delete creditcard-policy || true
            print_success "Transform configuration removed"
        else
            echo "Cleanup cancelled"
        fi
        ;;
    token)
        check_environment
        test_vault_connection
        create_policy
        create_service_token
        ;;
    *)
        echo "Usage: $0 [setup|test|show|clean|token]"
        echo ""
        echo "Commands:"
        echo "  setup  Complete Transform engine setup (default)"
        echo "  test   Test existing Transform configuration"
        echo "  show   Display current configuration"
        echo "  token  Create new service token only"
        echo "  clean  Remove Transform configuration"
        exit 1
        ;;
esac
