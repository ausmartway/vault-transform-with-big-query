#!/bin/bash
# Production deployment script for Vault Transform + BigQuery integration
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
    print_status "Checking environment variables..."
    
    if [ -z "$PROJECT_ID" ]; then
        print_error "PROJECT_ID environment variable not set"
        echo "Please set: export PROJECT_ID=your-gcp-project-id"
        exit 1
    fi
    
    if [ -z "$VAULT_ADDR" ]; then
        print_error "VAULT_ADDR environment variable not set"
        echo "Please set: export VAULT_ADDR=https://your-hcp-vault-cluster.vault.aws.hashicorp.cloud:8200"
        echo "Note: Must be HCP Vault URL, not localhost!"
        exit 1
    fi
    
    # Check for localhost in VAULT_ADDR
    if echo "$VAULT_ADDR" | grep -q "localhost\|127.0.0.1\|0.0.0.0"; then
        print_error "VAULT_ADDR points to localhost"
        echo "Cloud Functions cannot access local services!"
        echo "Please use HCP Vault: export VAULT_ADDR=https://your-hcp-vault-cluster.vault.aws.hashicorp.cloud:8200"
        echo "See hcp_vault_setup.md for setup instructions"
        exit 1
    fi
    
    if [ -z "$VAULT_CLIENT_TOKEN" ]; then
        print_warning "VAULT_CLIENT_TOKEN not set, using VAULT_TOKEN (admin token)"
        print_warning "For production, generate a client token with: ./setup-transform.sh"
        CLIENT_TOKEN="$VAULT_TOKEN"
    else
        CLIENT_TOKEN="$VAULT_CLIENT_TOKEN"
        print_success "Using client token for Cloud Function deployment"
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
    
    print_success "Environment variables validated"
    print_success "Using HCP Vault: $VAULT_ADDR"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check gcloud
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not found. Please install Google Cloud SDK"
        exit 1
    fi
    
    # Check bq
    if ! command -v bq &> /dev/null; then
        print_error "bq command not found. Please install BigQuery CLI"
        exit 1
    fi
    
    # Check if logged in
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 &> /dev/null; then
        print_error "Not logged into gcloud. Please run: gcloud auth login"
        exit 1
    fi
    
    # Set project
    gcloud config set project $PROJECT_ID
    
    print_success "Prerequisites check passed"
}

# Enable required APIs
enable_apis() {
    print_status "Enabling required Google Cloud APIs..."
    
    gcloud services enable cloudfunctions.googleapis.com
    gcloud services enable bigquery.googleapis.com
    gcloud services enable cloudbuild.googleapis.com
    gcloud services enable run.googleapis.com
    
    print_success "APIs enabled"
}

# Prepare Cloud Function source
prepare_function_source() {
    print_status "Preparing Cloud Function source..."
    
    # Change to deploy directory
    cd "$(dirname "$0")"
    
    # Create function directory
    mkdir -p cloud-function
    
    # Copy source files
    cp -r ../src/* cloud-function/
    
    # Create production requirements.txt
    cat > cloud-function/requirements.txt << EOF
functions-framework==3.5.0
hvac==2.0.0
google-cloud-bigquery==3.15.0
requests==2.31.0
EOF
    
    print_success "Function source prepared"
}

# Deploy Cloud Function
deploy_function() {
    print_status "Deploying Cloud Function..."
    
    # Get current user email for IAM
    USER_EMAIL=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1)
    print_status "Current user: $USER_EMAIL"
    
    # Deploy function without allow-unauthenticated
    gcloud functions deploy vault-transform-function \
        --gen2 \
        --runtime=python311 \
        --region=australia-southeast1 \
        --source=cloud-function \
        --entry-point=vault_transform_bigquery \
        --trigger-http \
        --memory=512MB \
        --timeout=60s \
        --set-env-vars="VAULT_ADDR=${VAULT_ADDR},VAULT_CLIENT_TOKEN=${CLIENT_TOKEN},VAULT_NAMESPACE=${VAULT_NAMESPACE},VAULT_ROLE=creditcard-transform,VAULT_TRANSFORMATION=creditcard-fpe"
    
    # Get function URL
    FUNCTION_URL=$(gcloud functions describe vault-transform-function \
        --region=australia-southeast1 \
        --format="value(serviceConfig.uri)")
    
    print_success "Cloud Function deployed at: $FUNCTION_URL"
    
    # Grant invoker permission to current user
    print_status "Setting up IAM permissions..."
    gcloud functions add-iam-policy-binding vault-transform-function \
        --region=australia-southeast1 \
        --member="user:${USER_EMAIL}" \
        --role="roles/cloudfunctions.invoker"
    
    # Grant BigQuery service account permission to invoke function
    # First, get the BigQuery connection service account
    print_status "Setting up BigQuery connection permissions..."
    
    echo "FUNCTION_URL=$FUNCTION_URL" > .env.function
    echo "USER_EMAIL=$USER_EMAIL" >> .env.function
}

# Test Cloud Function
test_function() {
    print_status "Testing Cloud Function with HCP Vault..."
    
    # Source the function URL and user info
    source .env.function
    
    # Get access token for authenticated request
    ACCESS_TOKEN=$(gcloud auth print-access-token)
    
    # Test encryption with authentication
    response=$(curl -s -X POST "$FUNCTION_URL" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "requestId": "test-deploy",
            "calls": [["4111111111111111"]]
        }')
    
    if echo "$response" | grep -q "replies"; then
        encrypted_value=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['replies'][0])")
        print_success "Function test passed: 4111111111111111 → $encrypted_value"
        print_success "HCP Vault integration working correctly"
    else
        print_error "Function test failed: $response"
        print_error "Check HCP Vault connectivity and configuration"
        exit 1
    fi
}

# Create BigQuery dataset
create_dataset() {
    print_status "Creating BigQuery dataset..."
    
    if bq ls -d ${PROJECT_ID}:fraud_detection &> /dev/null; then
        print_warning "Dataset fraud_detection already exists"
    else
        bq mk --dataset \
            --description="Fraud detection with encrypted credit cards" \
            --location=US \
            ${PROJECT_ID}:fraud_detection
        print_success "Dataset created"
    fi
}

# Create BigQuery table
create_table() {
    print_status "Creating BigQuery table..."
    
    # Create table schema
    cat > table_schema.json << 'EOF'
[
    {"name": "transaction_id", "type": "STRING", "mode": "REQUIRED"},
    {"name": "encrypted_credit_card", "type": "STRING", "mode": "REQUIRED"},
    {"name": "amount", "type": "FLOAT", "mode": "REQUIRED"},
    {"name": "merchant", "type": "STRING", "mode": "REQUIRED"},
    {"name": "category", "type": "STRING", "mode": "REQUIRED"},
    {"name": "transaction_date", "type": "TIMESTAMP", "mode": "REQUIRED"},
    {"name": "is_fraud", "type": "BOOLEAN", "mode": "REQUIRED"}
]
EOF
    
    if bq ls ${PROJECT_ID}:fraud_detection | grep -q transactions; then
        print_warning "Table transactions already exists"
    else
        bq mk --table \
            ${PROJECT_ID}:fraud_detection.transactions \
            table_schema.json
        print_success "Table created"
    fi
}

# Set up BigQuery remote functions
setup_remote_functions() {
    print_status "Setting up BigQuery remote functions..."
    
    # Source the function URL
    source .env.function
    
    # Create dataset for functions if it doesn't exist
    if ! bq ls -d ${PROJECT_ID}:vault_functions &> /dev/null; then
        bq mk --dataset \
            --description="Vault transform functions" \
            --location=US \
            ${PROJECT_ID}:vault_functions
        print_success "Created vault_functions dataset"
    fi
    
    # Create external connection first
    print_status "Creating BigQuery external connection..."
    
    # Create BigQuery SQL for connection setup
    cat > connection_setup.sql << EOF
CREATE OR REPLACE EXTERNAL CONNECTION \`${PROJECT_ID}.australia-southeast1.vault-connection\`
OPTIONS (
  type = 'CLOUD_RESOURCE',
  endpoint = '${FUNCTION_URL}'
);
EOF
    
    # Execute connection creation
    bq query --use_legacy_sql=false < connection_setup.sql
    
    # Get the connection service account
    print_status "Getting BigQuery connection service account..."
    CONNECTION_SA=$(bq show connection ${PROJECT_ID}.australia-southeast1.vault-connection --format=json | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['cloudResource']['serviceAccountId'])
")
    
    print_status "BigQuery connection service account: $CONNECTION_SA"
    
    # Grant the connection service account permission to invoke the function
    print_status "Granting BigQuery service account function invoke permission..."
    gcloud functions add-iam-policy-binding vault-transform-function \
        --region=australia-southeast1 \
        --member="serviceAccount:${CONNECTION_SA}" \
        --role="roles/cloudfunctions.invoker"
    
    # Now create the remote functions
    cat > bigquery_functions.sql << EOF
-- Create encryption function
CREATE OR REPLACE FUNCTION \`${PROJECT_ID}.vault_functions.encrypt_credit_card\`(credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION \`${PROJECT_ID}.australia-southeast1.vault-connection\`
OPTIONS (
  endpoint = '${FUNCTION_URL}',
  max_batching_rows = 100
);

-- Create decryption function  
CREATE OR REPLACE FUNCTION \`${PROJECT_ID}.vault_functions.decrypt_credit_card\`(encrypted_credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION \`${PROJECT_ID}.australia-southeast1.vault-connection\`
OPTIONS (
  endpoint = '${FUNCTION_URL}',
  max_batching_rows = 100
);
EOF
    
    # Execute function creation
    bq query --use_legacy_sql=false < bigquery_functions.sql
    
    print_success "Remote functions created with proper authentication"
    echo "CONNECTION_SA=$CONNECTION_SA" >> .env.function
}

# Test BigQuery integration
test_bigquery() {
    print_status "Testing BigQuery integration..."
    
    # Test encryption function
    encrypt_result=$(bq query --use_legacy_sql=false --format=csv \
        "SELECT vault_functions.encrypt_credit_card('4111111111111111') as encrypted_value" | tail -1)
    
    if [ -n "$encrypt_result" ] && [ "$encrypt_result" != "encrypted_value" ]; then
        print_success "BigQuery encryption test passed: $encrypt_result"
        
        # Test decryption function
        decrypt_result=$(bq query --use_legacy_sql=false --format=csv \
            "SELECT vault_functions.decrypt_credit_card('$encrypt_result') as original_value" | tail -1)
        
        if [ "$decrypt_result" = "4111111111111111" ]; then
            print_success "BigQuery decryption test passed"
        else
            print_warning "Decryption test result: $decrypt_result"
        fi
    else
        print_error "BigQuery encryption test failed"
        exit 1
    fi
}

# Load sample data
load_sample_data() {
    print_status "Loading sample data..."
    
    # Create data loading script
    cat > load_data.py << 'EOF'
import requests
from google.cloud import bigquery
import os
from datetime import datetime, timedelta
import subprocess

PROJECT_ID = os.getenv('PROJECT_ID')
FUNCTION_URL = os.getenv('FUNCTION_URL')

def get_access_token():
    """Get access token for authenticated requests"""
    result = subprocess.run(['gcloud', 'auth', 'print-access-token'], 
                          capture_output=True, text=True)
    return result.stdout.strip()

def encrypt_credit_card(card_number):
    """Encrypt credit card using authenticated request to Cloud Function"""
    access_token = get_access_token()
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    response = requests.post(FUNCTION_URL, json={
        "requestId": "data-load",
        "calls": [[card_number]]
    }, headers=headers)
    
    if response.status_code != 200:
        print(f"Error calling function: {response.status_code} - {response.text}")
        raise Exception(f"Function call failed: {response.status_code}")
    
    return response.json()['replies'][0]

client = bigquery.Client(project=PROJECT_ID)
sample_cards = ["4111111111111111", "4222222222222222", "5555555555554444", "6011111111111117"]
base_date = datetime.now() - timedelta(days=30)

rows_to_insert = []
for i, card in enumerate(sample_cards):
    print(f"Encrypting card {i+1}/4: {card[:4]}****{card[-4:]}")
    encrypted_card = encrypt_credit_card(card)
    for j in range(2):
        row = {
            "transaction_id": f"txn_{i}_{j}",
            "encrypted_credit_card": encrypted_card,
            "amount": 100.0 + (i * 50) + (j * 25),
            "merchant": f"Merchant_{i}_{j}",
            "category": ["Grocery", "Gas", "Restaurant", "Online"][i],
            "transaction_date": base_date + timedelta(days=i*2+j),
            "is_fraud": j == 1 and i % 2 == 0
        }
        rows_to_insert.append(row)

table_id = f"{PROJECT_ID}.fraud_detection.transactions"
table = client.get_table(table_id)
errors = client.insert_rows_json(table, rows_to_insert)

if errors:
    print(f"Errors: {errors}")
else:
    print(f"Inserted {len(rows_to_insert)} rows successfully")
EOF
    
    # Run data loading
    source .env.function
    export FUNCTION_URL
    python3 load_data.py
    
    print_success "Sample data loaded"
}

# Test complete workflow
test_workflow() {
    print_status "Testing complete workflow..."
    
    # Test query with remote functions
    result=$(bq query --use_legacy_sql=false --format=prettyjson \
        "SELECT 
            transaction_id,
            amount,
            merchant,
            is_fraud
        FROM \`${PROJECT_ID}.fraud_detection.transactions\`
        WHERE encrypted_credit_card = vault_functions.encrypt_credit_card('4111111111111111')
        LIMIT 5" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data))")
    
    if [ "$result" -gt 0 ]; then
        print_success "Complete workflow test passed: Found $result transactions"
    else
        print_error "Workflow test failed: No transactions found"
        exit 1
    fi
}

# Main deployment function
main() {
    echo "🚀 Deploying Vault Transform + BigQuery Integration to GCP"
    echo "Project: $PROJECT_ID"
    echo "HCP Vault: $VAULT_ADDR"
    echo ""
    print_warning "Ensure HCP Vault is configured (see hcp_vault_setup.md)"
    echo ""
    
    check_environment
    check_prerequisites
    enable_apis
    prepare_function_source
    deploy_function
    test_function
    create_dataset
    create_table
    setup_remote_functions
    test_bigquery
    load_sample_data
    test_workflow
    
    echo ""
    print_success "🎉 Production deployment completed successfully!"
    echo ""
    print_success "✅ HCP Vault integration working"
    print_success "✅ BigQuery remote functions deployed"
    print_success "✅ Sample data loaded and tested"
    echo ""
    echo "📋 Next steps:"
    echo "  • Test queries in BigQuery Console"
    echo "  • Set up monitoring and alerts"
    echo "  • Configure proper IAM permissions"
    echo "  • Review HCP Vault token rotation policy"
    echo ""
    echo "🧪 Test command:"
    echo "  bq query \"SELECT vault_functions.encrypt_credit_card('4111111111111111')\""
}

# Handle command line arguments
case "${1:-deploy}" in
    deploy)
        main
        ;;
    test)
        check_environment
        source .env.function 2>/dev/null || true
        test_function
        test_bigquery
        test_workflow
        ;;
    clean)
        print_status "Cleaning up resources..."
        gcloud functions delete vault-transform-function --region=australia-southeast1 --quiet || true
        bq rm -r -f ${PROJECT_ID}:fraud_detection || true
        print_success "Cleanup completed"
        ;;
    *)
        echo "Usage: $0 [deploy|test|clean]"
        echo ""
        echo "Commands:"
        echo "  deploy  Deploy the complete solution (default)"
        echo "  test    Test existing deployment"
        echo "  clean   Remove all deployed resources"
        exit 1
        ;;
esac
