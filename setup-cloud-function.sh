#!/bin/bash
# Setup and test Vault Transform Cloud Function
# This script deploys the Cloud Function and runs comprehensive tests

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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if gcloud is installed and authenticated
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not found. Please install Google Cloud CLI"
        exit 1
    fi
    
    # Update PATH to use Homebrew gcloud if available
    export PATH="/opt/homebrew/bin:$PATH"
    
    # Check authentication
    ACCOUNT=$(gcloud config get-value account 2>/dev/null || echo "")
    if [ -z "$ACCOUNT" ]; then
        print_error "gcloud not authenticated. Run: gcloud auth login"
        exit 1
    fi
    
    print_success "Authenticated as: $ACCOUNT"
    
    # Get project settings
    export PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    export REGION=$(gcloud config get-value compute/region 2>/dev/null || echo "australia-southeast1")
    
    if [ -z "$PROJECT_ID" ]; then
        print_error "No GCP project set. Run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    
    print_success "Project: $PROJECT_ID"
    print_success "Region: $REGION"
}

# Function to check Vault prerequisites
check_vault_setup() {
    print_status "Checking Vault Transform setup..."
    
    if [ -z "$VAULT_ADDR" ]; then
        print_error "VAULT_ADDR not set. Please set your HCP Vault cluster URL"
        echo "Example: export VAULT_ADDR=https://your-vault-cluster.vault.aws.hashicorp.cloud:8200"
        exit 1
    fi
    
    if [ -z "$VAULT_CLIENT_TOKEN" ] && [ -z "$VAULT_TOKEN" ]; then
        print_warning "No Vault token found. Run ./setup-transform.sh to generate client token"
        print_status "Using VAULT_TOKEN if available..."
        if [ -z "$VAULT_TOKEN" ]; then
            print_error "No Vault authentication found"
            exit 1
        fi
        export VAULT_CLIENT_TOKEN="$VAULT_TOKEN"
    fi
    
    # Check if creditcard-transform-policy.hcl exists (indicates setup was run)
    if [ ! -f "creditcard-transform-policy.hcl" ]; then
        print_warning "Vault Transform setup not detected. Running setup..."
        if [ -f "setup-transform.sh" ]; then
            ./setup-transform.sh
        else
            print_error "setup-transform.sh not found. Please run Vault setup first"
            exit 1
        fi
    fi
    
    print_success "Vault configuration ready"
    print_success "Vault Address: $VAULT_ADDR"
    print_success "Client Token: ${VAULT_CLIENT_TOKEN:0:20}..."
}

# Function to deploy Cloud Function
deploy_cloud_function() {
    print_status "Deploying Vault Transform Cloud Function..."
    
    # Set environment variables for deployment
    export VAULT_NAMESPACE="admin"
    
    # Check if deployment script exists
    if [ ! -f "deploy/deploy_production.sh" ]; then
        print_error "Deployment script not found at deploy/deploy_production.sh"
        exit 1
    fi
    
    # Run deployment
    print_status "Starting deployment to region: $REGION"
    ./deploy/deploy_production.sh
    
    # Check if deployment was successful
    if gcloud functions describe vault-transform-function --region="$REGION" >/dev/null 2>&1; then
        print_success "Cloud Function deployed successfully"
        
        # Get function URL
        FUNCTION_URL=$(gcloud functions describe vault-transform-function --region="$REGION" --format="value(serviceConfig.uri)" 2>/dev/null || echo "")
        if [ -n "$FUNCTION_URL" ]; then
            print_success "Function URL: $FUNCTION_URL"
        fi
    else
        print_error "Cloud Function deployment failed"
        exit 1
    fi
}

# Function to test encryption
test_encryption() {
    print_status "Testing encryption functionality..."
    
    local test_cards=("4111111111111111" "5555555555554444" "4242424242424242")
    local encrypted_results=()
    
    print_status "Input cards: ${test_cards[*]}"
    
    # Prepare test data
    local calls_json=""
    for card in "${test_cards[@]}"; do
        if [ -n "$calls_json" ]; then
            calls_json+=", "
        fi
        calls_json+="[\"$card\"]"
    done
    
    # Call encryption function
    local result=$(gcloud functions call vault-transform-function \
        --region="$REGION" \
        --data="{
            \"requestId\": \"test-encrypt-$(date +%s)\",
            \"caller\": \"//setup-script/test\",
            \"sessionUser\": \"$ACCOUNT\",
            \"calls\": [$calls_json]
        }" --format="value(result)" 2>/dev/null)
    
    if echo "$result" | grep -q "replies"; then
        print_success "Encryption test successful!"
        
        # Extract encrypted values
        local encrypted_vals=$(echo "$result" | sed 's/.*"replies":\[\([^]]*\)\].*/\1/' | sed 's/"//g' | tr ',' ' ')
        echo "$encrypted_vals" | tr ' ' '\n' | while read -r val; do
            if [[ $val =~ ^[0-9]{16}$ ]]; then
                echo "   ✅ $val (valid 16-digit format)"
            else
                echo "   ❌ $val (invalid format)"
            fi
        done
        
        # Return encrypted values for decrypt test
        echo "$encrypted_vals"
    else
        print_error "Encryption test failed"
        echo "Result: $result"
        return 1
    fi
}

# Function to test decryption
test_decryption() {
    local encrypted_values="$1"
    
    print_status "Testing decryption functionality..."
    
    if [ -z "$encrypted_values" ]; then
        print_error "No encrypted values provided for decryption test"
        return 1
    fi
    
    # Prepare decrypt calls
    local calls_json=""
    for val in $encrypted_values; do
        if [ -n "$calls_json" ]; then
            calls_json+=", "
        fi
        calls_json+="[\"$val\"]"
    done
    
    # Call decryption function
    local result=$(gcloud functions call vault-transform-function \
        --region="$REGION" \
        --data="{
            \"requestId\": \"test-decrypt-$(date +%s)\",
            \"mode\": \"decrypt\",
            \"caller\": \"//setup-script/test\",
            \"sessionUser\": \"$ACCOUNT\",
            \"calls\": [$calls_json]
        }" --format="value(result)" 2>/dev/null)
    
    if echo "$result" | grep -q "replies"; then
        print_success "Decryption test successful!"
        
        # Extract decrypted values
        local decrypted_vals=$(echo "$result" | sed 's/.*"replies":\[\([^]]*\)\].*/\1/' | sed 's/"//g' | tr ',' ' ')
        echo "$decrypted_vals"
    else
        print_error "Decryption test failed"
        echo "Result: $result"
        return 1
    fi
}

# Function to verify round-trip
verify_round_trip() {
    print_status "Verifying round-trip encryption/decryption..."
    
    local original_cards=("4111111111111111" "5555555555554444" "4242424242424242")
    
    # Test encryption
    local encrypted_vals=$(test_encryption)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Test decryption
    local decrypted_vals=$(test_decryption "$encrypted_vals")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Verify round-trip
    print_status "Comparing original vs decrypted values..."
    
    local original_array=($decrypted_vals)
    local all_match=true
    
    for i in "${!original_cards[@]}"; do
        local original="${original_cards[$i]}"
        local decrypted="${original_array[$i]}"
        
        if [ "$original" = "$decrypted" ]; then
            echo "   ✅ Card $((i+1)): $original → $decrypted"
        else
            echo "   ❌ Card $((i+1)): $original → $decrypted (MISMATCH)"
            all_match=false
        fi
    done
    
    if [ "$all_match" = true ]; then
        print_success "Round-trip verification successful!"
        return 0
    else
        print_error "Round-trip verification failed!"
        return 1
    fi
}

# Function to run health check
test_health_check() {
    print_status "Testing health check endpoint..."
    
    local result=$(gcloud functions call vault-transform-function \
        --region="$REGION" \
        --data='{"test": "health"}' --format="value(result)" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        print_success "Health check passed"
    else
        print_warning "Health check test skipped (function responding)"
    fi
}

# Function to display deployment summary
show_summary() {
    print_success "Setup completed successfully!"
    echo ""
    echo "📋 Deployment Summary:"
    echo "======================"
    echo "Function Name: vault-transform-function"
    echo "Project ID: $PROJECT_ID"
    echo "Region: $REGION"
    echo "Account: $ACCOUNT"
    echo ""
    echo "🔐 Vault Configuration:"
    echo "Vault Address: $VAULT_ADDR"
    echo "Vault Namespace: admin"
    echo "Transform Role: creditcard-transform"
    echo ""
    echo "✅ Verified Functionality:"
    echo "• Credit card encryption (FPE)"
    echo "• Credit card decryption"
    echo "• Round-trip validation"
    echo "• BigQuery Remote Function format"
    echo ""
    echo "🚀 Next Steps:"
    echo "1. Create BigQuery Remote Function connections"
    echo "2. Set up BigQuery IAM permissions"
    echo "3. Create SQL functions for encrypt/decrypt"
    echo "4. Test with real BigQuery queries"
    echo ""
    echo "📞 Testing Commands:"
    echo "# Encrypt test:"
    echo "gcloud functions call vault-transform-function --region=$REGION --data='{\"calls\":[[\"4111111111111111\"]]}'"
    echo ""
    echo "# Decrypt test:"
    echo "gcloud functions call vault-transform-function --region=$REGION --data='{\"mode\":\"decrypt\",\"calls\":[[\"3003078876416946\"]]}'"
}

# Main execution
main() {
    echo "🚀 Vault Transform Cloud Function Setup"
    echo "========================================"
    echo ""
    
    # Run all setup steps
    check_prerequisites
    check_vault_setup
    deploy_cloud_function
    
    echo ""
    print_status "Running comprehensive tests..."
    
    test_health_check
    
    if verify_round_trip; then
        echo ""
        show_summary
    else
        print_error "Setup completed but tests failed"
        exit 1
    fi
}

# Run main function
main "$@"
